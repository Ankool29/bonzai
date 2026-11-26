class_name Garden
## Le jardin : tous les arbres du joueur, chacun avec sa propre date, sauvegardés dans user://.
## Un fichier d'index (noms, arbre ouvert) et un fichier par arbre (on ne réécrit que celui qui change).

const INDEX := "user://jardin.save"

var trees: Array[TreeSim] = []
var names: Array[String] = []
var ids: Array[int] = []
var current := 0
var next_id := 1


func load_all() -> void:
	if not FileAccess.file_exists(INDEX):
		return
	var f := FileAccess.open(INDEX, FileAccess.READ)
	var d: Dictionary = f.get_var()
	current = d["current"]
	next_id = d["next_id"]
	for k in d["ids"].size():
		var tf := FileAccess.open(_path(d["ids"][k]), FileAccess.READ)
		if tf == null:
			continue  # fichier d'arbre perdu : on garde les autres
		var t := TreeSim.new()
		t.from_data(tf.get_var())
		trees.append(t)
		ids.append(d["ids"][k])
		names.append(d["names"][k])
	current = clampi(current, 0, maxi(trees.size() - 1, 0))


## Nouvel arbre, mis en pot début mars de l'année 1 ; devient l'arbre ouvert.
func add(species: Dictionary) -> void:
	var t := TreeSim.new()
	t.reset(randi(), species)
	trees.append(t)
	ids.append(next_id)
	names.append("%s %d" % [t.name.split(" ")[0], next_id])
	next_id += 1
	current = trees.size() - 1
	save_tree(current)
	save_index()


func remove(i: int) -> void:
	DirAccess.remove_absolute(_path(ids[i]))
	trees.remove_at(i)
	ids.remove_at(i)
	names.remove_at(i)
	current = clampi(current if current < i else current - 1, 0, trees.size() - 1)
	save_index()


func save_index() -> void:
	var f := FileAccess.open(INDEX, FileAccess.WRITE)
	f.store_var({"current": current, "next_id": next_id, "ids": ids, "names": names})


func save_tree(i: int) -> void:
	var f := FileAccess.open(_path(ids[i]), FileAccess.WRITE)
	f.store_var(trees[i].to_data())


func save_all() -> void:
	for i in trees.size():
		save_tree(i)
	save_index()


func _path(id: int) -> String:
	return "user://arbre_%d.save" % id
