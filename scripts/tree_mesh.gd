class_name TreeMesh
extends RefCounted
## Rendu pixel art texturé de l'arbre à l'instant t (semaines) :
## - chaque axe (tronc, branche, rameau) est un tube continu, épaisseur lissée, écorce texturée ;
## - le feuillage est une MultiMesh de petites images tournées vers la caméra (variantes d'un atlas).
## La scène est ensuite rendue en basse résolution par main.gd, d'où l'aspect pixel art.

const SIDES := 8
const TILE := 0.12                         # une texture d'écorce couvre 12 cm de long
const YOUNG := Color(0.55, 0.72, 0.3, 0.45)  # pousse de l'année : écorce verdie
const SELECTED := Color(0.95, 0.2, 0.12, 0.7)
const WEAK := Color(0.85, 0.7, 0.25, 0.45)   # branche qui s'affaiblit à l'ombre
const DRY := Color(0.85, 0.82, 0.75, 0.7)    # bois mort
const OLD := Color(1, 1, 1, 0)               # écorce seule
const AUTUMN := Color(1.0, 0.72, 0.3)

var sim: TreeSim
var t := 0.0
var verts := PackedVector3Array()
var norms := PackedVector3Array()
var uvs := PackedVector2Array()
var cols := PackedColorArray()
var idx := PackedInt32Array()
var cards: Array = []  # [position, taille, variante, teinte]


## Renvoie [ArrayMesh du bois, MultiMesh du feuillage].
static func build(s: TreeSim, highlight: PackedInt32Array, time: float, leaves: bool) -> Array:
	var m := TreeMesh.new()
	m.sim = s
	m.t = time
	return m._build(highlight, leaves)


static func bark_material(tex: Texture2D) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/bark.gdshader")
	mat.set_shader_parameter("tex", tex)
	return mat


static func foliage_material(tex: Texture2D, frames: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/foliage.gdshader")
	mat.set_shader_parameter("atlas", tex)
	mat.set_shader_parameter("frames", float(frames))
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
	return [_wood_mesh(), _cards_multimesh()]


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
	var s0 := sim.segs[i0]
	var d := (s0.end - s0.start).normalized()
	var a := _perp(d)
	var v := 0.0
	var prev := _ring(s0.start, d, a, r[0], v, seg_col[i0])
	for m in chain.size():
		var s := sim.segs[chain[m]]
		var tip := s.start + (s.end - s.start) * seg_f[chain[m]]
		d = (s.end - s.start).normalized()
		if m + 1 < chain.size():
			var nx := sim.segs[chain[m + 1]]
			d = (d + (nx.end - nx.start).normalized()).normalized()
		a = (a - d * a.dot(d)).normalized()  # transport parallèle : le tube ne se vrille pas
		v += (tip - s.start).length() / TILE
		var c := seg_col[chain[m + 1]] if m + 1 < chain.size() else seg_col[chain[m]]
		var cur := _ring(tip, d, a, r[m + 1], v, c)
		_join(prev, cur)
		prev = cur


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
			var cur := _ring(pts[q], (pts[q] - pts[q - 1]).normalized(), Vector3.UP, rads[q], q * 0.15, OLD)
			_join(prev, cur)
			prev = cur


func _perp(d: Vector3) -> Vector3:
	var a := d.cross(Vector3.UP)
	if a.length() < 0.01:
		a = d.cross(Vector3.RIGHT)
	return a.normalized()


## Anneau de SIDES+1 sommets (le dernier double le premier pour fermer la texture).
## La texture fait un nombre pair de tours (répétition en miroir sans raccord), environ 1 par 12 cm.
func _ring(c: Vector3, d: Vector3, a: Vector3, r: float, v: float, col: Color) -> int:
	a = (a - d * a.dot(d)).normalized()
	var b := d.cross(a)
	var turns := 2.0 * maxf(1.0, roundf(TAU * r / (2.0 * TILE)))
	var base := verts.size()
	for k in SIDES + 1:
		var ang := TAU * k / SIDES
		var nrm := a * cos(ang) + b * sin(ang)
		verts.append(c + nrm * r)
		norms.append(nrm)
		uvs.append(Vector2(turns * k / SIDES, v))
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
		if t - s.born > sim.leaf_years * 52:
			return
		# touffes au bout des pousses, et une partie le long des rameaux garnis
		var at_tip := s.term_bud or (s.main_child >= 0 and sim.segs[s.main_child].term_bud)
		if not at_tip and h > 0.3:
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
	# ombre : les bouquets à l'intérieur de la couronne sont plus sombres
	col *= lerpf(0.6, 1.0, clampf(s.light / maxf(s.count, 1) * 1.5, 0.0, 1.0))
	if selected:
		col = Color(1.0, 0.35, 0.3)
	var p := s.end + s.lat_dir * 0.004 + Vector3.DOWN * 0.004
	cards.append([p, sim.foliage_size * f, floori(h * sim.foliage_frames) % sim.foliage_frames, col])


func _wood_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


func _cards_multimesh() -> MultiMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = cards.size()
	for i in cards.size():
		var c: Array = cards[i]
		var sz: float = c[1]
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(sz, sz, sz)), c[0]))
		mm.set_instance_color(i, c[3])
		mm.set_instance_custom_data(i, Color(c[2], 0, 0, 0))
	return mm
