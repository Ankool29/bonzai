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
	print("=== BANC ===")
	print(out)
	quit()


## Étape 28 : orme sur 5 ans, libre, pincé chaque printemps, effeuillé chaque été (à partir de la 2e année).
## Mesuré en été de la 5e année, sur les pousses de l'année.
func _techniques() -> String:
	var out := "\n| conduite (orme, 5 ans) | entre-nœuds | pointes | entre-nœud moyen (mm) | taille des feuilles | santé |\n|---|---|---|---|---|---|\n"
	for mode in ["libre", "pincé", "effeuillé"]:
		var sim := TreeSim.new()
		sim.reset(1, Species.ELM)
		for y in 5:
			for w in 52:
				sim.step_week()
				var wk := sim.week % 52
				if mode == "pincé" and y >= 1 and wk >= 16 and wk <= 20:
					_pinch_all(sim)
				if mode == "effeuillé" and y >= 1 and wk == 24:
					sim.defoliate()
				if y == 4 and wk == 37:  # après le remplissage des réserves de fin d'été
					out += _stats(sim, mode)
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


func _stats(sim: TreeSim, mode: String) -> String:
	var y0 := floorf(sim.week / 52.0) * 52.0
	var tips := 0
	var len_sum := 0.0
	var leaf_sum := 0.0
	var n := 0
	for s in sim.segs:
		if s.dry:
			continue
		if s.term_bud:
			tips += 1
		if s.born >= y0:
			len_sum += (s.end - s.start).length()
			leaf_sum += s.size_k
			n += 1
	return "| %s | %d | %d | %.1f | %.2f | %.2f |\n" % [mode, sim.segs.size(), tips, 1000.0 * len_sum / maxi(n, 1), leaf_sum / maxi(n, 1), sim.health()]
