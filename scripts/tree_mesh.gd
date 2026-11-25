class_name TreeMesh
extends RefCounted
## Construit le maillage de l'arbre à l'instant t (semaines) : un cylindre à 6 faces par segment,
## les pousses en cours s'allongent, couleur selon l'âge et la santé.

const SIDES := 6
const YOUNG := Color(0.45, 0.62, 0.25)   # pousse de l'année
const BARK := Color(0.45, 0.38, 0.32)
const SELECTED := Color(1.0, 0.35, 0.2)
const WEAK := Color(0.8, 0.72, 0.3)     # branche qui s'affaiblit à l'ombre
const DRY := Color(0.72, 0.7, 0.64)     # bois mort
const LEAF := Color(0.3, 0.55, 0.2)
const LEAF_AUTUMN := Color(0.85, 0.7, 0.2)
const LEAF_LEN := 0.02                  # orme : petite feuille ovale (~2 cm)
const NEEDLE := Color(0.13, 0.33, 0.16)
const NEEDLE_LEN := 0.035               # pin noir en bonsaï : aiguilles de 3 à 5 cm


static func build(sim: TreeSim, highlight: PackedInt32Array, t: float, leaves: bool) -> ArrayMesh:
	var marked := {}
	for i in highlight:
		marked[i] = true
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var weak := PackedByteArray()
	weak.resize(sim.segs.size())
	for i in sim.segs.size():
		var s := sim.segs[i]
		weak[i] = 1 if s.weak > 0 or (s.parent >= 0 and weak[s.parent] == 1) else 0
		var f := sim.growth(s, t)
		var d := s.end - s.start
		var l := d.length() * f
		if l < 0.0001:
			continue
		d = d.normalized()
		var a := d.cross(Vector3.UP)
		if a.length() < 0.01:
			a = d.cross(Vector3.RIGHT)
		a = a.normalized()
		var b := d.cross(a)
		var r0 := s.radius
		var r1 := sim.segs[s.main_child].radius if s.main_child >= 0 and f >= 1.0 else sim.tip_radius
		r1 = minf(r0, r1)
		var col := YOUNG.lerp(BARK, clampf((t - s.born) / 52.0, 0.0, 1.0))
		if marked.has(i):
			col = SELECTED
		elif s.dry:
			col = DRY
		elif weak[i] == 1:
			col = col.lerp(WEAK, 0.7)
		var tip := s.start + d * l
		var base := verts.size()
		for k in SIDES:
			var ang := TAU * k / SIDES
			var n := a * cos(ang) + b * sin(ang)
			verts.append(s.start - d * r0 * 0.5 + n * r0)  # léger recouvrement pour cacher les jointures
			verts.append(tip + n * r1)
			norms.append(n)
			norms.append(n)
			cols.append(col)
			cols.append(col)
		for k in SIDES:
			var p0 := base + k * 2
			var p1 := base + ((k + 1) % SIDES) * 2
			for v in [p0, p0 + 1, p1, p1, p0 + 1, p1 + 1]:
				idx.append(v)
		if leaves and not s.dry:
			if sim.leaf_years > 0:
				_needles(s, t, f, d, l, sim.leaf_years, weak[i] == 1, marked.has(i), verts, norms, cols, idx)
			else:
				_leaf(s, t, f, weak[i] == 1, marked.has(i), verts, norms, cols, idx)
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


## Feuille de l'orme : une par nœud, seulement sur les pousses de l'année (caduc).
## Débourre avec la pousse, jaunit en octobre, tombe en novembre.
static func _leaf(s: TreeSim.Seg, t: float, f: float, weak: bool, selected: bool,
		verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, idx: PackedInt32Array) -> void:
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
static func _needles(s: TreeSim.Seg, t: float, f: float, d: Vector3, l: float, years: int, weak: bool,
		selected: bool, verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray,
		idx: PackedInt32Array) -> void:
	if t - s.born > years * 52:
		return
	var col := NEEDLE.lerp(WEAK, 0.6) if weak else NEEDLE
	if selected:
		col = SELECTED
	var a := d.cross(Vector3.UP)
	if a.length() < 0.01:
		a = d.cross(Vector3.RIGHT)
	a = a.normalized()
	var b := d.cross(a)
	var pairs := clampi(int(l / 0.004), 1, 6)
	var nl := NEEDLE_LEN * f
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
				norms.append(r)
				cols.append(col)
			idx.append(base)
			idx.append(base + 1)
			idx.append(base + 2)
