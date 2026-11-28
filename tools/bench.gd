extends SceneTree
## Banc d'essai sans écran (audit du moteur, phase 1), lancé par GitHub Actions à chaque PR :
## chaque espèce pousse 8 ans sans taille ; temps de simulation et de dessin, entre-nœuds, sommets.
## Les temps sont ceux d'un serveur, pas du téléphone : ils servent à comparer les versions entre elles.


func _init() -> void:
	# compile tous les scripts : une erreur de syntaxe apparaît dans le journal (« Parse Error »)
	for f in DirAccess.get_files_at("res://scripts"):
		if f.ends_with(".gd"):
			var sc: GDScript = load("res://scripts/" + f)
			if sc == null or not sc.can_instantiate():
				print("ERREUR DE SCRIPT : ", f)
	var out := "| espèce | an | entre-nœuds | simulation (ms/an) | dessin (ms) | sommets |\n|---|---|---|---|---|---|\n"
	var total := 0
	for sp in Species.ALL:
		var sim := TreeSim.new()
		sim.reset(1, sp)
		for y in 8:
			# dessin en été (semaine 30), avec les feuilles ; la simulation compte l'année entière
			var t0 := Time.get_ticks_usec()
			for w in 20:
				sim.step_week()
			var t1 := Time.get_ticks_usec()
			var m := TreeMesh.build(sim, PackedInt32Array(), sim.week, sim.week, true)
			var t2 := Time.get_ticks_usec()
			for w in 32:
				sim.step_week()
			var t3 := Time.get_ticks_usec()
			var sim_us := (t1 - t0) + (t3 - t2)
			total += t3 - t0
			if y % 2 == 1:
				out += "| %s | %d | %d | %d | %d | %d |\n" % [sp["name"], y + 1, sim.segs.size(), sim_us / 1000, (t2 - t1) / 1000, TreeMesh.vertex_count(m)]
	out += "\nTotal : %d ms\n" % (total / 1000)
	out += _techniques()
	out += _racines()
	out += _pause()
	out += _genevrier()
	out += _diag_genevrier()
	print("=== BANC ===")
	print(out)
	quit()


## Étape 28 : orme sur 5 ans, libre, pincé chaque printemps, effeuillé chaque été (à partir de la 2e année).
## Mesuré en été de la 5e année, sur les pousses de l'année.
func _techniques() -> String:
	var out := "\n| conduite (orme) | entre-nœuds | pointes | entre-nœud moyen (mm) | pousses : moyen / 9e décile (mm) | taille des feuilles | santé fin d'été / juin |\n|---|---|---|---|---|---|---|\n"
	for mode in ["libre", "pincé", "effeuillé", "libre (3 ans)", "pincé (3 ans)"]:
		var june := 0.0
		var sim := TreeSim.new()
		sim.reset(1, Species.ELM)
		var AGE := 3 if mode.ends_with("(3 ans)") else 5
		for y in AGE:
			for w in 52:
				sim.step_week()
				var wk := sim.week % 52
				if mode.begins_with("pincé") and y >= 1 and wk >= 16 and wk <= 20:
					_pinch_all(sim)
				if mode == "effeuillé" and y >= 1 and wk == 24:
					sim.defoliate()
				if y == AGE - 1 and wk == 23:
					june = sim.vigor_now()
				if y == AGE - 1 and wk == 37:  # après le remplissage des réserves de fin d'été
					out += _stats(sim, mode, june)
	return out


## Pince chaque pousse tendre de 3 entre-nœuds ou plus après son 2e entre-nœud.
func _pinch_all(sim: TreeSim) -> void:
	var y0 := floorf(sim.week / 52.0) * 52.0
	for i in range(sim.segs.size() - 1, 0, -1):
		if i >= sim.segs.size():
			continue
		var s := sim.segs[i]
		if s.born >= y0 and sim.segs[s.parent].born < y0 and sim.subtree(i).size() >= 3 and s.main_child >= 0:
			var m := sim.segs[s.main_child].main_child
			if m >= 0:
				sim.pinch(m)


func _stats(sim: TreeSim, mode: String, june: float) -> String:
	var y0 := floorf(sim.week / 52.0) * 52.0
	var tips := 0
	var len_sum := 0.0
	var leaf_sum := 0.0
	var n := 0
	var shoot := PackedFloat32Array()  # entre-nœuds des vraies pousses (pas des rameaux courts)
	for s in sim.segs:
		if s.dry:
			continue
		if s.term_bud:
			tips += 1
		if s.born >= y0:
			len_sum += (s.end - s.start).length()
			leaf_sum += s.size_k
			n += 1
			if s.grow_time < TreeSim.GROW_WEEKS * 0.75:  # pousse d'au moins 2 entre-nœuds
				shoot.append((s.end - s.start).length())
	shoot.sort()
	var mean := 0.0
	for x in shoot:
		mean += x
	mean /= maxi(shoot.size(), 1)
	var p90 := shoot[int(shoot.size() * 0.9)] if shoot.size() > 0 else 0.0
	var nmax := 0
	var nsum := 0.0
	var nn := 0
	for q in sim.segs:
		if q.born >= y0 and not q.dry:
			var k := roundi(TreeSim.GROW_WEEKS / q.grow_time)
			nmax = maxi(nmax, k)
			nsum += k
			nn += 1
	mode += " (entre-nœuds par pousse : moy. %.1f, max %d)" % [nsum / maxi(nn, 1), nmax]
	return "| %s | %d | %d | %.1f | %.1f / %.1f | %.2f | %.2f / %.2f |\n" % [mode, sim.segs.size(), tips, 1000.0 * len_sum / maxi(n, 1),
			1000.0 * mean, 1000.0 * p90, leaf_sum / maxi(n, 1), sim.health(), june]


## Étape 29a : orme sur 6 ans ; terre baissée d'1 cm chaque printemps à partir de la 4e année (témoin : terre
## d'origine). Racines exportées (lignes « RACINE ») pour la vérification dessinée (check/racines_nu.py).
func _racines() -> String:
	var out := "\n| racines (orme, 6 ans) | segments | à nu | à nu épaisses (> 2 mm) | rayon moyen à nu (mm) | santé |\n|---|---|---|---|---|---|\n"
	for mode in ["terre d'origine", "terre baissée", "pierre"]:
		var sim := TreeSim.new()
		sim.reset(1, Species.ELM)
		for y in 6:
			for w in 52:
				sim.step_week()
				if mode == "pierre" and y == 1 and sim.week % 52 == 8:
					sim.root.place_rock(1)
				if mode != "terre d'origine" and y >= 3 and sim.week % 52 == 8:
					sim.root.set_soil(sim.root.soil_y - (0.01 if mode == "terre baissée" else 0.015))
		var rs := sim.root
		var nu := 0
		var thick := 0
		var rsum := 0.0
		for i in rs.size():
			if not rs.in_soil(rs.p1[i]):
				nu += 1
				rsum += rs.rad[i]
				if rs.rad[i] > 0.001:
					thick += 1
		out += "| %s (terre %+.0f cm) | %d | %d | %d | %.2f | %.2f |\n" % [mode, rs.soil_y * 100.0, rs.size(), nu, thick, 1000.0 * rsum / maxi(nu, 1), sim.health()]
		if mode != "terre d'origine":
			var lines := "SOL %s %f %f %f %f\n" % [mode.replace(" ", "_"), rs.soil_y, rs.hx, rs.hz, sim.segs[0].radius]
			if rs.rock:
				lines += "ROCHE %f %f %f %f %f %f %f %f %f %f %f\n" % [rs.rock_c.x, rs.rock_c.y, rs.rock_c.z, rs.rock_r.x, rs.rock_r.y, rs.rock_r.z, rs.rock_s.x, rs.rock_s.y, rs.rock_s.z, rs.rim_y, rs.depth]
			for i in rs.size():
				lines += "RACINE %f %f %f %f %f %f %f\n" % [rs.p0[i].x, rs.p0[i].y, rs.p0[i].z, rs.p1[i].x, rs.p1[i].y, rs.p1[i].z, rs.rad[i]]
			print(lines)
	return out


## Étape 30b : coût de la copie d'état (à chaque paquet) et du retour en arrière (à la pause), sur un arbre de
## 8 ans ; puis même arbre au bout d'un an, joué d'un coup ou avec un retour en arrière au milieu.
func _pause() -> String:
	var out := "\n| pause (8 ans, semaine 20) | entre-nœuds | copie (ms) | retour (ms) | identique après retour |\n|---|---|---|---|---|\n"
	for sp in Species.ALL:
		var sim := TreeSim.new()
		sim.reset(3, sp)
		for w in 52 * 7 + 20:
			sim.step_week()
		var t0 := Time.get_ticks_usec()
		var snap := sim.to_data().duplicate(true)
		var t1 := Time.get_ticks_usec()
		var ref := TreeSim.new()
		ref.reset(3, sp)
		ref.from_data(snap.duplicate(true))
		for w in 6:
			sim.step_week()
		var t1b := Time.get_ticks_usec()
		sim.from_data(snap.duplicate(true))
		var t2 := Time.get_ticks_usec()
		for w in 26:
			sim.step_week()
			ref.step_week()
		var same := sim.segs.size() == ref.segs.size() and is_equal_approx(sim.segs[0].radius, ref.segs[0].radius) and sim.root.size() == ref.root.size()
		out += "| %s | %d | %d | %d | %s |\n" % [sp["name"], sim.segs.size(), (t1 - t0) / 1000, (t2 - t1b) / 1000, "oui" if same else "NON"]
	return out


## Étape 31 : genévrier sur 4 ans, libre, fortement taillé ou pincé au début du 4e printemps (semaine 10).
## Mesuré en été (semaine 30) de la 4e année ; export des segments pour le dessin de vérification.
func _genevrier() -> String:
	var out := "\n| genévrier (4 ans, été) | entre-nœuds | hauteur (cm) | pousses de l'année | dont juvéniles | bois nu (> 4 ans) | santé |\n|---|---|---|---|---|---|---|\n"
	for mode in ["libre", "forte taille", "pincé"]:
		var sim := TreeSim.new()
		sim.reset(1, Species.JUNIPER)
		for w in 52 * 3 + 10:
			sim.step_week()
		if mode == "forte taille":
			while sim.cut_year < 0.45:
				var best := -1
				for i in range(1, sim.segs.size()):
					var sg := sim.segs[i]
					if sim.segs[sg.parent].lat_child == i and not sg.dry and (best < 0 or sg.light > sim.segs[best].light):
						best = i
				if best < 0 or not sim.prune(best):
					break
		if mode == "pincé":
			_pinch_all(sim)
		for w in 20:
			sim.step_week()
		var y0 := floorf(sim.week / 52.0) * 52.0
		var young := 0
		var juv := 0
		var bare := 0
		for sg in sim.segs:
			if sg.born >= y0:
				young += 1
				if sg.juv:
					juv += 1
			elif not sg.dry and sim.week - sg.born >= 52 * 4:
				bare += 1
		out += "| %s | %d | %d | %d | %d | %d | %.2f |\n" % [mode, sim.segs.size(), roundi(sim.height() * 100.0), young, juv, bare, sim.health()]
		var lines := "GENEVRIER %s %d\n" % [mode.replace(" ", "_"), sim.week]
		for sg in sim.segs:
			lines += "JSEG %f %f %f %f %f %f %f %f %d %d %f\n" % [sg.start.x, sg.start.y, sg.start.z, sg.end.x, sg.end.y, sg.end.z, sg.radius, sg.born, int(sg.juv), int(sg.dry), sg.phase]
		print(lines)
	return out


## Diagnostic temporaire (étape 31) : le genévrier s'arrête de pousser ; variantes pour isoler la cause.
func _diag_genevrier() -> String:
	var out := "\n| diag genévrier | an1 seg | an2 seg | an3 seg | santé an3 | racines | lumière |\n|---|---|---|---|---|---|---|\n"
	for v in ["tel quel", "poussées orme", "non opposé", "caduc", "entre-nœud 1 cm", "fiche orme + écailles"]:
		var sim := TreeSim.new()
		sim.reset(1, Species.JUNIPER if v != "fiche orme + écailles" else Species.ELM)
		match v:
			"poussées orme": sim.flushes = {14: 1.0, 22: 0.7, 30: 0.4}
			"non opposé": sim.opposite = false
			"caduc": sim.leaf_years = 0
			"entre-nœud 1 cm": sim.internode = 0.01
			"fiche orme + écailles": sim.leaf_shape = 3
		var n := []
		for y in 3:
			for w in 52:
				sim.step_week()
				if y == 0 and (sim.week % 52 in [13, 15, 20, 25, 31, 34, 36, 37]):
					print("DIAG %s sem %d seg %d res %.3f roots %.3f light %.3f vig %.3f" % [v, sim.week, sim.segs.size(), sim.reserve, sim.roots, sim.segs[0].light, sim.last_vigor])
			n.append(sim.segs.size())
		out += "| %s | %d | %d | %d | %.2f | %.2f | %.2f |\n" % [v, n[0], n[1], n[2], sim.health(), sim.roots, sim.segs[0].light]
	return out
