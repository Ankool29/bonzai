class_name Species
## Fiches espèces : chaque clé remplace la variable du même nom dans TreeSim.

const ELM := {
	"name": "Orme de Chine",
	# écorce grise et lisse, taches orangées (desquamation), fines fissures
	"bark_colors": [Color(0.55, 0.52, 0.47), Color(0.63, 0.6, 0.55), Color(0.62, 0.45, 0.32), Color(0.33, 0.28, 0.24)],
	"bark_fleck": 0.15,
	"bark_fissure": 0.18,
	"foliage_tex": "res://textures/leaf_elm.png",  # 3 feuilles simples (PixelLab)
	"foliage_size": 0.016,
	"internode": 0.018,
	"alpha": 1.6,
	"apical": 0.53,
	"max_per_flush": 4,
	"branch_angle": deg_to_rad(45.0),
	"phyllotaxy": deg_to_rad(180.0),  # alterne distique
	"w_light": 0.35,
	"w_up": 0.12,
	"jitter": 0.12,
	"shed_ratio": 0.04,
	"bud_life": 52 * 8,
	"backbud_chance": 0.6,
	"capacity": 1500,
	"max_sprouts": 4,
	"flushes": {15: 1.0, 18: 1.0, 21: 0.8, 27: 0.5},
	"whorl": 0,          # bourgeon latéral à chaque nœud
	"leaf_years": 0,     # caduc
}

## Pin noir du Japon : une poussée par an (chandelle), bourgeons en couronne au bout de la pousse,
## forte dominance apicale, aiguilles 3 ans, presque pas de rebourgeonnage sur le vieux bois.
const PINE := {
	"name": "Pin noir du Japon",
	# plaques gris foncé, fissures profondes brun-rouge
	"bark_colors": [Color(0.38, 0.33, 0.31), Color(0.45, 0.4, 0.37), Color(0.4, 0.34, 0.3), Color(0.36, 0.18, 0.12)],
	"bark_fleck": 0.0,
	"bark_fissure": 0.28,
	"foliage_tex": "",  # aiguilles dessinées en géométrie
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
	"backbud_chance": 0.1,
	"capacity": 3000,
	"max_sprouts": 0,
	"flushes": {16: 1.0, 27: 0.3},
	"whorl": 4,
	"leaf_years": 3,
}
