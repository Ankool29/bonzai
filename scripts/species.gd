class_name Species
## Fiches espèces : chaque clé remplace la variable du même nom dans TreeSim.

const ELM := {
	"name": "Orme de Chine",
	# Doc (UF/IFAS ST-652, UConn, Flora of North America) : feuilles alternes, simples, dentées, base oblique,
	# limbe 2-6 cm (réduit à ~2 cm en bonsaï), pétiole 2-6 mm ; rameaux de l'année gris-brun, fins ;
	# écorce desquamée en plaques marbrées gris, olive, beige, orangé ; automne jaune à rouge-violet.
	# rameaux fins gris-brun ; écorce : voir le mode « lacebark » du shader
	"bark_colors": [Color(0.55, 0.52, 0.47), Color(0.63, 0.6, 0.55), Color(0.62, 0.45, 0.32), Color(0.33, 0.28, 0.24)],
	"foliage_size": 0.02,
	# Pousses de l'année (étape 11) : 3 feuilles déjà formées dans le bourgeon, plus selon la vigueur (jusqu'à 8),
	# entre-nœuds courts (5 à 15 mm), feuilles plus grandes vers le bout, croissance en zigzag (sympodiale).
	"internode": 0.010,
	"alpha": 1.6,
	"apical": 0.5,
	"max_per_flush": 8,
	"preformed": 3,
	"spur_len": 0.5,
	"leaf_area": 0.5,
	"sympodial": true,
	"branch_angle": deg_to_rad(45.0),
	"phyllotaxy": deg_to_rad(180.0),  # alterne distique
	"w_light": 0.35,
	"w_up": 0.06,
	"jitter": 0.06,
	"shed_ratio": 0.04,
	"bud_life": 52 * 8,
	"backbud_chance": 0.6,
	"capacity": 6000,
	"max_sprouts": 4,
	"flushes": {14: 1.0, 22: 0.7, 30: 0.4},  # printemps, début et fin d'été, de plus en plus faibles
	"leaf_shape": 0,
	"young_color": Color(0.55, 0.47, 0.38),
	"autumn_color": Color(0.82, 0.6, 0.2),
	"opposite": false,
	"fork": false,
	"bud_color": Color(0.42, 0.28, 0.18),
	"bud_size": 0.0025,
	"light_exp": true,
	"whorl": 0,          # bourgeon latéral à chaque nœud
	"leaf_years": 0,     # caduc
}

## Pin noir du Japon : une poussée par an (chandelle), bourgeons en couronne au bout de la pousse,
## forte dominance apicale, aiguilles 3 ans, presque pas de rebourgeonnage sur le vieux bois.
const PINE := {
	"name": "Pin noir du Japon",
	# Doc (étape 12) : Gymnosperm Database, Conifer Society, Wikipédia, Annals of Botany 2004 (bourgeon du pin),
	# Bonsai Tonight (mekiri, types de bourgeons, rebourgeonnage), Björn Bjorholm. Chandelle préformée : base
	# d'écailles nue, paires d'aiguilles (7-12 cm, 3-4 ans), couronne de bourgeons au bout ; poussée d'été si
	# très vigoureux ; mekiri : 0 à 5 bourgeons 2-4 semaines après, pousses et aiguilles plus courtes.
	# plaques gris foncé, fissures profondes brun-rouge
	"bark_colors": [Color(0.38, 0.33, 0.31), Color(0.45, 0.4, 0.37), Color(0.4, 0.34, 0.3), Color(0.36, 0.18, 0.12)],
	"internode": 0.02,
	"alpha": 1.6,
	"apical": 0.62,
	"max_per_flush": 5,
	"branch_angle": deg_to_rad(70.0),
	"phyllotaxy": deg_to_rad(137.5),  # spirale
	"w_light": 0.2,
	"w_up": 0.1,
	"jitter": 0.05,
	"shed_ratio": 0.06,  # aime la lumière
	"bud_life": 52 * 3,  # les bourgeons latents meurent avec les aiguilles
	"backbud_chance": 0.5,  # bourgeons d'aiguilles, en saison (voir prune)
	"capacity": 6000,
	"max_sprouts": 0,
	"flushes": {16: 1.0, 27: 0.3},
	"preformed": 0,
	"spur_len": 0.8,
	"leaf_area": 1.0,
	"sympodial": false,
	"leaf_shape": 0,
	"young_color": Color(0.55, 0.47, 0.38),
	"autumn_color": Color(0.82, 0.6, 0.2),
	"opposite": false,
	"fork": false,
	"bud_color": Color(0.86, 0.83, 0.76),
	"bud_size": 0.012,
	"light_exp": false,
	"whorl": 4,
	"leaf_years": 3,
}


const MAPLE := {
	"name": "Érable du Japon",
	# Doc (étape 13) : Virginia Tech Dendrology, UConn Plant Database, NC State Extension, Utah State Extension,
	# bonsai4me, Bonsai Tonight (pinçage, entre-nœuds, effeuillage), forums UBC et Houzz (paires alternées).
	# Feuilles et bourgeons opposés, paires tournées d'un quart de tour ; pas de vrai bourgeon terminal :
	# fourche au bout des rameaux ; pousse de printemps : une paire serrée puis de longs entre-nœuds ;
	# limbe palmé de 5 à 7 lobes dentés, long pétiole ; jeunes rameaux verts à rouges, écorce lisse gris clair.
	"bark_colors": [Color(0.58, 0.58, 0.55), Color(0.62, 0.62, 0.58), Color(0.55, 0.56, 0.5), Color(0.42, 0.42, 0.4)],
	"foliage_size": 0.035,
	"leaf_shape": 1,
	"young_color": Color(0.6, 0.25, 0.2),
	"autumn_color": Color(0.85, 0.2, 0.1),
	"internode": 0.02,
	"alpha": 1.6,
	"apical": 0.5,         # dominance du haut réduite (étape 18) : houppier plus étalé
	"max_per_flush": 4,    # paires de feuilles
	"preformed": 0,
	"spur_len": 0.4,
	"leaf_area": 0.5,      # deux bourgeons par nœud
	"sympodial": false,
	"opposite": true,
	"fork": true,
	"branch_angle": deg_to_rad(50.0),
	"phyllotaxy": deg_to_rad(90.0),  # opposées décussées
	"w_light": 0.35,
	"w_up": 0.08,
	"jitter": 0.06,
	"shed_ratio": 0.04,
	"bud_life": 52 * 4,
	"backbud_chance": 0.5,
	"capacity": 6000,
	"max_sprouts": 2,
	"flushes": {14: 1.0, 24: 0.5},
	"bud_color": Color(0.62, 0.16, 0.12),
	"bud_size": 0.003,
	"light_exp": true,
	"whorl": 0,
	"leaf_years": 0,
}
