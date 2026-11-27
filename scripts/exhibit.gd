class_name Exhibit
extends Node3D
## Jardin d'exposition (étape 22) : cour japonaise vue de trois quarts, 9 emplacements pour les bonsaïs.
## Inspiré du jardin du musée du bonsaï d'Omiya : gravier ratissé, pierres moussues, pas japonais,
## palissade de bambou, lanterne, tsukubai, tablettes (tana) et socle d'honneur.

const STONES := [Vector3(0.6, -1.6, 0.42), Vector3(1.3, -1.2, 0.25), Vector3(-0.1, -2.3, 0.2)]  # x, z, rayon
const TANAS := [Vector3(-1.6, 1.7, 3.6), Vector3(1.9, 0.2, 3.6)]  # x, z, longueur
const TANA_TOP := 0.81
const HONOR := Vector3(-2.9, 0.55, -1.6)  # dessus du tronçon d'honneur
const S := 0.5  # décor réduit de moitié autour des arbres (taille réelle) : les bonsaïs se voient mieux

var slots: Array[Vector3] = []   # dessus de chaque emplacement
var nodes := {}                  # emplacement -> arbre dessiné (cache)
var plus := {}                   # emplacement -> « + »
var decor := Node3D.new()


func _init() -> void:
	for t in TANAS:
		for i in 4:
			slots.append(Vector3(t.x + (i - 1.5) * t.z / 4.0, TANA_TOP, t.y) * S)
	slots.append(HONOR * S)
	decor.scale = Vector3.ONE * S
	add_child(decor)
	_decor()
	for s in slots.size():
		var l := Label3D.new()
		l.text = "+"
		l.font_size = 160
		l.outline_size = 40
		l.pixel_size = 0.0025
		l.modulate = Color(0.94, 0.89, 0.78)
		l.outline_modulate = Color(0.38, 0.27, 0.2)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.position = slots[s] + Vector3(0, 0.12, 0)
		add_child(l)
		plus[s] = l


## (Re)dessine l'arbre d'un emplacement, à sa date ; gardé tel quel jusqu'au prochain appel.
func show_tree(s: int, sim: TreeSim) -> void:
	clear(s)
	var n := Node3D.new()
	var m := TreeMesh.build(sim, PackedInt32Array(), sim.week, sim.week, true)
	var mats := [TreeMesh.bark_material(sim), TreeMesh.toon(0, Color.WHITE, false, 2), TreeMesh.toon(0, Color.WHITE, false, 2)]
	mats[1].set_shader_parameter("autumn_color", sim.autumn_color)
	mats[2].set_shader_parameter("deciduous", false)
	for k in 3:
		var mi := MeshInstance3D.new()
		mi.mesh = m[k]
		mi.material_override = mats[k]
		TreeMesh.set_time(mats[k], sim.week, sim.week, sim.week)
		n.add_child(mi)
	var kp := pow(sim.pot_volume / 8.0, 1.0 / 3.0)  # même pot que l'écran de travail
	var b := BoxMesh.new()
	b.size = Vector3(0.32, 0.05, 0.22) * kp
	_mesh(n, b, TreeMesh.toon(0, Color(0.55, 0.28, 0.2), true), Vector3(0, -0.026 * kp, 0))
	var pl := PlaneMesh.new()
	pl.size = Vector2(0.3, 0.2) * kp
	_mesh(n, pl, TreeMesh.toon(3, Color(0.5, 0.33, 0.22)), Vector3(0, 0.0005, 0))
	n.set_meta("dy", 0.051 * kp)  # le pot repose sur l'emplacement
	add_child(n)
	nodes[s] = n
	place(s)


func clear(s: int) -> void:
	if nodes.has(s):
		nodes[s].queue_free()
		nodes.erase(s)
	plus[s].visible = true


## Échange le contenu de deux emplacements (arbres dessinés compris).
func swap(a: int, b: int) -> void:
	var na: Node3D = nodes.get(a)
	var nb: Node3D = nodes.get(b)
	nodes.erase(a)
	nodes.erase(b)
	if na:
		nodes[b] = na
	if nb:
		nodes[a] = nb
	place(a)
	place(b)


## Remet l'arbre d'un emplacement à sa place (après l'avoir soulevé) ; montre le « + » s'il est libre.
func place(s: int) -> void:
	plus[s].visible = not nodes.has(s)
	if nodes.has(s):
		nodes[s].position = slots[s] + Vector3(0, nodes[s].get_meta("dy"), 0)


func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _cyl(r: float, h: float, c: Color, pos: Vector3, seg := 10, outline := true) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	return _mesh(decor, m, _mat(c, outline), pos + Vector3(0, h / 2.0, 0))


func _box(size: Vector3, c: Color, pos: Vector3) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mesh(decor, m, _mat(c, true), pos + Vector3(0, size.y / 2.0, 0))


## Matériau du décor : contour plus épais que celui des arbres, le jardin se voit de loin.
func _mat(c: Color, outline: bool) -> ShaderMaterial:
	var m := TreeMesh.toon(0, c, outline)
	if outline:
		m.next_pass.set_shader_parameter("width", 0.012)
	return m


func _decor() -> void:
	var rng := RandomNumberGenerator.new()  # décor toujours le même, sans toucher au hasard des arbres
	rng.seed = 4
	# gravier ratissé : lignes droites, ondes autour des pierres (motif 5 du shader)
	var g := PlaneMesh.new()
	g.size = Vector2(10, 8)
	var gm := TreeMesh.toon(5, Color(0.84, 0.82, 0.75))
	var st := PackedVector3Array()
	for v in STONES:
		st.append(v * S)
	gm.set_shader_parameter("stones", st)
	_mesh(decor, g, gm, Vector3.ZERO)
	# îlots de mousse aux bords irréguliers
	for mo in [[-2.9, -1.6, 1.5], [-2.2, 2.0, 1.9], [3.2, 2.2, 1.4], [3.6, -2.5, 1.0]]:
		for j in 3:
			var c := _cyl(mo[2] * rng.randf_range(0.6, 0.85), 0.01 + j * 0.002, Color(0.38, 0.48, 0.24), Vector3(mo[0], 0, mo[1]), 14, false)
			c.position += Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4)) * mo[2]
			c.scale = Vector3(rng.randf_range(0.9, 1.2), 1, rng.randf_range(0.7, 0.95))
	# pas japonais
	for p in [Vector2(1.2, -3.6), Vector2(0.4, -3.0), Vector2(-0.6, -2.7), Vector2(-1.2, -1.9), Vector2(-1.4, -0.9), Vector2(-0.9, 0.1), Vector2(-0.2, 0.8)]:
		_cyl(rng.randf_range(0.22, 0.3), 0.04, Color(0.59, 0.57, 0.53), Vector3(p.x, 0, p.y), 9)
	# trois pierres moussues
	for s in STONES:
		_cyl(s.z, s.z * 0.85, Color(0.47, 0.45, 0.42), Vector3(s.x, 0, s.y), 7)
		_cyl(s.z * 0.8, 0.02, Color(0.41, 0.5, 0.27), Vector3(s.x, s.z * 0.85, s.y), 7, false)
	# palissade de bambou au fond
	for i in 48:
		_cyl(0.1, 2.1, Color(0.7, 0.63, 0.38), Vector3(-5.0 + i * 0.21, 0, 3.8), 6, false)
	for y in [0.6, 1.5]:
		_box(Vector3(10, 0.08, 0.08), Color(0.36, 0.27, 0.17), Vector3(0, y, 3.62))
	# lanterne de pierre
	var ls := Color(0.6, 0.58, 0.54)
	var lp := Vector3(3.6, 0, 1.6)
	_cyl(0.32, 0.18, ls, lp, 6)
	_cyl(0.12, 0.8, ls, lp + Vector3(0, 0.18, 0), 6)
	_box(Vector3(0.42, 0.1, 0.42), ls, lp + Vector3(0, 0.98, 0))
	_box(Vector3(0.3, 0.32, 0.3), Color(0.93, 0.84, 0.59), lp + Vector3(0, 1.08, 0))
	_box(Vector3(0.76, 0.06, 0.76), ls, lp + Vector3(0, 1.4, 0))
	_cyl(0.12, 0.22, ls, lp + Vector3(0, 1.46, 0), 6)
	# tsukubai et son bambou verseur
	var tp := Vector3(3.5, 0, -2.5)
	_cyl(0.4, 0.45, Color(0.51, 0.49, 0.46), tp, 10)
	_cyl(0.3, 0.02, Color(0.27, 0.38, 0.42), tp + Vector3(0, 0.44, 0), 10, false)
	_cyl(0.05, 0.8, Color(0.67, 0.59, 0.35), tp + Vector3(0.9, 0, 0.2), 5)
	var spout := _cyl(0.035, 0.8, Color(0.67, 0.59, 0.35), tp + Vector3(0.5, 0.62, 0.1), 5)
	spout.rotation = Vector3(0, -0.25, PI / 2 - 0.2)
	spout.position.y = 0.66
	# érable du jardin (momiji) au fond
	var tr := _cyl(0.1, 2.4, Color(0.36, 0.26, 0.18), Vector3(2.5, 0, 3.0), 8)
	tr.rotation.z = -0.06
	for i in 12:
		var sp := SphereMesh.new()
		var r := rng.randf_range(0.45, 0.75)
		sp.radius = r
		sp.height = r * 1.7
		_mesh(decor, sp, _mat(Color(0.73, 0.28, 0.19), true),
				Vector3(2.5 + rng.randf_range(-1.3, 1.3), 2.6 + rng.randf_range(-0.3, 0.6), 3.0 + rng.randf_range(-0.6, 0.4)))
	# tablettes d'exposition : planche de bois sur deux poteaux de pierre
	for t in TANAS:
		for k in [-0.42, 0.42]:
			_box(Vector3(0.26, 0.72, 0.26), Color(0.55, 0.53, 0.49), Vector3(t.x + k * t.z, 0, t.y))
		_box(Vector3(t.z + 0.3, 0.09, 0.7), Color(0.55, 0.4, 0.27), Vector3(t.x, 0.72, t.y))
	# socle d'honneur : tronçon de bois sur l'îlot de mousse
	_cyl(0.42, HONOR.y, Color(0.45, 0.32, 0.21), Vector3(HONOR.x, 0, HONOR.z), 12)
	_cyl(0.4, 0.004, Color(0.69, 0.55, 0.38), Vector3(HONOR.x, HONOR.y, HONOR.z), 12, false)
