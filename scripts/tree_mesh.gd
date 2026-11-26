class_name TreeMesh
extends RefCounted
## Maillage de l'arbre en fin de période (t1, en semaines), rendu en cel shading. Chaque sommet porte ses
## dates (CUSTOM0 à 2) pour que shaders/anim.gdshaderinc joue la pousse de t0 à t1 sur la carte graphique :
## - chaque axe (tronc, branche, rameau) est un tube continu, tracé et épaisseur lissés, écorce procédurale ;
## - orme : une feuille par nœud (pétiole et limbe ovale en géométrie), ancrée au nœud ;
## - pin : aiguilles par paires dessinées en géométrie (deux triangles fins croisés).

const SIDES := 12
const LEAF_PTS := 14                       # points du bord d'un côté de la feuille
const SELECTED := Color(0.95, 0.2, 0.12, 0.7)
const WEAK := Color(0.8, 0.7, 0.35, 0.3)     # branche qui s'affaiblit à l'ombre
const OLD := Color(1, 1, 1, 0)               # écorce seule (rameau de l'année et bois mort : dans le shader)
const NEVER := 1.0e9                         # date de disparition : jamais

var sim: TreeSim
var t := 0.0   # fin de période : état du maillage
var t0 := 0.0  # début de période
var wc0 := PackedFloat32Array()  # CUSTOM0-2 du bois (4 flottants par sommet)
var wc1 := PackedFloat32Array()
var wc2 := PackedFloat32Array()
var lc0 := PackedFloat32Array()  # CUSTOM0-1 des feuilles
var lc1 := PackedFloat32Array()
var nc0 := PackedFloat32Array()  # CUSTOM0-1 des aiguilles
var nc1 := PackedFloat32Array()
var verts := PackedVector3Array()
var norms := PackedVector3Array()
var uvs := PackedVector2Array()
var uv2s := PackedVector2Array()
var nverts := PackedVector3Array()  # aiguilles
var ncols := PackedColorArray()
var cols := PackedColorArray()
var idx := PackedInt32Array()
var cont := PackedInt32Array()  # enfant qui continue l'axe (le plus gros), -1 au bout
var lverts := PackedVector3Array()  # feuilles
var lnorms := PackedVector3Array()
var lcols := PackedColorArray()
var lanim := [Vector4.ZERO, Vector3.ZERO]  # dates et point d'attache de la feuille en cours


## Renvoie [ArrayMesh du bois, ArrayMesh des feuilles, ArrayMesh des aiguilles] pour la période t_start..t_end
## (t_start = t_end pour un arbre immobile). Appelable depuis un fil de calcul.
static func build(s: TreeSim, highlight: PackedInt32Array, t_start: float, t_end: float, leaves: bool) -> Array:
	var m := TreeMesh.new()
	m.sim = s
	m.t0 = t_start
	m.t = t_end
	return m._build(highlight, leaves)


## Matériau cel shading (voir shaders/toon.gdshader), avec contour optionnel.
static func toon(pattern: int, color := Color.WHITE, outline := false, anim := 0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/toon.gdshader")
	mat.set_shader_parameter("pattern", pattern)
	mat.set_shader_parameter("albedo", color)
	mat.set_shader_parameter("anim", anim)
	if outline:
		var o := ShaderMaterial.new()
		o.shader = preload("res://shaders/outline.gdshader")
		o.set_shader_parameter("anim", anim)
		mat.next_pass = o
	return mat


## Instant affiché par un matériau animé (et son contour).
static func set_time(mat: ShaderMaterial, time: float, t_start: float, t_end: float) -> void:
	while mat:
		mat.set_shader_parameter("anim_time", time)
		mat.set_shader_parameter("anim_t0", t_start)
		mat.set_shader_parameter("anim_t1", t_end)
		mat = mat.next_pass as ShaderMaterial


static func bark_material(s: TreeSim) -> ShaderMaterial:
	var mat := toon(1 if s.leaf_years == 0 else 2, Color.WHITE, true, 1)
	for k in 4:
		mat.set_shader_parameter(["tone1", "tone2", "tone3", "fissure"][k], s.bark_colors[k])
	mat.set_shader_parameter("young_color", s.young_color)
	return mat


func _build(highlight: PackedInt32Array, leaves: bool) -> Array:
	var n := sim.segs.size()
	var marked := {}
	for i in highlight:
		marked[i] = true
	var weak := PackedByteArray()
	weak.resize(n)
	var seg_f := PackedFloat32Array()
	seg_f.resize(n)
	var seg_col := PackedColorArray()
	seg_col.resize(n)
	for i in n:
		var s := sim.segs[i]
		weak[i] = 1 if s.weak > 0 or (s.parent >= 0 and weak[s.parent] == 1) else 0
		seg_f[i] = sim.growth(s, t)
		var col := OLD
		if marked.has(i):
			col = SELECTED
		elif weak[i] == 1 and not s.dry:
			col = WEAK
		seg_col[i] = col
	# Hiérarchie des axes : à chaque nœud, l'enfant le plus gros continue l'axe (quel que soit son bourgeon),
	# les autres ouvrent un axe d'ordre suivant. Après une coupe, la branche qui reprend prolonge l'axe.
	cont.resize(n)
	for i in n:
		var s := sim.segs[i]
		var mc := s.main_child if s.main_child >= 0 and seg_f[s.main_child] > 0.0 else -1
		var lc := s.lat_child if s.lat_child >= 0 and seg_f[s.lat_child] > 0.0 else -1
		cont[i] = lc if lc >= 0 and (mc < 0 or sim.segs[lc].radius > sim.segs[mc].radius) else mc
	for i in n:
		var s := sim.segs[i]
		if seg_f[i] <= 0.0:
			continue
		if s.parent < 0 or cont[s.parent] != i:
			_axis(i, seg_f, seg_col)
		if leaves and not s.dry:
			_foliage(s, weak[i] == 1, marked.has(i))
		if s.wound_r > 0.0:
			_wound(s)
	if n > 0:
		_nebari()
	_fallen()
	return [_wood_mesh(), _leaf_mesh(), _needle_mesh()]


## Un axe : la suite des prolongements depuis i0, en un seul tube à l'épaisseur lissée.
func _axis(i0: int, seg_f: PackedFloat32Array, seg_col: PackedColorArray) -> void:
	var chain: Array[int] = []
	var k := i0
	while k >= 0 and seg_f[k] > 0.0:
		chain.append(k)
		if seg_f[k] < 1.0:
			break
		k = cont[k]
	# rayons aux anneaux : début de chaque segment puis pointe, lissés pour effacer les à-coups
	var r := PackedFloat32Array()
	for j in chain:
		r.append(sim.segs[j].radius)
	r.append(sim.tip_radius)
	for pass_i in 3:
		var sm := r.duplicate()
		for m in range(1, r.size() - 1):
			sm[m] = (r[m - 1] + 2.0 * r[m] + r[m + 1]) * 0.25
		r = sm
	if i0 == 0:  # pied du tronc : évasement
		r[0] *= 1.8
	var raw: Array[Vector3] = [sim.segs[i0].start]
	for m in chain.size():
		var s := sim.segs[chain[m]]
		raw.append(s.start + (s.end - s.start) * seg_f[chain[m]])
	var off := 0  # décalage entre raw et chain quand un point est ajouté au départ
	if sim.segs[i0].parent >= 0:
		var par := sim.segs[sim.segs[i0].parent]
		var pr := par.radius
		var rc := r[0]
		if rc > 0.7 * pr:
			# Grosse branche : fourche en Y. Elle naît dans le parent, sur son axe, un peu sous le nœud,
			# et s'en écarte doucement, comme deux troncs qui se séparent.
			raw.insert(0, raw[0] - (par.end - par.start).normalized() * pr * 1.5)
			r.insert(0, minf(pr * 0.85, rc * 1.1))
			r[1] = rc * 1.05
			off = 1
		else:
			# Collet : la branche part de l'axe du porteur, renflée à sa sortie (plus dessous), puis reprend
			# son diamètre ; les cernes du porteur et de la branche se chevauchent à la jonction.
			var node := raw[0]
			var d0 := (raw[1] - node).normalized()
			raw.insert(1, node + d0 * pr * 0.9 - Vector3.UP * rc * 0.25)
			r.insert(1, rc * 1.35)
			r[0] = minf(rc * 1.8, pr * 0.9)
			off = 1
			var p2 := node + d0 * (pr + rc * 2.5)
			if p2.distance_to(node) < raw[2].distance_to(node) * 0.8:
				raw.insert(2, p2)
				r.insert(2, rc * 1.08)
				off = 2
	# Continuité (règle des anneaux) : un anneau n'est jamais plus épais que celui qui le précède.
	for m in range(1, r.size()):
		r[m] = minf(r[m], r[m - 1])
	# Décimation : anneaux espacés d'au moins 2,5 rayons, sinon un tube épais se replie dans les virages
	# (c'était le tronc « en morceaux »).
	var pts: Array[Vector3] = [raw[0]]
	var rad := PackedFloat32Array([r[0]])
	var col := PackedColorArray([seg_col[i0]])
	var pidx := PackedFloat32Array([0.0])  # position de l'anneau en indice de raw (pour retrouver son entre-nœud)
	for m in range(1, raw.size()):
		if m <= off or m == raw.size() - 1 or raw[m].distance_to(pts[-1]) >= 2.5 * rad[rad.size() - 1]:
			pts.append(raw[m])
			rad.append(r[m])
			col.append(seg_col[chain[clampi(m - off, 0, chain.size() - 1)]])
			pidx.append(m)
	# Lissage de Chaikin (coupe les angles sans jamais dépasser, contrairement à une spline)
	for it in 3:
		if pts.size() < 3:
			break
		var np: Array[Vector3] = [pts[0]]
		var nr := PackedFloat32Array([rad[0]])
		var ncl := PackedColorArray([col[0]])
		var npar := PackedFloat32Array([pidx[0]])
		for m in pts.size() - 1:
			np.append(pts[m] * 0.75 + pts[m + 1] * 0.25)
			np.append(pts[m] * 0.25 + pts[m + 1] * 0.75)
			nr.append(rad[m] * 0.75 + rad[m + 1] * 0.25)
			nr.append(rad[m] * 0.25 + rad[m + 1] * 0.75)
			ncl.append(col[m])
			ncl.append(col[m + 1])
			npar.append(pidx[m] * 0.75 + pidx[m + 1] * 0.25)
			npar.append(pidx[m] * 0.25 + pidx[m + 1] * 0.75)
		np.append(pts[-1])
		nr.append(rad[rad.size() - 1])
		ncl.append(col[col.size() - 1])
		npar.append(pidx[pidx.size() - 1])
		pts = np
		rad = nr
		col = ncl
		pidx = npar
	# Branches portées assez grosses : le bois de chacune descend dans l'axe et y forme une côte (cannelure).
	var lat := []  # [nœud, indice dans raw, direction, rayon]
	for m in chain.size():
		var j := chain[m]
		for c in [sim.segs[j].main_child, sim.segs[j].lat_child]:
			if c >= 0 and c != cont[j] and seg_f[c] > 0.0 and sim.segs[c].radius > 0.15 * sim.segs[j].radius:
				lat.append([sim.segs[j].end, float(m + 1 + off), (sim.segs[c].end - sim.segs[c].start).normalized(), sim.segs[c].radius])
	var d := (pts[1] - pts[0]).normalized()
	var a := _perp(d)
	var v := 0.0
	var axis_seed := i0 * 0.37  # irrégularités propres à chaque axe
	var an := _ring_anim(pidx[0], chain, off, seg_f)
	var prev := _ring(pts[0], d, a, rad[0], v, col[0], axis_seed, an[0], an[1], NEVER, _flutes(lat, pts[0], pidx[0], d, rad[0]))
	_cap(prev, pts[0] - d * rad[0] * 0.5, false)
	for m in range(1, pts.size()):
		d = (pts[m] - pts[m - 1]).normalized()
		if m + 1 < pts.size():
			d = (d + (pts[m + 1] - pts[m]).normalized()).normalized()
		a = (a - d * a.dot(d)).normalized()  # transport parallèle : le tube ne se vrille pas
		v += (pts[m] - pts[m - 1]).length()
		an = _ring_anim(pidx[m], chain, off, seg_f)
		var cur := _ring(pts[m], d, a, maxf(rad[m], 0.0004), v, col[m], axis_seed, an[0], an[1], NEVER,
				_flutes(lat, pts[m], pidx[m], d, rad[m]))
		_join(prev, cur)
		prev = cur
	_cap(prev, pts[-1] + d * maxf(rad[rad.size() - 1], 0.0004) * 0.6, true)


## Côtes d'un anneau : une par branche portée plus haut, qui s'efface en descendant (sur 12 rayons de branche).
func _flutes(lat: Array, c: Vector3, p: float, d: Vector3, r: float) -> Array:
	var out := []
	for l in lat:
		if l[1] <= p:
			continue
		var f: float = 1.0 - c.distance_to(l[0]) / (12.0 * l[3])
		if f <= 0.0:
			continue
		var fd: Vector3 = l[2] - d * d.dot(l[2])
		if fd.length() < 0.1:
			continue
		out.append([fd.normalized(), minf(0.6, 0.5 * l[3] / maxf(r, 0.000001)) * f])
	return out


## Ferme un bout de tube (pointe, coupe) par un petit cône : plus de tube creux visible.
## flip : sens des triangles pour que la face avant regarde dehors (nécessaire au contour).
func _cap(ring: int, tip: Vector3, flip: bool) -> void:
	var t0 := verts.size()
	verts.append(tip)
	norms.append((tip - verts[ring]).normalized())
	uvs.append(uvs[ring])
	uv2s.append(uv2s[ring])
	cols.append(cols[ring])
	for e in 4:
		wc0.append(wc0[ring * 4 + e])
		wc1.append(wc1[ring * 4 + e])
		wc2.append(wc2[ring * 4 + e])
	for k in SIDES:
		idx.append(ring + k + (1 if flip else 0))
		idx.append(ring + k + (0 if flip else 1))
		idx.append(t0)


## Plaie de taille : disque de bois clair cerné d'un bourrelet d'écorce qui se referme avec les cernes.
func _wound(s: TreeSim.Seg) -> void:
	var n := s.wound_dir
	var c := s.end + n * (s.radius * 0.85 if s.wound_side else 0.0)
	_disc(c, n, s.wound_full * 1.2, Color(0.42, 0.34, 0.27, 1.0))  # bourrelet
	_disc(c + n * 0.0003, n, s.wound_r, Color(0.86, 0.76, 0.56, 1.0))  # bois à nu


## Disque plat (face avant vers n), immobile pendant l'animation.
func _disc(c: Vector3, n: Vector3, r: float, col: Color) -> void:
	var a := _perp(n)
	var b := n.cross(a)
	var base := verts.size()
	for k in SIDES + 1:
		var ang := TAU * k / SIDES
		verts.append(c + (a * cos(ang) + b * sin(ang)) * r if k < SIDES else c)
		norms.append(n)
		uvs.append(Vector2.ZERO)
		uv2s.append(Vector2(3, 0))
		cols.append(col)
		wc0.append_array([-1000.0, 1.0, 1.0, -1.0])
		wc1.append_array([c.x, c.y, c.z, NEVER])
		wc2.append_array([c.x, c.y, c.z, 0.0])
	for k in SIDES:
		idx.append(base + SIDES)
		idx.append(base + (k + 1) % SIDES)
		idx.append(base + k)


## Racines de surface provisoires, à la taille du tronc (en attendant les racines simulées).
func _nebari() -> void:
	# Racines de surface : 4 à 7, qui rayonnent depuis l'évasement du tronc et s'enfoncent dans la terre ;
	# plus longues chez l'érable. Elles suivent l'épaississement du tronc.
	var r := sim.segs[0].radius
	var n := 4 + int(absf(sin(sim.segs[0].lat_dir.x * 91.7 + sim.planted)) * 40.0) % 4
	var l := r * (2.5 + 1.5 * (1.4 if sim.leaf_shape == 1 else 1.0))
	var a0 := Vector4(-1000.0, 1.0, _ratio(sim.segs[0]), -1.0)
	for k in n:
		var ang := k * TAU / n + 0.5 * sin(k * 7.1)
		var prev := -1
		var pc := Vector3.ZERO
		var d := Vector3.ZERO
		for q in 7:
			var t := q / 6.0
			var a2 := ang + 0.25 * sin(k * 3.3 + t * 4.0)
			var dr := Vector3(cos(a2), 0.0, sin(a2))
			var c := dr * (r * 0.7 + l * t) + Vector3.UP * (r * 0.5 * pow(1.0 - t, 2.0) - 0.003 * t)
			var rr := r * 0.55 * pow(1.0 - t, 0.9) + 0.0008
			d = dr if q == 0 else (c - pc).normalized()
			var cur := _ring(c, d, Vector3.UP, rr, t * 0.02, OLD, k * 1.3, a0, Vector4.ZERO)
			if prev < 0:
				_cap(cur, c - d * rr * 0.5, false)
			else:
				_join(prev, cur)
			prev = cur
			pc = c
		_cap(prev, pc + d * 0.002, true)


func _perp(d: Vector3) -> Vector3:
	var a := d.cross(Vector3.UP)
	if a.length() < 0.01:
		a = d.cross(Vector3.RIGHT)
	return a.normalized()


## Anneau de SIDES+1 sommets (le dernier double le premier pour fermer le motif d'écorce).
## UV = (fraction du tour, longueur en m), UV2.x = nombre de cellules d'écorce (~2,5 mm) sur le tour.
## a0 = (naissance, durée d'allongement, épaisseur début/fin, séchage), a2 = (départ de la pousse, part de
## l'entre-nœud) ; voir shaders/anim.gdshaderinc. a2 nul : l'anneau suit son propre centre.
func _ring(c: Vector3, d: Vector3, a: Vector3, r: float, v: float, col: Color, axis_seed: float,
		a0: Vector4, a2: Vector4, vanish := NEVER, flutes := []) -> int:
	if a2 == Vector4.ZERO:
		a2 = Vector4(c.x, c.y, c.z, 0.0)
	a = (a - d * a.dot(d)).normalized()
	var b := d.cross(a)
	# Bois de réaction : sur un bois penché, le cœur est décentré ; plus de bois dessous chez le pin,
	# dessus chez les feuillus.
	var up := Vector3.UP - d * d.y
	var lean := up * r * 0.12 * (-1.0 if sim.leaf_years > 0 else 1.0) if up.length() > 0.01 else Vector3.ZERO
	var cells := maxf(3.0, roundf(TAU * r / 0.0025))
	var base := verts.size()
	for k in SIDES + 1:
		var ang := TAU * k / SIDES
		var nrm := a * cos(ang) + b * sin(ang)
		# Anneaux irréguliers (bosses, méplats, renflements) qui varient doucement le long du bois ;
		# plus marqués sur le bois épais, nuls sur les rameaux fins.
		var amp := minf(0.22, r * 14.0)
		var bump := 1.0 + amp * (0.45 * sin(2.0 * ang + axis_seed * 7.3 + v * 35.0)
				+ 0.3 * sin(3.0 * ang + axis_seed * 3.1 - v * 55.0)
				+ 0.15 * sin(5.0 * ang + axis_seed * 1.7 + v * 90.0)
				+ 0.25 * sin(v * 22.0 + axis_seed * 5.0))  # renflements le long du bois
		for f in flutes:
			bump += f[1] * pow(maxf(0.0, nrm.dot(f[0])), 3.0)
		verts.append(c + lean + nrm * r * bump)
		norms.append(nrm)
		uvs.append(Vector2(float(k) / SIDES, v))
		uv2s.append(Vector2(cells, 0))
		cols.append(col)
		wc0.append_array([a0.x, a0.y, a0.z, a0.w])
		wc1.append_array([c.x, c.y, c.z, vanish])
		wc2.append_array([a2.x, a2.y, a2.z, a2.w])
	return base


## Données d'animation d'un anneau à la position p (indice de raw) : son entre-nœud et la part de celui-ci
## que la pointe doit avoir parcourue pour l'atteindre.
func _ring_anim(p: float, chain: Array[int], off: int, seg_f: PackedFloat32Array) -> Array:
	var m := ceili(p - 0.0001)  # indice de raw de la fin de l'entre-nœud
	var j := chain[0]
	var u := 0.0
	if m > off:
		j = chain[clampi(m - 1 - off, 0, chain.size() - 1)]
		u = clampf(p - (m - 1), 0.0, 1.0) * seg_f[j]
	var s := sim.segs[j]
	var dry := float(s.dry_week) if s.dry else -1.0
	return [Vector4(s.born, s.grow_time, _ratio(s), dry), Vector4(s.start.x, s.start.y, s.start.z, u)]


## Épaisseur en début de période / épaisseur en fin de période.
func _ratio(s: TreeSim.Seg) -> float:
	var r0 := s.r0 if s.r0 > 0.0 else sim.tip_radius
	return clampf(r0 / maxf(s.radius, 0.000001), 0.0, 1.0)


## Rameaux morts tombés pendant la période : dessinés jusqu'à leur chute.
func _fallen() -> void:
	for fl in sim.fallen:
		var st: Vector3 = fl[0]
		var en: Vector3 = fl[1]
		var d := (en - st).normalized()
		var a := _perp(d)
		var a0 := Vector4(-1000.0, 1.0, 1.0, fl[3])
		var p := _ring(st, d, a, fl[2], 0.0, OLD, 0.0, a0, Vector4.ZERO, fl[4])
		var q := _ring(en, d, a, fl[2] * 0.8, (en - st).length(), OLD, 0.0, a0, Vector4.ZERO, fl[4])
		_join(p, q)


func _join(r0: int, r1: int) -> void:
	for k in SIDES:
		for q in [r0 + k, r1 + k, r0 + k + 1, r0 + k + 1, r1 + k, r1 + k + 1]:
			idx.append(q)


## Feuillage d'un segment sur la période : feuilles d'orme (pousses de l'année, jusqu'à leur chute en
## novembre) ou aiguilles de pin (pendant leaf_years ans). Dessiné à pleine taille ; le shader le fait
## pousser, jaunir et tomber.
func _foliage(s: TreeSim.Seg, weak: bool, selected: bool) -> void:
	var h := fposmod(sin(s.end.x * 91.3 + s.end.y * 13.7 + s.end.z * 47.1) * 43758.5, 1.0)  # hasard fixe
	var col := Color.WHITE
	if sim.leaf_years > 0:
		var gone := s.born + sim.leaf_years * 52.0
		if gone >= t0:
			_needles(s, h, weak, selected, gone)
		return
	var fall := floorf(s.born / 52.0) * 52.0 + 44.0 + h * 4.0  # chute étalée sur novembre
	if fall < t0:
		return
	if weak:
		if h < 0.4:
			return
		col *= Color(1.0, 0.9, 0.55)
	if selected:
		col = Color(1.0, 0.35, 0.3)
	lanim = [Vector4(s.born, s.grow_time, fall, 0.0), s.end]
	# Feuille d'orme : pétiole de 3 mm au nœud qui se prolonge en nervure centrale (liseré sombre),
	# limbe ovale le plus large sous le milieu, pointe aiguë, base oblique, bord finement denté, contour fin,
	# 5 paires de nervures. Limbe presque horizontal dans le prolongement du bourgeon (alternes, deux rangs).
	var dir := Vector3(s.lat_dir.x, s.lat_dir.y * 0.3, s.lat_dir.z).normalized()
	var side := Vector3.UP.cross(dir).normalized().rotated(dir, (h - 0.5) * 0.8)
	var nrm := dir.cross(side).normalized()
	var l := sim.foliage_size * (0.6 + 0.4 * s.leaf_k)  # feuilles plus petites à la base de la pousse
	var wmax := l * 0.27
	var b0 := s.end + dir * 0.003  # base du limbe, au bout du pétiole
	if not selected:
		col *= Color(0.35, 0.62, 0.22) if h < 0.5 else Color(0.28, 0.55, 0.2)
	var ink := Color(0.08, 0.14, 0.06)
	var vein := col.darkened(0.25)
	if sim.leaf_shape == 1:
		_palmate(s.end, dir, side, nrm, l, 5 if h < 0.6 else 7, col, ink, vein)
		return
	# contour : côté droit de la base à la pointe, puis côté gauche (plus étroit) de la pointe à la base
	var cont: Array[Vector3] = [b0]
	for k in range(1, LEAF_PTS + 1):
		cont.append(_leaf_pt(b0, dir, side, l, wmax, k, 1.0))
	for k in range(LEAF_PTS - 1, 0, -1):
		cont.append(_leaf_pt(b0, dir, side, l, wmax, k, -0.85))
	var c := b0 + dir * l * 0.42
	for k in cont.size():
		var p0 := cont[k]
		var p1 := cont[(k + 1) % cont.size()]
		_tri(c, p0, p1, nrm, col)
		# contour fin : ruban sombre juste à l'extérieur du limbe
		var o0 := p0 + (p0 - c).normalized() * 0.00035
		var o1 := p1 + (p1 - c).normalized() * 0.00035
		_tri(p0, o0, o1, nrm, ink)
		_tri(p0, o1, p1, nrm, ink)
	# pétiole + nervure centrale, puis nervures secondaires, légèrement décollés des deux faces
	_line(s.end, b0 + dir * l * 0.95, 0.00025, nrm, ink)
	for k in range(1, 6):
		var x := k / 6.0 * 0.85
		var x2 := x + 0.12
		var m0 := b0 + dir * l * x
		_line(m0, b0 + dir * l * x2 + side * _leaf_w(x2) * wmax * 0.85, 0.00012, nrm, vein)
		_line(m0, b0 + dir * l * x2 - side * _leaf_w(x2) * wmax * 0.72, 0.00012, nrm, vein)


## Feuille d'érable : long pétiole, limbe palmé de 5 ou 7 lobes lancéolés dentés, sinus profonds,
## une nervure par lobe. Contour en étoile autour de la base du limbe, rempli en éventail.
func _palmate(node: Vector3, dir: Vector3, side: Vector3, nrm: Vector3, l: float, lobes: int, col: Color, ink: Color, vein: Color) -> void:
	var r := l * 0.32                      # rayon du limbe
	var b0 := node + dir * l * 0.36        # base du limbe, au bout du pétiole
	var spread := deg_to_rad(105.0 if lobes == 7 else 95.0)  # angle du lobe le plus latéral
	var gap := spread * 2.0 / (lobes - 1)  # angle entre deux lobes
	var pt := func(ang: float, rad: float) -> Vector3: return b0 + (dir * cos(ang) + side * sin(ang)) * rad
	var cont: Array[Vector3] = []
	cont.append(pt.call(-spread - gap * 0.5, r * 0.12))
	var tips: Array[Vector3] = []
	for i in lobes:
		var a := -spread + gap * i
		var len_i := r * (1.0 - 0.35 * absf(a) / spread)  # lobes latéraux plus courts
		# bord gauche de la base vers la pointe, puis bord droit vers le sinus suivant ; dents une fois sur deux
		for k in 7:
			var t := k / 6.0
			cont.append(pt.call(a - _lobe_w(t) * gap, lerpf(r * 0.3, len_i, t) * (1.0 + 0.05 * (k % 2))))
		tips.append(pt.call(a, len_i))
		for k in range(5, -1, -1):
			var t := k / 6.0
			cont.append(pt.call(a + _lobe_w(t) * gap, lerpf(r * 0.3, len_i, t) * (1.0 + 0.05 * (k % 2))))
		if i < lobes - 1:
			cont.append(pt.call(a + gap * 0.5, r * 0.25))  # fond du sinus
	cont.append(pt.call(spread + gap * 0.5, r * 0.12))
	for k in cont.size():
		var p0 := cont[k]
		var p1 := cont[(k + 1) % cont.size()]
		_tri(b0, p0, p1, nrm, col)
		var o0 := p0 + (p0 - b0).normalized() * 0.00035
		var o1 := p1 + (p1 - b0).normalized() * 0.00035
		_tri(p0, o0, o1, nrm, ink)
		_tri(p0, o1, p1, nrm, ink)
	_line(node, b0, 0.0003, nrm, ink)
	for t in tips:
		_line(b0, b0 + (t - b0) * 0.9, 0.00012, nrm, vein)


## Demi-largeur angulaire d'un lobe d'érable (en fraction de l'écart entre lobes) : plus large au milieu, pointe aiguë.
func _lobe_w(t: float) -> float:
	return 0.42 * pow(1.0 - t, 1.1) * (1.0 + 1.5 * t)


## Point du bord de la feuille : x de 0 (base) à 1 (pointe), bord légèrement denté.
func _leaf_pt(b0: Vector3, dir: Vector3, side: Vector3, l: float, wmax: float, k: int, sgn: float) -> Vector3:
	var x := float(k) / LEAF_PTS
	var y := _leaf_w(x) * wmax * sgn
	if k < LEAF_PTS:
		y *= 1.0 + 0.08 * (k % 2)
	return b0 + dir * l * x + side * y


## Largeur relative du limbe (0 à 1) : maximum vers 40 % de la longueur, pointe aiguë.
func _leaf_w(x: float) -> float:
	return pow(x, 0.6) * pow(1.0 - x, 0.9) / 0.364


## Trait fin dans le plan de la feuille, dessiné sur les deux faces.
func _line(a: Vector3, b: Vector3, half_w: float, nrm: Vector3, col: Color) -> void:
	var w := (b - a).cross(nrm).normalized() * half_w
	for lift in [0.00012, -0.00012]:
		var o: Vector3 = nrm * lift
		_tri(a - w + o, b - w + o, b + w + o, nrm, col)
		_tri(a - w + o, b + w + o, a + w + o, nrm, col)


func _tri(p0: Vector3, p1: Vector3, p2: Vector3, nrm: Vector3, col: Color) -> void:
	var a0: Vector4 = lanim[0]
	var at: Vector3 = lanim[1]
	for q in [p0, p1, p2]:
		lverts.append(q)
		lnorms.append(nrm)
		lcols.append(col)
		lc0.append_array([a0.x, a0.y, a0.z, a0.w])
		lc1.append_array([at.x, at.y, at.z, 0.0])


## Aiguilles de pin par paires le long de la pousse : chacune = deux triangles fins croisés,
## visibles sous tous les angles. Trois verts mélangés.
func _needles(s: TreeSim.Seg, h: float, weak: bool, selected: bool, gone: float) -> void:
	if s.needle <= 0.0:
		return  # base nue de la chandelle, couronne de bourgeons
	var greens := [Color(0.16, 0.36, 0.22), Color(0.22, 0.45, 0.27), Color(0.12, 0.3, 0.2)]
	var d := (s.end - s.start).normalized()
	var l := (s.end - s.start).length()
	var a := _perp(d)
	var b := d.cross(a)
	var pairs := clampi(int(l / 0.002), 1, 10)
	var nl := 0.03 * s.needle
	for k in pairs:
		var p := s.start + d * l * (k + 0.5) / pairs
		var ang := s.phase + k * 2.4
		for side in [0.0, PI]:
			var r := a * cos(ang + side) + b * sin(ang + side)
			var dir := (d * 0.7 + r).normalized()
			var col: Color = greens[int(h * 7.0 + k + side) % 3]
			if weak:
				col = col.lerp(WEAK, 0.6)
			if selected:
				col = Color(1.0, 0.35, 0.3)
			for wv in [r.cross(dir).normalized() * 0.0007, r * 0.0007]:
				for q in [p - wv, p + wv, p + dir * nl]:
					nverts.append(q)
					ncols.append(col)
					# l'aiguille pousse quand la pousse atteint son niveau, depuis sa base
					nc0.append_array([s.born + s.grow_time * (k + 0.5) / pairs, s.grow_time, gone, 0.0])
					nc1.append_array([p.x, p.y, p.z, 0.0])


func _wood_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_TEX_UV2] = uv2s
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var flags := _custom(arr, [wc0, wc1, wc2])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
	return mesh


func _leaf_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if lverts.is_empty():
		return mesh
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = lverts
	arr[Mesh.ARRAY_NORMAL] = lnorms
	arr[Mesh.ARRAY_COLOR] = lcols
	var flags := _custom(arr, [lc0, lc1])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
	return mesh


func _needle_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if nverts.is_empty():
		return mesh
	var norm := PackedVector3Array()
	norm.resize(nverts.size())
	norm.fill(Vector3.UP)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = nverts
	arr[Mesh.ARRAY_NORMAL] = norm
	arr[Mesh.ARRAY_COLOR] = ncols
	var flags := _custom(arr, [nc0, nc1])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
	return mesh


## Canaux CUSTOM0-2 en 4 flottants par sommet (dates d'animation). Renvoie les drapeaux de format.
func _custom(arr: Array, chans: Array) -> int:
	var shifts := [Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT, Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT, Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT]
	var flags := 0
	for q in chans.size():
		arr[Mesh.ARRAY_CUSTOM0 + q] = chans[q]
		flags |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << shifts[q]
	return flags
