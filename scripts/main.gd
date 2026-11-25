extends Node
## Un bonsaï qui pousse et qu'on taille. Rendu cel shading en pleine résolution (3 tons nets,
## contours, ombres portées). Rotation au doigt, pincer pour zoomer.
## Pour avancer le temps : la période est calculée dans un fil de calcul (petit chargement), puis la pousse
## est jouée par la carte graphique à partir d'un seul maillage (voir shaders/anim.gdshaderinc).

var sim := TreeSim.new()
var wood_mi := MeshInstance3D.new()
var leaves_mi := MeshInstance3D.new()
var needles_mi := MeshInstance3D.new()
var cam := Camera3D.new()
var world := Node3D.new()
var yaw := 0.6
var pitch := 0.25
var dist := 0.35
var target := Vector3(0, 0.05, 0)
var selected := -1
var show_leaves := true
var layout := 0
var task := -1        # calcul de la période en cours (WorkerThreadPool), -1 si aucun
var built := []       # résultat du calcul : maillages de fin de période
var calc_ms := 0      # durée du dernier calcul
var anim_t0 := 0.0    # période animée (semaines)
var anim_t1 := 0.0
var anim_now := 0.0
var anim_dur := 1.0   # durée de l'animation (s)
var playing := false
var loader: Polygon2D

var touches := {}
var tap_start := Vector2.ZERO
var tap_moved := false
var pinch := 0.0
var mid := Vector2.ZERO      # milieu des deux doigts (déplacement de la vue)
var last_tap_ms := 0
var last_tap_pos := Vector2.ZERO
var goal_target := Vector3.ZERO  # vers où la caméra glisse après un double-tap
var goal_dist := 0.0
var gliding := false
const MIN_DIST := 0.03       # zoom au plus près : ~3 cm
var ui_scale := 1.0

var panel: PanelContainer
var info: Label
var cut_btn: Button


func _ready() -> void:
	ui_scale = get_viewport().get_visible_rect().size.x / 720.0
	add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.93, 0.9, 0.84)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.85)  # ombres bleutées
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 3.0  # ombres nettes sur la petite scène
	world.add_child(sun)
	world.add_child(wood_mi)
	world.add_child(leaves_mi)
	leaves_mi.material_override = TreeMesh.toon(0, Color.WHITE, false, 2)
	var nm := TreeMesh.toon(0, Color.WHITE, false, 2)
	nm.set_shader_parameter("deciduous", false)
	needles_mi.material_override = nm
	world.add_child(needles_mi)
	_add_pot()
	cam.near = 0.005
	cam.far = 20.0
	cam.fov = 45.0
	world.add_child(cam)
	_build_ui()
	_set_species(Species.ELM)
	_refresh()
	_recenter()


## Pot rectangulaire en terre cuite, terre d'akadama en granulés.
func _add_pot() -> void:
	var pot := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.32, 0.05, 0.22)
	pot.mesh = b
	pot.position.y = -0.026
	pot.material_override = TreeMesh.toon(0, Color(0.55, 0.28, 0.2), true)
	world.add_child(pot)
	var soil := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(0.3, 0.2)
	soil.mesh = pl
	soil.position.y = 0.0005
	soil.material_override = TreeMesh.toon(3, Color(0.5, 0.33, 0.22))
	world.add_child(soil)


func _set_species(species: Dictionary) -> void:
	sim.reset(randi(), species)
	wood_mi.material_override = TreeMesh.bark_material(sim)


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
	_button(row3, "Recentrer", _recenter)
	# Chargement : une feuille qui tourne au milieu de l'écran pendant le calcul de la période.
	loader = Polygon2D.new()
	var pts := PackedVector2Array()
	for k in 24:
		var u := TAU * k / 24.0
		pts.append(Vector2(cos(u) * 40.0, sin(u) * 18.0 * (1.0 - 0.4 * cos(u))) * ui_scale)
	loader.polygon = pts
	loader.color = Color(0.3, 0.58, 0.22)
	loader.position = get_viewport().get_visible_rect().size * Vector2(0.5, 0.4)
	loader.visible = false
	layer.add_child(loader)
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


## Avance le temps : la période est simulée et maillée dans un fil de calcul (petit chargement), puis
## jouée en animation fluide : ~1 s pour une semaine, ~3 s pour une saison, ~6 s pour un an.
func _advance(weeks: int) -> void:
	if _busy():
		return
	selected = -1
	sim.begin_period()
	anim_t0 = sim.week
	anim_t1 = sim.week + weeks
	anim_dur = clampf(0.8 + weeks * 0.1, 1.0, 6.0)
	var leaves := show_leaves
	var t_start := anim_t0
	var start_ms := Time.get_ticks_msec()
	loader.visible = true
	_set_buttons(false)
	task = WorkerThreadPool.add_task(func():
		for i in weeks:
			sim.step_week()
		built = TreeMesh.build(sim, PackedInt32Array(), t_start, sim.week, leaves)
		calc_ms = Time.get_ticks_msec() - start_ms)


func _process(delta: float) -> void:
	if gliding:  # glissement doux vers le point choisi par double-tap
		var k := 1.0 - exp(-delta * 8.0)
		target = target.lerp(goal_target, k)
		dist = lerpf(dist, goal_dist, k)
		gliding = target.distance_to(goal_target) > 0.0005 or absf(dist - goal_dist) > 0.0005
		_update_cam()
	if task >= 0:
		loader.rotation += delta * 4.0
		if not WorkerThreadPool.is_task_completed(task):
			return
		WorkerThreadPool.wait_for_task_completion(task)
		task = -1
		loader.visible = false
		layout = sim.layout
		_show(built)
		anim_now = anim_t0
		playing = true
	if playing:
		anim_now = minf(anim_now + (anim_t1 - anim_t0) * delta / anim_dur, anim_t1)
		_set_time(anim_now)
		_info(anim_now)
		if anim_now >= anim_t1:
			_stop_anim()


func _busy() -> bool:
	return task >= 0 or playing


## Fin de l'animation : le maillage de la période montre déjà l'arbre final, rien à recalculer.
func _stop_anim() -> void:
	playing = false
	_set_time(anim_t1)
	_info(anim_t1)
	_set_buttons(true)


func _set_buttons(on: bool) -> void:
	for b in panel.find_children("*", "Button", true, false):
		b.disabled = not on
	cut_btn.disabled = not on or selected <= 0


func _set_time(time: float) -> void:
	for mi in [wood_mi, leaves_mi, needles_mi]:
		TreeMesh.set_time(mi.material_override, time, anim_t0, anim_t1)


func _show(meshes: Array) -> void:
	wood_mi.mesh = meshes[0]
	leaves_mi.mesh = meshes[1]
	needles_mi.mesh = meshes[2]


func _cut() -> void:
	if not _busy() and sim.prune(selected):
		selected = -1
		layout = sim.layout
		_refresh()


func _toggle_leaves() -> void:
	if _busy():
		return
	show_leaves = not show_leaves
	_refresh()


func _new_tree(species: Dictionary) -> void:
	if _busy():
		return
	_set_species(species)
	selected = -1
	layout = sim.layout
	_refresh()
	_recenter()


## Arbre immobile à la date actuelle (après une coupe, une sélection, un changement d'affichage).
func _refresh() -> void:
	var hl := sim.subtree(selected) if selected > 0 else PackedInt32Array()
	anim_t0 = sim.week
	anim_t1 = sim.week
	_show(TreeMesh.build(sim, hl, sim.week, sim.week, show_leaves))
	_set_time(sim.week)
	cut_btn.disabled = selected <= 0
	_info(sim.week)
	_update_cam()


## Vue d'ensemble de l'arbre.
func _recenter() -> void:
	goal_target = Vector3(0, maxf(0.05, sim.height() * 0.45), 0)
	goal_dist = maxf(0.35, sim.height() * 1.6)
	gliding = true


func _info(time: float) -> void:
	var wk := floori(time)
	var w := wk % 52
	var season := "hiver"
	if w >= 11 and w < 24:
		season = "printemps"
	elif w >= 24 and w < 37:
		season = "été"
	elif w >= 37 and w < 50:
		season = "automne"
	var extra := "calcul %d ms" % calc_ms if calc_ms > 0 else "%d segments" % sim.segs.size()
	info.text = "%s · année %d · semaine %d (%s)\n%s · hauteur %d cm" % [
		sim.name, wk / 52 + 1, w + 1, season, extra, roundi(sim.height() * 100.0)]


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
				var p: Array = touches.values()
				mid = (p[0] + p[1]) * 0.5
		elif touches.has(ev.index):
			touches.erase(ev.index)
			if touches.is_empty() and not tap_moved:
				var now := Time.get_ticks_msec()
				if now - last_tap_ms < 350 and ev.position.distance_to(last_tap_pos) < 40.0 * ui_scale:
					_focus_at(ev.position)  # double-tap : on va voir ce point de près
					last_tap_ms = 0
				else:
					_select_at(ev.position)
					last_tap_ms = now
					last_tap_pos = ev.position
			elif touches.size() == 1:
				pinch = 0.0
	elif ev is InputEventScreenDrag and touches.has(ev.index):
		touches[ev.index] = ev.position
		if ev.position.distance_to(tap_start) > 12.0 * ui_scale:
			tap_moved = true
		if touches.size() == 1 and tap_moved:
			yaw -= ev.relative.x * 0.008
			pitch = clampf(pitch + ev.relative.y * 0.006, -1.5, 1.5)  # dessus comme dessous
			gliding = false
			_update_cam()
		elif touches.size() == 2:
			var d := _pinch_len()
			var p: Array = touches.values()
			var m: Vector2 = (p[0] + p[1]) * 0.5
			if pinch > 0.0 and d > 0.0:
				dist = clampf(dist * pinch / d, MIN_DIST, 2.0)
				# glisser à deux doigts : le point visé suit les doigts, dans le plan de l'écran
				var px := dist * 2.0 * tan(deg_to_rad(cam.fov * 0.5)) / get_viewport().get_visible_rect().size.y
				var dm := m - mid
				var bas := cam.global_transform.basis
				target += (-bas.x * dm.x + bas.y * dm.y) * px
			pinch = d
			mid = m
			gliding = false
			_update_cam()
	elif ev is InputEventMouseButton and ev.pressed:  # molette sur PC
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist = maxf(dist * 0.9, MIN_DIST)
			_update_cam()
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist = minf(dist * 1.1, 2.0)
			_update_cam()


func _pinch_len() -> float:
	var p: Array = touches.values()
	return p[0].distance_to(p[1]) if p.size() >= 2 else 0.0


## Double-tap : la caméra glisse vers le point de branche sous le doigt et s'en rapproche.
func _focus_at(pos: Vector2) -> void:
	var i := _pick(pos)
	if i < 0:
		return
	var s := sim.segs[i]
	var a := cam.unproject_position(s.start)
	var b := cam.unproject_position(s.end)
	var p := Geometry2D.get_closest_point_to_segment(pos, a, b)
	var u := clampf((p - a).dot(b - a) / maxf((b - a).length_squared(), 0.0001), 0.0, 1.0)
	goal_target = s.start.lerp(s.end, u)
	goal_dist = clampf(dist * 0.4, MIN_DIST * 2.0, 0.15)
	gliding = true


## Sélectionne le segment le plus proche du doigt à l'écran.
func _select_at(pos: Vector2) -> void:
	if playing:  # toucher l'écran pendant l'animation : on saute à la fin
		_stop_anim()
		return
	if task >= 0:
		return
	selected = _pick(pos)
	_refresh()


## Segment le plus proche du doigt à l'écran (-1 si aucun assez près).
func _pick(pos: Vector2) -> int:
	var best := -1
	var best_d := 40.0 * ui_scale
	for i in sim.segs.size():
		var s := sim.segs[i]
		if sim.growth(s, sim.week) <= 0.0:
			continue
		if cam.is_position_behind(s.start) or cam.is_position_behind(s.end):
			continue
		var a := cam.unproject_position(s.start)
		var b := cam.unproject_position(s.end)
		var d := Geometry2D.get_closest_point_to_segment(pos, a, b).distance_to(pos)
		if d < best_d:
			best_d = d
			best = i
	return best
