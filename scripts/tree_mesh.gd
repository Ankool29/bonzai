class_name TreeMesh
extends RefCounted
## Maillage de l'arbre en fin de période (t1, en semaines), rendu en cel shading. Chaque sommet porte ses
## dates (CUSTOM0 à 2) pour que shaders/anim.gdshaderinc joue la pousse de t0 à t1 sur la carte graphique :
## - chaque axe (tronc, branche, rameau) est un tube continu, tracé et épaisseur lissés, écorce procédurale ;
## - orme : une feuille par nœud (pétiole et limbe ovale en géométrie), ancrée au nœud ;
## - pin : aiguilles par paires dessinées en géométrie (deux triangles fins croisés).

const SIDES := 12
var sides := SIDES  # faces des anneaux en cours : 6 pour les rameaux fins et les bourgeons
static var all_roots := false  # rempotage (étape 23b) : toute la charpente racinaire, motte à nu
static var root_sel := -1      # racine choisie pour la coupe (surlignée avec tout ce qui en part)
const LEAF_PTS := 8                        # points du bord d'un côté de la feuille (audit, phase 2 : 14 avant)
const SELECTED := Color(0.95, 0.2, 0.12, 0.7)
const WEAK := Color(0.8, 0.7, 0.35, 0.3)     # branche qui s'affaiblit à l'ombre
const OLD := Color(1, 1, 1, 0)               # écorce seule (rameau de l'année et bois mort : dans le shader)
const NEVER := 1.0e9                         # date de disparition : jamais

var sim: TreeSim
var only := false  # surbrillance : seulement les entre-nœuds choisis (audit, phase 3)
var t := 0.0   # fin de période : état du maillage
var t0 := 0.0  # début de période
var wc0 := PackedFloat32Array()  # CUSTOM0-2 du bois (4 flottants par sommet)
var wc1 := PackedFloat32Array()
var wc2 := PackedFloat32Array()
var lc0 := PackedFloat32Array()  # CUSTOM0-1 des feuilles
var lc1 := PackedFloat32Array()
var lc2 := PackedFloat32Array()
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
var wire_phase := {}  # angle de la spirale du fil au bout de chaque entre-nœud (continuité d'un entre-nœud à l'autre)
var la0 := PackedFloat32Array([0, 0, 0, 0])  # dates de la feuille en cours (CUSTOM0)
var la1 := PackedFloat32Array([0, 0, 0, 0])  # point d'attache de la feuille en cours (CUSTOM1)
var la2 := PackedFloat32Array([0, 0, 0, 0])  # départ et allongement de son entre-nœud (CUSTOM2, étape 30a)
var luv := PackedVector2Array()   # feuilles : UV.x = 0 au centre du limbe, 1 au bord (contour tracé par le shader)
var luv2 := PackedVector2Array()  # feuilles : position dans le plan de la feuille (nervures tracées par le shader)
var lb0 := Vector3.ZERO           # repère de la feuille en cours : base du limbe, axe, côté, longueur
var ldir := Vector3.FORWARD
var lside := Vector3.RIGHT
var ll := 1.0


## Renvoie [ArrayMesh du bois, ArrayMesh des feuilles, ArrayMesh des aiguilles] pour la période t_start..t_end
## (t_start = t_end pour un arbre immobile). Appelable depuis un fil de calcul.
static func build(s: TreeSim, highlight: PackedInt32Array, t_start: float, t_end: float, leaves: bool) -> Array:
	var m := TreeMesh.new()
	m.sim = s
	m.t0 = t_start
	m.t = t_end
	return m._build(highlight, leaves)


## Surbrillance d'une sélection : seulement les entre-nœuds donnés, sans reconstruire tout l'arbre.
static func build_only(s: TreeSim, highlight: PackedInt32Array, leaves: bool) -> Array:
	var m := TreeMesh.new()
	m.sim = s
	m.t0 = s.week
	m.t = s.week
	m.only = true
	return m._build(highlight, leaves)


## Pierre de l'étape 29b : sphère déformée par la même forme que la simulation (RootSim.rock_radius).
static func rock_mesh(rs: RootSim) -> ArrayMesh:
	var sph := SphereMesh.new()
	sph.radial_segments = 32
	sph.rings = 20
	var a := sph.get_mesh_arrays()
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	for i in v.size():
		var u := v[i].normalized()
		v[i] = rs.rock_c + u * rs.rock_radius(u)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	for k in idx:
		st.add_vertex(v[k])
	st.generate_normals()
	return st.commit()


static func rock_material() -> ShaderMaterial:
	var m := toon(0, Color(0.55, 0.53, 0.5), true)
	m.next_pass.set_shader_parameter("width", 0.0015)
	return m


## Nombre de sommets d'un dessin (mesure).
static func vertex_count(m: Array) -> int:
	var n := 0
	for mesh in m:
		if mesh is ArrayMesh:
			for k in mesh.get_surface_count():
				n += mesh.surface_get_array_len(k)
	return n


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
	var mat := toon(2 if s.leaf_years > 0 else [1, 4, 6][s.leaf_shape], Color.WHITE, true, 1)  # écorce selon l'espèce
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
	if only:
		for i in n:
			if not marked.has(i):
				seg_f[i] = 0.0
	# Hiérarchie des axes : à chaque nœud, l'enfant le plus gros continue l'axe (quel que soit son bourgeon),
	# les autres ouvrent un axe d'ordre suivant. Après une coupe, la branche qui reprend prolonge l'axe.
	var year_now := floorf(t / 52.0)
	var spring: float = year_now * 52.0 + float(sim.flushes.keys().min())
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
		if s.parent < 0 or cont[s.parent] != i or seg_f[s.parent] <= 0.0:
			_axis(i, seg_f, seg_col)
		if leaves and not s.dry:
			_foliage(s, weak[i] == 1, marked.has(i))
			# Rameaux courts : au printemps, un bourgeon latéral dormant du bois de 1 à 5 ans débourre en rosette
			# de feuilles sans s'allonger (2 feuilles, 1 pour les bourgeons opposés). Purement visuel.
			if sim.leaf_years == 0 and weak[i] == 0 and s.lat_bud and s.lat_child < 0:
				var age := year_now - floorf(s.born / 52.0)
				if age >= 1.0 and age <= sim.spur_years and spring <= t:
					_foliage(s, false, marked.has(i), 0.6, 0.8, spring)
					if not sim.opposite:
						_foliage(s, false, marked.has(i), -0.6, 0.55, spring)
		if not s.dry and seg_f[i] >= 1.0 and t - s.born < 156.0:
			_buds(s)
		if seg_f[i] > 0.0 and (s.wire > 0 or s.mark > 0.05):
			_wire_helix(i, s)
		if s.wound_r > 0.0:
			_wound(s)
	if n > 0 and not only:
		_roots()
	if not only:
		_fallen()
	return [_wood_mesh(), _leaf_mesh(), _needle_mesh()]


## Un axe : la suite des prolongements depuis i0, en un seul tube à l'épaisseur lissée.
func _axis(i0: int, seg_f: PackedFloat32Array, seg_col: PackedColorArray) -> void:
	sides = 6 if sim.segs[i0].radius < 0.00075 else SIDES  # rameau de moins de 1,5 mm : 6 faces suffisent
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
	# Lissage de Chaikin (coupe les angles sans jamais dépasser, contrairement à une spline). Chaque passe double
	# les anneaux : 3 passes sur les axes épais, 1 sur les rameaux fins (audit : ×8 anneaux partout avant).
	for it in (3 if sides == SIDES else 1):
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
		var cur := _ring(pts[m], d, a, maxf(rad[m], 0.00025), v, col[m], axis_seed, an[0], an[1], NEVER,
				_flutes(lat, pts[m], pidx[m], d, rad[m]))
		_join(prev, cur)
		prev = cur
	_cap(prev, pts[-1] + d * maxf(rad[rad.size() - 1], 0.00025) * 0.6, true)


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


## Bourgeons vivants du bois de moins de 3 ans : latéral à l'aisselle (plaqué contre le rameau), terminal au bout.
func _buds(s: TreeSim.Seg) -> void:
	sides = 4  # bourgeon de 1 à 2 mm : 4 faces suffisent
	var axis := (s.end - s.start).normalized()
	var born := s.born + s.grow_time
	var small := 0.7 if sim.whorl > 0 else 1.0  # pin : bourgeons de la couronne plus petits que le terminal
	if s.lat_bud and s.lat_child < 0:
		var side := (s.lat_dir - axis * axis.dot(s.lat_dir)).normalized()
		_bud(s.end + side * s.radius * 0.8, (s.lat_dir.normalized() + axis).normalized(), sim.bud_size * small, born)
	if s.term_bud and s.main_child < 0:
		_bud(s.end, axis, sim.bud_size * (1.0 if sim.whorl > 0 else 1.2), born)


## Fil de ligature en spirale à 45° autour de l'entre-nœud (aluminium, cuivre pour le pin), d'un tiers du
## diamètre de la branche, qui s'enfonce quand il mord ; après son retrait, marque sombre dans l'écorce.
func _wire_helix(i: int, s: TreeSim.Seg) -> void:
	var d := s.end - s.start
	var l := d.length()
	if l < 0.00001:
		return
	var wr := maxf(0.0002, s.radius / 3.0)
	var col: Color = (Color(0.72, 0.42, 0.22) if sim.whorl > 0 else Color(0.72, 0.72, 0.74)) if s.wire > 0 \
			else sim.bark_colors[3]
	var rad := s.radius + wr * (1.0 - 0.7 * s.mark) if s.wire > 0 else s.radius
	if s.wire == 0:
		wr *= 0.5 * s.mark
	var dn := d / l
	var a := _perp(dn)
	var b := dn.cross(a)
	var ph: float = wire_phase.get(s.parent, 0.0)
	var turns := l / (TAU * rad)  # 45° : un tour par longueur de circonférence
	var n := maxi(3, ceili(turns * 8.0))
	var a0 := Vector4(-1000.0, 1.0, 1.0, -1.0)
	sides = 4
	var prev := -1
	var pc := Vector3.ZERO
	for q in n + 1:
		var ang := ph + TAU * turns * q / n
		var c := s.start + d * (float(q) / n) + (a * cos(ang) + b * sin(ang)) * rad
		var tg := (c - pc).normalized() if q > 0 else dn
		var cur := _ring(c, tg, _perp(tg), wr, 0.0, col, 0.0, a0, Vector4.ZERO)
		if prev < 0:
			_cap(cur, c - tg * wr, false)
		else:
			_join(prev, cur)
		prev = cur
		pc = c
	_cap(prev, pc + dn * wr, true)
	wire_phase[i] = ph + TAU * turns


## Bourgeon ovale (base, ventre, pointe), couleur unie de l'espèce, contour compris.
func _bud(p: Vector3, d: Vector3, l: float, born: float) -> void:
	var a0 := Vector4(born, 1.0, 1.0, -1.0)
	var a := _perp(d)
	var r := l * 0.32
	var r0 := _ring(p, d, a, r * 0.7, 0.0, sim.bud_color, 0.0, a0, Vector4.ZERO)
	var r1 := _ring(p + d * l * 0.45, d, a, r, 0.0, sim.bud_color, 0.0, a0, Vector4.ZERO)
	_join(r0, r1)
	_cap(r1, p + d * l, true)


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
	for k in sides:
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
	for k in sides + 1:
		var ang := TAU * k / sides
		verts.append(c + (a * cos(ang) + b * sin(ang)) * r if k < sides else c)
		norms.append(n)
		uvs.append(Vector2.ZERO)
		uv2s.append(Vector2(3, 0))
		cols.append(col)
		wc0.append_array([-1000.0, 1.0, 1.0, -1.0])
		wc1.append_array([c.x, c.y, c.z, NEVER])
		wc2.append_array([c.x, c.y, c.z, 0.0])
	for k in sides:
		idx.append(base + sides)
		idx.append(base + (k + 1) % sides)
		idx.append(base + k)


## Racines de surface provisoires, à la taille du tronc (en attendant les racines simulées).
## Racines qui dépassent de la terre (étape 23a, RootSim) : chaque racine suit son prolongement le plus gros,
## en un tube dont l'épaisseur passe en douceur d'un entre-nœud à l'autre ; elle s'arrête un entre-nœud
## après avoir plongé sous la terre. Le reste de la charpente, enterré, n'est pas dessiné.
func _roots() -> void:
	var rs := sim.root
	var n := rs.size()
	var cont := PackedInt32Array()
	cont.resize(n)
	cont.fill(-1)
	for i in n:
		var p := rs.par[i]
		if p >= 0 and (cont[p] < 0 or rs.rad[i] > rs.rad[cont[p]]):
			cont[p] = i
	var a0 := Vector4(-1000.0, 1.0, 1.0, -1.0)
	var sel := {}
	if root_sel >= 0 and root_sel < n:
		sel[root_sel] = true
		for j in range(root_sel + 1, n):
			if sel.has(rs.par[j]):
				sel[j] = true
	for i in n:
		var p := rs.par[i]
		if (p >= 0 and cont[p] == i) or (rs.p0[i].y + rs.rad[i] < rs.soil_y - 0.001 and not all_roots):
			continue  # prolongement d'un axe, ou départ enterré
		sides = 6 if rs.rad[i] < 0.0015 else SIDES
		var d := rs.dir[i]
		var prev := _ring(rs.p0[i], d, _perp(d), rs.rad[i], 0.0, SELECTED if sel.has(i) else OLD, i * 1.3, a0, Vector4.ZERO)
		_cap(prev, rs.p0[i] - d * rs.rad[i] * 0.5, false)
		var v := 0.0
		var j := i
		var last := rs.p0[i]
		while j >= 0:
			var nx := cont[j]
			var r: float = (rs.rad[j] + rs.rad[nx]) * 0.5 if nx >= 0 else rs.rad[j] * 0.7
			d = rs.dir[j]
			v += RootSim.RI
			var cur := _ring(rs.p1[j], d, _perp(d), r, v, SELECTED if sel.has(j) else OLD, i * 1.3, a0, Vector4.ZERO)
			_join(prev, cur)
			prev = cur
			last = rs.p1[j]
			if rs.p1[j].y + r < rs.soil_y - 0.001 and not all_roots:
				break  # la racine a plongé
			j = nx
		_cap(prev, last + d * 0.002, true)


func _perp(d: Vector3) -> Vector3:
	var a := d.cross(Vector3.UP)
	if a.length() < 0.01:
		a = d.cross(Vector3.RIGHT)
	return a.normalized()


## Anneau de sides+1 sommets (le dernier double le premier pour fermer le motif d'écorce).
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
	for k in sides + 1:
		var ang := TAU * k / sides
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
		uvs.append(Vector2(float(k) / sides, v))
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
	sides = 6  # brindilles tombées
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
	for k in sides:
		for q in [r0 + k, r1 + k, r0 + k + 1, r0 + k + 1, r1 + k, r1 + k + 1]:
			idx.append(q)


## Feuillage d'un segment sur la période : feuilles d'orme (pousses de l'année, jusqu'à leur chute en
## novembre) ou aiguilles de pin (pendant leaf_years ans). Dessiné à pleine taille ; le shader le fait
## pousser, jaunir et tomber.
## turn, scale, born : feuille de rosette (tournée autour de la verticale, plus petite, née au printemps).
func _foliage(s: TreeSim.Seg, weak: bool, selected: bool, turn := 0.0, scale := 1.0, born := -1.0) -> void:
	var h := fposmod(sin(s.end.x * 91.3 + s.end.y * 13.7 + s.end.z * 47.1) * 43758.5, 1.0)  # hasard fixe
	var col := Color.WHITE
	if sim.leaf_years > 0:
		var gone := s.born + sim.leaf_years * 52.0
		if gone >= t0:
			_needles(s, h, weak, selected, gone)
		return
	var b := s.born if born < 0.0 else born
	var shrink := 1.0
	if s.defol >= 0.0 and t >= s.defol and floorf(s.defol / 52.0) == floorf(t / 52.0):
		# effeuillé (étape 28) : plus de feuille, puis une feuille plus petite au « mini-printemps »
		if t < s.defol + TreeSim.DEFOL_REGROW:
			return
		b = s.defol + TreeSim.DEFOL_REGROW
		shrink = 0.65
	var fall := floorf(b / 52.0) * 52.0 + 44.0 + h * sim.fall_span  # chute étalée sur novembre (ginkgo : quelques jours)
	if fall < t0:
		return
	if weak:
		if h < 0.4:
			return
		col *= Color(1.0, 0.9, 0.55)
	if sim.vigor_now() < 0.25:
		col *= Color(1.0, 0.9, 0.55)  # arbre épuisé : feuillage jaunissant
	if selected:
		col = Color(1.0, 0.35, 0.3)
	# la feuille grandit ~3 semaines de plus que sa tige ; elle suit la pointe pendant que l'entre-nœud s'allonge
	la0 = PackedFloat32Array([b, s.grow_time + 3.0 if born < 0.0 else 2.0, fall, 0.0])
	la1 = PackedFloat32Array([s.end.x, s.end.y, s.end.z, 0.0])
	la2 = PackedFloat32Array([s.start.x, s.start.y, s.start.z, s.grow_time if b == s.born else 0.0])
	# Feuille d'orme : pétiole de 3 mm au nœud qui se prolonge en nervure centrale (liseré sombre),
	# limbe ovale le plus large sous le milieu, pointe aiguë, base oblique, bord finement denté, contour fin,
	# 5 paires de nervures. Limbe presque horizontal dans le prolongement du bourgeon (alternes, deux rangs).
	var dir := Vector3(s.lat_dir.x, s.lat_dir.y * 0.3, s.lat_dir.z).normalized().rotated(Vector3.UP, turn)
	var side := Vector3.UP.cross(dir).normalized().rotated(dir, (h - 0.5) * 0.8)
	var nrm := dir.cross(side).normalized()
	var l := sim.foliage_size * (0.6 + 0.4 * s.leaf_k) * s.size_k * scale * shrink  # plus petites à la base, sur une pousse faible, après un effeuillage
	var wmax := l * 0.27
	var b0 := s.end + dir * 0.003  # base du limbe, au bout du pétiole
	lb0 = b0
	ldir = dir
	lside = side
	ll = l
	if not selected:
		col *= sim.leaf_colors[0] if h < 0.5 else sim.leaf_colors[1]  # vert propre à l'espèce
	var ink := Color(0.08, 0.14, 0.06)
	var vein := col.darkened(0.25)
	if sim.leaf_shape == 1:
		_palmate(s.end, dir, side, nrm, l, 5 if h < 0.6 else 7, col, ink, vein)
		return
	if sim.leaf_shape == 2:
		_fan(s.end, dir, side, nrm, l, born < 0.0, col, ink, vein)  # rosette des rameaux courts : sans échancrure
		return
	# contour : côté droit de la base à la pointe, puis côté gauche (plus étroit) de la pointe à la base
	var cont: Array[Vector3] = [b0]
	for k in range(1, LEAF_PTS + 1):
		cont.append(_leaf_pt(b0, dir, side, l, wmax, k, 1.0))
	for k in range(LEAF_PTS - 1, 0, -1):
		cont.append(_leaf_pt(b0, dir, side, l, wmax, k, -0.85))
	var c := b0 + dir * l * 0.42
	for k in cont.size():  # contour et nervures : tracés par le shader (audit, phase 2)
		_tri(c, cont[k], cont[(k + 1) % cont.size()], nrm, col, Vector3(0, 1, 1))
	_line(s.end, b0, 0.00025, nrm, ink)  # pétiole


## Feuille d'érable : long pétiole, limbe palmé de 5 ou 7 lobes lancéolés dentés, sinus profonds,
## une nervure par lobe. Contour en étoile autour de la base du limbe, rempli en éventail.
func _palmate(node: Vector3, dir: Vector3, side: Vector3, nrm: Vector3, l: float, lobes: int, col: Color, ink: Color, vein: Color) -> void:
	var r := l * 0.32                      # rayon du limbe
	var b0 := node + dir * l * 0.36        # base du limbe, au bout du pétiole
	lb0 = b0
	col.a = lobes / 10.0  # le shader trace une nervure par lobe
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
		for k in 4:
			var t := k / 3.0
			cont.append(pt.call(a - _lobe_w(t) * gap, lerpf(r * 0.3, len_i, t) * (1.0 + 0.05 * (k % 2))))
		tips.append(pt.call(a, len_i))
		for k in range(2, -1, -1):
			var t := k / 3.0
			cont.append(pt.call(a + _lobe_w(t) * gap, lerpf(r * 0.3, len_i, t) * (1.0 + 0.05 * (k % 2))))
		if i < lobes - 1:
			cont.append(pt.call(a + gap * 0.5, r * 0.25))  # fond du sinus
	cont.append(pt.call(spread + gap * 0.5, r * 0.12))
	for k in cont.size():
		_tri(b0, cont[k], cont[(k + 1) % cont.size()], nrm, col, Vector3(0, 1, 1))
	_line(node, b0, 0.0003, nrm, ink)  # pétiole


## Feuille de ginkgo : long pétiole, limbe en éventail à base en coin, bord ondulé ; échancrure au milieu
## sur les pousses longues (feuille bilobée). Nervures en éventail tracées par le shader. Dessin : check/fan.py.
func _fan(node: Vector3, dir: Vector3, side: Vector3, nrm: Vector3, l: float, notch: bool, col: Color, ink: Color, vein: Color) -> void:
	var a_max := deg_to_rad(68.0)
	var r := l * 0.6
	var b0 := node + dir * l * 0.4  # base du limbe, au bout du pétiole
	lb0 = b0
	var cont: Array[Vector3] = []
	for k in 17:
		var a := -a_max + 2.0 * a_max * k / 16.0
		var rr := r * (1.0 - 0.08 * pow(a / a_max, 2.0)) * (1.0 + 0.025 * sin(k * 2.3))
		if notch:
			rr *= 1.0 - 0.42 * exp(-pow(a / 0.13, 2.0))
		cont.append(b0 + (dir * cos(a) + side * sin(a)) * rr)
	for k in 16:
		_tri(b0, cont[k], cont[k + 1], nrm, col, Vector3(0, 1, 1))
	_line(node, b0, 0.0003, nrm, ink)  # pétiole


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


func _tri(p0: Vector3, p1: Vector3, p2: Vector3, nrm: Vector3, col: Color, e := Vector3.ZERO) -> void:
	_lv(p0, nrm, col, e.x)
	_lv(p1, nrm, col, e.y)
	_lv(p2, nrm, col, e.z)


## Un sommet de feuille. e : 0 au centre du limbe, 1 au bord.
func _lv(p: Vector3, nrm: Vector3, col: Color, e: float) -> void:
	lverts.append(p)
	lnorms.append(nrm)
	lcols.append(col)
	lc0.append_array(la0)
	lc1.append_array(la1)
	lc2.append_array(la2)
	luv.append(Vector2(e, 0.0))
	var d := p - lb0
	luv2.append(Vector2(d.dot(ldir), d.dot(lside)) / ll)


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
					nc0.append_array([s.born + s.grow_time * (k + 0.5) / pairs, s.grow_time + 3.0, gone, 0.0])  # s'allonge après la chandelle
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
	arr[Mesh.ARRAY_TEX_UV] = luv
	arr[Mesh.ARRAY_TEX_UV2] = luv2
	var flags := _custom(arr, [lc0, lc1, lc2])
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
