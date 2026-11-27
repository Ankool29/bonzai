extends Node
## Un bonsaï qui pousse et qu'on taille. Rendu cel shading en pleine résolution (3 tons nets,
## contours, ombres portées). Rotation au doigt, pincer pour zoomer.
## Pour avancer le temps : la période est calculée dans un fil de calcul (petit chargement), puis la pousse
## est jouée par la carte graphique à partir d'un seul maillage (voir shaders/anim.gdshaderinc).

var garden := Garden.new()
var sim: TreeSim             # arbre ouvert
var garden_panel: PanelContainer   # panneau plein écran : nouvel arbre ou rempotage
var exhibit := Exhibit.new()       # jardin d'exposition (étape 22)
var in_garden := false             # vue du jardin ; sinon écran de travail de l'arbre ouvert
var sun := DirectionalLight3D.new()
var max_dist := 2.0                # recul maximal de la caméra
var press_ms := 0                  # début du toucher (appui long)
var lifted := -1                   # emplacement de l'arbre soulevé, -1 si aucun
var pending_open := -1             # emplacement à ouvrir quand la caméra a fini de s'approcher
var remove_ms := 0                 # premier appui sur « Retirer » (confirmation)
var gauges: HBoxContainer
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
var tool := 1                  # 0 : doigts (pinçage), 1 : ciseaux, 2 : pince concave, 3 : fil (ligature)
var tool_btns: Array[Button] = []
var dragging_cut := false
var dragging_bend := false      # outil fil : on plie la branche ligaturée en glissant depuis le repère
var bend_q := Quaternion.IDENTITY
var bend_b0 := Vector2.ZERO     # position du doigt au début du geste
var bend_axis := 0              # flèche tirée : 0 x (rouge), 1 y (vert), 2 z (bleu)
const AXES := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
const AXIS_COLS := [Color(0.95, 0.25, 0.2), Color(0.3, 0.85, 0.3), Color(0.3, 0.5, 1.0)]
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
var vig_bar: ProgressBar
var res_bar: ProgressBar
# Couleurs de l'interface (bois et papier, icônes PixelLab dans ui/icons)
const WOOD := Color(0.29, 0.2, 0.15)
const WOOD_EDGE := Color(0.38, 0.27, 0.2)
const GOLD := Color(0.94, 0.78, 0.47)
const PAPER := Color(0.93, 0.89, 0.78)
const PAPER2 := Color(0.84, 0.78, 0.63)
const INK := Color(0.16, 0.12, 0.09)
const ORANGE := Color(0.78, 0.47, 0.24)
var cut_btn: Button
var wire_btn: Button
var cut_tool := 1              # dernier outil de coupe choisi (onglet Taille)
var pages: Array[HBoxContainer] = []


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
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = false  # pas d'ombres pendant le travail (chauffe) ; elles serviront à l'exposition
	sun.directional_shadow_max_distance = 3.0  # ombres nettes sur la petite scène
	world.add_child(sun)
	world.add_child(exhibit)
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
	om.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA  # branche fantôme translucide
	om.cull_mode = BaseMaterial3D.CULL_DISABLED  # rubans et points vus des deux côtés
	overlay.material_override = om
	overlay.mesh = ImmediateMesh.new()
	world.add_child(overlay)
	_build_ui()
	garden.load_all()
	if garden.trees.is_empty():
		garden.add(Species.ELM, Garden.SLOTS - 1)  # premier arbre sur le socle d'honneur
	_enter_garden()


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


## Cadre de pixel art : fond uni, bordure épaisse, coins carrés.
func _box(bg: Color, edge: Color, w := 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(int(w * ui_scale))
	sb.set_content_margin_all(8 * ui_scale)
	return sb


func _build_ui() -> void:
	var theme := Theme.new()
	theme.default_font_size = int(26 * ui_scale)
	theme.set_stylebox("normal", "Button", _box(WOOD, WOOD_EDGE))
	theme.set_stylebox("hover", "Button", _box(WOOD, WOOD_EDGE))
	theme.set_stylebox("pressed", "Button", _box(PAPER2, GOLD))
	theme.set_stylebox("hover_pressed", "Button", _box(PAPER2, GOLD))
	theme.set_stylebox("disabled", "Button", _box(WOOD.darkened(0.3), WOOD_EDGE.darkened(0.3)))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_focus_color"]:
		theme.set_color(c, "Button", PAPER)
	for c in ["font_pressed_color", "font_hover_pressed_color"]:
		theme.set_color(c, "Button", INK)
	theme.set_color("font_disabled_color", "Button", PAPER.darkened(0.5))
	theme.set_constant("icon_max_width", "Button", int(52 * ui_scale))
	theme.set_stylebox("panel", "PanelContainer", _box(PAPER, WOOD_EDGE))
	theme.set_color("font_color", "Label", INK)
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # icônes pixel art nettes
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
	# Infos en haut, petites et translucides : l'arbre garde l'écran.
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", _box(Color(PAPER, 0.8), Color(WOOD_EDGE, 0.8), 2))
	top.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	root.move_child(top, 0)
	var tbox := VBoxContainer.new()
	top.add_child(tbox)
	info = Label.new()
	info.add_theme_font_size_override("font_size", int(19 * ui_scale))
	tbox.add_child(info)
	gauges = HBoxContainer.new()  # jauges de vigueur et de réserves
	tbox.add_child(gauges)
	for k in 2:
		var l := Label.new()
		l.text = ["Vigueur ", "  Réserves "][k]
		l.add_theme_font_size_override("font_size", int(17 * ui_scale))
		gauges.add_child(l)
		var bar := ProgressBar.new()
		bar.max_value = 1.0
		bar.show_percentage = false
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.custom_minimum_size = Vector2(110, 12) * ui_scale
		bar.add_theme_stylebox_override("background", _box(INK, INK, 1))
		bar.add_theme_stylebox_override("fill", _box([Color(0.84, 0.59, 0.24), Color(0.43, 0.67, 0.31)][k], INK, 1))
		gauges.add_child(bar)
		if k == 0:
			vig_bar = bar
		else:
			res_bar = bar
	# En bas, une seule rangée de petits boutons à icône : les onglets, puis les outils de l'onglet ouvert.
	panel = PanelContainer.new()
	root.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var row := HBoxContainer.new()
	box.add_child(row)
	var group := ButtonGroup.new()
	for k in 4:
		var t := _button(row, ["Temps", "Taille", "Fil", "Arbre"][k], _tab.bind(k), ["temps", "taille", "fil", "arbre"][k])
		t.toggle_mode = true
		t.button_group = group
		t.button_pressed = k == 0
		t.size_flags_horizontal = Control.SIZE_FILL
	row.add_child(VSeparator.new())
	for k in 4:
		var page := HBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(page)
		pages.append(page)
	_button(pages[0], "+1 semaine", func(): _advance(1), "semaine")
	_button(pages[0], "+1 saison", func(): _advance(13), "saison")
	_button(pages[0], "+1 an", func(): _advance(52), "an")
	for k in 3:
		var b := _button(pages[1], ["Doigts", "Ciseaux", "Concave"][k], _set_tool.bind(k), ["doigts", "ciseaux", "concave"][k])
		b.toggle_mode = true
		tool_btns.append(b)
	cut_btn = _button(pages[1], "Couper", _cut, "couper")
	wire_btn = _button(pages[2], "Ligaturer", _act, "ligaturer")
	wire_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	for b in [cut_btn, wire_btn]:  # boutons d'action en orange
		b.add_theme_stylebox_override("normal", _box(ORANGE, GOLD))
		b.add_theme_stylebox_override("hover", _box(ORANGE, GOLD))
	_button(pages[3], "Feuilles", _toggle_leaves, "feuilles")
	_button(pages[3], "Jardin", _enter_garden, "jardin")
	_button(pages[3], "Rempoter", _show_repot, "rempoter")
	_button(pages[3], "Recentrer", _recenter, "recentrer")
	_button(pages[3], "Retirer", _remove, "retirer")
	_tab(0)
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
	bottom.custom_minimum_size.y = 16 * ui_scale
	box.add_child(bottom)
	garden_panel = PanelContainer.new()  # liste des arbres, par-dessus tout
	garden_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	garden_panel.theme = theme
	garden_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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


## Jardin d'exposition : tous les arbres à leur place, ombres actives ; seul l'arbre retravaillé est redessiné.
func _enter_garden() -> void:
	if _busy():
		return
	_clear_cut()
	for i in garden.trees.size():
		if not exhibit.nodes.has(garden.slots[i]) or garden.trees[i] == sim:
			exhibit.show_tree(garden.slots[i], garden.trees[i])
	if sim and not in_garden:
		target += exhibit.slots[garden.slots[garden.current]]  # même vue : l'arbre a repris sa place
	in_garden = true
	_mode()
	_garden_info()
	goal_target = Vector3(0, 0.6, 0)
	goal_dist = 9.0
	gliding = true


## Écran de travail de l'arbre posé sur l'emplacement s.
func _work(s: int) -> void:
	target -= exhibit.slots[s]  # l'arbre de travail est à l'origine
	in_garden = false
	_mode()
	_open(garden.at(s))


func _mode() -> void:
	exhibit.visible = in_garden
	for n in [wood_mi, leaves_mi, needles_mi, pot_mi, soil_mi, overlay]:
		n.visible = not in_garden
	panel.visible = not in_garden
	gauges.visible = not in_garden
	sun.shadow_enabled = in_garden  # ombres seulement à l'exposition (chauffe)
	sun.directional_shadow_max_distance = 16.0 if in_garden else 3.0
	max_dist = 14.0 if in_garden else 2.0
	cam.near = 0.05 if in_garden else 0.005  # précision de profondeur sur toute la cour


func _garden_info() -> void:
	info.text = "Jardin · %d / %d arbres\ntoucher : travailler · appui long : déplacer" % [garden.trees.size(), Garden.SLOTS]


## Emplacement sous le doigt (le pot ou l'arbre), -1 si aucun.
func _slot_at(pos: Vector2) -> int:
	var best := -1
	var bd := 70.0 * ui_scale
	for s in exhibit.slots.size():
		var i := garden.at(s)
		var p: Vector3 = exhibit.slots[s]
		var q := p + Vector3(0, garden.trees[i].height() if i >= 0 and s != lifted else 0.25, 0)
		if cam.is_position_behind(p) or cam.is_position_behind(q):
			continue
		var d := Geometry2D.get_closest_point_to_segment(pos, cam.unproject_position(p), cam.unproject_position(q)).distance_to(pos)
		if d < bd:
			bd = d
			best = s
	return best


## Toucher dans le jardin : la caméra s'approche de l'arbre puis passe au travail ; un « + » propose un nouvel arbre.
func _garden_tap(pos: Vector2) -> void:
	var s := _slot_at(pos)
	if s < 0:
		return
	var i := garden.at(s)
	if i < 0:
		_show_add(s)
		return
	var h := garden.trees[i].height()
	goal_target = exhibit.slots[s] + Vector3(0, maxf(0.05, h * 0.45), 0)
	goal_dist = maxf(0.35, h * 1.6)
	gliding = true
	pending_open = s


## L'arbre soulevé suit le doigt, un peu au-dessus des tablettes.
func _carry(pos: Vector2) -> void:
	var o := cam.project_ray_origin(pos)
	var d := cam.project_ray_normal(pos)
	if d.y > -0.01:
		return
	exhibit.nodes[lifted].position = o + d * ((0.95 - o.y) / d.y)


## Dépose l'arbre soulevé sur l'emplacement visé ; échange si la place est prise.
func _drop(pos: Vector2) -> void:
	var src := lifted
	lifted = -1
	var s := _slot_at(pos)
	if s < 0 or s == src:
		exhibit.place(src)
		return
	var b := garden.at(s)
	garden.slots[garden.at(src)] = s
	if b >= 0:
		garden.slots[b] = src
	exhibit.swap(src, s)
	garden.save_index()


func _show_add(s: int) -> void:
	for c in garden_panel.get_children():
		c.queue_free()
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	garden_panel.add_child(box)
	for sp in [Species.ELM, Species.PINE, Species.MAPLE]:
		_button(box, "+ " + str(sp["name"]), func():
			garden_panel.visible = false
			garden.add(sp, s)
			exhibit.show_tree(s, garden.trees[-1])
			_garden_info())
	_button(box, "Annuler", func(): garden_panel.visible = false)
	garden_panel.visible = true


## « Retirer » deux fois de suite : l'arbre ouvert quitte le jardin (son fichier est supprimé).
func _remove() -> void:
	if _busy():
		return
	if Time.get_ticks_msec() - remove_ms > 3000:
		remove_ms = Time.get_ticks_msec()
		_say("Toucher encore « Retirer » pour enlever définitivement cet arbre.")
		return
	remove_ms = 0
	var s := garden.slots[garden.current]
	exhibit.clear(s)
	garden.remove(garden.current)
	sim = null
	target += exhibit.slots[s]
	_enter_garden()


func _button(parent: Control, text: String, cb: Callable, icon := "") -> Button:
	var b := Button.new()
	b.text = text
	if icon != "":  # petit bouton : l'icône PixelLab seule, le nom reste en info-bulle
		b.icon = load("res://ui/icons/%s.png" % icon)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.tooltip_text = text
		b.text = ""
	b.clip_text = true  # jamais plus large que l'écran
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.custom_minimum_size = Vector2(72, 72) * ui_scale if icon != "" else Vector2(0, 90) * ui_scale
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
		if in_garden and pending_open < 0:  # retour au jardin : vue de trois quarts depuis l'entrée
			yaw = lerp_angle(yaw, PI + 0.35, k)
			pitch = lerpf(pitch, 0.6, k)
		gliding = target.distance_to(goal_target) > 0.0005 or absf(dist - goal_dist) > 0.0005
		_update_cam()
		if not gliding and pending_open >= 0:
			var s := pending_open
			pending_open = -1
			_work(s)
	# appui long dans le jardin : on soulève l'arbre
	if in_garden and lifted < 0 and touches.size() == 1 and not tap_moved and Time.get_ticks_msec() - press_ms > 450:
		var s := _slot_at(tap_start)
		if s >= 0 and garden.at(s) >= 0:
			lifted = s
			_carry(tap_start)
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
	wire_btn.disabled = not on or cut_k < 0


func _set_time(time: float) -> void:
	for mi in [wood_mi, leaves_mi, needles_mi]:
		TreeMesh.set_time(mi.material_override, time, anim_t0, anim_t1)


func _show(meshes: Array) -> void:
	wood_mi.mesh = meshes[0]
	leaves_mi.mesh = meshes[1]
	needles_mi.mesh = meshes[2]


func _set_tool(k: int) -> void:
	tool = k
	cut_tool = k
	for i in tool_btns.size():
		tool_btns[i].set_pressed_no_signal(i == k)
	_update_act()


## Onglet k : 0 temps, 1 taille, 2 fil (outil fil), 3 arbre.
func _tab(k: int) -> void:
	for i in pages.size():
		pages[i].visible = i == k
	tool = 3 if k == 2 else cut_tool
	for i in tool_btns.size():
		tool_btns[i].set_pressed_no_signal(i == cut_tool)
	_update_act()
	if sim:
		_draw_overlay()


## Bouton d'action : couper, ou avec le fil, ligaturer / déligaturer la branche sélectionnée.
func _update_act() -> void:
	if wire_btn == null:
		return
	cut_btn.disabled = cut_k < 0
	wire_btn.disabled = cut_k < 0
	var wired := cut_k >= 0 and sim.segs[axis[cut_k]].wire > 0
	wire_btn.icon = load("res://ui/icons/%s.png" % ("couper" if wired else "ligaturer"))  # couper le fil
	wire_btn.tooltip_text = "Déligaturer" if wired else "Ligaturer"


## Onglet Fil : ligaturer ou déligaturer la branche sélectionnée.
func _act() -> void:
	if _busy() or cut_k < 0:
		return
	var i := axis[cut_k]
	var id := sim.segs[i].wire
	_say(sim.remove_wire(id) if id > 0 else sim.add_wire(i) + " Glisse depuis le repère jaune pour plier.")
	garden.save_tree(garden.current)
	layout = sim.layout
	_refresh()


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
	_update_act()
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
	if cut_k >= 0 and sim.segs[axis[cut_k]].wire > 0:
		extra += " · " + sim.wire_state(sim.segs[axis[cut_k]].wire)
	vig_bar.value = clampf(v / 2.5, 0.0, 1.0)
	res_bar.value = clampf(sim.health() / 1.5, 0.0, 1.0)
	var state := ""
	if sim.segs[0].dry:
		state = "\nl'arbre est mort"
	elif sim.segs[0].count > 0.85 * sim.capacity:
		state = "\nlimite de rameaux du jeu atteinte : éclaircir pour relancer"
	info.text = "%s · an %d · sem. %d · %s\n%d cm · pot %d L · %s%s" % [
		garden.names[garden.current], wk / 52 + 1, w + 1, season, roundi(sim.height() * 100.0),
		roundi(sim.pot_volume), extra, state]


func _update_cam() -> void:
	cam.position = target + Vector3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw)) * dist
	cam.look_at(target)


func _input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch or ev is InputEventScreenDrag:
		last_touch = Time.get_ticks_msec()


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed:
			if panel.visible and panel.get_global_rect().has_point(ev.position):
				return
			touches[ev.index] = ev.position
			if touches.size() == 1:
				tap_start = ev.position
				press_ms = Time.get_ticks_msec()
				tap_moved = false
				# doigt posé sur le repère : on le fait glisser le long de la branche, ou on plie la branche ligaturée
				# avec le fil : le rond se déplace le long de la branche ; attraper la branche au-delà du rond la plie
				# fil : deux points blancs ; le premier (point de pli) glisse le long de la branche, le second
				# (poignée, au bout du fil) se tire pour plier
				var near := 45.0 * ui_scale
				bend_q = Quaternion.IDENTITY
				dragging_bend = false
				if tool == 3 and cut_k >= 0 and sim.segs[axis[cut_k]].wire > 0:
					# la flèche la plus proche du doigt (de part et d'autre de la poignée)
					var hp := _bend_handle()
					var l := _arrow_len(hp)
					var best := near
					for k in 3:
						var a := cam.unproject_position(hp - AXES[k] * l)
						var b := cam.unproject_position(hp + AXES[k] * l)
						var d := Geometry2D.get_closest_point_to_segment(ev.position, a, b).distance_to(ev.position)
						if d < best:
							best = d
							bend_axis = k
							dragging_bend = true
					bend_b0 = ev.position
				dragging_cut = not dragging_bend and cut_k >= 0 and _cut_screen_pos().distance_to(ev.position) < near
			else:
				tap_moved = true
				pinch = _pinch_len()
				var p: Array = touches.values()
				mid = (p[0] + p[1]) * 0.5
		elif touches.has(ev.index):
			touches.erase(ev.index)
			if in_garden and touches.is_empty():
				if lifted >= 0:
					_drop(ev.position)
				elif not tap_moved:
					_garden_tap(ev.position)
				return
			if dragging_bend and touches.is_empty():
				dragging_bend = false
				var ang := bend_q.get_angle()
				if ang > 0.01:
					var m := sim.bend(sim.segs[axis[cut_k]].wire, axis[cut_k], bend_q.get_axis(), ang)
					if m != "":
						_say(m)
					garden.save_tree(garden.current)
					if m.begins_with("Crac"):
						_clear_cut()  # la branche a cassé : les indices ont changé
					layout = sim.layout
				_refresh()
				return
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
		if in_garden and lifted >= 0:
			if touches.size() == 1:
				_carry(ev.position)
		elif touches.size() == 1 and dragging_bend:
			# tirer une flèche : le bout de la branche se déplace le long de cet axe (rotation autour du point de pli)
			var hp := _bend_handle()
			var e: Vector3 = AXES[bend_axis]
			var sd := cam.unproject_position(hp + e * _arrow_len(hp)) - cam.unproject_position(hp)
			var px := cam.global_position.distance_to(hp) * 2.0 * tan(deg_to_rad(cam.fov * 0.5)) \
					/ get_viewport().get_visible_rect().size.y
			var disp: float = (ev.position - bend_b0).dot(sd.normalized()) * px
			var arm := hp - sim.segs[axis[cut_k]].start
			var lever := (arm - e * arm.dot(e)).length()
			var ax := arm.cross(e)
			bend_q = Quaternion(ax.normalized(), atan2(disp, maxf(lever, 0.001))) if ax.length() > 0.00001 \
					else Quaternion.IDENTITY
			_draw_overlay()
		elif touches.size() == 1 and dragging_cut:
			_move_cut(ev.position)
		elif touches.size() == 1 and tap_moved:
			yaw -= ev.relative.x * 0.008
			pitch = clampf(pitch + ev.relative.y * 0.006, 0.15 if in_garden else -1.5, 1.5)  # dessus comme dessous (pas sous le jardin)
			gliding = false
			_update_cam()
		elif touches.size() == 2:
			var d := _pinch_len()
			var p: Array = touches.values()
			var m: Vector2 = (p[0] + p[1]) * 0.5
			if pinch > 0.0 and d > 0.0:
				dist = clampf(dist * pinch / d, MIN_DIST, max_dist)
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
			dist = minf(dist * 1.1, max_dist)
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
	if tool != 3:
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
	if tool == 3:
		if dragging_bend:
			_draw_ghost(im)
		_dot(im, c.start)  # point de pli
		if c.wire > 0:
			var hp := _bend_handle()
			if dragging_bend:  # la poignée suit la branche fantôme
				var g := _ghost_parts()
				hp = g[1] + g[0] * (hp - g[1])
				if g[3] >= 0:
					hp = g[2] + g[0] * (hp - g[2])
			_dot(im, hp)
			if not dragging_bend:
				_arrows(im, hp)


## Pliage tel que la simulation le fera : [demi-rotation, pivot 1, pivot 2 (déjà tourné), entre-nœud 2 ou -1].
func _ghost_parts() -> Array:
	var i0 := axis[cut_k]
	var i1 := sim.segs[i0].main_child
	if i1 >= 0 and sim.segs[i1].wire != sim.segs[i0].wire:
		i1 = -1
	var half := Quaternion.IDENTITY
	if bend_q.get_angle() > 0.0001:
		half = Quaternion(bend_q.get_axis(), bend_q.get_angle() * (0.5 if i1 >= 0 else 1.0))
	var p0 := sim.segs[i0].start
	var p1 := (p0 + half * (sim.segs[i1].start - p0)) if i1 >= 0 else p0
	return [half, p0, p1, i1]


## Longueur des flèches : constante à l'écran.
func _arrow_len(p: Vector3) -> float:
	return cam.global_position.distance_to(p) * 0.07


## Croix de trois flèches (x rouge, y vert, z bleu) à la poignée, avec une pointe à chaque bout.
func _arrows(im: ImmediateMesh, p: Vector3) -> void:
	var l := _arrow_len(p)
	var view := -cam.global_transform.basis.z
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var e: Vector3 = AXES[k]
		var col: Color = AXIS_COLS[k]
		var w := view.cross(e)
		if w.length() < 0.2:
			continue  # flèche vue de face : on ne peut pas la tirer
		w = w.normalized() * l * 0.04
		for v in [p - e * l - w, p - e * l + w, p + e * l + w, p - e * l - w, p + e * l + w, p + e * l - w]:
			im.surface_set_color(col)
			im.surface_add_vertex(v)
		for sgn in [-1.0, 1.0]:  # pointes
			var tip: Vector3 = p + e * l * 1.25 * sgn
			var base: Vector3 = p + e * l * 0.95 * sgn
			for v in [tip, base + w * 4.0, base - w * 4.0]:
				im.surface_set_color(col)
				im.surface_add_vertex(v)
	im.surface_end()


## Poignée de pliage : au bout de la partie ligaturée qui suit le point de pli.
func _bend_handle() -> Vector3:
	var ch := sim.wire_segs(sim.segs[axis[cut_k]].wire)
	return sim.segs[ch[-1]].end


## Point blanc cerclé de noir, de taille constante à l'écran, tourné vers la caméra.
func _dot(im: ImmediateMesh, p: Vector3) -> void:
	var bas := cam.global_transform.basis
	var r := cam.global_position.distance_to(p) * 0.012
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in [[r * 1.35, Color(0.1, 0.1, 0.1)], [r, Color.WHITE]]:
		var rr: float = ring[0]
		var col: Color = ring[1]
		for k in 16:
			var u0 := TAU * k / 16.0
			var u1 := TAU * (k + 1) / 16.0
			for v in [p, p + (bas.x * cos(u0) + bas.y * sin(u0)) * rr, p + (bas.x * cos(u1) + bas.y * sin(u1)) * rr]:
				im.surface_set_color(col)
				im.surface_add_vertex(v)
	im.surface_end()


## Branche fantôme pendant le pliage : la partie au-delà du rond, pliée comme le fera la simulation (moitié
## de l'angle à la base de l'entre-nœud du rond, moitié au suivant), en rubans orange translucides.
func _draw_ghost(im: ImmediateMesh) -> void:
	var i0 := axis[cut_k]
	var g := _ghost_parts()
	var half: Quaternion = g[0]
	var p0: Vector3 = g[1]
	var p1: Vector3 = g[2]
	var i1: int = g[3]
	var second := {}
	if i1 >= 0:
		for k in sim.subtree(i1):
			second[k] = true
	var view := -cam.global_transform.basis.z
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in sim.subtree(i0):
		var s := sim.segs[k]
		if s.dry:
			continue
		var e := [s.start, s.end]
		for j in 2:
			e[j] = p0 + half * (e[j] - p0)
			if second.has(k):
				e[j] = p1 + half * (e[j] - p1)
		var side: Vector3 = view.cross(e[1] - e[0]).normalized() * maxf(s.radius * 1.2, 0.0012)
		var col := Color(1.0, 0.55, 0.1, 0.55)
		for v in [e[0] - side, e[0] + side, e[1] + side, e[0] - side, e[1] + side, e[1] - side]:
			im.surface_set_color(col)
			im.surface_add_vertex(v)
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
