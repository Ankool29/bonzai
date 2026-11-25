extends Node
## Un bonsaï qui pousse et qu'on taille. Rendu pixel art 3D façon estampe : la scène est rendue en basse
## résolution (SubViewport) puis agrandie sans lissage. Rotation au doigt, pincer pour zoomer.

const TOON := preload("res://shaders/toon.gdshader")
const INK := preload("res://shaders/ink.gdshader")
const TARGET_WIDTH := 480.0   # largeur du rendu en pixels

var sim := TreeSim.new()
var tree_mi := MeshInstance3D.new()
var cam := Camera3D.new()
var world := Node3D.new()
var shrink := 3
var yaw := 0.6
var pitch := 0.25
var dist := 0.35
var target := Vector3(0, 0.05, 0)
var selected := -1
var pending := 0      # semaines restant à jouer
var frac := 0.0       # avancement dans la semaine en cours (pour voir les pousses s'allonger)
var speed := 1.0      # semaines par seconde
var show_leaves := true
var layout := 0

var touches := {}
var tap_start := Vector2.ZERO
var tap_moved := false
var pinch := 0.0
var ui_scale := 1.0

var panel: PanelContainer
var info: Label
var cut_btn: Button


func _ready() -> void:
	var screen := get_viewport().get_visible_rect().size
	ui_scale = screen.x / 720.0
	shrink = maxi(1, roundi(screen.x / TARGET_WIDTH))
	var box := SubViewportContainer.new()
	box.stretch = true
	box.stretch_shrink = shrink
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(box)
	var vp := SubViewport.new()
	box.add_child(vp)
	vp.add_child(world)
	sim.reset()
	tree_mi.material_override = _toon(Color.WHITE)
	world.add_child(tree_mi)
	cam.near = 0.005
	cam.far = 20.0
	cam.fov = 45.0
	world.add_child(cam)
	var ink := MeshInstance3D.new()  # contours et papier, passe plein écran
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	ink.mesh = quad
	ink.extra_cull_margin = 16384.0
	var im := ShaderMaterial.new()
	im.shader = INK
	ink.material_override = im
	cam.add_child(ink)
	_add_pot()
	_build_ui()
	_refresh()


func _toon(c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("tint", c)
	return m


func _add_cyl(r_top: float, r_bot: float, h: float, pos: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r_top
	cyl.bottom_radius = r_bot
	cyl.height = h
	cyl.radial_segments = 24
	cyl.rings = 1
	mi.mesh = cyl
	mi.position = pos
	mi.material_override = _toon(c)
	world.add_child(mi)


## Pot émaillé dans un ton sourd, terre et quelques touches de mousse.
func _add_pot() -> void:
	_add_cyl(0.12, 0.1, 0.06, Vector3(0, -0.035, 0), Color(0.38, 0.42, 0.5))
	_add_cyl(0.114, 0.114, 0.004, Vector3(0, -0.004, 0), Color(0.4, 0.32, 0.25))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 14:
		var ang := rng.randf() * TAU
		var d := rng.randf_range(0.03, 0.1)
		var r := rng.randf_range(0.008, 0.02)
		_add_cyl(r, r, 0.004, Vector3(cos(ang) * d, -0.002, sin(ang) * d), Color(0.46, 0.55, 0.3))


func _build_ui() -> void:
	var theme := Theme.new()
	theme.default_font_size = int(26 * ui_scale)
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	layer.add_child(root)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(spacer)
	panel = PanelContainer.new()
	root.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	info = Label.new()
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(info)
	var row1 := HBoxContainer.new()
	box.add_child(row1)
	_button(row1, "+1 semaine", func(): _advance(1))
	_button(row1, "+1 saison", func(): _advance(13))
	_button(row1, "+1 an", func(): _advance(52))
	var row2 := HBoxContainer.new()
	box.add_child(row2)
	cut_btn = _button(row2, "Couper", _cut)
	_button(row2, "Feuilles", _toggle_leaves)
	var row3 := HBoxContainer.new()
	box.add_child(row3)
	_button(row3, "Nouvel orme", func(): _new_tree(Species.ELM))
	_button(row3, "Nouveau pin", func(): _new_tree(Species.PINE))
	var bottom := Control.new()  # marge pour la barre de gestes du téléphone
	bottom.custom_minimum_size.y = 40 * ui_scale
	box.add_child(bottom)


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 90 * ui_scale
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


## Le temps défile à l'écran : ~0,7 s pour une semaine, ~2 s pour une saison, ~5 s pour un an.
func _advance(weeks: int) -> void:
	pending += weeks
	speed = maxf(speed if pending > weeks else 0.0, weeks / (0.6 + weeks * 0.08))


func _process(delta: float) -> void:
	if pending <= 0:
		return
	frac += delta * speed
	while frac >= 1.0 and pending > 0:
		sim.step_week()
		pending -= 1
		frac -= 1.0
	if pending == 0:
		frac = 0.0
	if sim.layout != layout:  # des rameaux morts sont tombés : les indices ont changé
		layout = sim.layout
		selected = -1
	_refresh()


func _cut() -> void:
	if sim.prune(selected):
		selected = -1
		layout = sim.layout
		_refresh()


func _toggle_leaves() -> void:
	show_leaves = not show_leaves
	_refresh()


func _new_tree(species: Dictionary) -> void:
	sim.reset(randi(), species)
	selected = -1
	layout = sim.layout
	pending = 0
	frac = 0.0
	dist = 0.35
	_refresh()


func _refresh() -> void:
	var hl := sim.subtree(selected) if selected > 0 else PackedInt32Array()
	tree_mi.mesh = TreeMesh.build(sim, hl, sim.week + frac, show_leaves)
	cut_btn.disabled = selected <= 0
	var w := sim.week % 52
	var season := "hiver"
	if w >= 11 and w < 24:
		season = "printemps"
	elif w >= 24 and w < 37:
		season = "été"
	elif w >= 37 and w < 50:
		season = "automne"
	info.text = "%s · année %d · semaine %d (%s)\n%d segments · hauteur %d cm" % [
		sim.name, sim.week / 52 + 1, w + 1, season, sim.segs.size(), roundi(sim.height() * 100.0)]
	target.y = maxf(0.05, sim.height() * 0.45)
	_update_cam()


func _update_cam() -> void:
	cam.position = target + Vector3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw)) * dist
	cam.look_at(target)


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed:
			if panel.get_global_rect().has_point(ev.position):
				return
			touches[ev.index] = ev.position
			if touches.size() == 1:
				tap_start = ev.position
				tap_moved = false
			else:
				tap_moved = true
				pinch = _pinch_len()
		elif touches.has(ev.index):
			touches.erase(ev.index)
			if touches.is_empty() and not tap_moved:
				_select_at(ev.position)
	elif ev is InputEventScreenDrag and touches.has(ev.index):
		touches[ev.index] = ev.position
		if ev.position.distance_to(tap_start) > 12.0 * ui_scale:
			tap_moved = true
		if touches.size() == 1 and tap_moved:
			yaw -= ev.relative.x * 0.008
			pitch = clampf(pitch + ev.relative.y * 0.006, -0.2, 1.4)
			_update_cam()
		elif touches.size() == 2:
			var d := _pinch_len()
			if pinch > 0.0 and d > 0.0:
				dist = clampf(dist * pinch / d, 0.06, 2.0)
			pinch = d
			_update_cam()
	elif ev is InputEventMouseButton and ev.pressed:  # molette sur PC
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist = maxf(dist * 0.9, 0.06)
			_update_cam()
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist = minf(dist * 1.1, 2.0)
			_update_cam()


func _pinch_len() -> float:
	var p: Array = touches.values()
	return p[0].distance_to(p[1]) if p.size() >= 2 else 0.0


## Sélectionne le segment le plus proche du doigt à l'écran.
func _select_at(pos: Vector2) -> void:
	pos /= shrink  # coordonnées du rendu basse résolution
	var best := -1
	var best_d := 40.0 * ui_scale / shrink
	for i in sim.segs.size():
		var s := sim.segs[i]
		if sim.growth(s, sim.week + frac) <= 0.0:
			continue
		if cam.is_position_behind(s.start) or cam.is_position_behind(s.end):
			continue
		var a := cam.unproject_position(s.start)
		var b := cam.unproject_position(s.end)
		var d := Geometry2D.get_closest_point_to_segment(pos, a, b).distance_to(pos)
		if d < best_d:
			best_d = d
			best = i
	selected = best
	_refresh()
