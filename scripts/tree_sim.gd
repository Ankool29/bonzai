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
var leaf_shape := 0           # 0 : feuille simple (orme), 1 : palmée (érable)
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
var tip_radius := 0.0006        # jeune rameau : 1,2 mm de diamètre
var ring_area := 1.5e-6        # cerne annuel : surface ajoutée (m²) par unité de lumière captée au-dessus
var shed_ratio := 0.04        # lumière par entre-nœud sous laquelle une branche dépérit
var bud_life := 52 * 8        # durée de vie d'un bourgeon dormant (semaines)
var backbud_nodes := 4        # nœuds sous la coupe qui peuvent rebourgeonner
var backbud_chance := 0.6
var capacity := 1500          # entre-nœuds vivants que le pot peut nourrir (en attendant les racines)
var release_nodes := 3        # nœuds sous la coupe qui profitent de la levée de dominance
var release_boost := 3.0
var sprout_excess := 1.4      # réserves / lumière au-delà duquel des rejets apparaissent
var max_sprouts := 4
var whorl := 0                # >0 : bourgeons seulement en couronne au bout de la pousse (pin)
var leaf_years := 0           # 0 : caduc ; sinon durée de vie des aiguilles (le réveil n'a lieu que là où il y en a)
## Semaine de l'année -> force de la poussée (printemps puis petite poussée d'été).
var flushes := {15: 1.0, 18: 1.0, 21: 0.8, 27: 0.5}
var flush_now := 1.0          # force de la poussée en cours (< 1 : poussée d'été)
var extra_flush := -1         # semaine de la poussée provoquée par une coupe de chandelles (pin)
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
var _vsum := 0.0
var _vn := 0
const ROOTS_PER_LITRE := 40.0  # lumière qu'un litre de pot peut alimenter (8 L : arbre d'environ 75 cm à 8 ans)
const SPEND := 0.4             # part de l'apport puisée dans les réserves à chaque poussée (par unité de force)
var layout := 0               # change quand des segments sont retirés (les indices changent)
var fallen: Array = []        # rameaux morts tombés pendant la période : [début, fin, rayon, séchage, chute]
var rng := RandomNumberGenerator.new()
var planted := 10             # semaine de mise en pot


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


## Sauvegarde : toutes les variables de l'arbre (fiche espèce comprise) et des segments, colonne par colonne,
## plus l'état du hasard pour que la suite de la pousse soit la même.
func to_data() -> Dictionary:
	var d := {}
	for p in get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and p.name != "segs" and p.name != "rng" and p.name != "fallen":
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
	return d


func from_data(d: Dictionary) -> void:
	for k in d:
		if k != "segs" and k != "count" and k != "rng_seed" and k != "rng_state":
			set(k, d[k])
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
	if w == DIEBACK_WEEK:
		_dieback()
	if w == 0:
		_end_of_year()


## Réserves rapportées aux racines : 1 = pleine santé, < 0,25 = épuisé.
func health() -> float:
	return reserve / maxf(roots, 0.001)


## Rempotage : nouveau pot (litres) et part des racines coupées. Hors fin d'hiver, l'arbre souffre.
## Renvoie un message pour le joueur.
func repot(volume: float, cut: float) -> String:
	pot_volume = volume
	roots = minf(roots * (1.0 - cut), volume * ROOTS_PER_LITRE)
	reserve *= 1.0 - cut * 0.5  # une part des réserves est dans les racines
	var w := week % 52
	if w >= 6 and w <= 14:
		return "Rempoté au bon moment."
	if cut > 0.0 and w >= 15 and w <= 40:
		reserve *= 0.5
		return "Racines coupées en pleine pousse : l'arbre souffre."
	return "Rempoté hors saison : les racines repartiront au printemps."


## Coupe le segment i et tout ce qu'il porte. Renvoie false pour la base (on ne coupe pas tout l'arbre).
const WOUND_MIN := 0.0015      # rayon au-delà duquel une coupe laisse une plaie (3 mm de diamètre)


## concave : coupe à la pince concave (la plaie se referme deux fois plus vite).
func prune(i: int, concave := false) -> bool:
	if i <= 0 or i >= segs.size():
		return false
	var j := segs[i].parent
	var cut := segs[i]
	reserve = maxf(0.0, reserve - 0.5 * cut.light)  # l'énergie investie dans le feuillage coupé est perdue
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
	# et le tronc continue de grossir même après une taille.
	for s in segs:
		if not s.dry:
			var old := s.radius
			s.radius = sqrt(s.radius * s.radius + ring_area * leaf_area * s.light / PI)
			if s.wound_r > 0.0:
				# le bourrelet de cicatrisation avance avec le cerne, deux fois plus vite après la pince concave
				s.wound_r = maxf(0.0, s.wound_r - (s.radius - old) * (6.0 if s.wound_concave else 3.0))
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
	reserve = minf(reserve + l, 1.5 * roots)
	var t := minf(l, pot_volume * ROOTS_PER_LITRE)
	roots = minf(t, roots * 2.0 + 5.0) if t > roots else roots + (t - roots) * 0.5
	for i in range(1, segs.size()):
		var s := segs[i]
		if s.dry:
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
		s.q_term = _light(s.end) if s.term_bud and has_shadow else 0.0
		s.q_lat = _light(_lat_pos(s)) if s.lat_bud and has_shadow else 0.0
		s.light = s.q_term + s.q_lat
		s.count = 0 if s.dry else 1
		for c in [s.main_child, s.lat_child]:
			if c >= 0:
				s.light += segs[c].light
				s.count += segs[c].count


## De la base vers les feuilles : répartition de la vigueur (Borchert-Honda).
## Apport d'une poussée : feuillage actuel plus réserves, plafonné par les racines ; les réserves en paient une part.
func _allocate(strength: float) -> void:
	var l := segs[0].light
	roots = maxf(roots, minf(minf(l, pot_volume * ROOTS_PER_LITRE), roots * 2.0 + 5.0))
	var supply := minf(reserve + l, roots)
	reserve = maxf(0.0, reserve - SPEND * supply * strength)
	var pot := clampf(1.0 - float(segs[0].count) / capacity, 0.0, 1.0)  # garde-fou de calcul
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
		if s.term_bud and (s.v_term >= 1.0 if summer else s.v_term + rng.randf() >= 1.0):
			var d := s.end - s.start
			if s.relay:  # repart du bourgeon latéral : l'axe fait un coude
				d = d.normalized() + s.lat_dir.normalized()
			s.term_bud = false
			s.relay = false
			s.main_child = _shoot(i, d, s.v_term)
		if s.lat_bud and (s.v_lat >= 1.0 if summer else s.v_lat + rng.randf() >= 1.0):
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
		s.size_k = clampf(0.6 + 0.25 * v, 0.6, 1.3)  # pousse faible : petites feuilles (miniaturisation)
		var profile := 1.0 if spur else 0.85 + 0.35 * sin(PI * (k + 0.5) / n)
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


func _compute_shadow() -> void:
	shadow.resize(GX * GY * GZ)
	shadow.fill(0.0)
	for s in segs:
		if s.term_bud:
			_cast(s.end)
		if s.lat_bud:
			_cast(_lat_pos(s))


func _cast(p: Vector3) -> void:
	var c := _cell(p)
	for q in SH_Q + 1:
		var y := c.y - q
		if y < 0:
			break
		if y >= GY:
			continue
		var v := SH_A * leaf_area * pow(SH_B, -q)
		for dz in range(-q, q + 1):
			var z := c.z + dz
			if z < 0 or z >= GZ:
				continue
			for dx in range(-q, q + 1):
				var x := c.x + dx
				if x >= 0 and x < GX:
					shadow[(y * GZ + z) * GX + x] += v
