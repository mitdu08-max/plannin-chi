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
| **Import** | PDF texte, PDF scanné (1 à 10 pages), photo ou capture d'écran ; OCR ML Kit local sur Android |
| **Analyse** | Extraction des nuits de l'utilisateur, des congés (CA / CET / CFR) et des collègues en poste chaque nuit |
| **Contrôle qualité** | Pour l'OCR : confirmation du mois et vérification de chaque jour des lignes importées ; les cases illisibles restent inconnues jusqu'à correction |
| **Calendrier** | Grande grille mensuelle et fiche du jour vitrée (horaires, durée réelle, collègues), navigation mois/semaine, ajout / modification / suppression manuelle |
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
   ├─ pdf_parser_service.dart extraction PDF + analyse texte
   ├─ pdf_image_renderer.dart rendu local des pages PDF sur Android
   ├─ ocr_parser_service.dart OCR ML Kit et coordonnées des mots
   ├─ positioned_planning_parser.dart repérage des colonnes et cases OCR
   ├─ planning_day_review.dart état de la vérification manuelle
   ├─ statistics_service.dart calculs purs, testés
   └─ notification_service.dart rappels locaux (alarmes exactes)
```

### À propos de l'analyse du planning

Le parseur lit une grille « 1 ligne = 1 agent, 1 cellule = 1 jour ». Pour les
images et PDF scannés, il utilise les coordonnées OCR et les numéros en tête
de colonnes pour associer les codes aux jours. Les cases absentes ou ambiguës
restent « ? » : l'utilisateur doit les renseigner et confirmer avoir comparé
tous les jours au document, car même une case reconnue peut être erronée.
Les codes CS et FC sont également à préciser manuellement ; seuls CA, CET et
CFR sont enregistrés comme congés. La page originale est accessible avec zoom
pendant cette vérification. Si les colonnes ne sont pas assez lisibles, toutes
les cases doivent être saisies manuellement.

L'utilisateur confirme ou corrige toujours le mois et l'année pour l'OCR. Il
choisit sa ligne, puis peut importer seulement son planning ou toutes les
lignes détectées ; dans ce dernier cas chaque ligne nécessite une vérification.
Un nom mal reconnu peut être associé à une personne déjà enregistrée. L'import
personnel ne récupère pas les collègues. Toute donnée existante des agents et du mois
concernés est remplacée uniquement après confirmation ; les autres mois sont
conservés. L'application ne précharge plus automatiquement les anciens
plannings d'octobre et novembre au démarrage. Cette modification ne supprime
pas les entrées déjà présentes : vérifiez les données préchargées auparavant.
Importez un mois par fichier : les pages d'un PDF multipage doivent
concerner le même mois. Le PDF original est préférable à une capture réduite.
Pour l'OCR d'un PDF, des images temporaires sont créées dans le cache privé de
l'application et supprimées en fin d'import ; après une interruption, Android
ou le prochain rendu PDF peut également nettoyer ces fichiers.

Pour un PDF contenant du texte sélectionnable, la lecture reste séquentielle :
une case manquante peut décaler les suivantes. Un avertissement est affiché
pour les lignes incomplètes et l'aperçu doit être vérifié.

## Tests

```bash
flutter test
```

- `test/pdf_parser_test.dart` — parseur : extraction, agents inconnus, lignes
  incomplètes, mois absent / forcé, codes `F EXT` et OCR positionné.
- `test/positioned_planning_parser_test.dart`, `test/planning_day_review_test.dart`
  et `test/ocr_review_dialog_test.dart` — colonnes OCR, cases inconnues,
  conflits et vérification manuelle.
- `test/calendar_screen_test.dart` — fiche du jour, actions, données mises à
  jour, navigation et petits écrans.
- `test/database_initialization_test.dart` — conservation des entrées au
  démarrage sans préchargement automatique.
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
