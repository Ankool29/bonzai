class_name TreeMesh
extends RefCounted
## Construit le maillage de l'arbre : un cylindre à 6 faces par segment, couleur selon l'âge.

const SIDES := 6
const YOUNG := Color(0.45, 0.62, 0.25)   # pousse de l'année
const BARK := Color(0.45, 0.38, 0.32)
const SELECTED := Color(1.0, 0.35, 0.2)


static func build(sim: TreeSim, highlight: PackedInt32Array) -> ArrayMesh:
	var marked := {}
	for i in highlight:
		marked[i] = true
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for i in sim.segs.size():
		var s := sim.segs[i]
		var d := s.end - s.start
		var l := d.length()
		if l < 0.0001:
			continue
		d /= l
		var a := d.cross(Vector3.UP)
		if a.length() < 0.01:
			a = d.cross(Vector3.RIGHT)
		a = a.normalized()
		var b := d.cross(a)
		var r0 := s.radius
		var r1 := sim.segs[s.main_child].radius if s.main_child >= 0 else sim.tip_radius
		r1 = minf(r0, r1)
		var col := SELECTED if marked.has(i) else YOUNG.lerp(BARK, clampf((sim.week - s.born) / 52.0, 0.0, 1.0))
		var base := verts.size()
		for k in SIDES:
			var ang := TAU * k / SIDES
			var n := a * cos(ang) + b * sin(ang)
			verts.append(s.start - d * r0 * 0.5 + n * r0)  # léger recouvrement pour cacher les jointures
			verts.append(s.end + n * r1)
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
