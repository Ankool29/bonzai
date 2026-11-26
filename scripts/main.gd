extends Node
## Un bonsaï qui pousse et qu'on taille. Rendu cel shading en pleine résolution (3 tons nets,
## contours, ombres portées). Rotation au doigt, pincer pour zoomer.
## Pour avancer le temps : la période est calculée dans un fil de calcul (petit chargement), puis la pousse
## est jouée par la carte graphique à partir d'un seul maillage (voir shaders/anim.gdshaderinc).

var garden := Garden.new()
var sim: TreeSim             # arbre ouvert
var garden_panel: PanelContainer   # panneau plein écran : jardin ou rempotage
var pot_mi := MeshInstance3D.new()
var soil_mi := MeshInstance3D.new()
var wood_mi := MeshInstance3D.new()
var leaves_mi := MeshInstance3D.new()
var needles_mi := MeshInstance3D.new()
var cam := Camera3D.new()
var world := Node3D.new()
var yaw := 0.6
var pitch := 0.25
var dist := 0.35
var target := Vector3(0, 0.05, 0)
var axis: Array[int] = []    # branche sélectionnée, de sa base à sa pointe
var cut_k := -1                # entre-nœud de l'axe où passe la coupe (juste au-dessus du nœud d'en dessous)
var tool := 1                  # 0 : doigts (pinçage), 1 : ciseaux, 2 : pince concave
var tool_btns: Array[Button] = []
var dragging_cut := false
var overlay := MeshInstance3D.new()  # repère de coupe et bourgeons
var msg: Label
var msg_until := 0
var show_leaves := true
var layout := 0
var task := -1        # calcul de la période en cours (WorkerThreadPool), -1 si aucun
var built := []       # résultat du calcul : maillages de fin de période
var calc_ms := 0      # durée du dernier calcul
var last_touch := 0   # ms du dernier toucher (cadence d'affichage)
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
	sun.shadow_enabled = false  # pas d'ombres pendant le travail (chauffe) ; elles serviront à l'exposition
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
	var om := StandardMaterial3D.new()
	om.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	om.vertex_color_use_as_albedo = true
	om.no_depth_test = true
	overlay.material_override = om
	overlay.mesh = ImmediateMesh.new()
	world.add_child(overlay)
	_build_ui()
	garden.load_all()
	if garden.trees.is_empty():
		garden.add(Species.ELM)
	_open(garden.current)


## Pot rectangulaire en terre cuite, terre d'akadama en granulés.
func _add_pot() -> void:
	var b := BoxMesh.new()
	b.size = Vector3(0.32, 0.05, 0.22)  # pot de 8 L ; mis à l'échelle selon le volume (_size_pot)
	pot_mi.mesh = b
	pot_mi.material_override = TreeMesh.toon(0, Color(0.55, 0.28, 0.2), true)
	world.add_child(pot_mi)
	var pl := PlaneMesh.new()
	pl.size = Vector2(0.3, 0.2)
	soil_mi.mesh = pl
	soil_mi.position.y = 0.0005
	soil_mi.material_override = TreeMesh.toon(3, Color(0.5, 0.33, 0.22))
	world.add_child(soil_mi)


func _size_pot() -> void:
	var k := pow(sim.pot_volume / 8.0, 1.0 / 3.0)
	pot_mi.scale = Vector3.ONE * k
	pot_mi.position.y = -0.026 * k
	soil_mi.scale = Vector3(k, 1.0, k)


## Ouvre l'arbre i du jardin.
func _open(i: int) -> void:
	garden.current = i
	garden.save_index()
	sim = garden.trees[i]
	wood_mi.material_override = TreeMesh.bark_material(sim)
	var lm := leaves_mi.material_override as ShaderMaterial
	lm.set_shader_parameter("autumn_color", sim.autumn_color)
	_clear_cut()
	layout = sim.layout
	_size_pot()
	_refresh()
	_recenter()


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
	msg = Label.new()  # message court (outil inadapté…)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_color_override("font_color", Color(0.15, 0.1, 0.08))
	msg.custom_minimum_size.y = 120 * ui_scale
	msg.visible = false
	root.add_child(msg)
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
	for k in 3:
		var b := _button(row2, ["Doigts", "Ciseaux", "Pince concave"][k], _set_tool.bind(k))
		b.toggle_mode = true
		tool_btns.append(b)
	_set_tool(tool)
	cut_btn = _button(row2, "Couper", _cut)
	var row3 := HBoxContainer.new()
	box.add_child(row3)
	_button(row3, "Feuilles", _toggle_leaves)
	_button(row3, "Jardin", _show_garden)
	_button(row3, "Rempoter", _show_repot)
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
	garden_panel = PanelContainer.new()  # liste des arbres, par-dessus tout
	garden_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	garden_panel.theme = theme
	garden_panel.visible = false
	layer.add_child(garden_panel)


## Rempotage : choix du pot et de la part des racines à couper.
func _show_repot() -> void:
	if _busy():
		return
	for c in garden_panel.get_children():
		c.queue_free()
	var box := VBoxContainer.new()
	garden_panel.add_child(box)
	var top := Control.new()
	top.custom_minimum_size.y = 60 * ui_scale
	box.add_child(top)
	var title := Label.new()
	title.text = "Rempoter (idéal : fin février à début avril)\nPot actuel : %d L" % roundi(sim.pot_volume)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var choice := [sim.pot_volume, 0.0]  # volume, part des racines coupées
	var groups := [ButtonGroup.new(), ButtonGroup.new()]
	var rows := [[[8.0, "Grand 8 L"], [3.0, "Moyen 3 L"], [1.0, "Petit 1 L"]],
			[[0.0, "Racines intactes"], [0.33, "Couper 1/3"], [0.5, "Couper 1/2"]]]
	for g in 2:
		var row := HBoxContainer.new()
		box.add_child(row)
		for opt in rows[g]:
			var b := _button(row, opt[1], Callable())
			b.toggle_mode = true
			b.button_group = groups[g]
			b.button_pressed = is_equal_approx(opt[0], choice[g])
			b.pressed.connect(func(): choice[g] = opt[0])
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var row3 := HBoxContainer.new()
	box.add_child(row3)
	_button(row3, "Rempoter", func():
		garden_panel.visible = false
		_say(sim.repot(choice[0], choice[1]))
		garden.save_tree(garden.current)
		_size_pot()
		_info(sim.week))
	_button(row3, "Annuler", func(): garden_panel.visible = false)
	var bottom := Control.new()
	bottom.custom_minimum_size.y = 40 * ui_scale
	box.add_child(bottom)
	garden_panel.visible = true


## Jardin : une ligne par arbre (toucher pour l'ouvrir, « Suppr. » deux fois pour le supprimer),
## puis les boutons pour mettre un nouvel arbre en pot.
func _show_garden() -> void:
	if _busy():
		return
	for c in garden_panel.get_children():
		c.queue_free()
	var box := VBoxContainer.new()
	garden_panel.add_child(box)
	var top := Control.new()
	top.custom_minimum_size.y = 60 * ui_scale
	box.add_child(top)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for i in garden.trees.size():
		var t := garden.trees[i]
		var row := HBoxContainer.new()
		list.add_child(row)
		var age := (t.week - t.planted) / 52
		var label := "%s · %d an%s · %d cm" % [garden.names[i], age, "s" if age > 1 else "", roundi(t.height() * 100.0)]
		var open := _button(row, ("> " if i == garden.current else "") + label, func():
			garden_panel.visible = false
			_open(i))
		open.size_flags_stretch_ratio = 4.0
		var del := _button(row, "Suppr.", Callable())
		del.pressed.connect(func():
			if garden.trees.size() <= 1:
				_say("Il faut garder au moins un arbre.")
			elif del.text != "Sûr ?":
				del.text = "Sûr ?"
			else:
				var was_open := i == garden.current
				garden.remove(i)
				if was_open:
					_open(garden.current)
				_show_garden())
	var row2 := HBoxContainer.new()
	box.add_child(row2)
	for sp in [Species.ELM, Species.PINE, Species.MAPLE]:
		_button(row2, "+ " + str(sp["name"]).split(" ")[0], func():
			garden_panel.visible = false
			garden.add(sp)
			_open(garden.current))
	var row3 := HBoxContainer.new()
	box.add_child(row3)
	_button(row3, "Fermer", func(): garden_panel.visible = false)
	var bottom := Control.new()
	bottom.custom_minimum_size.y = 40 * ui_scale
	box.add_child(bottom)
	garden_panel.visible = true


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 90 * ui_scale
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if cb.is_valid():
		b.pressed.connect(cb)
	parent.add_child(b)
	return b


## Avance le temps : la période est simulée et maillée dans un fil de calcul (petit chargement), puis
## jouée en animation fluide : ~1 s pour une semaine, ~3 s pour une saison, ~6 s pour un an.
func _advance(weeks: int) -> void:
	if _busy():
		return
	_clear_cut()
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
		for i in weeks:  # chaque arbre a sa propre date : seul l'arbre ouvert pousse
			sim.step_week()
		built = TreeMesh.build(sim, PackedInt32Array(), t_start, sim.week, leaves)
		calc_ms = Time.get_ticks_msec() - start_ms)


func _process(delta: float) -> void:
	# 30 images/s au repos, 60 quand on touche l'écran ou que l'arbre bouge (l'écran du téléphone va jusqu'à 120)
	var active := playing or gliding or task >= 0 or Time.get_ticks_msec() - last_touch < 2000
	Engine.max_fps = 60 if active else 30
	if msg.visible and Time.get_ticks_msec() > msg_until:
		msg.visible = false
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
		garden.save_tree(garden.current)
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
	cut_btn.disabled = not on or cut_k < 0


func _set_time(time: float) -> void:
	for mi in [wood_mi, leaves_mi, needles_mi]:
		TreeMesh.set_time(mi.material_override, time, anim_t0, anim_t1)


func _show(meshes: Array) -> void:
	wood_mi.mesh = meshes[0]
	leaves_mi.mesh = meshes[1]
	needles_mi.mesh = meshes[2]


func _set_tool(k: int) -> void:
	tool = k
	for i in tool_btns.size():
		tool_btns[i].set_pressed_no_signal(i == k)


## Coupe à l'endroit du repère avec l'outil choisi ; le jeu refuse un outil inadapté.
func _cut() -> void:
	if _busy() or cut_k < 0:
		return
	var i := axis[cut_k]
	var s := sim.segs[i]
	if i == 0:
		_say("On ne coupe pas le tronc à sa base.")
		return
	if tool == 0 and s.born < sim.week - 8:
		_say("Le pinçage ne marche que sur les pousses vertes de moins de deux mois.")
		return
	if tool == 1 and s.radius > TreeSim.WOUND_MIN:
		_say("Trop épais pour les ciseaux : prends la pince concave.")
		return
	if sim.prune(i, tool == 2):
		garden.save_tree(garden.current)
		_clear_cut()
		layout = sim.layout
		_refresh()


func _say(text: String) -> void:
	msg.text = text
	msg.visible = true
	msg_until = Time.get_ticks_msec() + 2500


func _clear_cut() -> void:
	axis.clear()
	cut_k = -1
	dragging_cut = false
	_draw_overlay()


func _toggle_leaves() -> void:
	if _busy():
		return
	show_leaves = not show_leaves
	_refresh()


## Arbre immobile à la date actuelle (après une coupe, une sélection, un changement d'affichage).
func _refresh() -> void:
	var hl := sim.subtree(axis[cut_k]) if cut_k >= 0 else PackedInt32Array()
	anim_t0 = sim.week
	anim_t1 = sim.week
	_show(TreeMesh.build(sim, hl, sim.week, sim.week, show_leaves))
	_set_time(sim.week)
	cut_btn.disabled = cut_k < 0
	_info(sim.week)
	_draw_overlay()
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
	var v := sim.last_vigor
	var vig := "forte" if v >= 2.0 else ("bonne" if v >= 1.0 else ("faible" if v >= 0.5 else "très faible"))
	var state := "mort" if sim.segs[0].dry else "vigueur %s · réserves %d %%" % [vig, roundi(minf(sim.health(), 1.5) * 100.0)]
	info.text = "%s · année %d · semaine %d (%s)\n%s · hauteur %d cm · pot %d L\n%s" % [
		garden.names[garden.current], wk / 52 + 1, w + 1, season, extra, roundi(sim.height() * 100.0),
		roundi(sim.pot_volume), state]


func _update_cam() -> void:
	cam.position = target + Vector3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw)) * dist
	cam.look_at(target)


func _input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch or ev is InputEventScreenDrag:
		last_touch = Time.get_ticks_msec()


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed:
			if panel.get_global_rect().has_point(ev.position):
				return
			touches[ev.index] = ev.position
			if touches.size() == 1:
				tap_start = ev.position
				tap_moved = false
				# doigt posé sur le repère de coupe : on le fait glisser le long de la branche
				dragging_cut = cut_k >= 0 and _cut_screen_pos().distance_to(ev.position) < 45.0 * ui_scale
			else:
				tap_moved = true
				pinch = _pinch_len()
				var p: Array = touches.values()
				mid = (p[0] + p[1]) * 0.5
		elif touches.has(ev.index):
			touches.erase(ev.index)
			if dragging_cut and touches.is_empty():
				dragging_cut = false
				if tap_moved:
					_refresh()  # la partie retirée s'affiche en rouge
					return
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
		if touches.size() == 1 and dragging_cut:
			_move_cut(ev.position)
		elif touches.size() == 1 and tap_moved:
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
	var i := _pick(pos)
	axis.clear()
	cut_k = -1
	if i >= 0:
		# l'axe qui porte l'entre-nœud touché, de sa base à sa pointe
		var b := i
		while sim.segs[b].parent >= 0 and sim.segs[sim.segs[b].parent].main_child == b:
			b = sim.segs[b].parent
		while b >= 0:
			axis.append(b)
			b = sim.segs[b].main_child
		cut_k = axis.find(i)
	_refresh()


func _cut_screen_pos() -> Vector2:
	return cam.unproject_position(sim.segs[axis[cut_k]].start)


## Le repère saute de nœud en nœud le long de la branche, au plus près du doigt.
func _move_cut(pos: Vector2) -> void:
	var best := cut_k
	var best_d := INF
	for k in axis.size():
		var p := sim.segs[axis[k]].start
		if cam.is_position_behind(p):
			continue
		var d := cam.unproject_position(p).distance_to(pos)
		if d < best_d:
			best_d = d
			best = k
	if best != cut_k:
		cut_k = best
		_draw_overlay()


## Repère de coupe (jaune), partie retirée pendant qu'on glisse (rouge), bourgeons de la branche (vert)
## avec la direction où ils repartiront ; le bourgeon juste sous la coupe est plus long.
func _draw_overlay() -> void:
	var im := overlay.mesh as ImmediateMesh
	im.clear_surfaces()
	if cut_k < 0:
		return
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var c := sim.segs[axis[cut_k]]
	var d := (c.end - c.start).normalized()
	var a := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
	var b := d.cross(a)
	var r := c.radius + 0.004
	for v in [a, b]:
		im.surface_set_color(Color(1.0, 0.85, 0.1))
		im.surface_add_vertex(c.start - v * r)
		im.surface_set_color(Color(1.0, 0.85, 0.1))
		im.surface_add_vertex(c.start + v * r)
	if dragging_cut:
		for k in sim.subtree(axis[cut_k]):
			var s := sim.segs[k]
			im.surface_set_color(Color(0.95, 0.2, 0.12))
			im.surface_add_vertex(s.start)
			im.surface_set_color(Color(0.95, 0.2, 0.12))
			im.surface_add_vertex(s.end)
	for k in axis.size():
		var s := sim.segs[axis[k]]
		if not s.lat_bud:
			continue
		var below := k == cut_k - 1
		var col := Color(0.2, 1.0, 0.3) if below else Color(0.3, 0.75, 0.3)
		im.surface_set_color(col)
		im.surface_add_vertex(s.end)
		im.surface_set_color(col)
		im.surface_add_vertex(s.end + s.lat_dir * (0.012 if below else 0.006))
	im.surface_end()


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
