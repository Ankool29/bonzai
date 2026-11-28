# Étape 31 : genévrier de Chine, Shimpaku (Juniperus chinensis var. sargentii)

Validé par le joueur le 28/11/2026. Fait.

## Botanique (sources)
- Deux sortes de feuilles. Adulte : écailles de 1 à 3 mm, opposées par paires croisées (4 rangs), plaquées sur le
  rameau, qui forme un cordon vert de 0,8 à 1,5 mm de large. Juvénile : aiguilles de 4 à 12 mm, par paires ou par
  trois, écartées, pointues, avec deux bandes pâles (Ruhr-Universität Bochum, Cupressaceae ; University of
  Illinois, Woody Plants ; Gymnosperm Database).
- Les aiguilles juvéniles dominent chez le jeune plant et sur les rameaux à l'ombre ; elles reviennent sur un arbre
  adulte après un stress : taille trop forte, sécheresse, racines trop coupées, pincement (Wikipédia, Juniper ;
  Shohin Europe ; Björn Bjorholm ; Bonsai Nut).
- Le rameau reste vert et feuillé plusieurs années, puis brunit quand ses écailles meurent (Virginia Tech
  Dendrology). La pousse continue toute la saison, contrairement au pin (UNH Extension).
- Pas de repousse sur le bois nu : un rameau rabattu sous son feuillage reste nu ou meurt ; le rebourgeonnage sur
  bois de plus de quelques années est rare et imprévisible (Penn State / ask.extension.org ; Gardener's Path ;
  Bonsai Empire).
- Bonsaï : ne pas pincer (cela affaiblit et provoque le feuillage juvénile) ; laisser pousser au printemps, puis
  couper aux ciseaux, à leur base, les pousses qui s'allongent hors du coussin, deux ou trois fois dans la saison ;
  ne jamais retirer plus de 25 à 30 % du feuillage à la fois (Bonsai Bark ; Shohin Europe ; Björn Bjorholm ;
  Bonsai Nut).
- Écorce gris-brun à brun-rouge, fissurée en long, qui se détache en fines lanières (Gymnosperm Database ;
  NC State Extension).

## 31a : l'espèce
- Fiche `Species.JUNIPER` : bourgeons opposés (paires croisées), entre-nœuds courts (8 mm), pousse lente mais
  continue : poussées aux semaines 14, 19, 24 et 30 (une poussée après le bilan de fin d'été, semaine 35, vidait
  les réserves) ; ombre progressive (en tout-ou-rien, les coussins serrés s'étouffaient selon la graine) ; feuillage vivant 4 ans (`leaf_years` 4) ; bourgeons
  latents qui meurent avec le feuillage (`bud_life` 4 ans) ; peu de rejets.
- Feuillage d'écailles (`leaf_shape` 3) : chaque entre-nœud feuillé porte de petits cordons verts par paires
  croisées, au dessin d'écailles. Vert vif au printemps, plus sombre en vieillissant. Le vieux bois sans feuillage
  est nu.
- Écorce brun-rouge en lanières (nouveau motif dans `toon.gdshader`).

## 31b : la taille
- Couper sous le feuillage : la branche reste nue (rien ne repart sur le bois sans écailles).
- Pincer un genévrier : pas de raccourcissement des entre-nœuds ; il s'affaiblit et passe en feuillage juvénile.
- Feuillage juvénile : après un stress (plus de 30 % du feuillage retiré en une saison, plus d'un tiers des racines
  coupées, pincement), les pousses de l'année suivante sortent en aiguilles par trois, piquantes et bleutées. Le
  feuillage redevient adulte si l'arbre est laissé tranquille une saison.
- Repère de coupe (comme le pin) : vert = coupe dans le feuillage ; orange = coupe qui dépasse 30 % du feuillage
  (feuillage juvénile à prévoir) ; rouge = plus de feuillage en dessous (la branche restera nue).

## Vérification
- Banc : l'espèce est mesurée avec les autres ; export du genévrier à 6 ans (segments, feuillage) et dessin Python
  avant d'envoyer : port, cordons d'écailles, aiguilles juvéniles après une forte taille.

## Hors de cette étape
- Jin et shari (bois mort sculpté), greffe.

## Résultats (banc)
- Sans taille, pot de 8 L, à 4 ans en été : 1087 entre-nœuds, 20 cm, santé 0,99 ; environ 30 cm à 6 ans.
- Forte taille au printemps (45 % du feuillage) : les 22 pousses de l'année sont juvéniles. Pincement : 132 pousses
  juvéniles sur 226. Sans taille : aucune.
- Robustesse : 4 graines, de 2100 à 4000 entre-nœuds et 25 à 29 cm à 6 ans, santé 1.
- 8 ans : 4900 entre-nœuds, 0,23 s de simulation par an et 0,7 s de dessin sur le serveur du banc.
- Dessin de vérification : `docs/genevrier_verif.png`.
