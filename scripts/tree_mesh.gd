class_name TreeMesh
extends RefCounted
## Construit le maillage de l'arbre à l'instant t (semaines) : chaque axe (tronc, branche, rameau) est
## un tube continu qui s'affine, les pousses en cours s'allongent, couleurs façon estampe selon l'âge
## et la santé. Feuilles d'orme ou aiguilles de pin, et un nebari provisoire au pied.

const SIDES := 6
const YOUNG := Color(0.58, 0.64, 0.38)   # pousse de l'année
const SELECTED := Color(0.85, 0.27, 0.18)  # vermillon
const WEAK := Color(0.84, 0.68, 0.3)     # branche qui s'affaiblit à l'ombre
const DRY := Color(0.8, 0.77, 0.7)       # bois mort
const LEAF := Color(0.45, 0.58, 0.33)    # vert sauge
const LEAF_AUTUMN := Color(0.86, 0.64, 0.26)
const LEAF_LEN := 0.02                   # orme : petite feuille ovale (~2 cm)
const NEEDLE := Color(0.18, 0.34, 0.3)   # vert sombre bleuté
const NEEDLE_LEN := 0.035                # pin noir en bonsaï : aiguilles de 3 à 5 cm

var sim: TreeSim
var t := 0.0
var verts := PackedVector3Array()
var norms := PackedVector3Array()
var cols := PackedColorArray()
var idx := PackedInt32Array()
var seg_col := PackedColorArray()
var seg_f := PackedFloat32Array()


static func build(s: TreeSim, highlight: PackedInt32Array, time: float, leaves: bool) -> ArrayMesh:
	var m := TreeMesh.new()
	m.sim = s
	m.t = time
	return m._build(highlight, leaves)


func _build(highlight: PackedInt32Array, leaves: bool) -> ArrayMesh:
	var n := sim.segs.size()
	var marked := {}
	for i in highlight:
		marked[i] = true
	var weak := PackedByteArray()
	weak.resize(n)
	seg_col.resize(n)
	seg_f.resize(n)
	for i in n:
		var s := sim.segs[i]
		weak[i] = 1 if s.weak > 0 or (s.parent >= 0 and weak[s.parent] == 1) else 0
		seg_f[i] = sim.growth(s, t)
		var col := YOUNG.lerp(sim.bark, clampf((t - s.born) / 52.0, 0.0, 1.0))
		if marked.has(i):
			col = SELECTED
		elif s.dry:
			col = DRY
		elif weak[i] == 1:
			col = col.lerp(WEAK, 0.7)
		seg_col[i] = col
	for i in n:
		var s := sim.segs[i]
		var starts_axis := s.parent < 0 or sim.segs[s.parent].main_child != i
		if starts_axis and seg_f[i] > 0.0:
			_axis(i)
		if leaves and not s.dry and seg_f[i] > 0.0:
			var d := (s.end - s.start).normalized()
			var l := (s.end - s.start).length() * seg_f[i]
			if sim.leaf_years > 0:
				_needles(s, d, l, weak[i] == 1, marked.has(i))
			else:
				_leaf(s, seg_f[i], weak[i] == 1, marked.has(i))
	if n > 0:
		_nebari()
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


## Un axe : la suite des prolongements depuis le segment i0, en un seul tube.
func _axis(i0: int) -> void:
	var chain: Array[int] = []
	var k := i0
	while k >= 0 and seg_f[k] > 0.0:
		chain.append(k)
		if seg_f[k] < 1.0:
			break
		k = sim.segs[k].main_child
	var s0 := sim.segs[i0]
	var dir0 := (s0.end - s0.start).normalized()
	var a := _perp(dir0)
	var r0 := s0.radius
	var c0 := s0.start
	if i0 == 0:  # pied du tronc : évasement
		r0 *= 1.7
		c0.y -= 0.005
	var prev := _ring(c0, dir0, a, r0, seg_col[i0])
	for m in chain.size():
		var s := sim.segs[chain[m]]
		var d := (s.end - s.start).normalized()
		var tip := s.start + (s.end - s.start) * seg_f[chain[m]]
		var nxt := chain[m + 1] if m + 1 < chain.size() else -1
		var r := sim.segs[nxt].radius if nxt >= 0 else sim.tip_radius
		var c := seg_col[nxt] if nxt >= 0 else seg_col[chain[m]]
		if nxt >= 0:
			d = (d + (sim.segs[nxt].end - sim.segs[nxt].start).normalized()).normalized()
		if i0 == 0 and m == 0:
			r = maxf(r, s.radius) * 1.15
		a = (a - d * a.dot(d)).normalized()  # transport parallèle : le tube ne se vrille pas
		var cur := _ring(tip, d, a, minf(r, s.radius * 1.15), c)
		_join(prev, cur)
		prev = cur


## Racines de surface provisoires, à la taille du tronc (en attendant les racines simulées).
func _nebari() -> void:
	var r := sim.segs[0].radius
	var col := sim.bark
	for k in 5:
		var ang := k * TAU / 5.0 + 0.5 * sin(k * 7.1)
		var dir := Vector3(cos(ang), 0, sin(ang))
		var a := Vector3.UP
		var pts := [dir * r * 0.6 + Vector3.UP * 0.003, dir * (r * 1.8 + 0.008), dir * (r * 2.8 + 0.018) + Vector3.DOWN * 0.004]
		var rads := [r * 0.45, r * 0.25, r * 0.06]
		var prev := _ring(pts[0], dir, a, rads[0], col)
		for q in range(1, 3):
			var cur := _ring(pts[q], (pts[q] - pts[q - 1]).normalized(), a, rads[q], col)
			_join(prev, cur)
			prev = cur


func _perp(d: Vector3) -> Vector3:
	var a := d.cross(Vector3.UP)
	if a.length() < 0.01:
		a = d.cross(Vector3.RIGHT)
	return a.normalized()


func _ring(c: Vector3, d: Vector3, a: Vector3, r: float, col: Color) -> int:
	a = (a - d * a.dot(d)).normalized()
	var b := d.cross(a)
	var base := verts.size()
	for k in SIDES:
		var ang := TAU * k / SIDES
		var nrm := a * cos(ang) + b * sin(ang)
		verts.append(c + nrm * r)
		norms.append(nrm)
		cols.append(col)
	return base


func _join(r0: int, r1: int) -> void:
	for k in SIDES:
		var k1 := (k + 1) % SIDES
		for v in [r0 + k, r1 + k, r0 + k1, r0 + k1, r1 + k, r1 + k1]:
			idx.append(v)


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
	var base := verts.size()
	for q in [p, p + u * l * 0.4 + v * l * 0.25, p + u * l, p + u * l * 0.4 - v * l * 0.25]:
		verts.append(q)
		norms.append(n)
		cols.append(col)
	for k in [0, 1, 2, 0, 2, 3]:
		idx.append(base + k)


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
	for k in pairs:
		var p := s.start + d * l * (k + 0.5) / pairs
		var ang := s.phase + k * 2.4
		for side in [0.0, PI]:
			var r := a * cos(ang + side) + b * sin(ang + side)
			var dir := (d * 0.6 + r).normalized()
			var wv := dir.cross(r).normalized() * 0.0012
			var base := verts.size()
			for q in [p - wv, p + wv, p + dir * nl]:
				verts.append(q)
				norms.append((r + Vector3.UP).normalized())
				cols.append(col)
			idx.append(base)
			idx.append(base + 1)
			idx.append(base + 2)
