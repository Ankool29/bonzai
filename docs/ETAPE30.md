# Étape 30 : temps continu et pousse réaliste

En attente de validation par le joueur.

## Constat (capture du joueur, érable, an 4, semaine 17)
- Les feuilles apparaissent au bout de la pousse avant que la tige ne l'ait atteint : elles flottent dans le vide.
  Cause : chaque feuille grandit autour de son point d'attache **final** (`TreeMesh._foliage`, `la1 = s.end`),
  alors que l'entre-nœud, lui, s'allonge de son départ vers sa fin (`anim_wood`).
- Le temps avance par bonds (+1 semaine, +1 saison, +1 an) : on ne peut pas s'arrêter au moment voulu
  (par exemple au début d'une poussée, pour pincer).

## Sources
- Après le débourrement, les feuilles mettent quelques semaines à atteindre leur taille adulte, et cette phase est
  plus courte chez les feuillus que chez les persistants (Springer, Plant Ecology 2020, durée d'expansion des
  feuilles ; NSF, « vitesse du verdissement » entre débourrement et feuilles adultes).
- La feuille sort pliée et petite du bourgeon, s'étale pendant que la pousse s'allonge, puis finit de grandir une
  fois l'entre-nœud à sa longueur.

## 30a : pousse réaliste (dessin seulement, la simulation ne change pas)
- La feuille suit la pointe : son point d'attache avance avec le bout de l'entre-nœud qui s'allonge (même calcul
  que le bois dans `anim.gdshaderinc`). Plus aucune feuille dans le vide.
- La feuille grandit plus longtemps que sa tige : elle naît à ~15 % de sa taille quand son entre-nœud commence à
  pousser, puis atteint sa taille finale environ 3 semaines plus tard. Le pétiole grandit avec elle.
- Pin : même règle pour les aiguilles, qui s'allongent après la chandelle.
- Les bourgeons apparaissent une fois l'entre-nœud fini (déjà le cas).

## 30b : temps continu
- Les boutons « +1 semaine / +1 saison / +1 an » sont remplacés par :
  - un bouton Lecture / Pause ;
  - un bouton de vitesse qui passe de ×1 à ×2, ×5 puis ×10 (×1 = un jour par seconde, soit une semaine en 7 s ;
    ×10 = une semaine en 0,7 s, un an en ~36 s).
- Pendant la lecture, l'arbre pousse en continu. Le calcul de la suite se fait en arrière-plan pendant que
  l'animation joue (plus de petit chargement entre deux périodes).
- Sur un gros arbre, le dessin prend plus de temps : le calcul se fait alors par paquets de plusieurs semaines, sans
  que l'animation ralentisse.
- Pause immédiate, au jour près : l'arbre reste affiché tel qu'il est ce jour-là. La simulation, qui avance par
  semaines, est ramenée à la fin de la semaine en cours si elle avait pris de l'avance (copie de l'état gardée à
  chaque paquet). Les pousses de la semaine existent déjà dans la simulation, même pas encore visibles : pincer ou
  couper une pousse en train de s'allonger marche donc au jour près. Les outils de taille, de fil, le
  rempotage… ne marchent qu'en pause ; toucher un outil met en pause.
- Sauvegarde automatique à chaque pause et tous les trois mois de jeu.

## Vérification
- Banc : temps de la copie d'état et du retour en arrière par espèce (objectif : quelques ms) ; mêmes résultats en
  jouant d'un coup ou avec des pauses.
- Dessin Python de quelques images d'une poussée (tige et feuilles à 0, 1, 2 et 3 semaines) avant d'envoyer.

## Limites prévues
- Sur un très gros arbre (dessin de 1 à 2 s), la mise en pause peut prendre jusqu'à ce temps avant que l'arbre
  redessiné à la bonne semaine s'affiche.
