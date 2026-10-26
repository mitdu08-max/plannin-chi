# Corrections appliquées

Suivi des corrections issues de l'audit (`ANALYSE.md`). Chaque point de l'audit
est repris avec son statut et l'endroit du code concerné.

## P0 — bloquants

| # | Correction | Fichier |
|---|---|---|
| 1 | **Permissions réellement demandées.** `requestPermissions()` demande `POST_NOTIFICATIONS` **et** les alarmes exactes, et il est appelé au premier import (et depuis les paramètres). Un message explique quoi faire en cas de refus. | `notification_service.dart`, `import_screen.dart`, `settings_screen.dart` |
| 2 | **Durée de garde positive.** `duration` gère le passage à minuit (19h → 7h = 12h) et renvoie 0 si les horaires sont identiques. `startDateTime` / `endDateTime` / `isOvernight` ajoutés. | `night_shift.dart` |
| 3 | **Parsing vérifié.** Chaque ligne est contrôlée (`cellules lues` vs `jours du mois`) ; tout écart produit un avertissement affiché dans l'aperçu d'import. Le mois n'est plus jamais inventé : s'il est illisible, il est demandé. Suppression des `stopKeywords` codés en dur (« NOVEMBRE 2026 », …). | `pdf_parser_service.dart`, `import_screen.dart` |
| 4 | **Plus de notification annuelle fantôme.** Suppression de `matchDateTimeComponents` (et de `uiLocalNotificationDateInterpretation`, déprécié en v18). | `notification_service.dart` |
| 5 | **Import idempotent.** Les gardes du mois sont supprimées avant réécriture (`deleteNightShiftsForMonth`), le message de succès indique combien ont été remplacées. | `database_service.dart`, `import_screen.dart` |
| 6 | **Données nominatives retirées du dépôt.** Les 2 PDF et la capture WhatsApp ne sont plus suivis, et `*.pdf` / captures sont ignorés à la racine. ⚠️ L'historique Git les contient encore : voir `README.md` (`git filter-repo`). | `.gitignore` |

## P1 — fonctionnel

| # | Correction | Fichier |
|---|---|---|
| 7 | **Identité stable** : plus de `userId` `user_<timestamp>` ; l'`userId` existant est conservé, sinon il prend la valeur du trigramme/nom (même clé que les gardes). | `settings_screen.dart` |
| 8 | **Trigramme ou nom** accepté (2 à 12 caractères, champ renommé « Trigramme / nom sur le planning ») au lieu d'un trigramme strictement égal à 3. | `settings_screen.dart` |
| 9 | **Filtre des statistiques élargi** : `agentId` **ou** trigramme, comme dans le calendrier. | `statistics_screen.dart` |
| 10 | **Week-ends calculés par dates** : le dimanche est cherché par date réelle, un samedi 31/10 + dimanche 01/11 compte donc comme week-end complet. | `statistics_service.dart` |
| 11 | **Aucun mois deviné** + liste d'agents extensible (détection générique des agents inconnus, `AppConstants.knownAgentNames`). | `pdf_parser_service.dart`, `app_constants.dart` |
| 12 | **Ajout / modification de garde implémentés** (horaires, collègues, congés), marqués `isManualOverride`, avec replanification des rappels ; « Aller à l'import » navigue réellement. | `calendar_screen.dart` |
| 13 | **`print()` supprimés** (dont ceux qui affichaient tout le planning nominatif) ; `debugPrint` en mode debug uniquement. | `pdf_parser_service.dart`, `ocr_parser_service.dart`, services |
| 14 | **Code OCR mort supprimé** (`parsePlanningImageBytes` aux métadonnées codées en dur) ; `TextRecognizer` réutilisé et libérable. | `ocr_parser_service.dart` |
| 15 | **Heures cohérentes** : les statistiques somment la durée réelle des gardes et ne retombent sur `shiftDurationHours` que si la saisie est incomplète. | `statistics_service.dart` |
| 16 | **Import des congés simplifié** : un jour ne peut pas être à la fois garde et congé, plus de condition `&&`/`||` ambiguë. | `import_screen.dart` |

## P2 — dette technique

| # | Correction | Fichier |
|---|---|---|
| 17 | Dépendances mortes retirées : `go_router`, `permission_handler`, `shared_preferences`, `uuid`, `android_alarm_manager_plus`, `riverpod_annotation` / `riverpod_generator`. | `pubspec.yaml` |
| 18 | — | plateformes non Android conservées (web impossible à compiler, cf. `dart:io`) |
| 19 | Code mort supprimé : `createNightShiftsFromParsedData` (×2), providers inutilisés, méthodes de parsing obsolètes. | `lib/` |
| 20 | Contrastes corrigés dans l'aperçu (carte « congés » en orange translucide sur thème sombre, code visible en libellé). | `import_screen.dart` |
| 21 | Descriptions d'usage caméra / photothèque ajoutées (`Info.plist`), sinon l'app iOS plante à l'import photo. | `ios/Runner/Info.plist` |
| 22 | **Sauvegarde Android désactivée** (`allowBackup="false"`, `fullBackupContent="false"`). | `AndroidManifest.xml` |
| 23 | Argument déprécié de `flutter_local_notifications` retiré (préparation v19). | `notification_service.dart` |
| 24 | Licence Syncfusion documentée. | `README.md` |

## Qualité

- **Tests** : 3 fichiers, jeux de données **synthétiques** (aucun nom réel) —
  parseur (8 cas), durée des gardes (5 cas), statistiques (6 cas).
  L'ancien `widget_test.dart` a été supprimé : il ne pouvait pas passer sans
  plugin `path_provider`.
- **CI** : `.github/workflows/ci.yml` → `flutter analyze` + `flutter test` sur
  chaque push.
- **Documentation** : `README.md` réécrit (fonctionnalités, build, architecture,
  compromis du parseur, données personnelles, limites).

## Vérifications effectuées

Le parseur corrigé a été **rejoué sur les deux plannings de référence** (avant
retrait du dépôt), avec une vérité terrain reconstruite indépendamment par
coordonnées de mots :

| Mois | Agents | Nuits retrouvées | Congés | Avertissements |
|---|---|---|---|---|
| Novembre 2026 | 13 | 120/120 (100 %) | 22/22 | 1 (ligne `WICKER` : 31 cellules pour 30 jours — anomalie réelle du PDF) |
| Octobre 2026 | 13 | 125/125 (100 %) | 15/15 | aucun |

Le garde-fou a donc été validé sur un cas réel : la ligne `WICKER` de novembre
compte 31 cellules dans le PDF d'origine, ce qui aurait décalé la lecture silencieusement ; elle est désormais signalée dans l'aperçu.

> Non vérifié : la compilation et l'exécution de l'application (SDK Flutter
> absent de l'environnement d'audit). Lancer `flutter analyze` et `flutter test`
> localement, puis `flutter pub get` pour régénérer `pubspec.lock` après le
> nettoyage des dépendances.
