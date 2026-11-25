# Bonzai — document de conception

## Principe
Jeu mobile : cultiver des bonsaï pour les exposer et les vendre. La particularité est la simulation complète
de l'arbre : pousse selon l'espèce, réaction à la taille et au ligaturage.

## Simulation de l'arbre
- Base : modèle auto-organisé de Palubicki et al. (2009), *Self-organizing tree models for image synthesis* :
  compétition des bourgeons pour la lumière et l'espace, flux de vigueur interne, mort des branches faibles.
  La taille redistribue la vigueur et réveille des bourgeons dormants (rebourgeonnage).
- Épaississement : « pipe model » (règle de Léonard de Vinci).
- Ligaturage : déformation plastique du bois sous contrainte constante (idée de Pirk et al. 2014, *Windy Trees*).
  Le fil marque l'écorce s'il reste trop longtemps. Casse si on plie trop.
- Espèces : un jeu de paramètres (phyllotaxie alterne/opposée/verticillée, dominance apicale, entre-nœuds, angles,
  tropismes, poussées par an, rebourgeonnage sur vieux bois, cicatrisation, fragilité de l'écorce, souplesse,
  sensibilité à la sécheresse). La difficulté en bonsaï découle de ces paramètres.
  Base théorique : modèles architecturaux de Hallé et Oldeman ; thèse de Palubicki (2013).
- Conifères : règles en plus (chandelles et arrachage d'aiguilles du pin, pinçage du genévrier, peu de
  rebourgeonnage sur vieux bois, bois mort jin/shari).
- Espèces de départ : orme de Chine (facile), érable du Japon (moyen), pin noir du Japon (expert).

## Environnement (simulé simplement)
- Lumière : simulée finement, pilote la pousse. Emplacement et rotation du pot.
- Eau : jauge d'humidité selon saison, pot, substrat. Trop sec ou trop humide = dégâts.
- Engrais : levier de vigueur (pousses longues contre finesse), avec calendrier.
- Terreaux : quelques mélanges (akadama, pouzzolane, kiryu, organique) avec rétention, drainage, aération.
- Racines : masse racinaire abstraite, rempotage avec taille des racines tous les 2-3 ans.
- Hors périmètre au début : maladies détaillées, photosynthèse chimique, météo réelle.

## Taille (cœur du gameplay)
- Aperçu de la partie coupée avant validation.
- Choix du point de coupe au-dessus d'un bourgeon (oriente la future pousse).
- Outils : pinçage, ciseaux, pince concave (meilleure cicatrisation), effeuillage.
- Conséquences : cicatrices sur plusieurs saisons, mauvaise saison = affaiblissement, trop couper = mort possible.
- Caméra : rotation libre, zoom fort, pivot sur la branche sélectionnée, vue silhouette.

## Temps
- Lent et contemplatif par défaut (ordre d'idée : une saison ≈ une journée réelle), accélération ×1/×7/×30
  ou « avancer jusqu'à… ».
- Arrêts automatiques sur événements (débourrement, fil qui marque, terreau sec, gel, période de taille).
- Simulation par pas fixes (une semaine de jeu).
- Le temps passe jeu fermé, rejoué au retour avec un résumé. Garde-fous : plancher de survie hors ligne
  (pas de mort sans pouvoir réagir), mode vacances, équipement automatique, notifications réglables,
  plafond de rattrapage. Heure vérifiée contre la triche.

## Graphismes
- Arbre en 3D rendu en basse résolution puis agrandi (pixel art 3D), cel shading, palette limitée, contours.
- Feuillage par petits amas calés sur la grille de pixels ; un jeu de feuilles par espèce.
- Rotation par petits crans pour éviter le grouillement des pixels.
- Pots en 3D avec le même rendu. PixelLab pour interface, icônes, décors, personnages.
- Palette commune imposée à la 3D et à PixelLab.

## Ordre
1. L'arbre (simulation puis rendu). 2. L'habillage. Valeur et économie des arbres : plus tard.
