class_name RootSim
extends RefCounted
## Charpente racinaire dans le pot (étape 23a) : entre-nœuds ligneux qui poussent vers la terre libre,
## courent sous la surface, tournent le long des parois et grossissent selon la part du houppier qu'ils
## nourrissent (modèle des tuyaux, secteurs). Les grosses racines proches du tronc affleurent : le nebari.
## Prototype et vérification : check/racines.py.

const RI := 0.012          # entre-nœud racinaire (m)
const LPU := 0.05          # m de racine ligneuse par unité de racines (TreeSim.roots)
const CELL := 0.01         # grille de terre
const MAX := 1500          # plafond de segments
const MIN_R := 0.0008
const SECTORS := 8

var p0 := PackedVector3Array()
var p1 := PackedVector3Array()
var dir := PackedVector3Array()
var par := PackedInt32Array()
var rad := PackedFloat32Array()
var tip := PackedByteArray()
var order := PackedByteArray()
var occ := {}              # cellule -> nombre de segments (densité de racines)
var hx := 0.15
var hz := 0.10
var depth := 0.048
var sp := {}               # réglages de l'espèce : n, tap, dip, branch, mix
var rng := RandomNumberGenerator.new()  # hasard propre : la pousse des branches ne change pas


func setup(species: Dictionary, volume: float) -> void:
	sp = {"n": species["root_n"], "tap": species["root_tap"], "dip": species["root_dip"],
			"branch": species["root_branch"], "mix": species["root_mix"]}
	set_pot(volume)


## Pot de la même forme que celui dessiné (32 × 22 × 5 cm à 8 L).
func set_pot(volume: float) -> void:
	var k := pow(volume / 8.0, 1.0 / 3.0)
	hx = 0.15 * k
	hz = 0.10 * k
	depth = 0.048 * k


func size() -> int:
	return p0.size()


func plant(seed_value: int) -> void:
	rng.seed = seed_value
	var c := Vector3(0, -0.004, 0)
	if sp["tap"]:
		_add(c, Vector3.DOWN, -1, 0)
	var a0 := rng.randf() * TAU
	for k in int(sp["n"]):
		var a: float = a0 + k * TAU / sp["n"] + rng.randf_range(-0.3, 0.3)
		_add(c + Vector3(cos(a), 0, sin(a)) * 0.002, Vector3(cos(a) * cos(0.1), -sin(0.1), sin(a) * cos(0.1)), -1, 0)


func _add(a: Vector3, d: Vector3, parent: int, o: int) -> int:
	var b := a + d * RI
	p0.append(a)
	p1.append(b)
	dir.append(d)
	par.append(parent)
	rad.append(MIN_R)
	tip.append(1)
	order.append(o)
	if parent >= 0:
		tip[parent] = 0
	var c := _cell(b)
	occ[c] = occ.get(c, 0) + 1
	return p0.size() - 1


func _cell(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / CELL), floori(p.y / CELL), floori(p.z / CELL))


func _free(p: Vector3) -> float:
	return 1.0 / (1.0 + occ.get(_cell(p), 0) / 3.0)


func _inside(p: Vector3, m := 0.004) -> bool:
	return absf(p.x) < hx - m and absf(p.z) < hz - m and p.y > -depth + m and p.y < 0.0


## Direction suivante d'une pointe : à fleur de terre près du tronc, plus profond au-delà (selon l'ordre).
func _steer(i: int) -> Vector3:
	var d := dir[i]
	var h := Vector3(d.x, 0, d.z)
	h = h.normalized() if h.length() > 0.000001 else Vector3.RIGHT
	var want := Vector3.DOWN
	if not (sp["tap"] and i == 0):
		var far := minf(1.0, Vector2(p1[i].x, p1[i].z).length() / 0.05)
		var zd: float = -0.002 - (sp["dip"] + 8.0 * order[i]) * 0.001 * far
		want = (h + Vector3(0, (zd - p1[i].y) / 0.01, 0)).normalized()
	var j := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 0.3), rng.randf_range(-1, 1)) * 0.25
	return _wall(p1[i], d * 0.7 + want * 0.3 + j)


## Au bord du pot, la pointe glisse le long de la paroi (les racines finissent par tourner en rond).
func _wall(p: Vector3, d: Vector3) -> Vector3:
	d = d.normalized()
	var nx := p + d * RI
	if not _inside(nx):
		if absf(nx.x) >= hx - 0.004 and d.x * nx.x > 0.0:
			d.x = 0.0
		if absf(nx.z) >= hz - 0.004 and d.z * nx.z > 0.0:
			d.z = 0.0
		if nx.y <= -depth + 0.004 and d.y < 0.0:
			d.y = 0.0
		if nx.y >= 0.0 and d.y > 0.0:
			d.y = 0.0
		d = d.normalized() if d.length() > 0.000001 else Vector3(-p.z, 0, p.x).normalized()
	return d


## Poussée de racines : les pointes s'allongent jusqu'à la longueur que demandent les racines (TreeSim.roots).
func pulse(roots: float) -> void:
	var tips := PackedInt32Array()
	for i in p0.size():
		if tip[i]:
			tips.append(i)
	var budget := mini(mini(int((roots * LPU - p0.size() * RI) / RI), tips.size() * 3), MAX - p0.size())
	for n in budget:
		# tirage pondéré : terre libre devant la pointe, racines fines un peu moins favorisées
		var sum := 0.0
		var w := PackedFloat32Array()
		w.resize(tips.size())
		for k in tips.size():
			var t := tips[k]
			w[k] = pow(_free(p1[t]), 2.0) / (1.0 + 0.5 * order[t])
			sum += w[k]
		var r := rng.randf() * sum
		var k := 0
		while k < tips.size() - 1 and r > w[k]:
			r -= w[k]
			k += 1
		var i := tips[k]
		var d := _steer(i)
		var j := _add(p1[i], d, i, order[i])
		tips[k] = j
		if order[i] < 4 and rng.randf() < sp["branch"]:  # racine latérale, presque à l'horizontale
			var a := deg_to_rad(70.0) * (1.0 if rng.randf() < 0.5 else -1.0)
			var ld := Vector3(d.x * cos(a) - d.z * sin(a), d.y * 0.3, d.x * sin(a) + d.z * cos(a))
			tips.append(_add(p1[i], _wall(p1[i], ld), i, order[i] + 1))
			tip[j] = 1  # le prolongement reste une pointe


## Cerne annuel des racines (modèle des tuyaux) : chaque pointe porte la part du houppier de son secteur,
## mêlée selon l'intégration de l'espèce ; contreforts près du collet (zone de rapide décroissance).
func thicken(sector_light: PackedFloat32Array, ring: float, trunk_r: float) -> void:
	var n := p0.size()
	if n == 0:
		return
	var flow := PackedFloat32Array()
	flow.resize(n)
	var cnt := PackedInt32Array()
	cnt.resize(SECTORS)
	var ntip := 0
	var tot := 0.0
	for s in sector_light:
		tot += s
	for i in n:
		if tip[i]:
			cnt[sector(p1[i])] += 1
			ntip += 1
	for i in n:
		if tip[i]:
			var s := sector(p1[i])
			flow[i] = (1.0 - sp["mix"]) * sector_light[s] / cnt[s] + sp["mix"] * tot / ntip
	for i in range(n - 1, -1, -1):
		if par[i] >= 0:
			flow[par[i]] += flow[i]
	for i in n:
		var zrt := 1.0 + 2.0 * maxf(0.0, 1.0 - Vector2(p0[i].x, p0[i].z).length() / (4.0 * trunk_r))
		rad[i] = sqrt(rad[i] * rad[i] + ring * flow[i] * zrt / PI)


func sector(p: Vector3) -> int:
	return int(fposmod(atan2(p.z, p.x), TAU) / TAU * SECTORS) % SECTORS


## Rempotage : retire la part « cut » de la longueur, en commençant par les racines les plus éloignées du tronc.
func prune_far(cut: float) -> void:
	if cut <= 0.0 or p0.size() == 0:
		return
	var idx := range(p0.size())
	idx.sort_custom(func(a, b): return p1[a].length_squared() > p1[b].length_squared())
	var dead := {}
	for k in int(p0.size() * cut):
		dead[idx[k]] = true
	for i in p0.size():  # un segment dont le parent est retiré l'est aussi
		if par[i] >= 0 and dead.has(par[i]):
			dead[i] = true
	_remove(dead)


func _remove(dead: Dictionary) -> void:
	var map := PackedInt32Array()
	map.resize(p0.size())
	var n0 := PackedVector3Array()
	var n1 := PackedVector3Array()
	var nd := PackedVector3Array()
	var np := PackedInt32Array()
	var nr := PackedFloat32Array()
	var nt := PackedByteArray()
	var no := PackedByteArray()
	for i in p0.size():  # les parents précèdent toujours leurs enfants
		map[i] = -1
		if dead.has(i):
			continue
		map[i] = n0.size()
		n0.append(p0[i])
		n1.append(p1[i])
		nd.append(dir[i])
		np.append(map[par[i]] if par[i] >= 0 else -1)
		nr.append(rad[i])
		nt.append(1)
		no.append(order[i])
	for i in np.size():  # les bouts coupés redeviennent des pointes
		if np[i] >= 0:
			nt[np[i]] = 0
	p0 = n0
	p1 = n1
	dir = nd
	par = np
	rad = nr
	tip = nt
	order = no
	_rebuild_occ()


func _rebuild_occ() -> void:
	occ.clear()
	for p in p1:
		var c := _cell(p)
		occ[c] = occ.get(c, 0) + 1


func to_data() -> Dictionary:
	return {"p0": p0, "p1": p1, "dir": dir, "par": par, "rad": rad, "tip": tip, "order": order,
			"seed": rng.seed, "state": rng.state}


func from_data(d: Dictionary) -> void:
	p0 = d["p0"]
	p1 = d["p1"]
	dir = d["dir"]
	par = d["par"]
	rad = d["rad"]
	tip = d["tip"]
	order = d["order"]
	rng.seed = d["seed"]
	rng.state = d["state"]
	_rebuild_occ()
