# Analyse technique — « Planning CHI » (`night_shift_planning`)

> **Suivi : les corrections décrites ici ont été appliquées — voir [`CORRECTIONS.md`](CORRECTIONS.md).**
>
> Audit réalisé le 26/10/2026 sur la branche `arena/c31d1726-plannin-chi`, commit `a8bcb8f`.
> Périmètre : 5 366 lignes de Dart applicatif (`lib/`), 80 lignes de tests, 2 PDF de référence, plateformes Android/iOS/web/desktop.
> Méthode : lecture intégrale de `lib/`, confrontation au cahier des charges (`PROMPT_CLAUDE.md`), et **exécution d'une réplique fidèle de l'algorithme de parsing** sur les deux PDF réels du dépôt, dont la vérité terrain a été extraite indépendamment (positions `x/y` des mots via `pdfplumber`).
> Le SDK Flutter n'étant pas disponible dans l'environnement d'audit, **aucune compilation ni exécution de l'app n'a eu lieu** : les constats de compilation/API sont signalés comme « à vérifier ».

---

## 1. Verdict en une page

| Axe | Note | Commentaire |
|---|---|---|
| Architecture & organisation | **6/10** | Découpage `models / services / providers / screens` propre, mais la logique métier vit dans les écrans (3 fichiers = 61 % du code). |
| Qualité du code | **6/10** | Code lisible, nommage correct, `copyWith`/`==` soignés ; mais duplication, code mort, `print()` de debug, fichiers-mammouths. |
| Robustesse de l'import | **6/10** | Excellent sur le PDF cible (100 % des nuits des 12 agents), **mais** l'algorithme est positionnel par index : une cellule manquante décale tout le mois, silencieusement. |
| Couverture du cahier des charges | **6/10** | Import, calendrier, stats, notifications : présents. Édition/échange de garde, changement de profil : **non implémentés**. |
| Tests & CI | **2/10** | 2 fichiers de test, dont 1 qui ne peut passer que sur le PC de l'auteur. Aucune CI. |
| Sécurité / vie privée | **4/10** | App 100 % hors-ligne (bien), mais plannings **nominatifs de vrais agents publiés dans un dépôt public**, base non chiffrée, pas de `allowBackup=false`. |
| UX / design | **7/10** | Thème sombre soigné, verre dépoli, parcours d'import clair ; quelques contrastes cassés et boutons morts. |
| Documentation | **2/10** | `README.md` = template Flutter par défaut. Aucun changelog, aucune description de build. |

**Global : ~5,5/10.** C'est un **prototype avancé et fonctionnel sur son cas d'usage réel** (le CH de l'auteur), pas encore une application fiable au quotidien : les trois risques majeurs sont l'**exactitude silencieuse du parser**, les **notifications qui peuvent ne jamais partir** (permission jamais demandée) et les **données nominatives exposées dans un dépôt public**.

---

## 2. Ce que fait l'application

Application Flutter Android, **100 % hors-ligne**, pour une équipe de nuit hospitalière (13 agents : `RINAUDO`, `TETON`, `PIAZZA`, `RENFORT 1`, `LEROY`, `MONTEILLET`, `CAUVIERE`, `LIBAULT`, `TOUZET`, `ABDELALIM`, `ARRAGAIN`, `MONTREUIL`, `WICKER`).

Parcours utilisateur réel :

1. **Premier lancement** → `ImportScreen(isFirstLaunch: true)` sans barre de navigation.
2. **Import** d'un PDF (`syncfusion_flutter_pdf`) ou d'une capture/photo (`google_mlkit_text_recognition`).
3. **Parsing texte** → `Map<agent, joursTravaillés>` + `Map<agent, {jour: CA|CET|CFR}>`.
4. **Dialogue de sélection** de son propre nom parmi les agents détectés.
5. **Aperçu** (nuits + vacances) puis **validation** → écriture Hive.
6. **Calendrier** (`table_calendar`), **Statistiques** (`fl_chart`), **Paramètres**.
7. **Notifications locales** planifiées 2 h avant chaque garde, avec les prénoms des collègues.

Confrontation au cahier des charges `PROMPT_CLAUDE.md` :

| Exigence | État | Détail |
|---|---|---|
| Import PDF | ✅ | Testé : fonctionne sur les 2 PDF du dépôt |
| Import image / OCR | ⚠️ | Chemin de code présent, **mais** `parsePlanningImageBytes` passe des métadonnées codées en dur (1000×1000, BGRA) et l'OCR n'est pas testé |
| Sélection du profil au 1er lancement | ✅ | `_showUserSelectionDialog` |
| Aperçu + validation 1 clic | ✅ | Avec badge vacances |
| Identification des collègues par nuit | ✅ | `coWorkerIds` figé à l'import |
| Notifications avec prénoms | ⚠️ | Logique OK, **permission jamais demandée** (cf. P0-1) |
| Cumul horaire mois/année | ⚠️ | `shiftDurationHours` (entier) au lieu de la durée réelle du shift |
| Nuits par jour de semaine | ✅ | `BarChart` + comptage |
| Week-ends complets / demi / repos | ⚠️ | Implémenté, cas limites faux (cf. P1-4) |
| Binômes/trinômes | ✅ | `getTopTeammates` |
| Calendrier interactif | ✅ | Pastilles, détail du jour, vacances |
| **Rectification / échange de garde** | ❌ | `_showAddShiftDialog` et `_showEditShiftDialog` = simple SnackBar « À implémenter » |
| Changement de profil | ❌ | `_showChangeUserDialog` = « Fonctionnalité à venir » |
| Thème sombre Material 3 | ✅ | Très soigné |

---

## 3. Architecture

```
main.dart  ── init DateFormat fr_FR, timezones, Hive + adapters ──> ProviderScope
   │
   ├─ providers/app_providers.dart   (Riverpod : FutureProvider en lecture seule)
   │     databaseInitialized → teamMembers / allNightShifts / userConfig / *_forMonth
   │
   ├─ screens/
   │     home_screen      NavigationBar 4 onglets (screens construits en eager)
   │     import_screen    1016 l.  ← picking + parsing + preview + PERSISTANCE + notifs
   │     calendar_screen   878 l.  ← calendrier + détail + suppression
   │     statistics_screen 782 l.  ← agrégats + graphiques
   │     settings_screen   493 l.  ← formulaire + reset
   │
   ├─ services/
   │     database_service    singleton Hive (3 box)
   │     pdf_parser_service  extraction texte + parseur "universel"
   │     ocr_parser_service  ML Kit → délègue au parseur PDF
   │     statistics_service  calculs purs (statique)
   │     notification_service singleton flutter_local_notifications
   │
   └─ models/  TeamMember · NightShift · UserConfig (+ TimeOfDay adapter) — générés Hive
```

**Stack** : Flutter (Dart SDK `^3.12.2`) · Riverpod 2.6 · Hive 2.2 (+ `hive_generator`) · Syncfusion PDF 28 · ML Kit text recognition 0.17 · flutter_local_notifications 18 · table_calendar 3.3 · fl_chart 0.70 · intl · file_picker 13 · image_picker 1.2.

Points structurels notables :

- **Pas de couche repository / use-case** : les providers tapent directement le singleton `DatabaseService`, et `ImportScreen` orchestre parsing → validation → persistance → re-planification des notifications. Toute la règle métier est donc intestable sans widget test.
- **Le modèle de données confond nom et trigramme** : le parseur produit des clés qui sont des **noms de famille** (`RINAUDO`), stockées dans un champ nommé `trigramme` ; les paramètres imposent un trigramme de **3 caractères**. C'est la source de plusieurs bugs silencieux (§7).
- Duplication de l'initialisation : adapters Hive enregistrés dans `main.dart` **et** dans `DatabaseService.initialize()`, `Hive.initFlutter()` appelé deux fois.

### Métriques

| Mesure | Valeur |
|---|---|
| Dart applicatif (`lib/`) | 5 366 lignes · 23 fichiers (+195 l. générées) |
| Écrans | 3 169 l. (**61 %**) · `import_screen` 1 016 l. |
| Commentaires | 174 l. (**3,2 %**) |
| Tests | 80 l. (2 fichiers) — soit **1,5 %** du code de prod |
| `print()` en code de prod | 14, dont 6 qui affichent **le texte brut complet du planning** |
| TODO / stubs | 3 fonctionnalités visibles non implémentées |

---

## 4. Ce qui est vraiment bien fait

1. **Hors-ligne assumé et cohérent** : aucune permission `INTERNET`, Hive en local, ML Kit on-device. La promesse « 100 % hors-ligne, sans compte » est tenue.
2. **Le parser atteint son objectif sur son document cible** (voir §5) : 100 % des nuits des 12 agents individuels, 100 % des congés CA/CET/CFR, sur deux mois différents.
3. **Migration de schéma Hive anticipée** : `@HiveField(9, defaultValue: false)`, `@HiveField(10, defaultValue: '')`. C'est la bonne pratique, rare dans un prototype.
4. **Repli gracieux des alarmes** : `exactAllowWhileIdle` puis fallback `inexact` si l'autorisation système manque (`notification_service.dart:100-130`) — exactement ce qu'il faut sur Android 14.
5. **Détection du mois robuste** : accents gérés (`FÉVRIER`/`FEVRIER`, `AOÛT`/`AOUT`), normalisation `\u00A0` et `F EXT → F_EXT` — signe que l'auteur a vraiment regardé ses PDF.
6. **UX soignée** : thème sombre basse lumière, badges « Seul de garde », aperçu avant enregistrement, message de notification conforme au cahier des charges.

---

## 5. Validation factuelle du parser (le point le plus important)

### Méthode
1. Extraction du texte des deux PDF (`OCTOBRE 2026-NUIT.pdf`, `NOVEMBRE 2026-NUIT.pdf`) avec `pypdf`.
2. **Réplique Python fidèle** de `PdfParserService.parsePlanningText` (mêmes regex de normalisation, même liste `knownAgents`, même `tokenizeCodeString`, même logique ligne-par-ligne).
3. **Vérité terrain indépendante** : reconstruction de la grille par coordonnées `x/y` de chaque mot (`pdfplumber`), chaque code rattaché à la colonne-jour la plus proche.
4. Comparaison jour par jour des nuits et des congés.

### Résultats

| Mois | Nuits attendues | Nuits retrouvées | Faux positifs | Congés |
|---|---|---|---|---|
| Novembre 2026 (30 j) | 110 | **110 (100 %)** | 0 | 22/22 |
| Octobre 2026 (31 j) | 116 | **116 (100 %)** | 0 | 15/15 |

Exemple vérifié : `RINAUDO` novembre → `[1, 6, 9, 10, 11, 18, 21, 22, 26, 27, 30]`, identique à la grille PDF (et à l'assertion du test existant).

**C'est excellent** — et cela explique pourquoi l'application semble marcher. Mais cette réussite **repose sur une hypothèse non vérifiée** :

### La faille : un alignement purement séquentiel

`pdf_parser_service.dart:220` :

```dart
final monthTokens = tokens.take(totalDays).toList();
for (int i = 0; i < monthTokens.length; i++) {
  if (monthTokens[i] == 'N') workingDays.add(i + 1);   // jour = position dans la liste
}
```

Le jour est déduit de **l'ordre** des jetons, jamais de leur **position dans la page**. Il suffit donc qu'**une seule cellule** disparaisse (OCR, PDF aplati, cellule vide, retour à la ligne) pour que **toutes les nuits suivantes soient décalées d'un jour**.

Démonstration effectuée : en supprimant un seul `R` de la ligne `LEROY` de novembre (simulation d'un OCR imparfait), le résultat passe de

```
[2, 3, 7, 8, 12, 13, 16, 19, 20, 23, 24]      (correct)
[2, 3, 6, 7, 11, 12, 15, 18, 19, 22, 23]      (1 cellule perdue → tout décale)
```

Aucune erreur n'est signalée : l'utilisateur valide un planning faux en un clic, et ses notifications partiront les mauvais soirs. **C'est le bug le plus dangereux de l'application** parce qu'il est silencieux.

Deux cas voisins vérifiés :

| Scénario | Comportement observé |
|---|---|
| PDF contenant **2 mois** (octobre + novembre concaténés) | Les jetons des deux mois sont mis bout à bout → nuits fausses (`RINAUDO` → `[5,10,11,15,16,19,20,24,25,28]`) |
| Titre du mois illisible par l'OCR | Retombe **silencieusement** sur `11/2026` (`pdf_parser_service.dart:257-258`) → données enregistrées au mauvais mois |
| `RENFORT 1` | ✅ correctement rattaché (13 agents détectés), mais uniquement parce que le nom est **codé en dur** |

**Recommandations (par ordre d'impact)**
1. Valider le nombre de jetons par agent : `if (tokens.length != totalDays) → avertir dans l'aperçu` (badge orange « ligne incomplète : 28/30 ») et refuser la validation automatique.
2. Passer à un parsing **positionnel** : extraire le texte avec coordonnées (ou détecter les colonnes du header `D01…L30`) et rattacher chaque cellule à sa colonne. C'est la seule correction qui rend l'app sûre sur des captures d'écran.
3. Rendre la liste des agents **paramétrable** (stockée en Hive), au lieu de `knownAgents` codé en dur (`:113`).
4. Ne jamais deviner le mois : si le titre n'est pas trouvé, **demander** à l'utilisateur (sélecteur mois/année dans l'aperçu).
5. Supprimer les `print()` du texte brut (données nominatives en clair dans logcat).

---

## 6. Bugs & risques classés

### P0 — à corriger avant tout usage réel

| # | Problème | Emplacement | Impact | Correctif |
|---|---|---|---|---|
| 1 | **Permission POST_NOTIFICATIONS jamais demandée.** `requestPermissions()` existe mais n'est appelée nulle part. | `notification_service.dart:264` (0 appelant) | Sur Android 13+, **aucune notification n'apparaît jamais**. La fonctionnalité phare est morte sur les téléphones récents. | Appeler `requestPermissions()` (et l'`exactAlarm`) au 1er lancement et depuis l'écran Paramètres, avec message si refusé. |
| 2 | **Durée de garde négative.** `endMinutes - startMinutes` = `420 - 1140 = -720`. | `night_shift.dart:55-61` | Le calendrier affiche `-12h` sous chaque garde (`calendar_screen.dart:501`). | `if (end <= start) end += 24*60;` |
| 3 | **Alignement séquentiel du parser** (cf. §5). | `pdf_parser_service.dart:220` | Planning faux en un clic, sans aucune alerte. | Validation du compte de jetons + parsing par colonnes. |
| 4 | **Notification répétée chaque année.** `matchDateTimeComponents: DateTimeComponents.dateAndTime` sur un événement unique. | `notification_service.dart:113` et `:126` | Un rappel de garde se ré-affiche **tous les ans à la même date**. | Supprimer ce paramètre (one-shot `zonedSchedule`). |
| 5 | **Import non idempotent.** Les shifts sont réécrits (même `id`), mais **rien n'est supprimé** : une garde retirée du nouveau planning reste en base, idem pour les congés. | `import_screen.dart:851-912` | Cumul de données fantômes au fil des réimports ; stats faussées à la hausse. | Avant d'écrire : lire le mois, supprimer les shifts `userId` du mois, puis réinsérer. |
| 6 | **Plannings nominatifs publiés dans un dépôt public.** `OCTOBRE/NOVEMBRE 2026-NUIT.pdf` + une capture WhatsApp contiennent les noms réels de 13 soignants. | racine du dépôt, historique Git | Exposition de données personnelles (RGPD : données professionnelles identifiantes). | Retirer du dépôt, `git filter-repo`/BFG sur l'historique, ajouter des PDF **anonymisés** dans `test/fixtures/`. |

### P1 — corrections fonctionnelles

| # | Problème | Emplacement |
|---|---|---|
| 7 | `userId` régénéré en `user_<timestamp>` si aucune config n'existe → **ne correspond à aucun shift** → stats vides. | `settings_screen.dart:68` |
| 8 | Paramètres : trigramme **validé à 3 caractères**, alors que les clés d'import sont des noms (`RINAUDO`). Saisir `RIN` casse le lien avec les données importées. | `settings_screen.dart:268-280` |
| 9 | Le filtre des stats est `agentId == userConfig.userId` uniquement → changer de nom/trigramme dans les paramètres vide les statistiques. | `statistics_screen.dart:69` |
| 10 | Week-ends : si le dernier samedi du mois est le 30/31, `workingDays.contains(day + 1)` cherche un jour du mois suivant → week-end mal classé. Les week-ends à cheval sur deux mois sont comptés en « demi ». | `statistics_service.dart:95-115` |
| 11 | Mois/année par défaut codés en dur (`2026`, `11`) et `stopKeywords` contient `NOVEMBRE 2026` / `DÉCEMBRE 2026` en dur → **l'app ne survivra pas à janvier 2027**. | `pdf_parser_service.dart:113, 257-258` |
| 12 | Ajout / modification / échange de garde non implémentés (SnackBar « À implémenter »), bouton « Aller à l'import » sans action, « Changer » de profil en TODO. | `calendar_screen.dart:833, 839` · `import_screen.dart:1002` |
| 13 | 14 `print()` en production, dont **6 qui loggent l'intégralité du planning nominatif**. | `pdf_parser_service.dart:52-100` · `ocr_parser_service.dart:26-54` |
| 14 | `ocr_parser_service.parsePlanningImageBytes` : métadonnées en dur (`Size(1000,1000)`, `bgra8888`, `bytesPerRow: 4000`) → image déformée ou illisible sur toute photo non conforme. | `ocr_parser_service.dart:40-46` |
| 15 | Heures : les stats utilisent `shiftDurationHours` (entier, saisi) tandis que le calendrier utilise la durée calculée → **deux vérités différentes**. | `statistics_service.dart` vs `night_shift.dart` |
| 16 | Dans l'aperçu, un jour de congé est ignoré s'il figure déjà dans `previewItems`, avec une condition booléenne `&&`/`||` ambiguë (les deux branches disent la même chose). | `import_screen.dart:887-895` |

### P2 — dette et finitions

17 **Dépendances mortes** : `go_router`, `permission_handler`, `shared_preferences`, `uuid`, `android_alarm_manager_plus` ne sont **jamais importés** ; l'asset `assets/images/logo.png` (256 Ko) n'est jamais affiché. → ~5 dépendances et 250 Ko à supprimer.
18 **Plateformes inutiles** : `web/`, `linux/`, `macos/`, `windows/` sont générés mais la cible est Android. Le build **web est impossible** (`dart:io` dans `import_screen`, ML Kit non-web).
19 **Code mort** : `createNightShiftsFromParsedData` (deux versions), `currentUserProvider`, `selectedMonthProvider`, `notificationsEnabledProvider`, `parsePlanningPdf`/`parsePlanningPdfBytes`/`parsePlanningImage` (non utilisés), `_buildDetailRow`, `isManualOverride` (jamais mis à `true`).
20 **Contrastes cassés** : `Colors.orange.shade50` + texte foncé posé sur un thème sombre (aperçu des vacances), `Colors.red.shade700` en dur partout au lieu de `colorScheme`.
21 **iOS non configuré** : pas de `NSPhotoLibraryUsageDescription` / `NSCameraUsageDescription` dans `Info.plist` → crash à l'import photo si la cible iOS est activée.
22 **Confidentialité au repos** : Hive **non chiffré** et `android:allowBackup` laissé par défaut (`true`) → les plannings partent dans la sauvegarde cloud Google. Pour une app de soignants : `HiveAesCipher` + `android:allowBackup="false"` / `dataExtractionRules`.
23 **`uiLocalNotificationDateInterpretation`** est déprécié en `flutter_local_notifications` 18 et **supprimé en 19** : la montée de version cassera la compilation (à traiter avec la migration vers la v19 et les `AndroidFlutterLocalNotificationsPlugin.requestExactAlarmsPermission`).
24 **Licence Syncfusion** : `syncfusion_flutter_pdf` est gratuit sous Community License seulement (< 1 M$ de CA, ≤ 5 devs) — à documenter.

### À vérifier (non compilé ici)

- `FilePicker.pickFiles(...)` en statique (l'API historique est `FilePicker.platform.pickFiles()`, retour `FilePickerResult?`) : le code traite le retour comme une `List` (`files.isEmpty`, `files.first.path`) — **à confirmer contre la v13.3.0 verrouillée**.
- `Receivers` de `flutter_local_notifications` (redémarrage de l'appareil) : `RECEIVE_BOOT_COMPLETED` est déclaré, mais la persistance des alarmes après reboot dépend des `receiver` fusionnés par le plugin.
- `test/widget_test.dart` attend un `CircularProgressIndicator` alors qu'en environnement de test `path_provider` lève `MissingPluginException` → l'app affiche l'état d'erreur. Le test échoue très probablement.
- `test/pdf_parser_test.dart:9` référence `C:\Users\ATony\...\media_1793023434781.pdf` → **test rouge sur toute autre machine**, donc aucun test exploitable en CI.

---

## 7. Performance

À l'échelle visée (13 agents × 31 jours ≈ 400 lignes), rien de bloquant. Deux points à surveiller si le volume grandit :

- `DatabaseService` fait des **scans linéaires** de la box complète à chaque appel (`getNightShiftsForMonth`, `getNightShift`, `getNightShiftsForAgent`), et `TableCalendar.eventLoader` est appelé **pour chaque jour affiché** (~42 par mois) → ~42 × N itérations à chaque frame de changement de mois. Un index `Map<String /*yyyy-MM*/, List<NightShift>>` en mémoire suffirait.
- `BackdropFilter(blur 16)` sur la carte de détail + `_screens` instanciés en eager au démarrage : coût GPU/batterie inutile sur du matériel de garde.

---

## 8. Tests, CI et documentation

- **2 fichiers de test, 0 test unitaire du calcul statistique** (le code le plus « logique » de l'app, `statistics_service.dart`, 346 lignes, n'a aucun test).
- Aucun test du parseur sur fixture versionnée et anonymisée (le seul test réel dépend d'un chemin Windows absolu).
- **Aucun workflow GitHub Actions** : ni `flutter analyze`, ni `flutter test`, ni build APK.
- `analysis_options.yaml` = template par défaut (`flutter_lints`), aucun lint additionnel ; `avoid_print` est désactivé par défaut dans `flutter_lints`… et 14 `print()` en profitent.
- `README.md` = texte de démarrage Flutter. Rien sur : comment builder, comment sont produits les mots de passe/`applicationId`, la stratégie de parsing, la licence.

---

## 9. Plan d'action proposé

**Sprint 1 — Rendre l'app digne de confiance (≈ 2 jours)**
1. P0-2 durée négative (5 min) et P0-4 `matchDateTimeComponents` (5 min).
2. P0-1 : demander `POST_NOTIFICATIONS` + `SCHEDULE_EXACT_ALARM` au premier lancement, avec écran explicatif si refus.
3. P0-5 : import idempotent (purge du mois avant réinsertion).
4. P0-3 : contrôle `tokens.length == totalDays` + avertissement bloquant dans l'aperçu ; suppression du mois par défaut au profit d'un sélecteur.
5. P1-8/9 : unifier l'identité — **une seule clé** `agentId` stable, le libellé (nom ou trigramme) devient un attribut d'affichage.
6. Nettoyage : `print()`, dépendances mortes, `logo.png`, plateformes inutilisées. `README.md` utile.

**Sprint 2 — Fiabiliser et outiller (≈ 3 jours)**
7. Parsing positionnel (colonnes du header) + banc de tests sur fixtures anonymisées (les 2 PDF fournis, versions caviardées) et un jeu OCR dégradé.
8. Tests unitaires `statistics_service` (week-ends, changements d'année, mois à cheval) et CI GitHub Actions `analyze + test`.
9. Implémenter l'édition de garde + ajout/suppression + échange (spec §D), avec `isManualOverride = true` et re-planification des alarmes.
10. `HiveAesCipher` + `allowBackup=false`.

**Sprint 3 — Confort produit (≈ 2 jours)**
11. Export iCal / partage d'un mois (très demandé dans ce type d'outil), widget d'écran d'accueil (prochaine garde + collègues).
12. Paramétrage de l'équipe (agents détectés éditables) pour sortir du codage en dur.
13. Ceinture de sécurité : écran « Vérifier les données importées » (grille éditable avant validation) — c'est le meilleur rempart contre un parser faux.
14. Accessibilité : contraste AA, `colorScheme` partout, taille de police minimale, mode clair (le `darkModeEnabled` existe dans le modèle mais n'est jamais lu).

---

## 10. Annexes — commandes de vérification

```bash
# 1. Qualité statique
flutter pub get && flutter analyze

# 2. Tests (après avoir supprimé la dépendance au chemin Windows)
flutter test

# 3. Vérifier que la durée d'une garde n'est plus négative
flutter test test/night_shift_test.dart   # à créer

# 4. Audit du parser (méthode utilisée pour ce rapport)
pip install pypdf pdfplumber
# -> réplique du parseur + vérité terrain par coordonnées des mots
```

---

### Synthèse en une phrase

> L'application est un **prototype très abouti et personnellement utile**, dont le point fort (un parser taillé pour son PDF) est aussi son point faible (aucune prise en compte de la mise en page, aucune alerte en cas de dérive), et dont la fonctionnalité phare — la notification de garde — ne peut actuellement **pas fonctionner** sur Android 13+ faute de demande de permission.
