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
var internode := 0.018
var alpha := 1.6              # vigueur totale = alpha × lumière captée
var apical := 0.53            # part de vigueur donnée à l'axe principal (λ)
var max_per_flush := 4        # entre-nœuds max par bourgeon et par poussée
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
var reserve := 0.0            # vigueur que les racines peuvent fournir (suit la lumière avec retard)
var layout := 0               # change quand des segments sont retirés (les indices changent)
var fallen: Array = []        # rameaux morts tombés pendant la période : [début, fin, rayon, séchage, chute]
var rng := RandomNumberGenerator.new()


func reset(seed_value: int = 1, species: Dictionary = Species.ELM) -> void:
	for k in species:
		set(k, species[k])
	rng.seed = seed_value
	segs.clear()
	reserve = 0.0
	week = 10  # début mars, année 1
	var s := Seg.new()
	s.end = Vector3(0, internode * 2.0, 0)
	s.term_bud = true
	s.radius = tip_radius
	_set_lateral(s, Vector3.UP)
	segs.append(s)


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
	if w == DIEBACK_WEEK:
		_dieback()
	if w == 0:
		_end_of_year()


## Coupe le segment i et tout ce qu'il porte. Renvoie false pour la base (on ne coupe pas tout l'arbre).
const WOUND_MIN := 0.0015      # rayon au-delà duquel une coupe laisse une plaie (3 mm de diamètre)


## concave : coupe à la pince concave (la plaie se referme deux fois plus vite).
func prune(i: int, concave := false) -> bool:
	if i <= 0 or i >= segs.size():
		return false
	var j := segs[i].parent
	var cut := segs[i]
	if cut.radius > WOUND_MIN and not cut.dry:
		var w := segs[j]
		w.wound_full = maxf(w.wound_full, cut.radius)
		w.wound_r = w.wound_full
		w.wound_concave = concave
		w.wound_dir = (cut.end - cut.start).normalized()
		w.wound_side = w.main_child != i
	_kill(i)
	# La coupe lève la dominance apicale : les bourgeons juste en dessous (dormants ou adventifs)
	# se réveillent et prennent de la vigueur l'année suivante.
	for k in backbud_nodes:
		if j < 0:
			break
		var p := segs[j]
		var leafy := leaf_years == 0 or week - p.born < leaf_years * 52
		if leafy and not p.dry and not p.lat_bud and p.lat_child < 0 and rng.randf() < backbud_chance:
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
	_compute_shadow()
	_basipetal()
	if _sprouts():
		_basipetal()
	_allocate(strength)
	_grow()
	_basipetal()


func _end_of_year() -> void:
	for s in segs:
		s.release = 1.0
		if s.lat_bud:
			s.lat_bud_age += 52
			if s.lat_bud_age > bud_life:
				s.lat_bud = false
	reserve = lerpf(reserve, segs[0].light, 0.5)  # les racines s'ajustent en un an ou deux
	# Cerne annuel : chaque entre-nœud vivant ajoute une couche de bois proportionnelle au feuillage
	# qu'il porte (loi de Pressler). Le bas du tronc, qui porte tout, épaissit le plus : conicité continue,
	# et le tronc continue de grossir même après une taille.
	for s in segs:
		if not s.dry:
			var old := s.radius
			s.radius = sqrt(s.radius * s.radius + ring_area * s.light / PI)
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
	var excess := reserve / maxf(segs[0].light, 0.01)
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
	for i in range(1, segs.size()):
		var s := segs[i]
		if s.dry:
			continue
		if s.light < shed_ratio * s.count:
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
func _allocate(strength: float) -> void:
	reserve = maxf(reserve, segs[0].light)
	var pot := clampf(1.0 - float(segs[0].count) / capacity, 0.0, 1.0)
	segs[0].vigor = alpha * reserve * strength * pot
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
		if s.term_bud and s.v_term + rng.randf() >= 1.0:
			s.term_bud = false
			s.main_child = _shoot(i, s.end - s.start, s.v_term)
		if s.lat_bud and s.v_lat + rng.randf() >= 1.0:
			s.lat_bud = false
			s.lat_child = _shoot(i, s.lat_dir, s.v_lat)
		s.v_term = 0.0
		s.v_lat = 0.0


## Fait pousser une tige depuis le bout du segment parent. Renvoie le premier entre-nœud.
## Vigueur < 1 : rameau court (un entre-nœud raccourci). Sinon environ v entre-nœuds (arrondi au hasard),
## d'autant plus longs que la pousse est vigoureuse, plus courts au début et à la fin du rameau.
func _shoot(parent_i: int, dir: Vector3, v: float) -> int:
	var spur := v < 1.0
	var n := 1 if spur else clampi(int(v + rng.randf()), 1, max_per_flush)
	var len_v := 0.8 if spur else clampf(0.6 + 0.15 * v, 0.7, 1.5)
	var first := -1
	var prev := parent_i
	var d := dir.normalized()
	var p := segs[parent_i].end
	var phase := segs[parent_i].phase
	for k in n:
		var rnd := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		d = (d * w_dir + _light_dir(p) * w_light + Vector3.UP * w_up + rnd * jitter).normalized()
		var s := Seg.new()
		s.parent = prev
		s.start = p
		var profile := 1.0 if spur else 0.85 + 0.35 * sin(PI * (k + 0.5) / n)
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
			s.lat_bud = false  # pin : pas de bourgeon le long de la chandelle
		prev = idx
		p = s.end
	if whorl > 0 and not spur:
		# Couronne de bourgeons au bout de la pousse : entre-nœuds minuscules en spirale.
		var t0 := segs[prev].born + segs[prev].grow_time
		for k in whorl:
			var s := Seg.new()
			s.parent = prev
			s.start = p
			s.end = p + d * internode * 0.06
			s.radius = tip_radius
			s.grow_time = 0.2
			s.born = t0
			phase += deg_to_rad(137.5)
			s.phase = phase
			_set_lateral(s, d)
			s.lat_q = rng.randf_range(0.6, 1.4)
			segs.append(s)
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


func _light(p: Vector3) -> float:
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
		var v := SH_A * pow(SH_B, -q)
		for dz in range(-q, q + 1):
			var z := c.z + dz
			if z < 0 or z >= GZ:
				continue
			for dx in range(-q, q + 1):
				var x := c.x + dx
				if x >= 0 and x < GX:
					shadow[(y * GZ + z) * GX + x] += v
