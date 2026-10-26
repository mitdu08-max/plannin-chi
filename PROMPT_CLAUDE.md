# MASTER PROMPT CLAUDE CODE : FLUTTER ANDROID - NIGHT SHIFT & TEAM PLANNING ANALYTICS

## 1. VISION DU PROJET
Développer une application mobile Android personnelle en Flutter (100% hors-ligne, sans compte obligatoire).
L'application permet d'importer un planning d'équipe (12 agents) au format **PDF ou Capture d'écran**, d'extraire automatiquement les nuits de travail de l'utilisateur, d'identifier ses collègues en poste chaque nuit, de déclencher des notifications intelligentes précisant les coéquipiers de service, et de fournir des statistiques approfondies (heures, jours de semaine, week-ends complets).

---

## 2. FONCTIONNALITÉS CŒUR

### A. IMPORT & PARSER DE PLANNING D'ÉQUIPE (12 AGENTS)
- **Sources acceptées** :
  - Fichier **PDF** (extraction de texte et tableaux)
  - **Capture d'écran / Image** (OCR haute performance avec `google_ml_kit_text_recognition`)
- **Structure de la grille attendue** :
  - Colonnes = Jours du mois (1 à 30/31)
  - Lignes = Les 12 agents de l'équipe
- **Configuration initiale de l'utilisateur** :
  - Saisie / Sélection de son Nom ou Trigramme au premier lancement
- **Logique d'extraction** :
  1. Détection de la ligne de l'utilisateur pour extraire ses nuits de garde (codes de travail vs repos/congés).
  2. Détection simultanée de tous les collègues travaillant la même nuit.
- **Écran d'aperçu & validation** :
  - Affichage clair du résultat avant enregistrement (ex: *"21 nuits détectées pour Novembre - Équipe identifiée"*). Bouton de validation rapide en 1 clic.

### B. NOTIFICATIONS INTELLIGENTES AVEC COLLÈGUES EN POSTE
- Déclenchement automatique via `flutter_local_notifications` (compatible Android 13+ et exact alarms).
- Notification contextualisée quelques heures avant la prise de poste (heure paramétrable, ex: 17h00 ou 18h00 pour 19h00).
- **Format du message** :
  - *"🌙 Prise de poste ce soir à 19h00 avec [Prénom 1] et [Prénom 2]. Bonne garde !"*
  - Si seul : *"🌙 Prise de poste ce soir à 19h00 (Seul de garde)."*

### C. TABLEAU DE BORD STATISTIQUES & ANALYSES
- **Volume horaire** :
  - Cumul d'heures mensuel (paramétrage de la durée d'une nuit, ex: 10h, 11h ou 12h)
  - Cumul d'heures annuel
- **Décompte précis par jour de la semaine** :
  - Nombre de nuits de Lundi, Mardi, Mercredi, Jeudi, Vendredi travaillées sur le mois et sur l'année
- **Analyse des Week-ends** :
  - Week-ends complets travaillés (Nuit Samedi + Nuit Dimanche)
  - Demi week-ends travaillés
  - Week-ends complets de repos
- **Statistiques d'équipe (Bonus)** :
  - Fréquence de travail en binôme/trinôme (ex: *"Tu as travaillé 8 fois avec Thomas ce mois-ci"*).

### D. CALENDRIER INTERACTIF & RECTIFICATION MANUELLE
- Vue calendrier mensuel (`table_calendar`) avec pastilles colorées.
- En cliquant sur un jour : détail des horaires et liste des collègues de service.
- Possibilité d'ajuster ou d'échanger une garde manuellement en cas de changement de dernière minute.

---

## 3. ARCHITECTURE & CHOIX TECHNIQUES

- **Plateforme** : Android (Flutter dernière version stable)
- **Stockage local** : Hive ou Isar (persistance rapide, sans serveur)
- **Modèles de données principaux** :
  - `TeamMember` : id, nom, prénom, trigramme
  - `NightShift` : date, agentId, startTime, endTime, isWorking, coWorkerIds
  - `UserConfig` : userName, shiftDurationHours, notificationDelayMinutes
- **Packages recommandés** :
  - `google_ml_kit_text_recognition` (OCR local pour captures d'écran)
  - `syncfusion_flutter_pdf` ou `pdf_text` (lecture PDF)
  - `flutter_local_notifications` & `timezone` (gestion des alertes)
  - `table_calendar` (calendrier)
  - `fl_chart` (graphiques statistiques)
  - `flutter_riverpod` (gestion d'état)
- **Design** : Material 3 moderne, thème sombre (Dark Mode) contrasté et immersif pour le travail de nuit.

---

## 4. PLAN DE DÉVELOPPEMENT POUR CLAUDE CODE (À EXÉCUTER ÉTAPE PAR ÉTAPE)

1. **Phase 1 : Socle technique**
   - Initialisation du projet et configuration des permissions Android (`RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM`, `POST_NOTIFICATIONS`).
   - Mise en place des modèles de données et de la base locale.

2. **Phase 2 : Moteur d'Importation & OCR**
   - Création du service d'extraction (PDF + Image).
   - Logique d'alignement de la matrice 12 agents × 31 jours.
   - Écran de sélection du nom utilisateur + écran d'aperçu et confirmation.

3. **Phase 3 : Logique d'Analyse & Coéquipiers**
   - Moteur de calcul des statistiques (heures, jours de la semaine, week-ends complets).
   - Résolution des coéquipiers présents par date.

4. **Phase 4 : Notifications & Alarmes**
   - Programmation des notifications locales au moment de l'import ou de la modification d'un shift.
   - Formatage dynamique du message avec les prénoms des collègues.

5. **Phase 5 : UI & Finitions**
   - Écran Calendrier avec fiche détaillée du jour.
   - Écran Statistiques avec graphiques clairs et décomptes précis.
   - Écran Paramètres (gestion de son nom, horaires de nuit, heure de notification).

Développe ce projet avec un code propre, modulaire et directement exécutable sur Android.
