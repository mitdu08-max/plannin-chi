# Refonte visuelle — identité « Nocturne néon »

Deuxième refonte complète de l'interface : noir absolu, grille de moniteur,
cyan et lime, angles vifs, chiffres en monospace. Aucune logique métier n'a
bougé (parseur, base Hive, notifications, statistiques : inchangés).

> Direction choisie parmi cinq propositions — voir `docs/design-directions.html`
> et l'aperçu statique `docs/design-neon.html` (ouvrir à la racine du dossier
> `docs/` via un petit serveur local, ou consulter la preview HTML).

---

## 1. Intention

L'application est utilisée la nuit, dans une chambre ou une salle de repos
éteinte. L'interface doit donc :

1. **S'allumer comme un scope** : fond noir absolu (`#04060B`), pas de gris
   bleuté, lumière uniquement là où il y a de l'information.
2. **Répondre en une seconde** : l'heure de la prochaine garde est le plus gros
   élément de l'écran, en lime lumineux, en monospace.
3. **Avoir une langue technique cohérente** : filets d'un pixel, équerres aux
   angles des cartes importantes, libellés en capitales espacées, valeurs en
   mono tabulaire. Rien de décoratif, tout est repère.

## 2. Design system

### Couleurs (`lib/theme/app_theme.dart`)

| Rôle | Nuit (défaut) | Jour |
|---|---|---|
| Fond | `#04060B` | `#EDF2F5` |
| Surface | `#080C13` | `#FFFFFF` |
| Surface haute | `#0C121B` | `#F4F8FA` |
| Filet | `#16232E` | `#CBD9E0` |
| Texte | `#E6FCFF` | `#06121A` |
| Texte secondaire | `#5E7C8C` | `#5A7280` |
| Primaire (cyan) | `#00E5FF` | `#007A8C` |
| Secondaire (lime) | `#B6FF3B` | `#4F7A00` |
| Tertiaire (ambre) | `#FFC857` | `#B26A00` |

Couleurs sémantiques :

- **Garde de nuit** : cyan → teal profond (`#0089A6 → #013A47`), assez sombre
  pour porter du texte blanc.
- **Congés** : olive → vert sombre (`#4C6B00 → #223300`), et lime pour les
  accents.
- **Repos** : `#3C4E5A`.
- **Alerte / erreur / succès** : `#FFC857` / `#FF5470` / `#B6FF3B`.

Le dégradé signature `AppColors.neon` (cyan → lime) sert aux boutons et aux
traits lumineux — **jamais** sous du texte blanc (texte encre `#04060B` obligatoire).

### Typographie (`AppFonts`)

- Deux registres : sans-serif serré pour lire, **monospace tabulaire** pour
  mesurer (`AppFonts.monoText` / `AppFonts.tag`).
- Les libellés courts sont en capitales avec `letterSpacing` 1,2 à 2,2.
- Échelle : 38 / 30 / 26 / 23 / 20 / 17 / 15,5 / 14 / 12.
- Chiffres clés : jusqu'à 34 px (heure de garde), 25 px (`MetricCard`),
  18 px (numéro de jour dans les listes).

> La famille `monospace` est résolue par le moteur sur Android ; ailleurs,
> `AppFonts.monoFallback` (Roboto Mono, Menlo, Courier…) prend le relais et, à
> défaut, les chiffres restent alignés grâce aux *tabular figures*.

### Formes et espacement

- Rayons : **3 / 4 / 6 / 8 / 12** — plus rien de rond au-delà de 12.
- Espacements : 6 / 12 / 16 / 24 / 32 (`AppSpacing`).
- Cartes : fond `surface`, filet 1 px `outline`, ombre noire très courte
  (14 px) ; variante `glow` = filet coloré + halo de 26 px.

### Composants (`lib/widgets/app_widgets.dart`)

| Composant | Usage |
|---|---|
| `NeonBackground` | noir + grille 26 px à 5 % + deux halos cyan/lime (`AuroraBackground` conservé en alias) |
| `SurfaceCard` | carte unique : filet, `onTap`, `gradient`, `glow`, **`brackets`** (équerres d'angle) |
| `TechLabel` | étiquette mono majuscule très espacée |
| `SectionHeader` | carré d'accent + titre mono + filet |
| `GradientButton` | bouton cyan → lime, texte encre, halo |
| `MetricCard` | libellé mono + valeur 25 px + icône teintée |
| `Pill` | pastille rectangulaire à filet coloré |
| `InitialsAvatar` | carré à filet, initiale en mono |
| `EmptyState` | cadre à halo, titre mono |
| `StatusLegend` | légende nuit / congés / repos (carrés, pas de ronds) |
| `FrostedPanel` | verre translucide ponctuel |
| `PulseDot` | point qui pulse (garde en cours) |
| `NeonNavBar` | barre de navigation maison (voir §3) |

## 3. Navigation

Barre maison `NeonNavBar` — pas de `NavigationBar` Material :

`ACCUEIL · CALENDRIER · STATS · RÉGLAGES`

- Libellés en capitales mono 8,5 px, onglet actif en lime avec un trait
  lumineux de 2 px au-dessus.
- `IndexedStack` : l'état de chaque onglet est conservé.
- L'import reste une **action** ponctuelle (bouton sur l'accueil, entrée dans
  les réglages), ouverte en pleine page.

## 4. Écrans

### Accueil (`dashboard_screen.dart`)

- Date en mono majuscule, salutation 26 px, `PulseDot` + « EN SERVICE CETTE
  NUIT » quand la garde est ce soir.
- **Carte « Prochaine garde »** : équerres cyan, halo, étiquette de compte à
  rebours (CE SOIR / DEMAIN / DANS 3 J) collée au coin supérieur droit,
  `19:00` en lime 34 px avec ombre lumineuse, flèche vers l'heure de fin,
  durée, puis collègues en pastilles à filet.
- **Bandeau 7 jours** : jours en mono, cases 38 px, aujourd'hui cerclé de cyan
  avec chiffre lime, barre de statut sous le chiffre.
- Trois `MetricCard` : nuits du mois (cyan), heures (ambre), week-ends (lime).
- Actions « Importer » (dégradé) et « Mes stats » (filet).
- Liste des prochaines gardes : filet vertical cyan de 2 px, numéro de jour en
  lime, horaires en mono.

### Calendrier

- Calendrier `table_calendar` sur carte : mois en mono, jours de la semaine en
  petites capitales, cases 46 px à angles vifs.
- Gardes en dégradé cyan/teal, congés en olive, aujourd'hui contour cyan,
  sélection en teal profond avec halo.
- Panneau de détail du jour : fond `surface` franchement plat (plus de verre
  blanc), badge de statut coloré, bloc horaires, équipe en pastilles carrées,
  actions Modifier / Supprimer.

### Statistiques

- Cartes `MetricCard`, histogramme `fl_chart` à barres fines (14 px, sommet
  carré), libellés d'axes en mono 8 px.
- Analyse des week-ends en trois blocs compacts (valeur mono 22 px).
- Classement des collègues : rangs `01…05` numérotés en mono, plus de médailles.

### Réglages

- Sections étiquetées (`PROFIL`, `APPARENCE`, `HORAIRES DE GARDE`, `RAPPELS`,
  `PLANNING`, `À PROPOS`) : icône cyan, libellé mono, filet qui complète la ligne.
- Sélecteur de thème Nuit / Jour / Auto en trois cases vives, persisté dans
  `UserConfig.darkModeEnabled` + `themeModeProvider`.
- Heures de garde affichées en mono lime 17 px.

### Import

- En-tête à équerres cyan avec halo, profil actif dans un cadre plat, bouton
  « Changer » en cyan.
- Trois options d'import : icône carrée à filet cyan, flèche discrète.
- Aperçu : cartes de nuit (numéro en mono cyan) et de congé (numéro ambre).

### Démarrage

Écran d'allumage : cadre cyan lumineux, croissant lime, « PLANNING CHI » en
mono espacé, « INITIALISATION… » et barre de chargement de 2 px.

## 5. Icône et branding

- Icône conservée (croissant sur fond nuit avec aurore en partie basse) :
  elle fonctionne avec le nouveau fond noir, le cyan restant la couleur du
  croissant.
- Déclinaisons : Android (5 densités), iOS (15 tailles), macOS (7), web
  (192/512 + maskables 78 %). Source : `assets/branding/app_icon_1024.png`.

## 6. Performance et accessibilité

- Aucun `BackdropFilter` plein écran ; la grille est un `CustomPaint` de
  lignes à 1 px, dessiné une fois.
- `PulseDot` : une seule animation courte (1,4 s), pas de répétition coûteuse
  ailleurs.
- Contrastes : texte principal ≥ 15:1 sur `#04060B`, secondaire ≥ 4,5:1 ; le
  cyan `#00E5FF` sur noir est à ~13:1.
- Zones tactiles ≥ 48 px ; boutons 48–50 px de haut.
- Le mode jour est volontairement plus doux (encre froide, accents assombris)
  pour rester lisible en plein soleil.

## 7. Ce qui n'a pas changé

Modèle de données, base Hive, parseur PDF/OCR
(`PdfParserService.parsePlanningText`), calculs statistiques et notifications :
**inchangés**. Les tests unitaires restent valables.
