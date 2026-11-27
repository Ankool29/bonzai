# Bonzai — notes pour Claude

Jeu mobile de culture de bonsaï : cultiver, tailler, ligaturer, exposer et vendre.
Cœur du projet : l'arbre est entièrement simulé (pousse selon l'espèce, réaction à la taille et au fil).
Godot 4.7, GDScript, cible mobile (Galaxy S25 Ultra). Le joueur parle français : réponses, commentaires et docs en français.

## Façon de travailler
- Applique la skill `ponytail` sur toute tâche de code : plus petit changement qui règle le problème.
- Aucun code sans cahier d'étape validé par le joueur.
- Ne lis que les fichiers utiles à la tâche. Commence par ce plan, pas par une exploration du dépôt.
- Réponses courtes : ce qui a changé et comment le tester, sans récapituler chaque étape.
- Nouvelle espèce : d'abord une recherche botanique approfondie (pousses de l'année, entre-nœuds, phyllotaxie, ramification, poussées, réaction à la taille), sources citées dans le cahier d'étape et la fiche espèce, puis vérification dessinée avant d'envoyer.
- Mets à jour `docs/A_CORRIGER.md` quand un défaut connu est corrigé ou découvert.

## Plan du code
- `scripts/tree_sim.gd` (`TreeSim`) : simulation de l'arbre (segments, bourgeons, grille d'ombre, poussées, élagage naturel, taille, ligature). Valeurs de l'orme par défaut, remplacées par une fiche espèce.
- `scripts/species.gd` (`Species`) : fiches espèces (orme, pin, érable).
- `scripts/tree_mesh.gd` (`TreeMesh`) : bois (anneaux continus, fourches en Y), feuilles d'orme et d'érable, aiguilles de pin en géométrie, dates d'animation par sommet, matériaux cel shading.
- `scripts/garden.gd` (`Garden`) : jardin (tous les arbres, chacun sa date ; seul l'arbre ouvert pousse), sauvegarde dans `user://` (un index + un fichier par arbre).
- `scripts/main.gd` : scène (soleil et ombres, pot), caméra au doigt, sélection, repère de coupe, outils de taille et fil, boutons ; avance du temps (calcul en fil de calcul puis animation). Scène : `scenes/main.tscn`.
- `shaders/toon.gdshader` (cel shading, motifs d'écorce et de terre), `shaders/outline.gdshader` (contours), `shaders/anim.gdshaderinc` (animation de la pousse à partir des dates portées par les sommets). Icônes d'interface : `ui/icons` (PixelLab). Ne jamais mettre la clé PixelLab dans le dépôt.

## Ailleurs
- `docs/CONCEPTION.md` : décisions de conception. `docs/ETAPEx.md` : cahiers d'étape. Lis seulement le cahier de l'étape en cours.

## Test
Le joueur teste sur téléphone : `git pull` puis ouverture dans l'éditeur Godot Android.
Pas de Godot dans l'environnement de Claude : vérifie la syntaxe GDScript à la relecture.
