class_name TreeSim
extends RefCounted
## Simulation d'un arbre : modèle auto-organisé de Palubicki et al. (2009), simplifié.
## Les bourgeons se disputent la lumière (grille d'ombre), la vigueur part de la base et se répartit
## avec une dominance apicale (modèle de Borchert-Honda), les branches mal éclairées meurent,
## le bois épaissit d'un cerne par an (loi de Pressler). Unités : mètres ; temps : semaines (52 par an).

class Seg:
	var parent := -1
	var start := Vector3.ZERO
	var end := Vector3.ZERO
	var main_child := -1     # prolongement de l'axe
	var lat_child := -1      # rameau latéral issu du bourgeon axillaire
	var term_bud := false    # bourgeon terminal au bout (si pas de prolongement)
	var lat_bud := false     # bourgeon axillaire dormant (si pas de rameau latéral)
	var lat_dir := Vector3.ZERO
	var lat_bud_age := 0
	var phase := 0.0         # angle de phyllotaxie
	var radius := 0.0
	var born := 0.0          # semaine où l'entre-nœud commence à s'allonger
	var grow_time := 1.0     # semaines pour atteindre sa longueur
	var dead := false        # à retirer du tableau
	var dry := false         # bois mort resté sur l'arbre
	var dry_week := 0
	var r0 := 0.0            # épaisseur en début de période animée (0 : né pendant la période)
	# plaie de taille au bout de cet entre-nœud (sur le côté si la branche coupée était latérale)
	var wound_full := 0.0    # rayon de la coupe
	var wound_r := 0.0       # rayon encore ouvert (0 : refermée)
	var wound_concave := false
	var wound_dir := Vector3.ZERO
	var wound_side := false
	var weak := 0            # étés passés trop à l'ombre
	var lat_q := 1.0         # qualité du bourgeon axillaire (puis vigueur propre du rameau latéral)
	var release := 1.0       # bonus des bourgeons de ce nœud après une coupe (levée de dominance)
	var relay := false       # bourgeon terminal avorté : la pousse repartira du dernier bourgeon latéral
	var size_k := 1.0        # taille des feuilles selon la vigueur de la pousse
	var leaf_k := 1.0        # place dans sa pousse (0 : base, 1 : bout) ; les feuilles grandissent vers le bout
	var needle := 1.0        # pin : longueur relative des aiguilles (0 : base nue de la chandelle, couronne)
	var forced := false      # pin : bourgeon né d'une coupe de chandelle, part même s'il est faible
	var wire := 0            # fil posé (identifiant dans TreeSim.wires), 0 : aucun
	var mark := 0.0          # marque laissée par un fil qui a mordu (0 à 1), s'efface avec les cernes
	var crack := false       # fêlée en pliant : une chance sur deux de dépérir à la fin de l'été
	var defol := -1.0        # semaine de l'effeuillage (étape 28), -1 : jamais
	var kick := false        # bourgeon réveillé par un pincement ou un effeuillage : part à la poussée provoquée
	# recalculés à chaque poussée
	var light := 0.0
	var count := 0
	var vigor := 0.0
	var q_term := 0.0
	var q_lat := 0.0
	var v_term := 0.0
	var v_lat := 0.0

# --- Paramètres de l'espèce (valeurs de l'orme ; remplacés par la fiche de scripts/species.gd) ---
var name := "Orme de Chine"
var bark_colors := [Color(0.55, 0.52, 0.47), Color(0.63, 0.6, 0.55), Color(0.62, 0.45, 0.32), Color(0.33, 0.28, 0.24)]
var foliage_size := 0.02     # longueur d'une feuille avec son pétiole (m)
var leaf_shape := 0           # 0 : feuille simple (orme), 1 : palmée (érable), 2 : éventail (ginkgo)
var young_color := Color(0.55, 0.47, 0.38)  # rameau de l'année
var autumn_color := Color(0.82, 0.6, 0.2)
var bud_color := Color(0.42, 0.28, 0.18)
var bud_size := 0.0025        # longueur d'un bourgeon latéral (m)
var internode := 0.018
var alpha := 1.6              # vigueur totale = alpha × lumière captée
var apical := 0.53            # part de vigueur donnée à l'axe principal (λ)
var max_per_flush := 4        # entre-nœuds max par bourgeon et par poussée
var preformed := 0            # feuilles déjà formées dans le bourgeon (0 : environ une par unité de vigueur)
var spur_len := 0.8           # longueur relative des entre-nœuds d'un rameau court
var leaf_area := 1.0          # surface de feuille par nœud (ombre portée, cerne, seuil de dépérissement)
var light_exp := false        # lumière à travers le feuillage (feuillus tolérants à l'ombre)
var sympodial := false        # le bourgeon terminal avorte en hiver : croissance en zigzag
var opposite := false         # bourgeons par paires opposées (érable) ; phyllotaxy = rotation d'une paire à l'autre
var fork := false             # le bout du rameau avorte en hiver : repart des deux bourgeons de la dernière paire
var branch_angle := deg_to_rad(45.0)
var phyllotaxy := deg_to_rad(180.0)  # alterne distique
var w_dir := 1.0
var w_light := 0.35
var w_up := 0.12
var jitter := 0.12
var tip_radius := 0.0004        # jeune rameau : 0,8 mm de diamètre
const RING_AREA := 0.9e-6      # cerne annuel : surface ajoutée (m²) par unité de lumière captée au-dessus (étape 23b : 1,5e-6 avant)
var shed_ratio := 0.04        # lumière par entre-nœud sous laquelle une branche dépérit
var bud_life := 52 * 8        # durée de vie d'un bourgeon dormant (semaines)
var backbud_nodes := 4        # nœuds sous la coupe qui peuvent rebourgeonner
var backbud_chance := 0.6
var capacity := 6000          # garde-fou de calcul : nombre d'entre-nœuds vivants au-delà duquel la pousse s'arrête
var release_nodes := 3        # nœuds sous la coupe qui profitent de la levée de dominance
var release_boost := 3.0
var sprout_excess := 1.4      # réserves / lumière au-delà duquel des rejets apparaissent
var max_sprouts := 4
var whorl := 0                # >0 : bourgeons seulement en couronne au bout de la pousse (pin)
var leaf_years := 0           # 0 : caduc ; sinon durée de vie des aiguilles (le réveil n'a lieu que là où il y en a)
## Semaine de l'année -> force de la poussée (printemps puis petite poussée d'été).
var flushes := {15: 1.0, 18: 1.0, 21: 0.8, 27: 0.5}
var flush_now := 1.0          # force de la poussée en cours (< 1 : poussée d'été)
var extra_flush := -1         # semaine de la poussée provoquée (mekiri, pincement, effeuillage)
var extra_defol := false      # la poussée provoquée suit un effeuillage : « mini-printemps », feuilles plus petites
var extra_local := false      # poussée provoquée par un pincement ou un effeuillage : seuls les bourgeons libérés partent
var debt := 0.0               # coût des gestes faits quand les réserves sont vides (été) : retenu sur le remplissage de fin d'été
const DEFOL_REGROW := 4       # semaines sans feuilles après un effeuillage
const GROW_WEEKS := 3.0       # durée d'allongement d'une pousse (écart entre deux poussées)
const DIEBACK_WEEK := 35      # fin d'été : bilan de lumière des branches

# --- Grille d'ombre (Palubicki 2009, propagation en pyramide vers le bas) ---
# Bonsaï seul sur sa table : seul l'arbre se fait de l'ombre, les côtés sont ouverts.
const CELL := 0.025
const GX := 40
const GY := 48
const GZ := 40
const SH_A := 0.15
const SH_B := 2.2
const SH_Q := 4
var shadow := PackedFloat32Array()

var segs: Array[Seg] = []
var week := 0
# Physiologie (étape 17). Unités : la lumière captée par la couronne (segs[0].light).
var reserve := 1.0            # réserves (amidon) : remplies en été par les feuilles, dépensées à chaque poussée
var roots := 1.0              # ce que les racines peuvent alimenter ; suivent la couronne, plafonnées par le pot
var pot_volume := 8.0         # litres
var low_years := 0            # années de suite à bout de réserves
var last_vigor := 0.0         # vigueur moyenne des pousses de la dernière poussée
# Ligature (étape 19) : id -> {need, done, over, at (angle plié par position), raffia, bends: [[axe, angle, position]...]}
var wires := {}
var next_wire := 1
const WIRE_SEGS := 6            # entre-nœuds couverts par un fil
const WIRE_GRACE := 6           # semaines de pousse après la prise avant que le fil morde
var _vsum := 0.0
var _vn := 0
const ROOTS_PER_LITRE := 40.0  # lumière qu'un litre de pot peut alimenter (8 L : arbre d'environ 75 cm à 8 ans)
const SPEND := 0.4             # part de l'apport puisée dans les réserves à chaque poussée (par unité de force)
var layout := 0               # change quand des segments sont retirés (les indices changent)
var fallen: Array = []        # rameaux morts tombés pendant la période : [début, fin, rayon, séchage, chute]
var rng := RandomNumberGenerator.new()
var planted := 10             # semaine de mise en pot
var heal := 1.0               # vitesse de fermeture des plaies (ginkgo : presque nulle)
var fall_span := 4.0          # semaines de chute des feuilles
var spur_years := 5.0         # âge max des rameaux courts à rosette
var leaf_colors := [Color(0.24, 0.38, 0.16), Color(0.2, 0.33, 0.15)]  # deux verts du feuillage (étape 27)
var root := RootSim.new()     # charpente racinaire (étape 23a), sauvegardée à part
const ROOT_WEEKS := [14, 22, 36]  # poussées de racines : printemps, début et fin d'été


## start_week : date du jardin (10 = début mars de l'année 1).
func reset(seed_value: int = 1, species: Dictionary = Species.ELM, start_week := 10) -> void:
	for k in species:
		set(k, species[k])
	rng.seed = seed_value
	segs.clear()
	reserve = 1.0
	roots = 1.0
	pot_volume = 8.0
	low_years = 0
	week = start_week
	planted = start_week
	var s := Seg.new()
	s.born = start_week
	s.end = Vector3(0, internode * 2.0, 0)
	s.term_bud = true
	s.radius = tip_radius
	_set_lateral(s, Vector3.UP)
	segs.append(s)
	root = RootSim.new()
	root.setup(species, pot_volume)
	root.plant(seed_value)


## Sauvegarde : toutes les variables de l'arbre (fiche espèce comprise) et des segments, colonne par colonne,
## plus l'état du hasard pour que la suite de la pousse soit la même.
func to_data() -> Dictionary:
	var d := {}
	for p in get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and p.name != "segs" and p.name != "rng" and p.name != "fallen" and p.name != "root":
			d[p.name] = get(p.name)
	d["rng_seed"] = rng.seed
	d["rng_state"] = rng.state
	var cols := {}
	if not segs.is_empty():
		for p in segs[0].get_property_list():
			if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				var col := []
				for sg in segs:
					col.append(sg.get(p.name))
				cols[p.name] = col
	d["segs"] = cols
	d["count"] = segs.size()
	d["root"] = root.to_data()
	return d


func from_data(d: Dictionary) -> void:
	for k in d:
		if k != "segs" and k != "count" and k != "rng_seed" and k != "rng_state" and k != "root":
			set(k, d[k])
	capacity = maxi(capacity, 15000)  # limite relevée (audit, phase 5)
	# L'apparence suit toujours la fiche espèce actuelle (un réglage graphique s'applique aussi aux anciens arbres).
	var species: Dictionary = Species.ELM
	for sp in Species.ALL:
		if sp["name"] == name:
			species = sp
			for k in ["bud_size", "bud_color", "bark_colors", "young_color", "autumn_color", "foliage_size", "heal", "fall_span", "spur_years", "leaf_colors"]:
				if sp.has(k):
					set(k, sp[k])
	if not d.has("roots"):  # arbre sauvegardé avant l'étape 17
		roots = maxf(reserve, 1.0)
		reserve = roots
	rng.seed = d["rng_seed"]
	rng.state = d["rng_state"]
	segs.clear()
	fallen.clear()
	var cols: Dictionary = d["segs"]
	for i in int(d["count"]):
		var sg := Seg.new()
		for k in cols:
			sg.set(k, cols[k][i])
		segs.append(sg)
	root = RootSim.new()
	root.setup(species, pot_volume)
	if d.has("root"):
		root.from_data(d["root"])
	else:
		_grow_roots_for_old_tree(d["rng_seed"])


## Arbre sauvegardé avant l'étape 23a : charpente qui remplit ce que demandent ses racines, épaisseurs
## données d'un coup (la somme au collet suit la section du tronc).
func _grow_roots_for_old_tree(seed_value: int) -> void:
	root.plant(seed_value)
	for k in 40:
		var n := root.size()
		root.pulse(roots)
		if root.size() == n:
			break
	_compute_shadow()
	_basipetal()
	var sl := _sector_light()
	var tot := 0.0
	for x in sl:
		tot += x
	if tot > 0.0:
		var r := segs[0].radius
		root.thicken(sl, PI * r * r / tot, r)


## Lumière captée par le houppier, en 8 secteurs autour du tronc (côté de chaque bourgeon).
func _sector_light() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(RootSim.SECTORS)
	for s in segs:
		var q := s.q_term + s.q_lat
		if q > 0.0:
			out[root.sector(s.end)] += q
	return out


## Début d'une période animée : on note les épaisseurs et on vide la liste des rameaux tombés.
func begin_period() -> void:
	for s in segs:
		s.r0 = s.radius
	fallen.clear()


func step_week() -> void:
	week += 1
	var w := week % 52
	if flushes.has(w):
		_flush(flushes[w])
	if week == extra_flush:
		_flush(0.6)
		extra_defol = false
		extra_local = false
		for s in segs:
			s.kick = false  # le réveil ne vaut que pour cette poussée
	if w == DIEBACK_WEEK:
		_dieback()
	if w == 0:
		_end_of_year()
	if ROOT_WEEKS.has(w):
		root.pulse(roots)
	_wires_week(w)


## Pose un fil sur l'entre-nœud i et les suivants de son axe (WIRE_SEGS au plus). Raphia sur les
## branches de plus de 5 mm. Renvoie un message.
func add_wire(i: int) -> String:
	if segs[i].wire > 0:
		return "Déjà ligaturée."
	if segs[i].dry:
		return "On ne ligature pas le bois mort."
	var id := next_wire
	next_wire += 1
	var r := segs[i].radius
	var pliant := whorl > 0  # pin : bois souple, mais prend la forme lentement
	wires[id] = {"need": (40.0 if pliant else 12.0) * clampf(sqrt(r / 0.0015), 0.7, 3.0), "done": 0.0,
			"over": 0, "at": {}, "raffia": r > 0.0025, "bends": []}
	var k := i
	for n in WIRE_SEGS:
		if k < 0 or segs[k].dry or segs[k].wire > 0:
			break
		segs[k].wire = id
		k = segs[k].main_child
	return "Ligaturée avec raphia (branche épaisse)." if wires[id]["raffia"] else "Ligaturée."


## Entre-nœuds d'un fil, de la base vers la pointe (un parent est toujours avant ses enfants).
func wire_segs(id: int) -> Array[int]:
	var out: Array[int] = []
	for i in segs.size():
		if segs[i].wire == id:
			out.append(i)
	return out


## Retire le fil ; si la branche n'a pas encore pris sa forme, elle revient en partie en arrière.
func remove_wire(id: int) -> String:
	if not wires.has(id):
		return ""
	var w: Dictionary = wires[id]
	var back: float = 1.0 - clampf(w["done"] / w["need"], 0.0, 1.0)
	var ch := wire_segs(id)
	if back > 0.0 and not ch.is_empty():
		var bends: Array = w["bends"]
		for b in range(bends.size() - 1, -1, -1):
			var bd: Array = bends[b]
			var part: Array = ch if bd.size() < 3 else ch.slice(bd[2], mini(bd[2] + 2, ch.size()))
			_bend_chain(part, bd[0], -bd[1] * back)
	for i in ch:
		segs[i].wire = 0
	wires.erase(id)
	if back > 0.6:
		return "Fil retiré trop tôt : la branche revient presque entièrement."
	if back > 0.0:
		return "Fil retiré un peu tôt : la branche revient de %d %%." % roundi(back * 100.0)
	return "Fil retiré : la branche garde sa forme."


## Plie la branche ligaturée à la base de l'entre-nœud i : angle (radians) autour de l'axe donné, réparti sur
## cet entre-nœud et le suivant. Au-delà de la limite à cet endroit, la branche se fêle ; bien au-delà, elle casse.
func bend(id: int, i: int, axis: Vector3, angle: float) -> String:
	var ch := wire_segs(id)
	var k := ch.find(i)
	if k < 0 or absf(angle) < 0.001:
		return ""
	var used: Array = ch.slice(k, mini(k + 2, ch.size()))
	var w: Dictionary = wires[id]
	if not w.has("at"):
		w["at"] = {}
	# rameau de 1,5 mm : 60° par entre-nœud ; plus épais, beaucoup moins ; pin plus souple ; raphia +50 %
	var lim := deg_to_rad(60.0) * clampf(0.0015 / segs[i].radius, 0.1, 2.0) * used.size()
	lim *= (1.3 if whorl > 0 else 1.0) * (1.5 if w["raffia"] else 1.0)
	var total: float = w["at"].get(k, 0.0) + absf(angle)
	if total > lim * 1.25 and i > 0:
		for j in ch:
			segs[j].wire = 0
		wires.erase(id)
		prune(i, true)
		return "Crac ! La branche a cassé."
	_bend_chain(used, axis, angle)
	w["at"][k] = total
	w["bends"].append([axis, angle, k])
	if total > lim:
		for j in used:
			segs[j].crack = true
		return "La branche s'est fêlée : elle risque de dépérir."
	if total > lim * 0.8:
		return "La branche approche de sa limite à cet endroit."
	return ""


## Fait tourner chaque entre-nœud de la chaîne (et tout ce qu'il porte) d'une part égale de l'angle,
## autour de sa base : la courbure se répartit le long du fil.
func _bend_chain(ch: Array, axis: Vector3, angle: float) -> void:
	var a := angle / ch.size()
	var ax := axis.normalized()
	for i in ch:
		var pivot := segs[i].start
		for k in subtree(i):
			var s := segs[k]
			s.start = pivot + (s.start - pivot).rotated(ax, a)
			s.end = pivot + (s.end - pivot).rotated(ax, a)
			s.lat_dir = s.lat_dir.rotated(ax, a)
			s.wound_dir = s.wound_dir.rotated(ax, a)
	layout += 1


## Chaque semaine de pousse, le fil fait prendre la forme ; une fois prise, au-delà de WIRE_GRACE semaines,
## il mord l'écorce de plus en plus.
func _wires_week(w: int) -> void:
	if wires.is_empty() or w < 14 or w > 40:
		return
	var biting := []
	for id in wires:
		var d: Dictionary = wires[id]
		d["done"] += 1.0
		if d["done"] >= d["need"]:
			d["over"] += 1
			if d["over"] > WIRE_GRACE:
				biting.append(id)
	if not biting.is_empty():
		for s in segs:
			if s.wire in biting:
				s.mark = minf(1.0, s.mark + 0.08)


## État du fil pour l'affichage : prise en %, et s'il mord.
func wire_state(id: int) -> String:
	if not wires.has(id):
		return ""
	var d: Dictionary = wires[id]
	var txt := "fil : forme prise à %d %%" % roundi(clampf(d["done"] / d["need"], 0.0, 1.0) * 100.0)
	if d["over"] > WIRE_GRACE:
		txt += " · le fil mord !"
	return txt

## Réserves rapportées aux racines : 1 = pleine santé, < 0,25 = épuisé.
func health() -> float:
	return reserve / maxf(roots, 0.001)


## Coût d'un geste en réserves ; ce qui manque devient une dette, retenue à la fin de l'été (en été les
## réserves sont vides : sans cela, tailler ou effeuiller en pleine saison ne coûtait rien).
func _spend(cost: float) -> void:
	if cost < 0.0:  # remboursement (pincement) : d'abord la dette
		var back := minf(debt, -cost)
		debt -= back
		reserve += -cost - back
		return
	var take := minf(reserve, cost)
	reserve -= take
	debt += cost - take


## Forme du moment (étape 28) : réserves plus ce que capte le feuillage, rapportés aux racines. En été les
## réserves sont basses (les poussées les ont dépensées) même sur un arbre vigoureux : c'est la forme qui
## dit si un mekiri ou un effeuillage est supportable.
func vigor_now() -> float:
	return (reserve + segs[0].light) / maxf(roots, 0.001)


## Rempotage : nouveau pot (litres) et part des racines coupées. Hors fin d'hiver, l'arbre souffre.
## Renvoie un message pour le joueur.
func repot(volume: float, cut: float) -> String:
	pot_volume = volume
	var n := root.size()
	root.set_pot(volume)
	root.fit_pot()  # les racines qui dépassent du nouveau pot sont coupées : elles comptent dans la part coupée
	var outside := n - root.size()
	cut = 1.0 - (1.0 - cut) * root.size() / maxf(n, 1.0)
	roots = minf(roots * (1.0 - cut), volume * ROOTS_PER_LITRE)
	reserve *= 1.0 - cut * 0.5  # une part des réserves est dans les racines
	var w := week % 52
	var txt := "Les racines qui dépassaient du pot ont été coupées. " if outside > 0 else ""
	if w >= 6 and w <= 14:
		return txt + "Rempoté au bon moment."
	if cut > 0.0 and w >= 15 and w <= 40:
		reserve *= 0.5
		return txt + "Racines coupées en pleine pousse : l'arbre souffre."
	return txt + "Rempoté hors saison : les racines repartiront au printemps."


## Pincement aux doigts (étape 28) : seulement une pousse tendre (moins de 5 semaines). Presque rien n'y était
## investi ; les 1 ou 2 bourgeons qui restent partent 2 à 3 semaines plus tard : une fourche aux entre-nœuds courts
## (Walston, Evergreen Gardenworks ; Bonsai4me).
func pinch(i: int) -> String:
	if i <= 0 or i >= segs.size():
		return ""
	var s := segs[i]
	if week - s.born > 5.0 or s.dry:
		return "Pousse trop dure pour les doigts : prends les ciseaux."
	var lost := s.light
	var j := s.parent
	prune(i)
	_spend(-0.4 * lost)  # la coupe ordinaire coûte 0,5 ; la pousse tendre seulement 0,1
	# Les 2 nœuds restants partent tout de suite, sans garder de bonus de vigueur pour les poussées suivantes :
	# sinon ils captaient la vigueur de l'été et refaisaient de longues pousses (le pincement ne raccourcissait rien).
	for k in 2:
		if j < 0:
			break
		segs[j].release = 1.0
		segs[j].kick = true
		j = segs[j].parent
	var wk := week % 52
	if wk >= 12 and wk <= 30 and (extra_flush <= week):
		extra_flush = week + 2 + rng.randi() % 2
		extra_local = true
	return "Pincée : les bourgeons restants partiront dans 2 à 3 semaines."


## Effeuillage (étape 28), au repos du milieu de l'été. Sans only : tout l'arbre ; avec only (une branche) :
## partiel, la feuille du bout de chaque pousse reste (elle tire la sève). Pendant DEFOL_REGROW semaines, les
## parties effeuillées ne captent presque plus de lumière : la vigueur part vers celles qui ont gardé leurs
## feuilles (rééquilibrage). Puis « mini-printemps » : les bourgeons partent là où étaient les feuilles, avec des
## feuilles plus petites et des entre-nœuds courts. Coût : les réserves (Bonsai4me, Bonsai Tonight, Bonsai Bark).
func defoliate(only := PackedInt32Array()) -> String:
	if leaf_years > 0 or leaf_shape == 2:
		return "Cette espèce ne s'effeuille pas : elle ne referait pas ses feuilles."
	var wk := week % 52
	if wk < 21 or wk > 27:
		return "L'effeuillage se fait au repos du milieu de l'été, de fin mai à début juillet."
	if vigor_now() < 0.8:
		return "Arbre trop faible pour l'effeuillage : laisse-le reprendre des forces."
	var lst := only
	if lst.is_empty():
		lst.resize(segs.size())
		for i in segs.size():
			lst[i] = i
	var lost := 0.0
	var n := 0
	for i in lst:
		var s := segs[i]
		if s.dry or (not only.is_empty() and s.main_child < 0):
			continue
		s.defol = week
		s.kick = true  # les bourgeons à l'aisselle des feuilles retirées partiront au mini-printemps
		lost += s.q_term + s.q_lat
		n += 1
		if s.weak > 0 and rng.randf() < 0.5:  # une branche déjà faible ne le supporte pas
			for k in subtree(i):
				segs[k].dry = true
				segs[k].term_bud = false
				segs[k].lat_bud = false
				segs[k].dry_week = week
	if n == 0:
		return "Rien à effeuiller ici."
	_spend(0.7 * lost)  # semaines sans photosynthèse et nouvelles feuilles à fabriquer
	extra_flush = week + DEFOL_REGROW - 1 + rng.randi() % 2
	extra_defol = true
	extra_local = true
	_basipetal()
	return ("Effeuillé" if only.is_empty() else "Branche effeuillée (feuilles du bout gardées)") + \
			" : nouvelles feuilles, plus petites, dans 3 à 4 semaines."


## Pin (étape 24) : chandelles de l'année (pousses du printemps parties d'un bois plus vieux).
func candles() -> PackedInt32Array:
	var y0 := floorf(week / 52.0) * 52.0
	var out := PackedInt32Array()
	for i in range(1, segs.size()):
		var s := segs[i]
		if s.born >= y0 and segs[s.parent].born < y0 and not s.dry:
			out.append(i)
	return out


const MEKIRI_MIN := 4  # chandelle d'au moins 4 entre-nœuds : forte ; les plus faibles sont épargnées


## Mekiri de tout l'arbre : coupe les chandelles fortes, épargne les faibles (comme les bonsaïstes).
## Refusé hors saison ou sur un arbre affaibli (vérifié au portage : sur toutes les chandelles, il tue l'arbre).
func mekiri() -> String:
	var wk := week % 52
	if wk < 20 or wk > 28:
		return "Le mekiri se fait quand les chandelles ont fini de pousser : fin mai à début juillet."
	if vigor_now() < 0.8:
		return "Arbre trop faible pour le mekiri : laisse-le reprendre des forces cette année."
	var cs := candles()
	var n := 0
	for k in range(cs.size() - 1, -1, -1):  # de la fin : une coupe ne décale que les indices au-delà
		if subtree(cs[k]).size() >= MEKIRI_MIN:
			prune(cs[k])
			n += 1
	return "Mekiri : %d chandelles coupées, %d faibles épargnées. Pousses d'été dans 2 à 4 semaines." % [n, cs.size() - n]


## Pin, automne : chaque couronne ramenée à 2 bourgeons, les plus horizontaux ; le bourgeon central,
## le plus fort, est retiré : la pousse se partage en deux l'an prochain.
func select_buds() -> String:
	var wk := week % 52
	if wk < 37 or wk > 50:
		return "Le tri des bourgeons se fait en automne, quand ils sont formés."
	var removed := 0
	for t in segs.size():
		if not segs[t].term_bud or segs[t].dry:
			continue
		var crown: Array[int] = []
		var k := t
		while k >= 0 and segs[k].lat_bud and (segs[k].end - segs[k].start).length() < internode * 0.1:
			crown.append(k)
			k = segs[k].parent
		if crown.size() < 2:
			continue
		crown.sort_custom(func(a, b): return absf(segs[a].lat_dir.y) < absf(segs[b].lat_dir.y))
		for m in range(2, crown.size()):
			segs[crown[m]].lat_bud = false
			removed += 1
		segs[t].term_bud = false
		removed += 1
	return "Bourgeons triés : %d retirés, 2 gardés par couronne." % removed if removed > 0 else "Aucune couronne de plus de 2 bourgeons."


## Pin : ce que donnera une coupe du segment i. [0 vert, 1 orange, 2 rouge ; conseil]
func pine_hint(i: int) -> Array:
	var s := segs[i]
	var p := segs[s.parent]
	var y0 := floorf(week / 52.0) * 52.0
	var wk := week % 52
	if s.born >= y0 and p.born < y0:
		if wk < 20:
			return [1, "Chandelle encore en pousse : mekiri de fin mai à début juillet."]
		if wk <= 28:
			return [0, "Mekiri : 2 à 4 pousses d'été ici, si l'arbre est vigoureux."]
		return [1, "Mekiri tardif : les bourgeons ne partiront qu'au printemps."]
	if week - p.born < leaf_years * 52 and p.needle > 0.0:
		if wk >= 18 and wk <= 30:
			return [1, "Dans les aiguilles : bourgeons possibles, branche affaiblie."]
		return [1, "Dans les aiguilles hors saison : peu de chances de bourgeons."]
	return [2, "Bois sans aiguilles : rien ne repartira de cette coupe."]


## Coupe le segment i et tout ce qu'il porte. Renvoie false pour la base (on ne coupe pas tout l'arbre).
const WOUND_MIN := 0.0015      # rayon au-delà duquel une coupe laisse une plaie (3 mm de diamètre)


## concave : coupe à la pince concave (la plaie se referme deux fois plus vite).
func prune(i: int, concave := false) -> bool:
	if i <= 0 or i >= segs.size():
		return false
	var j := segs[i].parent
	var cut := segs[i]
	_spend(0.5 * cut.light)  # l'énergie investie dans le feuillage coupé est perdue
	var y0 := floorf(week / 52.0) * 52.0
	# Pin : chandelle de l'année coupée à sa base = mekiri. Couronne de 0 à 4 entre-nœuds (n + 1 bourgeons)
	# selon la vigueur de la chandelle retirée ; elle part 2 à 4 semaines plus tard si on coupe de fin mai
	# à début juillet, sinon au printemps suivant.
	var buds := -1
	if whorl > 0 and cut.born >= y0 and segs[j].born < y0:
		buds = clampi(int(subtree(i).size() * 0.5 + rng.randf() * 2.0) - 1, 0, 4)
	if cut.radius > WOUND_MIN and not cut.dry:
		var w := segs[j]
		w.wound_full = maxf(w.wound_full, cut.radius)
		w.wound_r = w.wound_full
		w.wound_concave = concave
		w.wound_dir = (cut.end - cut.start).normalized()
		w.wound_side = w.main_child != i
	var side := segs[j].main_child != i
	_kill(i)
	if buds > 0:
		var d := (cut.end - cut.start).normalized()
		var first := _crown(j, segs[j].end, d, segs[j].phase, buds, week)
		if side:
			segs[j].lat_child = first
		else:
			segs[j].main_child = first
		for k in range(first, segs.size()):
			segs[k].forced = true
		var wk := week % 52
		if wk >= 20 and wk <= 28:
			extra_flush = week + 2 + rng.randi() % 3
	# La coupe lève la dominance apicale : les bourgeons juste en dessous (dormants ou adventifs)
	# se réveillent et prennent de la vigueur l'année suivante.
	for k in backbud_nodes:
		if j < 0:
			break
		var p := segs[j]
		var leafy := leaf_years == 0 or week - p.born < leaf_years * 52
		var chance := backbud_chance
		if whorl > 0:
			# Pin : bourgeons d'aiguilles, réveillés surtout en pleine saison ; sur le vieux bois, rarement,
			# et seulement sur un jeune arbre.
			var wk := week % 52
			if leafy and p.needle > 0.0:
				chance = backbud_chance if wk >= 18 and wk <= 30 else backbud_chance * 0.2
			else:
				chance = 0.03 if week < 52 * 10 else 0.0
			leafy = true
		if leafy and not p.dry and not p.lat_bud and p.lat_child < 0 and rng.randf() < chance:
			p.phase = rng.randf() * TAU
			_set_lateral(p, (p.end - p.start).normalized())
		if k < release_nodes:
			p.release = release_boost
		j = p.parent
	_compact()
	_basipetal()
	return true


func subtree(i: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var stack := [i]
	while not stack.is_empty():
		var k: int = stack.pop_back()
		out.append(k)
		if segs[k].main_child >= 0:
			stack.append(segs[k].main_child)
		if segs[k].lat_child >= 0:
			stack.append(segs[k].lat_child)
	return out


func height() -> float:
	var h := 0.0
	for s in segs:
		h = maxf(h, s.end.y)
	return h


# --- Cycle de croissance ---

func _flush(strength: float) -> void:
	flush_now = strength
	_vsum = 0.0
	_vn = 0
	_compute_shadow()
	_basipetal()
	if _sprouts():
		_basipetal()
	_allocate(strength)
	_grow()
	_basipetal()
	if _vn > 0:
		last_vigor = _vsum / _vn


func _end_of_year() -> void:
	for s in segs:
		s.release = 1.0
		s.forced = false
		if s.wire == 0 and s.mark > 0.0:
			s.mark = maxf(0.0, s.mark - 0.3)  # les cernes recouvrent peu à peu la marque du fil
		if fork and s.term_bud and s.lat_bud and not s.dry:
			s.term_bud = false
		if sympodial and s.term_bud and s.lat_bud and not s.dry:
			s.lat_bud = false
			s.relay = true
		if s.lat_bud:
			s.lat_bud_age += 52
			if s.lat_bud_age > bud_life:
				s.lat_bud = false
	# Épuisement : deux hivers de suite sans réserves et presque sans feuillage, l'arbre meurt.
	low_years = low_years + 1 if health() < 0.1 and segs[0].light < 0.3 * roots else 0
	if low_years >= 2:
		for q in segs:
			if not q.dry:
				q.dry = true
				q.dry_week = week
			q.term_bud = false
			q.lat_bud = false
	# Cerne annuel : chaque entre-nœud vivant ajoute une couche de bois proportionnelle au feuillage
	# qu'il porte (loi de Pressler). Le bas du tronc, qui porte tout, épaissit le plus : conicité continue,
	# et le tronc continue de grossir même après une taille. Quand le pot est plein, les racines ne nourrissent
	# qu'une part de la couronne : le bois produit diminue d'autant (petit pot = tronc qui grossit peu).
	# Étape 23b : le cerne dépend aussi du pot (racines tassées quand il est plein : jusqu'à -60 %) et de la
	# santé (un arbre sans réserves fait un cerne mince). Les racines grossissent au même rythme que le tronc.
	var full := clampf((roots / (pot_volume * ROOTS_PER_LITRE) - 0.7) / 0.3, 0.0, 1.0)
	var rf := minf(1.0, roots / maxf(segs[0].light, 0.01)) * (1.0 - 0.6 * full) * clampf(health(), 0.2, 1.0)
	root.thicken(_sector_light(), RING_AREA * leaf_area * rf, segs[0].radius)
	for s in segs:
		if not s.dry:
			var old := s.radius
			s.radius = sqrt(s.radius * s.radius + RING_AREA * leaf_area * s.light * rf / PI)
			if s.wound_r > 0.0:
				# le bourrelet de cicatrisation avance avec le cerne, deux fois plus vite après la pince concave
				s.wound_r = maxf(0.0, s.wound_r - (s.radius - old) * (6.0 if s.wound_concave else 3.0) * heal)
				if s.wound_r == 0.0:
					s.wound_full = 0.0
	# Les rameaux morts fins tombent d'eux-mêmes au bout d'un an ; le gros bois mort reste.
	var fell := false
	for i in range(1, segs.size()):
		var s := segs[i]
		if s.dry and not s.dead and not segs[s.parent].dry and s.radius < 0.004 and week - s.dry_week >= 40:
			for k in subtree(i):
				var q := segs[k]
				fallen.append([q.start, q.end, q.radius, float(q.dry_week), float(week)])
			_kill(i)
			fell = true
	if fell:
		_compact()


## Rejets : quand les racines fournissent bien plus que la couronne ne peut employer (après une
## taille sévère), des bourgeons adventifs percent sur le vieux bois, surtout en bas du tronc.
func _sprouts() -> bool:
	var excess := roots / maxf(segs[0].light, 0.01)  # racines trop grosses pour la couronne
	if max_sprouts == 0 or excess < sprout_excess or segs.size() < 10:
		return false
	var n := mini(int((excess - sprout_excess) * 4.0) + 1, max_sprouts)
	for k in n:
		var best := -1
		for tries in 10:  # parmi quelques nœuds de vieux bois, le plus gros (bas du tronc)
			var c := rng.randi_range(0, segs.size() - 1)
			var s := segs[c]
			if s.dry or s.lat_bud or s.lat_child >= 0 or s.born > week - 52:
				continue
			if best < 0 or s.radius > segs[best].radius:
				best = c
		if best >= 0:
			var p := segs[best]
			p.phase = rng.randf() * TAU
			_set_lateral(p, (p.end - p.start).normalized())
			p.lat_dir = (p.lat_dir + Vector3.UP * 1.5).normalized()  # gourmand : pousse vers le haut
			p.lat_q = 1.5
			p.release = release_boost
	return true


## Une branche trop à l'ombre pour sa taille s'affaiblit ; au deuxième été de suite, elle sèche
## et reste sur l'arbre en bois mort (au joueur de la couper). Éclaircir au-dessus la sauve.
func _dieback() -> void:
	_compute_shadow()
	_basipetal()
	# Fin d'été : les feuilles ont rempli les réserves ; les racines suivent la couronne (rapport racines /
	# couronne constant), sans dépasser le pot, et meurent à moitié de l'excès quand la couronne a été réduite.
	var l := segs[0].light
	reserve = clampf(reserve + l - debt, 0.0, 1.5 * roots)
	debt = 0.0
	var t := minf(l, pot_volume * ROOTS_PER_LITRE)
	roots = minf(t, roots * 2.0 + 5.0) if t > roots else roots + (t - roots) * 0.5
	for i in range(1, segs.size()):
		var s := segs[i]
		if s.dry:
			continue
		if s.crack:  # branche fêlée en pliant : guérit ou meurt
			s.crack = false
			if rng.randf() < 0.5:
				for k in subtree(i):
					segs[k].dry = true
					segs[k].term_bud = false
					segs[k].lat_bud = false
					segs[k].dry_week = week
				continue
		if s.light < shed_ratio * leaf_area * s.count:
			s.weak += 1
			if s.weak >= 2:
				for k in subtree(i):
					segs[k].dry = true
					segs[k].term_bud = false
					segs[k].lat_bud = false
					segs[k].dry_week = week
		else:
			s.weak = 0
	_basipetal()


## Avancement de l'allongement d'un segment à l'instant t (en semaines) : 0 = pas commencé, 1 = fini.
func growth(s: Seg, t: float) -> float:
	return clampf((t - s.born) / s.grow_time, 0.0, 1.0)


func _lat_pos(s: Seg) -> Vector3:
	return s.end + s.lat_dir * internode * 0.5


## Des feuilles vers la base : lumière captée, nombre d'entre-nœuds, diamètre.
func _basipetal() -> void:
	var has_shadow := shadow.size() == GX * GY * GZ
	for i in range(segs.size() - 1, -1, -1):
		var s := segs[i]
		var lf := _leafless(s)
		s.q_term = _light(s.end) * lf if s.term_bud and has_shadow else 0.0
		s.q_lat = _light(_lat_pos(s)) * lf if s.lat_bud and has_shadow else 0.0
		s.light = s.q_term + s.q_lat
		s.count = 0 if s.dry else 1
		if s.main_child >= 0:  # sans tableau créé à chaque entre-nœud (audit, phase 4)
			s.light += segs[s.main_child].light
			s.count += segs[s.main_child].count
		if s.lat_child >= 0:
			s.light += segs[s.lat_child].light
			s.count += segs[s.lat_child].count


## De la base vers les feuilles : répartition de la vigueur (Borchert-Honda).
## Apport d'une poussée : feuillage actuel plus réserves, plafonné par les racines ; les réserves en paient une part.
func _allocate(strength: float) -> void:
	var l := segs[0].light
	roots = maxf(roots, minf(minf(l, pot_volume * ROOTS_PER_LITRE), roots * 2.0 + 5.0))
	var supply := minf(reserve + l, roots)
	reserve = maxf(0.0, reserve - SPEND * supply * strength)
	# Garde-fou de calcul : sans effet jusqu'à 85 % de la limite, puis freine jusqu'à l'arrêt. (Le vrai frein
	# biologique, c'est le pot, via les racines.)
	var pot := clampf((capacity - segs[0].count) / (0.15 * capacity), 0.0, 1.0)
	segs[0].vigor = alpha * supply * strength * pot
	for s in segs:
		var qm := segs[s.main_child].light if s.main_child >= 0 else s.q_term
		var ql := segs[s.lat_child].light if s.lat_child >= 0 else s.q_lat
		var wm := apical * qm * (s.release if s.main_child < 0 else 1.0)
		var wl := (1.0 - apical) * ql * s.lat_q * (s.release if s.lat_child < 0 else 1.0)
		var tot := wm + wl
		var vm := s.vigor * wm / tot if tot > 0.0 else 0.0
		var vl := s.vigor * wl / tot if tot > 0.0 else 0.0
		if s.main_child >= 0:
			segs[s.main_child].vigor = vm
		else:
			s.v_term = vm
		if s.lat_child >= 0:
			segs[s.lat_child].vigor = vl
		else:
			s.v_lat = vl


func _grow() -> void:
	var n0 := segs.size()
	for i in n0:
		var s := segs[i]
		# Démarre avec une probabilité égale à sa vigueur (sous 1 : rameau court).
		# Pin, poussée d'été : seuls les bourgeons très vigoureux (ou nés d'une coupe de chandelle) partent.
		var summer := whorl > 0 and flush_now < 1.0 and not s.forced
		if extra_local:  # poussée provoquée : seuls les bourgeons libérés (pincés, effeuillés) partent, presque tous
			if not s.kick:
				s.v_term = 0.0
				s.v_lat = 0.0
				continue
			s.v_term = 0.5 + rng.randf() * 0.7  # réponse courte : rameau court ou 1 à 2 entre-nœuds
			s.v_lat = 0.5 + rng.randf() * 0.7
		if s.term_bud and (s.v_term >= 1.0 if summer else s.v_term + rng.randf() >= 1.0):
			var d := s.end - s.start
			if s.relay:  # repart du bourgeon latéral : l'axe fait un coude
				d = d.normalized() + s.lat_dir.normalized()
			s.term_bud = false
			s.relay = false
			s.main_child = _shoot(i, d, s.v_term)
		# Inhibition par le houppier : un bourgeon dormant passé deux hivers ne part plus de lui-même
		# (vieux bois du tronc) ; seule une coupe proche le libère. Les rejets d'une taille sévère naissent neufs.
		var dormant := s.lat_bud_age > 52 and s.release <= 1.0
		if s.lat_bud and not dormant and (s.v_lat >= 1.0 if summer else s.v_lat + rng.randf() >= 1.0):
			s.lat_bud = false
			s.lat_child = _shoot(i, s.lat_dir, s.v_lat)
		s.v_term = 0.0
		s.v_lat = 0.0


## Fait pousser une tige depuis le bout du segment parent. Renvoie le premier entre-nœud.
## Vigueur < 1 : rameau court (un entre-nœud raccourci). Sinon environ v entre-nœuds (arrondi au hasard),
## d'autant plus longs que la pousse est vigoureuse, plus courts au début et à la fin du rameau.
func _shoot(parent_i: int, dir: Vector3, v: float) -> int:
	_vsum += v
	_vn += 1
	var spur := v < 1.0
	var n := 1 if spur else clampi(int(v + rng.randf()), 1, max_per_flush)
	if preformed > 0:
		n = clampi(int(preformed + (0.0 if spur else v) + rng.randf()), 1, max_per_flush)
	var len_v := spur_len if spur else clampf(0.6 + 0.15 * v, 0.7, 1.5)
	# Étape 28 : à l'ombre, la pousse s'étire et ses feuilles grandissent (étiolement) ; au soleil, c'est
	# l'inverse. Poussées d'été plus courtes, aux feuilles plus petites ; après un effeuillage, plus encore.
	var lum := _light(segs[parent_i].end) if shadow.size() == GX * GY * GZ else 0.6
	var season := 1.0 if flush_now >= 1.0 else (0.7 if extra_defol else 0.8)
	len_v *= (1.25 - 0.35 * lum) * (1.0 if spur else season)
	var leaf_f := (1.2 - 0.35 * lum) * season
	var first := -1
	var prev := parent_i
	var d := dir.normalized()
	var p := segs[parent_i].end
	var phase := segs[parent_i].phase
	# pin : aiguilles plus longues sur une pousse forte, deux fois plus courtes l'été
	var needle_len := clampf(0.6 + 0.25 * v, 0.6, 1.4) * (1.0 if flush_now >= 1.0 else 0.5)
	for k in n:
		var rnd := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		d = (d * w_dir + _light_dir(p) * w_light + Vector3.UP * w_up + rnd * jitter).normalized()
		var s := Seg.new()
		s.parent = prev
		s.start = p
		s.leaf_k = float(k + 1) / n
		s.size_k = clampf(0.6 + 0.25 * v, 0.6, 1.3) * leaf_f  # pousse faible, soleil, été : petites feuilles
		# entre-nœuds courts à la base de la pousse, longs au milieu, courts au bout : pincer tôt garde les courts
		var profile := 1.0 if spur else 0.45 + 0.75 * sin(PI * (k + 0.5) / n)
		if opposite and not spur:
			profile = 0.35 if k == 0 else 0.8 + 0.5 * float(k) / n  # première paire serrée, puis de plus en plus long
		s.end = p + d * internode * len_v * profile * rng.randf_range(0.8, 1.2)
		s.radius = tip_radius
		s.grow_time = GROW_WEEKS / n
		s.born = week + k * s.grow_time  # les entre-nœuds s'allongent l'un après l'autre
		phase += phyllotaxy + rng.randf_range(-0.2, 0.2)
		s.phase = phase
		_set_lateral(s, d)
		s.lat_q = rng.randf_range(0.6, 1.4) * (0.7 + 0.6 * float(k + 1) / n)  # acrotonie : le haut du rameau part plus fort
		segs.append(s)
		var idx := segs.size() - 1
		if k == 0:
			first = idx
		else:
			segs[prev].main_child = idx
		if whorl > 0:
			s.lat_bud = false  # pin : bourgeons d'aiguilles latents, réveillés seulement par une coupe
			s.needle = 0.0 if k < n / 3 else needle_len  # base de la chandelle nue (écailles)
		prev = idx
		p = s.end
		if opposite:
			# second bourgeon de la paire : entre-nœud quasi nul, bourgeon du côté opposé
			var t := Seg.new()
			t.parent = prev
			t.start = p
			t.end = p + d * internode * 0.02
			t.radius = tip_radius
			t.grow_time = s.grow_time
			t.born = s.born
			t.leaf_k = s.leaf_k
			t.phase = s.phase + PI
			_set_lateral(t, d)
			t.lat_q = s.lat_q * rng.randf_range(0.8, 1.2)
			segs.append(t)
			segs[prev].main_child = segs.size() - 1
			prev = segs.size() - 1
			p = t.end
	if whorl > 0 and not spur:
		# couronne : 2 ou 3 bourgeons sur une pousse moyenne, jusqu'à whorl + 1 sur une forte
		var nw := clampi(int(1.5 * v + rng.randf()), 0, whorl)
		if nw > 0:
			var c := _crown(prev, p, d, phase, nw, segs[prev].born + segs[prev].grow_time)
			segs[prev].main_child = c
			return first
	segs[prev].term_bud = true
	return first


## Couronne de bourgeons (pin) au bout de prev : entre-nœuds minuscules en spirale, chacun avec un bourgeon
## latéral, le dernier avec un bourgeon terminal. Renvoie le premier ; à rattacher par l'appelant.
func _crown(prev: int, p: Vector3, d: Vector3, phase: float, count: int, t0: float) -> int:
	var first := segs.size()
	for k in count:
		var s := Seg.new()
		s.parent = prev
		s.start = p
		s.end = p + d * internode * 0.06
		s.radius = tip_radius
		s.grow_time = 0.2
		s.born = t0
		s.needle = 0.0
		phase += deg_to_rad(137.5)
		s.phase = phase
		_set_lateral(s, d)
		s.lat_q = rng.randf_range(0.6, 1.4)
		segs.append(s)
		if k > 0:
			segs[prev].main_child = segs.size() - 1
		prev = segs.size() - 1
		p = s.end
	segs[prev].term_bud = true
	return first


func _set_lateral(s: Seg, d: Vector3) -> void:
	var a := d.cross(Vector3.UP)
	if a.length() < 0.01:
		a = d.cross(Vector3.RIGHT)
	a = a.normalized().rotated(d, s.phase)
	s.lat_dir = d.rotated(a, branch_angle)
	s.lat_bud = true
	s.lat_bud_age = 0


func _kill(i: int) -> void:
	var p := segs[i].parent
	if p >= 0:
		if segs[p].main_child == i:
			segs[p].main_child = -1
		if segs[p].lat_child == i:
			segs[p].lat_child = -1
	for k in subtree(i):
		segs[k].dead = true


## Retire les segments morts en gardant l'ordre (un parent est toujours avant ses enfants).
func _compact() -> void:
	var remap := PackedInt32Array()
	remap.resize(segs.size())
	var out: Array[Seg] = []
	for i in segs.size():
		if segs[i].dead:
			remap[i] = -1
		else:
			remap[i] = out.size()
			out.append(segs[i])
	for s in out:
		s.parent = remap[s.parent] if s.parent >= 0 else -1
		s.main_child = remap[s.main_child] if s.main_child >= 0 else -1
		s.lat_child = remap[s.lat_child] if s.lat_child >= 0 else -1
	segs = out
	layout += 1


# --- Grille d'ombre ---

func _cell(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / CELL) + GX / 2, floori(p.y / CELL), floori(p.z / CELL) + GZ / 2)


func _shadow_at(c: Vector3i) -> float:
	if c.y < 0:
		return 1.0  # sous la terre : pas de lumière
	if c.x < 0 or c.z < 0 or c.x >= GX or c.y >= GY or c.z >= GZ:
		return 0.0  # hors de la grille : plein ciel
	return shadow[(c.y * GZ + c.z) * GX + c.x]


## light_exp : la lumière traverse le feuillage en s'affaiblissant (Beer-Lambert), l'intérieur d'un houppier
## dense n'est jamais tout à fait noir. Sinon (pin) : l'ombre s'additionne jusqu'au noir.
func _light(p: Vector3) -> float:
	if light_exp:
		return minf(exp(-_shadow_at(_cell(p))), 1.0)
	return clampf(1.0 - _shadow_at(_cell(p)) + SH_A, 0.0, 1.0)


func _light_dir(p: Vector3) -> Vector3:
	var c := _cell(p)
	var g := Vector3(
		_shadow_at(c + Vector3i(1, 0, 0)) - _shadow_at(c - Vector3i(1, 0, 0)),
		_shadow_at(c + Vector3i(0, 1, 0)) - _shadow_at(c - Vector3i(0, 1, 0)),
		_shadow_at(c + Vector3i(0, 0, 1)) - _shadow_at(c - Vector3i(0, 0, 1)))
	return -g.normalized() if g.length() > 0.001 else Vector3.ZERO


## Les bourgeons d'une même cellule projettent la même ombre : on les compte d'abord, puis on projette une fois
## par cellule occupée (audit, phase 4 : même résultat, beaucoup moins de calcul quand le feuillage est dense).
func _compute_shadow() -> void:
	shadow.resize(GX * GY * GZ)
	shadow.fill(0.0)
	var n := {}
	for s in segs:
		var lf := _leafless(s)  # effeuillé : presque plus d'ombre portée
		if s.term_bud:
			var c := _cell(s.end)
			n[c] = n.get(c, 0.0) + lf
		if s.lat_bud:
			var c := _cell(_lat_pos(s))
			n[c] = n.get(c, 0.0) + lf
	for c in n:
		_cast(c, n[c])


## Effeuillé depuis moins de DEFOL_REGROW semaines : 0,15 (il ne reste que les bourgeons), sinon 1.
func _leafless(s: Seg) -> float:
	return 0.15 if s.defol >= 0.0 and week >= s.defol and week < s.defol + DEFOL_REGROW else 1.0


func _cast(c: Vector3i, count: float) -> void:
	for q in SH_Q + 1:
		var y := c.y - q
		if y < 0:
			break
		if y >= GY:
			continue
		var v := SH_A * leaf_area * pow(SH_B, -q) * count
		for dz in range(-q, q + 1):
			var z := c.z + dz
			if z < 0 or z >= GZ:
				continue
			for dx in range(-q, q + 1):
				var x := c.x + dx
				if x >= 0 and x < GX:
					shadow[(y * GZ + z) * GX + x] += v
