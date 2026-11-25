class_name TreeMesh
extends RefCounted
## Maillage de l'arbre à l'instant t (semaines), rendu en cel shading :
## - chaque axe (tronc, branche, rameau) est un tube continu, tracé et épaisseur lissés, écorce procédurale ;
## - orme : une feuille par nœud (pétiole et limbe ovale en géométrie), ancrée au nœud ;
## - pin : aiguilles par paires dessinées en géométrie (deux triangles fins croisés).

const SIDES := 12
const LEAF_PTS := 14                       # points du bord d'un côté de la feuille
const YOUNG := Color(0.55, 0.47, 0.38, 0.35)  # rameau de l'année : gris-brun lisse
const SELECTED := Color(0.95, 0.2, 0.12, 0.7)
const WEAK := Color(0.8, 0.7, 0.35, 0.3)     # branche qui s'affaiblit à l'ombre
const DRY := Color(0.85, 0.82, 0.75, 0.7)    # bois mort
const OLD := Color(1, 1, 1, 0)               # écorce seule
const AUTUMN := Color(1.0, 0.72, 0.3)

var sim: TreeSim
var t := 0.0
var verts := PackedVector3Array()
var norms := PackedVector3Array()
var uvs := PackedVector2Array()
var uv2s := PackedVector2Array()
var nverts := PackedVector3Array()  # aiguilles
var ncols := PackedColorArray()
var cols := PackedColorArray()
var idx := PackedInt32Array()
var lverts := PackedVector3Array()  # feuilles
var lnorms := PackedVector3Array()
var lcols := PackedColorArray()


## Renvoie [ArrayMesh du bois, ArrayMesh des feuilles, ArrayMesh des aiguilles].
static func build(s: TreeSim, highlight: PackedInt32Array, time: float, leaves: bool) -> Array:
	var m := TreeMesh.new()
	m.sim = s
	m.t = time
	return m._build(highlight, leaves)


## Matériau cel shading (voir shaders/toon.gdshader), avec contour optionnel.
static func toon(pattern: int, color := Color.WHITE, outline := false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/toon.gdshader")
	mat.set_shader_parameter("pattern", pattern)
	mat.set_shader_parameter("albedo", color)
	if outline:
		var o := ShaderMaterial.new()
		o.shader = preload("res://shaders/outline.gdshader")
		mat.next_pass = o
	return mat


static func bark_material(s: TreeSim) -> ShaderMaterial:
	var mat := toon(1 if s.leaf_years == 0 else 2, Color.WHITE, true)
	for k in 4:
		mat.set_shader_parameter(["tone1", "tone2", "tone3", "fissure"][k], s.bark_colors[k])
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
		var col := YOUNG.lerp(OLD, clampf((t - s.born) / 52.0, 0.0, 1.0))
		if marked.has(i):
			col = SELECTED
		elif s.dry:
			col = DRY
		elif weak[i] == 1:
			col = WEAK
		seg_col[i] = col
	for i in n:
		var s := sim.segs[i]
		if seg_f[i] <= 0.0:
			continue
		if s.parent < 0 or sim.segs[s.parent].main_child != i:
			_axis(i, seg_f, seg_col)
		if leaves and not s.dry:
			_foliage(s, seg_f[i], weak[i] == 1, marked.has(i))
	if n > 0:
		_nebari()
	return [_wood_mesh(), _leaf_mesh(), _needle_mesh()]


## Un axe : la suite des prolongements depuis i0, en un seul tube à l'épaisseur lissée.
func _axis(i0: int, seg_f: PackedFloat32Array, seg_col: PackedColorArray) -> void:
	var chain: Array[int] = []
	var k := i0
	while k >= 0 and seg_f[k] > 0.0:
		chain.append(k)
		if seg_f[k] < 1.0:
			break
		k = sim.segs[k].main_child
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
		if rc > 0.5 * pr:
			# Grosse branche : fourche en Y. Elle naît dans le parent, sur son axe, un peu sous le nœud,
			# et s'en écarte doucement, comme deux troncs qui se séparent.
			raw.insert(0, raw[0] - (par.end - par.start).normalized() * pr * 1.5)
			r.insert(0, minf(pr * 0.85, rc * 1.1))
			r[1] = rc * 1.05
			off = 1
		else:
			# Petite branche : départ enfoncé dans le parent, avec un léger col.
			raw[0] -= (raw[1] - raw[0]).normalized() * pr * 0.5
			r[0] = minf(rc * 1.2, pr * 0.9)
	# Continuité (règle des anneaux) : un anneau n'est jamais plus épais que celui qui le précède.
	for m in range(1, r.size()):
		r[m] = minf(r[m], r[m - 1])
	# Décimation : anneaux espacés d'au moins 2,5 rayons, sinon un tube épais se replie dans les virages
	# (c'était le tronc « en morceaux »).
	var pts: Array[Vector3] = [raw[0]]
	var rad := PackedFloat32Array([r[0]])
	var col := PackedColorArray([seg_col[i0]])
	for m in range(1, raw.size()):
		if m == raw.size() - 1 or raw[m].distance_to(pts[-1]) >= 2.5 * rad[rad.size() - 1]:
			pts.append(raw[m])
			rad.append(r[m])
			col.append(seg_col[chain[clampi(m - off, 0, chain.size() - 1)]])
	# Lissage de Chaikin (coupe les angles sans jamais dépasser, contrairement à une spline)
	for it in 3:
		if pts.size() < 3:
			break
		var np: Array[Vector3] = [pts[0]]
		var nr := PackedFloat32Array([rad[0]])
		var nc := PackedColorArray([col[0]])
		for m in pts.size() - 1:
			np.append(pts[m] * 0.75 + pts[m + 1] * 0.25)
			np.append(pts[m] * 0.25 + pts[m + 1] * 0.75)
			nr.append(rad[m] * 0.75 + rad[m + 1] * 0.25)
			nr.append(rad[m] * 0.25 + rad[m + 1] * 0.75)
			nc.append(col[m])
			nc.append(col[m + 1])
		np.append(pts[-1])
		nr.append(rad[rad.size() - 1])
		nc.append(col[col.size() - 1])
		pts = np
		rad = nr
		col = nc
	var d := (pts[1] - pts[0]).normalized()
	var a := _perp(d)
	var v := 0.0
	var axis_seed := i0 * 0.37  # irrégularités propres à chaque axe
	var prev := _ring(pts[0], d, a, rad[0], v, col[0], axis_seed)
	_cap(prev, pts[0] - d * rad[0] * 0.5, false)
	for m in range(1, pts.size()):
		d = (pts[m] - pts[m - 1]).normalized()
		if m + 1 < pts.size():
			d = (d + (pts[m + 1] - pts[m]).normalized()).normalized()
		a = (a - d * a.dot(d)).normalized()  # transport parallèle : le tube ne se vrille pas
		v += (pts[m] - pts[m - 1]).length()
		var cur := _ring(pts[m], d, a, maxf(rad[m], 0.0008), v, col[m], axis_seed)
		_join(prev, cur)
		prev = cur
	_cap(prev, pts[-1] + d * maxf(rad[rad.size() - 1], 0.0008) * 0.6, true)


## Ferme un bout de tube (pointe, coupe) par un petit cône : plus de tube creux visible.
## flip : sens des triangles pour que la face avant regarde dehors (nécessaire au contour).
func _cap(ring: int, tip: Vector3, flip: bool) -> void:
	var t0 := verts.size()
	verts.append(tip)
	norms.append((tip - verts[ring]).normalized())
	uvs.append(uvs[ring])
	uv2s.append(uv2s[ring])
	cols.append(cols[ring])
	for k in SIDES:
		idx.append(ring + k + (1 if flip else 0))
		idx.append(ring + k + (0 if flip else 1))
		idx.append(t0)


## Racines de surface provisoires, à la taille du tronc (en attendant les racines simulées).
func _nebari() -> void:
	var r := sim.segs[0].radius
	for k in 5:
		var ang := k * TAU / 5.0 + 0.5 * sin(k * 7.1)
		var dir := Vector3(cos(ang), 0, sin(ang))
		var pts := [dir * r * 0.6 + Vector3.UP * 0.003, dir * (r * 1.8 + 0.008), dir * (r * 2.8 + 0.018) + Vector3.DOWN * 0.004]
		var rads := [r * 0.5, r * 0.28, r * 0.06]
		var prev := _ring(pts[0], dir, Vector3.UP, rads[0], 0.0, OLD)
		for q in range(1, 3):
			var cur := _ring(pts[q], (pts[q] - pts[q - 1]).normalized(), Vector3.UP, rads[q], q * 0.012, OLD)
			_join(prev, cur)
			prev = cur


func _perp(d: Vector3) -> Vector3:
	var a := d.cross(Vector3.UP)
	if a.length() < 0.01:
		a = d.cross(Vector3.RIGHT)
	return a.normalized()


## Anneau de SIDES+1 sommets (le dernier double le premier pour fermer le motif d'écorce).
## UV = (fraction du tour, longueur en m), UV2.x = nombre de cellules d'écorce (~2,5 mm) sur le tour.
func _ring(c: Vector3, d: Vector3, a: Vector3, r: float, v: float, col: Color, axis_seed := 0.0) -> int:
	a = (a - d * a.dot(d)).normalized()
	var b := d.cross(a)
	var cells := maxf(3.0, roundf(TAU * r / 0.0025))
	var base := verts.size()
	for k in SIDES + 1:
		var ang := TAU * k / SIDES
		var nrm := a * cos(ang) + b * sin(ang)
		# Anneaux légèrement irréguliers (bosses, méplats) qui varient doucement le long du bois ;
		# plus marqués sur le bois épais, nuls sur les rameaux fins.
		var bump := 1.0 + minf(0.12, r * 8.0) * (0.6 * sin(2.0 * ang + axis_seed * 7.3 + v * 35.0) + 0.4 * sin(3.0 * ang + axis_seed * 3.1 - v * 55.0))
		verts.append(c + nrm * r * bump)
		norms.append(nrm)
		uvs.append(Vector2(float(k) / SIDES, v))
		uv2s.append(Vector2(cells, 0))
		cols.append(col)
	return base


func _join(r0: int, r1: int) -> void:
	for k in SIDES:
		for q in [r0 + k, r1 + k, r0 + k + 1, r0 + k + 1, r1 + k, r1 + k + 1]:
			idx.append(q)


## Feuillage d'un segment : bouquet de feuilles (orme, pousses de l'année) ou touffe d'aiguilles (pin).
func _foliage(s: TreeSim.Seg, f: float, weak: bool, selected: bool) -> void:
	var h := fposmod(sin(s.end.x * 91.3 + s.end.y * 13.7 + s.end.z * 47.1) * 43758.5, 1.0)  # hasard fixe
	var col := Color.WHITE
	if sim.leaf_years > 0:
		if t - s.born <= sim.leaf_years * 52:
			_needles(s, f, h, weak, selected)
		return
	else:
		if floori(s.born / 52.0) != floori(t / 52.0):
			return
		var w := fposmod(t, 52.0)
		if w > 44.0 + h * 4.0:  # chute étalée sur novembre
			return
		col = Color.WHITE.lerp(AUTUMN, clampf((w - 40.0) / 5.0, 0.0, 1.0))
	if weak:
		if h < 0.4:
			return
		col *= Color(1.0, 0.9, 0.55)
	if selected:
		col = Color(1.0, 0.35, 0.3)
	# Feuille d'orme : pétiole de 3 mm au nœud qui se prolonge en nervure centrale (liseré sombre),
	# limbe ovale le plus large sous le milieu, pointe aiguë, base oblique, bord finement denté, contour fin,
	# 5 paires de nervures. Limbe presque horizontal dans le prolongement du bourgeon (alternes, deux rangs).
	var dir := Vector3(s.lat_dir.x, s.lat_dir.y * 0.3, s.lat_dir.z).normalized()
	var side := Vector3.UP.cross(dir).normalized().rotated(dir, (h - 0.5) * 0.8)
	var nrm := dir.cross(side).normalized()
	var l := sim.foliage_size * f
	var wmax := l * 0.27
	var b0 := s.end + dir * 0.003 * f  # base du limbe, au bout du pétiole
	if not selected:
		col *= Color(0.35, 0.62, 0.22) if h < 0.5 else Color(0.28, 0.55, 0.2)
	var ink := Color(0.08, 0.14, 0.06)
	var vein := col.darkened(0.25)
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
	for q in [p0, p1, p2]:
		lverts.append(q)
		lnorms.append(nrm)
		lcols.append(col)


## Aiguilles de pin par paires le long de la pousse : chacune = deux triangles fins croisés,
## visibles sous tous les angles. Trois verts mélangés.
func _needles(s: TreeSim.Seg, f: float, h: float, weak: bool, selected: bool) -> void:
	var greens := [Color(0.16, 0.36, 0.22), Color(0.22, 0.45, 0.27), Color(0.12, 0.3, 0.2)]
	var d := (s.end - s.start).normalized()
	var l := (s.end - s.start).length() * f
	var a := _perp(d)
	var b := d.cross(a)
	var pairs := clampi(int(l / 0.002), 1, 10)
	var nl := 0.03 * f
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
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
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
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
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
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh
