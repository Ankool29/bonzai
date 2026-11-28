# À corriger

- Réglages de l'orme encore approximatifs (vérifiés seulement sur un portage Python de la simulation) : à ajuster après les essais sur téléphone.
- Le pincement densifie, mais n'a pas encore raccourci les entre-nœuds dans le portage Python : à surveiller.
- Étape 15 : pot à 6000 entre-nœuds pour les trois espèces (317 ms pour 3 arbres en 3000) : surveiller le temps de calcul.
- Étape 15 : la ride d'écorce dans l'angle des fourches n'est pas encore dessinée.
- Érable : sans taille, il pousse lentement (surtout des rameaux courts, 47 cm en 10 ans dans le portage Python) ; vigueur à régler après essais.
- Sauvegarde : chaque arbre garde la fiche espèce de sa mise en pot ; un réglage d'espèce changé plus tard ne s'applique qu'aux nouveaux arbres.
- Étape 16 : les rosettes de feuilles des rameaux courts sont seulement dessinées (elles ne font pas d'ombre dans la simulation).
- Étape 17 : tailler sans répit affaiblit l'arbre la première année puis il s'adapte (comme une haie) ; seul un arbre presque sans feuillage s'épuise et meurt. À durcir si c'est trop indulgent.
- Étape 17 : les arbres plantés avant l'étape 17 démarrent avec des racines égales à leurs anciennes réserves.
- Étape 19 : le raphia est posé automatiquement au-dessus de 5 mm (pas encore de bouton) ; pliage autour d'un seul axe par geste ; pas de hauban.
- Le gros bois mort ne tombe jamais tout seul.
- Pin : la coupe des chandelles donne des bourgeons, mais beaucoup ne partent pas en pousse d'été (vigueur faible) : à régler après essais.
- Étape 22 : le jardin a 9 places ; une ancienne sauvegarde de plus de 9 arbres garde les suivants invisibles. Pas d'éclairage de saison au jardin (chaque arbre a sa propre date).
- Corrigé : les vieux bourgeons dormants du bas du tronc (jusqu'à 8 ans) partaient chaque printemps sous un houppier plein ; passé deux hivers, ils ne partent plus que libérés par une coupe proche. Une coupe faite après la dernière poussée (semaine 30) perd sa levée de dominance à la fin de l'année.
- Étape 23a : le nebari décoratif est remplacé par les racines simulées. Les anciens arbres reçoivent une charpente reconstituée au chargement (épaisseurs données d'un coup). Le rempotage coupe d'abord les racines les plus éloignées (coupe à la main en 23b). Les racines ne s'animent pas pendant l'avance du temps (elles changent d'un coup en fin d'année).
- Étape 23b : réglage du cerne estimé sans mesure dans le jeu (objectif : 2-3 mm de diamètre par an en pot de 8 L libre, moins de 1 mm pour un bonsaï pincé) ; à ajuster avec l'affichage en mm. On ne peut quitter le mode racines qu'en replantant (même pot possible).
- Étape 24 : seuils du mekiri (4 entre-nœuds, santé 0,6) mesurés sur le portage Python, pas dans le jeu. Godot n'a pas pu être lancé dans l'environnement de Claude (refusé), les vérifications restent à la relecture.
- Étape 26 : le style encre lit l'image et la profondeur de la scène (moteur mobile) ; à surveiller sur la chauffe. Le fond est reconnu à la profondeur nulle (Z inversé, Godot 4.3+).
