extends Node3D
## Étape 1 : un orme qui pousse et qu'on taille. Vue 3D simple, rotation au doigt, pincer pour zoomer.

var sim := TreeSim.new()
var tree_mi := MeshInstance3D.new()
var cam := Camera3D.new()
var yaw := 0.6
var pitch := 0.25
var dist := 0.35
var target := Vector3(0, 0.05, 0)
var selected := -1

var touches := {}
var tap_start := Vector2.ZERO
var tap_moved := false
var pinch := 0.0
var ui_scale := 1.0

var panel: PanelContainer
var info: Label
var cut_btn: Button


func _ready() -> void:
	ui_scale = get_viewport().get_visible_rect().size.x / 720.0
	sim.reset()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	tree_mi.material_override = mat
	add_child(tree_mi)
	cam.near = 0.005
	cam.fov = 45.0
	add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.86, 0.88, 0.83)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.7)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_add_pot()
	_build_ui()
	_refresh()


func _add_pot() -> void:
	var pot := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.1
	cyl.height = 0.06
	pot.mesh = cyl
	pot.position.y = -0.031
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.35, 0.3, 0.32)
	pot.material_override = m
	add_child(pot)


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
	_button(row2, "Nouvelle pousse", _new_tree)
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


func _advance(weeks: int) -> void:
	for i in weeks:
		sim.step_week()
	selected = -1  # les indices changent quand des branches meurent
	_refresh()


func _cut() -> void:
	if sim.prune(selected):
		selected = -1
		_refresh()


func _new_tree() -> void:
	sim.reset(randi())
	selected = -1
	dist = 0.35
	_refresh()


func _refresh() -> void:
	var hl := sim.subtree(selected) if selected > 0 else PackedInt32Array()
	tree_mi.mesh = TreeMesh.build(sim, hl)
	cut_btn.disabled = selected <= 0
	var w := sim.week % 52
	var season := "hiver"
	if w >= 11 and w < 24:
		season = "printemps"
	elif w >= 24 and w < 37:
		season = "été"
	elif w >= 37 and w < 50:
		season = "automne"
	info.text = "Année %d · semaine %d (%s)\n%d segments · hauteur %d cm" % [
		sim.week / 52 + 1, w + 1, season, sim.segs.size(), roundi(sim.height() * 100.0)]
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
	var best := -1
	var best_d := 40.0 * ui_scale
	for i in sim.segs.size():
		var s := sim.segs[i]
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
