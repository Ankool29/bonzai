# Bonzai — notes pour Claude

Jeu mobile de culture de bonsaï : cultiver, tailler, ligaturer, exposer et vendre.
Cœur du projet : l'arbre est entièrement simulé (pousse selon l'espèce, réaction à la taille et au fil).
Godot 4.7, GDScript, cible mobile (Galaxy S25 Ultra). Le joueur parle français : réponses, commentaires et docs en français.

## Façon de travailler
- Applique la skill `ponytail` sur toute tâche de code : plus petit changement qui règle le problème.
- Aucun code sans cahier d'étape validé par le joueur.
- Ne lis que les fichiers utiles à la tâche. Commence par ce plan, pas par une exploration du dépôt.
- Réponses courtes : ce qui a changé et comment le tester, sans récapituler chaque étape.
- Mets à jour `docs/A_CORRIGER.md` quand un défaut connu est corrigé ou découvert.

## Plan du code
- `scripts/tree_sim.gd` (`TreeSim`) : simulation de l'arbre (segments, bourgeons, grille d'ombre, poussées, élagage naturel, taille). Paramètres de l'espèce en tête de fichier.
- `scripts/tree_mesh.gd` (`TreeMesh`) : maillage de l'arbre (cylindres, couleur selon l'âge, surbrillance).
- `scripts/main.gd` : scène, caméra au doigt, sélection et coupe, boutons. Scène : `scenes/main.tscn`.

## Ailleurs
- `docs/CONCEPTION.md` : décisions de conception. `docs/ETAPEx.md` : cahiers d'étape. Lis seulement le cahier de l'étape en cours.

## Test
Le joueur teste sur téléphone : `git pull` puis ouverture dans l'éditeur Godot Android.
Pas de Godot dans l'environnement de Claude : vérifie la syntaxe GDScript à la relecture.
