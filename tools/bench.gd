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
	print("=== BANC ===")
	print(out)
	quit()
