# Planning CHI — Night Shift Planning

Application **Android**, **100 % hors-ligne**, pour suivre ses gardes de nuit et
celles de son équipe : import du planning d'équipe (PDF ou capture d'écran),
calendrier, statistiques et rappels avant chaque prise de poste.

> Aucun compte, aucun serveur, **aucune permission réseau** : les données
> restent sur le téléphone (Hive).

---

## Fonctionnalités

| Domaine | Détail |
|---|---|
| **Accueil** | Prochaine garde (compte à rebours, horaires, collègues), 7 jours à venir, chiffres du mois |
| **Import** | PDF (extraction de texte) ou photo / capture d'écran (OCR local ML Kit) |
| **Analyse** | Extraction des nuits de l'utilisateur, des congés (CA / CET / CFR) et des collègues en poste chaque nuit |
| **Contrôle qualité** | Chaque ligne du planning est vérifiée : si une ligne n'a pas le bon nombre de cellules, un avertissement bloque la validation silencieuse |
| **Calendrier** | Vue mensuelle, détail du jour (horaires, durée réelle, collègues), congés, ajout / modification / suppression manuelle |
| **Statistiques** | Heures cumulées (mois / année), nuits par jour de semaine, week-ends complets / demi / repos, binômes les plus fréquents |
| **Notifications** | Rappel paramétrable avant chaque garde, avec les prénoms des collègues de service |
| **Apparence** | Thème nuit (défaut) / jour / système, persisté |
| **Confidentialité** | Base locale non synchronisée, sauvegarde Android désactivée (`allowBackup=false`) |

## Design

Interface « Nocturne néon » : noir absolu, grille de moniteur, cyan et lime,
angles vifs et chiffres en monospace — pensée pour être lue la nuit, dans une
salle éteinte. Thème nuit (défaut) et jour, navigation maison, écran d'accueil
centré sur la prochaine garde.

Palette, composants et détail écran par écran : [`DESIGN.md`](DESIGN.md).
Aperçus statiques (HTML, sans compilation Flutter) :
[`docs/design-neon.html`](docs/design-neon.html),
[`docs/design-directions.html`](docs/design-directions.html) (les cinq
directions explorées).

## Démarrage

```bash
flutter pub get
flutter run                # appareil/émulateur Android
flutter test               # tests unitaires
flutter analyze            # analyse statique
flutter build apk --release
```

Prérequis : Flutter stable (Dart ≥ 3.12), Android SDK, Java 17.
`minSdk` suit la version Flutter par défaut ; l'OCR ML Kit nécessite un
appareil Android doté des services Google Play.

### Autorisations Android

- `POST_NOTIFICATIONS` : demandée **au premier import** (Android 13+).
- `SCHEDULE_EXACT_ALARM` : demandée en même temps ; en cas de refus, l'appel
  se replie automatiquement sur une alarme inexacte.
- Pas de permission `INTERNET`.

## Architecture

```
lib/
├─ main.dart                  démarrage, thème nuit/jour, écran de lancement
├─ theme/app_theme.dart       palette, typographie, styles Material 3
├─ widgets/app_widgets.dart   composants partagés (cartes, boutons, avatars…)
├─ models/                    TeamMember, NightShift, UserConfig (Hive)
├─ providers/                 Riverpod : accès base, thème, onglet actif
├─ screens/                   accueil, calendrier, statistiques, réglages, import
└─ services/
   ├─ database_service.dart   Hive (3 box), purge par mois, upsert équipe
   ├─ pdf_parser_service.dart extraction PDF + analyse texte commune
   ├─ ocr_parser_service.dart ML Kit -> même analyseur
   ├─ statistics_service.dart calculs purs, testés
   └─ notification_service.dart rappels locaux (alarmes exactes)
```

### À propos de l'analyse du planning

Le parseur lit une grille « 1 ligne = 1 agent, 1 cellule = 1 jour ». Comme un
PDF et un OCR ne fournissent pas la même géométrie, la position des cellules
n'est pas utilisée : les codes sont lus dans l'ordre de la ligne. **Conséquence
assumée** : si une cellule disparaît, la ligne se décale. C'est pourquoi le
nombre de cellules de chaque ligne est contrôlé (`totalDays`) et affiché dans
l'aperçu d'import. Une ligne incomplète est signalée mais reste importable
après validation explicite.

Le mois n'est **jamais deviné** : si le titre du document est illisible, il est
demandé à l'utilisateur.

## Tests

```bash
flutter test
```

- `test/pdf_parser_test.dart` — parseur : extraction, agents inconnus, lignes
  incomplètes, mois absent / forcé, codes `F EXT`, lignes de continuation.
- `test/night_shift_test.dart` — durée des gardes de nuit (minuit), horaires
  identiques, calculs de dates.
- `test/statistics_service_test.dart` — heures, week-ends à cheval sur deux
  mois, binômes.

CI : `.github/workflows/ci.yml` (analyse + tests sur chaque push).

## Données personnelles

Les plannings réels contiennent des **noms de soignants** : ils ne sont pas
versionnés (`*.pdf`, captures d'écran ignorées à la racine). L'historique Git du
dépôt a été nettoyé en conséquence (`git filter-repo`) : aucun de ces documents
n'y figure plus. Les tests utilisent uniquement des jeux de données
synthétiques.

## Licence

Code sous licence MIT. La dépendance `syncfusion_flutter_pdf` est utilisée sous
**Syncfusion Community License** (gratuite pour un usage individuel / une
société de moins de 1 M$ de chiffre d'affaires et 5 développeurs maximum) ; voir
les conditions de l'éditeur si l'application est redistribuée.

## Limites connues

- Le parsing reste sensible aux documents très dégradés (capture de travers,
  colonnes fusionnées) : les avertissements de l'aperçu sont le garde-fou.
- Une seule équipe / un seul utilisateur par appareil.
- Base Hive non chiffrée (les données ne quittent pas l'appareil et la
  sauvegarde Android est désactivée).
