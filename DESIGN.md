# Refonte visuelle — identité « Aurora »

Nouveau design complet de l'application : thème, composants, navigation,
nouvel écran d'accueil et icône. Aucune logique métier n'a été modifiée (le
parseur, la base et les notifications sont inchangés sur le fond).

---

## 1. Intention

L'ancienne interface était un thème sombre Material 3 appliqué par défaut, avec
des couleurs codées en dur (`Colors.red`, `Colors.green`, `shade700`…), un
mélange de `Card` + verre dépoli + `BackdropFilter` coûteux, et quatre écrans
sans hiérarchie visuelle commune.

La refonte vise trois choses :

1. **Lire l'essentiel en 3 secondes** : la prochaine garde, à quelle heure, avec qui.
2. **Une identité propre** : dégradé « aurore » (indigo → bleu → menthe) qui
   distingue la nuit (indigo), le repos (gris) et les congés (menthe).
3. **Moins de bruit** : typographie hiérarchisée, une seule famille de cartes,
   animations courtes, zéro couleur en dur dans les écrans.

## 2. Design system

### Couleurs (`lib/theme/app_theme.dart`)

| Rôle | Nuit | Jour |
|---|---|---|
| Fond | `#070B14` | `#F4F6FC` |
| Surface | `#101827` | `#FFFFFF` |
| Surface haute | `#16213A` | `#FFFFFF` |
| Bordure | `#25314B` | `#E1E7F3` |
| Texte | `#E9EFFB` | `#111A2C` |
| Texte secondaire | `#93A4C3` | `#5E6E8A` |
| Primaire | `#7C8CFF` | `#3D5BE0` |
| Secondaire | `#37D9C0` | `#0F9E8A` |
| Tertiaire | `#FFB454` | `#E08A00` |

Couleurs sémantiques, identiques dans les deux modes :

- **Garde de nuit** : dégradé `#6C5CFF → #3E8BFF`
- **Congés** : dégradé `#12B886 → #37D9C0`
- **Repos** : `#64748B`
- **Succès / alerte / erreur** : `#2FBF71` / `#F5A524` / `#F2555A`

Plus aucune valeur hexadécimale n'est écrite dans `lib/screens/` : tout passe
par `AppColors`.

### Typographie

Échelle resserrée (28 / 22 / 19 / 17 / 15 / 13 / 12,5), `letterSpacing` négatif
sur les grands titres, poids 800 pour les chiffres clés. Les valeurs métier
(durées, compteurs) sont toujours en gras, les libellés en `bodySmall` gris.

### Formes et espacement

- Rayons : 12 / 18 / 24 / 32, pastilles 999.
- Espacements : 6 / 12 / 16 / 24 / 32 (`AppSpacing`).
- Cartes : bord 1 px `outline`, fond `surface`, ombre douce (jamais plus de
  28 px de flou), rayon 24.

### Composants (`lib/widgets/app_widgets.dart`)

| Composant | Usage |
|---|---|
| `AuroraBackground` | deux halos radiaux discrets derrière chaque écran |
| `SurfaceCard` | carte unique (fond, bord, ombre, `onTap`, variante `gradient` + `glow`) |
| `GradientButton` | action principale en dégradé |
| `MetricCard` | chiffre clé + libellé + icône teintée, apparition animée |
| `SectionHeader` | titre de section + action à droite |
| `Pill` | statut compact (nb de collègues, code de congé) |
| `InitialsAvatar` | avatar à initiales, couleur stable dérivée du nom |
| `EmptyState` | état vide / non configuré illustré |
| `StatusLegend` | légende nuit / congés / repos |
| `FrostedPanel` | verre dépoli, utilisé ponctuellement (plus de blur plein écran) |

## 3. Navigation

`NavigationBar` Material 3, 4 onglets, libellés courts :

`Accueil · Calendrier · Stats · Réglages`

- `IndexedStack` conserve l'état de chaque onglet (le calendrier ne se réinitialise plus).
- Barre séparée du contenu par un filet, `extendBody` pour un rendu bord à bord.
- L'import n'est plus un onglet : c'est une **action** (bouton « Importer » sur
  l'accueil, entrée dans les réglages), ouverte en pleine page. C'est un
  parcours ponctuel, pas une destination permanente.

## 4. Écrans

### Accueil (`dashboard_screen.dart`) — **nouveau**

- Salutation datée + avatar du profil.
- **Carte « Prochaine garde »** en dégradé : compte à rebours (Ce soir /
  Demain / Dans X jours), date longue, horaires, durée réelle, avatars empilés
  des collègues de service.
- **Bandeau des 7 prochains jours** : un point de couleur par jour (nuit,
  congé), aujourd'hui cerclé.
- Trois `MetricCard` : nuits du mois, heures cumulées, week-ends complets.
- Deux actions : « Importer » (dégradé) et « Mes stats ».
- Liste des 4 prochaines gardes.

### Calendrier

- Fond aurore, calendrier sur carte, cellule-jour unifiée (dégradé nuit /
  congés, contour primaire pour aujourd'hui, halo pour la sélection).
- Légende des statuts sous le calendrier.
- Détail du jour repensé en verre léger : badge de statut, bloc horaires avec
  durée réelle, équipe de la nuit, actions Modifier / Supprimer, ou
  « Ajouter une garde ».
- Édition de garde : sélecteur d'horaires, collègues en `FilterChip`, type
  d'absence (CA / CET / CFR / repos).

### Statistiques

- Sélecteur de période, cartes `MetricCard`, histogramme par jour de semaine
  avec barres en **dégradé** (week-ends distingués), tooltip arrondi,
  analyse des week-ends, binômes les plus fréquents.

### Réglages

- Sections étiquetées : Profil, **Apparence**, Horaires, Rappels, Planning, À propos.
- **Nouvelle section Apparence** : Nuit / Jour / Auto, persistée dans
  `UserConfig.darkModeEnabled` et appliquée instantanément (nouvelles clés :
  `AppTheme.light()`, `AppTheme.dark()`, `themeModeProvider`).
- Le mode nuit reste le défaut (métier de nuit), mais il n'est plus imposé.

### Import

- En-tête en carte dégradée avec profil actif et bouton « Changer ».
- Trois options d'import en cartes tactiles (PDF, galerie, appareil photo).
- Aperçu : bandeau d'avertissement orange si une ligne du planning est
  incomplète, cartes de nuit et de congé lisibles sur fond sombre.

### Démarrage

Écran de lancement en dégradé aurore (logo + indicateur 2,4 px) au lieu d'un
simple spinner gris ; écran d'erreur d'initialisation mis en forme.

## 5. Icône et branding

- Nouvelle icône : croissant de lune blanc sur fond nuit, avec une aurore
  indigo → bleu → menthe en partie basse.
- Déclinée sur Android (5 densités), iOS (15 tailles), macOS (7 tailles) et
  web (192/512 + maskables avec zone de sécurité de 78 %).
- Source vectorielle conservée : `assets/branding/app_icon_1024.png`.
- L'ancien `assets/images/logo.png` (flamme rouge/noire, 256 Ko), incompatible
  avec la palette, a été supprimé.

## 6. Performance et accessibilité

- Suppression des `BackdropFilter` plein écran au profit de dégradés (un seul
  blur léger, ponctuel).
- Cartes sans elevation GPU : bord + ombre simple.
- Contrastes : texte principal ≥ 12:1 sur fond nuit, secondaire ≥ 4,6:1.
- Toutes les zones tactiles principales ≥ 48 px ; boutons à 52 px de haut.
- `MediaQuery` respectée : textes en `bodySmall` redimensionnables, pas de
  largeur fixe en dur (sauf pastilles < 44 px).
- Animations courtes (180–450 ms) et sans rebond.

## 7. Ce qui n'a pas changé

Modèle de données, base Hive, parseur PDF/OCR, calculs statistiques,
notifications : **inchangés** par la refonte (seuls la présentation et le
câblage de navigation ont bougé). Les 19 tests unitaires restent valables.
