class_name TreeMesh
extends RefCounted
## Rendu voxel : l'arbre à l'instant t (semaines) est converti en cubes de 3 mm, dessinés en une seule
## MultiMesh. Seule la surface des branches est remplie. Feuilles d'orme ou aiguilles de pin en touffes,
## nebari provisoire au pied. Pot, terre et mousse en voxels aussi.

const V := 0.003                         # taille d'un voxel (m)
const YOUNG := Color(0.5, 0.7, 0.25)     # pousse de l'année
const SELECTED := Color(0.95, 0.2, 0.12)
const WEAK := Color(0.9, 0.75, 0.2)      # branche qui s'affaiblit à l'ombre
const DRY := Color(0.88, 0.85, 0.78)     # bois mort
const LEAF := Color(0.3, 0.68, 0.18)
const LEAF_AUTUMN := Color(0.95, 0.65, 0.12)
const LEAF_LEN := 0.02                   # orme : petite feuille ovale (~2 cm)
const NEEDLE := Color(0.1, 0.45, 0.25)
const NEEDLE_LEN := 0.035                # pin noir en bonsaï : aiguilles de 3 à 5 cm
const SHADER := preload("res://shaders/voxel.gdshader")

var sim: TreeSim
var t := 0.0
var vox := {}  # clé entière -> Color


static func build(s: TreeSim, highlight: PackedInt32Array, time: float, leaves: bool) -> MultiMesh:
	var m := TreeMesh.new()
	m.sim = s
	m.t = time
	m._tree(highlight, leaves)
	return m._multimesh()


static func material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	return mat


## Pot émaillé, terre et touches de mousse (fixe).
static func pot() -> MultiMesh:
	var m := TreeMesh.new()
	var glaze := Color(0.15, 0.4, 0.65)
	var y := -0.06
	while y <= 0.0:
		var r := lerpf(0.1, 0.12, (y + 0.06) / 0.06)
		var n := ceili(TAU * r / (V * 0.7))
		for k in n:
			var a := TAU * k / n
			m._put(Vector3(cos(a) * r, y, sin(a) * r), glaze)
		y += V
	var x := -0.12
	while x <= 0.12:
		var z := -0.12
		while z <= 0.12:
			if Vector2(x, z).length() < 0.117:
				var moss := sin(x * 90.0) * sin(z * 110.0) + sin((x + z) * 60.0) > 1.1
				m._put(Vector3(x, -0.004, z), Color(0.35, 0.62, 0.2) if moss else Color(0.42, 0.3, 0.2))
			z += V
		x += V
	return m._multimesh()


func _key(p: Vector3) -> int:
	return (floori(p.x / V) + 1024) | ((floori(p.y / V) + 1024) << 11) | ((floori(p.z / V) + 1024) << 22)


func _put(p: Vector3, c: Color, force := false) -> void:
	var k := _key(p)
	if force or not vox.has(k):
		vox[k] = c


func _multimesh() -> MultiMesh:
	var cube := BoxMesh.new()
	cube.size = Vector3(V, V, V)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = cube
	mm.instance_count = vox.size()
	var buf := PackedFloat32Array()
	buf.resize(vox.size() * 16)
	var i := 0
	for k: int in vox:
		var c: Color = vox[k]
		var h := 0.93 + 0.14 * float((k * 2654435761) & 255) / 255.0  # légère variation par voxel
		buf[i] = 1.0
		buf[i + 3] = ((k & 2047) - 1024 + 0.5) * V
		buf[i + 5] = 1.0
		buf[i + 7] = (((k >> 11) & 2047) - 1024 + 0.5) * V
		buf[i + 10] = 1.0
		buf[i + 11] = (((k >> 22) & 2047) - 1024 + 0.5) * V
		buf[i + 12] = c.r * h
		buf[i + 13] = c.g * h
		buf[i + 14] = c.b * h
		buf[i + 15] = 1.0
		i += 16
	mm.buffer = buf
	return mm


func _tree(highlight: PackedInt32Array, leaves: bool) -> void:
	var n := sim.segs.size()
	var marked := {}
	for i in highlight:
		marked[i] = true
	var weak := PackedByteArray()
	weak.resize(n)
	for i in n:
		var s := sim.segs[i]
		weak[i] = 1 if s.weak > 0 or (s.parent >= 0 and weak[s.parent] == 1) else 0
		var f := sim.growth(s, t)
		if f <= 0.0:
			continue
		var col := YOUNG.lerp(sim.bark, clampf((t - s.born) / 52.0, 0.0, 1.0))
		var sel := marked.has(i)
		if sel:
			col = SELECTED
		elif s.dry:
			col = DRY
		elif weak[i] == 1:
			col = col.lerp(WEAK, 0.7)
		# Épaisseur lissée le long de l'axe : du rayon du segment à celui de son prolongement.
		var ra := s.radius * (1.7 if i == 0 else 1.0)
		var rb := sim.segs[s.main_child].radius if s.main_child >= 0 and f >= 1.0 else sim.tip_radius
		var tip := s.start + (s.end - s.start) * f
		_tube(s.start, tip, ra, minf(rb, s.radius), col, sel)
		if leaves and not s.dry:
			var d := (s.end - s.start).normalized()
			if sim.leaf_years > 0:
				_needles(s, d, (tip - s.start).length(), weak[i] == 1, sel)
			else:
				_leaf(s, f, weak[i] == 1, sel)
	if n > 0:
		_nebari()


## Tube creux d'un rayon à l'autre : anneaux de voxels (un seul voxel quand c'est plus fin).
func _tube(a: Vector3, b: Vector3, ra: float, rb: float, c: Color, force: bool) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.00001:
		_put(a, c, force)
		return
	d /= l
	var u := _perp(d)
	var w := d.cross(u)
	var steps := maxi(1, ceili(l / (V * 0.7)))
	for i in steps + 1:
		var f := float(i) / steps
		var p := a + d * (l * f)
		var r := lerpf(ra, rb, f)
		if r < V * 2.5:
			_put(p, c, force)
		if r < V * 0.8:
			continue
		var m := ceili(TAU * r / (V * 0.7))
		for k in m:
			var ang := TAU * k / m
			var o := u * cos(ang) + w * sin(ang)
			_put(p + o * r, c, force)
			if r > V * 1.5:
				_put(p + o * (r - V * 0.8), c, force)


## Racines de surface provisoires, à la taille du tronc (en attendant les racines simulées).
func _nebari() -> void:
	var r := sim.segs[0].radius
	for k in 5:
		var ang := k * TAU / 5.0 + 0.5 * sin(k * 7.1)
		var dir := Vector3(cos(ang), 0, sin(ang))
		var p0 := dir * r * 0.6 + Vector3.UP * 0.003
		var p1 := dir * (r * 1.8 + 0.008)
		var p2 := dir * (r * 2.8 + 0.018) + Vector3.DOWN * 0.004
		_tube(p0, p1, r * 0.45, r * 0.25, sim.bark, false)
		_tube(p1, p2, r * 0.25, r * 0.06, sim.bark, false)


func _perp(d: Vector3) -> Vector3:
	var a := d.cross(Vector3.UP)
	if a.length() < 0.01:
		a = d.cross(Vector3.RIGHT)
	return a.normalized()


## Feuille de l'orme : une par nœud, seulement sur les pousses de l'année (caduc).
## Débourre avec la pousse, jaunit en octobre, tombe en novembre.
func _leaf(s: TreeSim.Seg, f: float, weak: bool, selected: bool) -> void:
	if floori(s.born / 52.0) != floori(t / 52.0):
		return
	var w := fposmod(t, 52.0)
	var h := fposmod(sin(s.end.x * 91.3 + s.end.y * 13.7 + s.end.z * 47.1) * 43758.5, 1.0)  # hasard fixe par feuille
	if w > 44.0 + h * 4.0:  # chute étalée sur novembre
		return
	if weak and h < 0.4:  # branche affaiblie : feuillage clairsemé
		return
	var col := LEAF.lerp(LEAF_AUTUMN, clampf((w - 40.0) / 5.0, 0.0, 1.0))
	if weak:
		col = col.lerp(WEAK, 0.6)
	if selected:
		col = SELECTED
	var n := (Vector3.UP * 0.8 + s.lat_dir * 0.2).normalized()
	var u := (s.lat_dir - n * s.lat_dir.dot(n)).normalized().rotated(n, (h - 0.5) * 0.8)
	var v := n.cross(u)
	var l := LEAF_LEN * f
	var p := s.end + s.lat_dir * 0.002
	var x := 0.0
	while x <= l:
		var half := l * 0.25 * sin(PI * x / maxf(l, 0.0001))
		var y := -half
		while y <= half + 0.0001:
			_put(p + u * x + v * y, col, selected)
			y += V * 0.8
		x += V * 0.8


## Aiguilles de pin : par paires, le long des pousses des dernières années (persistantes).
func _needles(s: TreeSim.Seg, d: Vector3, l: float, weak: bool, selected: bool) -> void:
	if t - s.born > sim.leaf_years * 52:
		return
	var col := NEEDLE.lerp(WEAK, 0.6) if weak else NEEDLE
	if selected:
		col = SELECTED
	var a := _perp(d)
	var b := d.cross(a)
	var pairs := clampi(int(l / 0.004), 1, 6)
	var nl := NEEDLE_LEN * sim.growth(s, t)
	var steps := maxi(1, ceili(nl / (V * 0.9)))
	for k in pairs:
		var p := s.start + d * l * (k + 0.5) / pairs
		var ang := s.phase + k * 2.4
		for side in [0.0, PI]:
			var r := a * cos(ang + side) + b * sin(ang + side)
			var dir := (d * 0.6 + r).normalized()
			for j in range(1, steps + 1):
				_put(p + dir * (nl * j / steps), col, selected)
