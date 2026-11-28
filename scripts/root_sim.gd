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
const TILE_R := 0.06       # tuile sous le tronc (étape 23b) : les racines au-dessus ne descendent plus
const TILE_Y := -0.012

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
var tile := false
var soil_y := 0.0          # niveau de la terre (étape 29a) : sous le bord du pot = racines à nu, au-dessus = butte
const SOIL_MIN := -0.03
const SOIL_MAX := 0.04
# Pierre (étape 29b) : posée sous le collet ; le pot est abaissé d'autant (bord à rim_y).
var rock := false
var rock_c := Vector3.ZERO     # centre
var rock_r := Vector3.ONE      # demi-axes
var rock_s := Vector3.ZERO     # phases du relief (forme propre à chaque pierre)
var rim_y := 0.0               # hauteur du bord du pot (0 sans pierre)
const ROCKS := [Vector3(0.035, 0.03, 0.03), Vector3(0.05, 0.045, 0.04), Vector3(0.04, 0.07, 0.035)]  # petite, moyenne, haute


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


func _add(a: Vector3, d: Vector3, parent: int, o: int, l := RI) -> int:
	var b := a + d * l
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
	return absf(p.x) < hx - m and absf(p.z) < hz - m and p.y > rim_y - depth + m and in_soil(p) and not _under_tile(p)


## Sous la terre : dans le pot sous le niveau de la terre, ou dans la butte (plus étroite vers le haut) ;
## jamais dans la pierre.
func in_soil(p: Vector3) -> bool:
	if p.y >= soil_y or (rock and rock_dist(p) < 0.0):
		return false
	if p.y <= rim_y:
		return true
	var f := 1.0 - 0.65 * (p.y - rim_y) / (soil_y - rim_y)
	return absf(p.x) < hx * f and absf(p.z) < hz * f


## Rayon de la pierre dans la direction u (unitaire) : ellipsoïde bosselé, même forme pour la simulation et le dessin.
func rock_radius(u: Vector3) -> float:
	var e := 1.0 / sqrt(pow(u.x / rock_r.x, 2.0) + pow(u.y / rock_r.y, 2.0) + pow(u.z / rock_r.z, 2.0))
	var n := sin(3.0 * u.x + rock_s.x) * sin(2.5 * u.y + rock_s.y) * sin(3.5 * u.z + rock_s.z) + 0.5 * sin(7.0 * u.x + 5.0 * u.z + rock_s.y)
	return e * (1.0 + 0.12 * n)


## Distance (approchée) à la surface de la pierre : < 0 dedans.
func rock_dist(p: Vector3) -> float:
	var q := p - rock_c
	var l := q.length()
	return l - rock_radius(q / l) if l > 0.000001 else -1.0


func rock_normal(p: Vector3) -> Vector3:
	var e := 0.001
	return Vector3(rock_dist(p + Vector3(e, 0, 0)) - rock_dist(p - Vector3(e, 0, 0)),
			rock_dist(p + Vector3(0, e, 0)) - rock_dist(p - Vector3(0, e, 0)),
			rock_dist(p + Vector3(0, 0, e)) - rock_dist(p - Vector3(0, 0, e))).normalized()


## Pose l'arbre sur une pierre (0 petite, 1 moyenne, 2 haute) : la pierre touche le collet, le pot s'abaisse pour
## l'enterrer aux deux tiers, la terre monte en butte jusqu'au collet (racines protégées, comme en vrai). Les racines
## à plus de 3 cm du collet sont coupées, les autres plaquées sur la pierre. Renvoie la part de racines coupées.
func place_rock(kind: int) -> float:
	rock = true
	rock_r = ROCKS[kind]
	rock_s = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
	rock_c = Vector3(0, -0.004, 0)
	rock_c.y -= rock_radius(Vector3.UP)
	var bottom := rock_c.y - rock_radius(Vector3.DOWN)
	rim_y = bottom + depth * 0.7
	soil_y = 0.0
	var n := p0.size()
	var dead := {}
	for i in n:
		if dead.has(par[i]) or p1[i].length() > 0.03:
			dead[i] = true
	if not dead.is_empty():
		_remove(dead)
	for i in p0.size():  # plaquées sur la pierre
		p0[i] = _hug(p0[i])
		p1[i] = _hug(p1[i])
		dir[i] = (p1[i] - p0[i]).normalized() if p1[i] != p0[i] else Vector3.DOWN
	_rebuild_occ()
	return float(n - p0.size()) / maxf(n, 1.0)


## Point ramené à fleur de pierre (s'il est dedans ou tout près).
func _hug(p: Vector3) -> Vector3:
	for k in 3:
		var d := rock_dist(p)
		if d > 0.003:
			break
		p += rock_normal(p) * (0.0015 - d)
	return p


func _under_tile(p: Vector3) -> bool:
	return tile and p.y < TILE_Y and Vector2(p.x, p.z).length() < TILE_R


## Direction suivante d'une pointe : à fleur de terre près du tronc, plus profond au-delà (selon l'ordre).
func _steer(i: int) -> Vector3:
	var d := dir[i]
	var h := Vector3(d.x, 0, d.z)
	h = h.normalized() if h.length() > 0.000001 else Vector3.RIGHT
	var want := Vector3.DOWN
	if rock and p1[i].y > rim_y - 0.01 and rock_dist(p1[i]) < 0.015:
		# sur la pierre : la racine descend en suivant sa surface, plaquée contre elle
		var nr := rock_normal(p1[i])
		var down := (Vector3.DOWN - nr * Vector3.DOWN.dot(nr)).normalized()
		want = (down - nr * clampf((rock_dist(p1[i]) - 0.0015) / 0.004, -1.0, 1.0)).normalized()
		var jr := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 0.15
		return _wall(p1[i], d * 0.4 + want * 0.6 + jr)
	if not (sp["tap"] and i == 0):
		var far := minf(1.0, Vector2(p1[i].x, p1[i].z).length() / 0.05)
		var zd: float = minf(soil_y, rim_y) - 0.002 - (sp["dip"] + 8.0 * order[i]) * 0.001 * far
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
		if nx.y <= rim_y - depth + 0.004 and d.y < 0.0:
			d.y = 0.0
		if (nx.y >= soil_y - 0.002 and d.y > 0.0) or (_under_tile(nx) and d.y < 0.0):
			d.y = 0.0
		d = d.normalized() if d.length() > 0.000001 else Vector3(-p.z, 0, p.x).normalized()
	if rock and rock_dist(p + d * RI) < 0.0005:  # contre la pierre : la pointe glisse sur sa surface
		var nr := rock_normal(p + d * RI)
		d = d - nr * minf(d.dot(nr), 0.0)
		d = d.normalized() if d.length() > 0.000001 else Vector3.DOWN
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
			# une pointe à l'air ne pousse plus (ni latérales) : il lui faut la terre
			w[k] = pow(_free(p1[t]), 2.0) / (1.0 + 0.5 * order[t]) if in_soil(p1[t]) else 0.0
			sum += w[k]
		if sum <= 0.0:
			break
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
func thicken(sector_light: PackedFloat32Array, ring: float, trunk_r: float) -> float:
	var n := p0.size()
	if n == 0:
		return 0.0
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
	# Racines à nu (étape 29a) : une racine épaisse continue de grossir et devient du tronc tant que ses pointes
	# sont dans la terre ; une racine fine (moins de 2 mm) à l'air se dessèche avec tout ce qu'elle porte ; une
	# racine sans aucune pointe dans la terre sèche (Bonsai Bark, Bonsai Nut, Fire Escape Bonsai). D'où l'intérêt
	# de dégager peu à peu, une fois les racines épaissies.
	var wet := PackedByteArray()
	wet.resize(n)
	for i in range(n - 1, -1, -1):
		if tip[i] and in_soil(p1[i]):
			wet[i] = 1
		if wet[i] and par[i] >= 0:
			wet[par[i]] = 1
	var dead := {}
	for i in n:
		if not wet[i] or (par[i] >= 0 and dead.has(par[i])) or (not in_soil(p1[i]) and rad[i] < 0.001):
			dead[i] = true
			continue
		var zrt := 1.0 + 2.0 * maxf(0.0, 1.0 - Vector2(p0[i].x, p0[i].z).length() / (4.0 * trunk_r))
		rad[i] = sqrt(rad[i] * rad[i] + ring * flow[i] * zrt / PI)
	if not dead.is_empty():
		_remove(dead)
	return float(dead.size()) / n  # part des racines perdues (racines à nu desséchées)


func sector(p: Vector3) -> int:
	return int(fposmod(atan2(p.z, p.x), TAU) / TAU * SECTORS) % SECTORS


## Monte (+) ou baisse (-) la terre ; renvoie le nouveau niveau.
func set_soil(y: float) -> float:
	soil_y = clampf(y, rim_y + maxf(SOIL_MIN, -depth * 0.6), maxf(rim_y + SOIL_MAX, 0.0))
	return soil_y


## Coupe la racine i et tout ce qui en part ; 2 ou 3 jeunes racines repartent du bout coupé.
## Renvoie le nombre de segments retirés.
func cut(i: int) -> int:
	var dead := {i: true}
	for j in range(i + 1, p0.size()):
		if dead.has(par[j]):
			dead[j] = true
	var at := p0[i]
	var d := dir[i]
	var o := order[i]
	var pc := par[i]
	var map := _remove(dead)
	var p := map[pc] if pc >= 0 else -1
	for k in 2 + rng.randi() % 2:
		var a := rng.randf_range(-1.2, 1.2)
		_add(at, _wall(at, Vector3(d.x * cos(a) - d.z * sin(a), 0.0, d.x * sin(a) + d.z * cos(a))), p, mini(o + 1, 4), 0.003)
	return dead.size()


## Après le choix du pot : les racines qui en dépasseraient sont coupées.
func fit_pot() -> void:
	var dead := {}
	for i in p0.size():
		var q := p1[i]
		if dead.has(par[i]) or absf(q.x) > hx or absf(q.z) > hz or q.y < rim_y - depth:
			dead[i] = true
	if not dead.is_empty():
		_remove(dead)


func _remove(dead: Dictionary) -> PackedInt32Array:
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
	return map


func _rebuild_occ() -> void:
	occ.clear()
	for p in p1:
		var c := _cell(p)
		occ[c] = occ.get(c, 0) + 1


func to_data() -> Dictionary:
	return {"p0": p0, "p1": p1, "dir": dir, "par": par, "rad": rad, "tip": tip, "order": order,
			"seed": rng.seed, "state": rng.state, "tile": tile, "soil_y": soil_y,
			"rock": rock, "rock_c": rock_c, "rock_r": rock_r, "rock_s": rock_s, "rim_y": rim_y}


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
	tile = d.get("tile", false)
	soil_y = d.get("soil_y", 0.0)
	rock = d.get("rock", false)
	rock_c = d.get("rock_c", Vector3.ZERO)
	rock_r = d.get("rock_r", Vector3.ONE)
	rock_s = d.get("rock_s", Vector3.ZERO)
	rim_y = d.get("rim_y", 0.0)
	_rebuild_occ()
