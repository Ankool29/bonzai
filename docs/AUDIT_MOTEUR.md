# Audit du moteur de l'arbre (28/11/2026)

Constats du joueur : performances moyennes au-delà de 40 cm ; la limite d'entre-nœuds rend les arbres peu fournis.
Audit fait à la lecture du code (Godot ne peut pas tourner dans l'environnement de Claude) : les ordres de grandeur
sont calculés, pas mesurés. La phase 1 sert justement à mesurer.

## Comment la simulation fait pousser l'arbre (rappel)
1. À chaque poussée (`_flush`) : grille d'ombre (`_compute_shadow`) → lumière des bourgeons et cumul vers la base
   (`_basipetal`) → rejets éventuels → vigueur répartie de la base vers les bourgeons (`_allocate`, Borchert-Honda)
   → les bourgeons partent selon leur vigueur (`_grow`, `_shoot`) → nouveau cumul.
2. Fin d'été (`_dieback`) : bilan de lumière, réserves, racines, branches trop à l'ombre qui sèchent.
3. Fin d'année : cernes (tronc, racines), plaies, bourgeons qui vieillissent.
4. Après le calcul, tout l'arbre est redessiné (`TreeMesh.build`), dans un fil de calcul pour l'avance du temps,
   sur le fil principal pour une coupe ou une sélection.

## Constats, du plus coûteux au moins coûteux

### 1. Les feuilles : de loin le plus lourd (dessin)
- Une feuille d'orme fait environ 130 triangles : limbe (29), liseré du contour (58), nervure centrale et
  10 nervures secondaires dessinées en double épaisseur (44). Soit environ 390 sommets, chacun avec 5 tableaux
  à remplir, et deux petits tableaux créés pour chaque sommet (`_tri`, `_line`).
- Avec 6 000 entre-nœuds feuillés (plus les rosettes), cela fait de l'ordre de 2 millions de sommets :
  c'est trop pour un téléphone, à la fois pour construire (GDScript) et pour afficher (GPU).
- Les nervures et le contour n'ont pas besoin d'être de la géométrie : le shader peut les tracer.

### 2. Toute sélection reconstruit tout l'arbre
- `_refresh()` (13 appels : sélection, déplacement du repère sur certains outils, coupe, affichage des
  feuilles…) relance `TreeMesh.build` sur le fil principal. Sur un grand arbre, chaque toucher fige l'écran.
- Pour surligner une branche, un petit maillage de surbrillance suffit.

### 3. La grille d'ombre (simulation)
- Chaque bourgeon projette son ombre sur 5 couches de cellules (1 + 9 + 25 + 49 + 81 = 165 cellules).
  6 000 bourgeons font 1 million d'opérations par calcul, et ce calcul est fait à chaque poussée et en fin d'été.
- Or les cellules font 2,5 cm et les entre-nœuds 1 à 2 cm : beaucoup de bourgeons partagent une cellule.
  Compter d'abord les bourgeons par cellule, puis projeter une fois par cellule occupée, donne exactement
  le même résultat pour 5 à 20 fois moins de travail.
- `_basipetal` crée un petit tableau pour chaque entre-nœud (`for c in [main_child, lat_child]`), et il est
  appelé 3 à 4 fois par poussée.

### 4. La limite d'entre-nœuds (densité)
- `capacity` = 6 000 entre-nœuds vivants, freinage dès 85 %. C'est un garde-fou de calcul, pas de la biologie :
  le vrai frein est le pot. Avec l'orme (entre-nœuds de 1 cm), 6 000 entre-nœuds ne font que 60 m de rameaux,
  peu pour un houppier dense de 40 cm et plus.
- L'érable compte deux segments par nœud (le second, presque nul, porte le bourgeon d'en face) : il atteint
  la limite deux fois plus vite.
- Les deux premières phases doivent rendre le relèvement possible (vers 15 000).

### 5. Le bois
- Un anneau de 6 à 12 faces par entre-nœud, même sur un vieil axe droit où rien ne change d'un entre-nœud
  à l'autre. L'idée du joueur (fusionner les vieux entre-nœuds) s'applique bien ici, au dessin seulement :
  sur un vieil axe régulier, un anneau tous les 3 ou 4 entre-nœuds, sans rien changer à la simulation.

### 6. Le reste
- Les segments sont des objets GDScript (`Seg`) : chaque accès est plus lent qu'un tableau compact. C'est un
  gain réel, mais c'est une grosse réécriture : à garder pour après les phases 1 à 4.
- C++ (GDExtension) : le moteur entier irait 10 à 50 fois plus vite, mais il faut compiler une bibliothèque
  pour Android arm64 (et l'éditeur Android), par exemple avec GitHub Actions. À faire seulement si, après les
  phases 1 à 5, les mesures montrent que la simulation reste trop lente.

## Plan proposé
1. **Mesurer** : temps de simulation, temps de construction, nombre de sommets, affichés dans les infos
   (mode réglage). Option : banc d'essai qui tourne Godot sans écran dans GitHub Actions, pour comparer avant
   et après chaque phase sans dépendre du téléphone.
2. **Feuilles légères** : silhouette de 8 à 14 triangles ; contour, dents et nervures tracés par le shader.
   Environ 10 fois moins de sommets de feuilles. L'aspect doit rester le même (vérification dessinée).
3. **Sélection sans reconstruction** : surbrillance dans un petit maillage à part ; la coupe seule reconstruit.
4. **Simulation** : ombre projetée par cellule occupée ; plus de tableaux créés dans `_basipetal`. Même résultat,
   vérifié au portage Python.
5. **Plus de densité** : capacité relevée selon les mesures (objectif 15 000) ; nœuds de l'érable comptés une fois.
6. **Bois allégé** : anneaux espacés sur les vieux axes réguliers.
7. **Si nécessaire** : C++ pour la simulation, construit par GitHub Actions.
