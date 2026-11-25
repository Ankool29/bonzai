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


static func build(sim: TreeSim, highlight: PackedInt32Array, t: float) -> ArrayMesh:
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
