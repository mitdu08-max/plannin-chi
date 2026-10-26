import '../constants/app_constants.dart';
import '../models/models.dart';
import 'database_service.dart';
import 'pdf_parser_service.dart';

/// Service de pré-chargement des données d'équipe du planning CHI.
///
/// Permet de renseigner immédiatement les gardes de toute l'équipe pour
/// qu'un utilisateur en repos ou en congé puisse voir qui est de garde chaque nuit.
class SeedDataService {
  static const String octoberPlanningText = '''
J01 V02 S03 D04 L05 M06 M07 J08 V09 S10 D11 L12 M13 M14 J15 V16 S17 D18 L19 M20 M21 J22 V23 S24 D25 L26 M27 M28 J29 V30 S31
Oct Oct Oct Oct S41 Oct Oct Oct Oct Oct Oct S42 Oct Oct Oct Oct Oct Oct S43 Oct Oct Oct Oct Oct Oct S44 Oct Oct Oct Oct Oct
RINAUDO                                R R RH RH N R R R RH N N RH R R N N RH RH N N R R RH N N RH R N R RH N
TETON R R RH RH N R R R RH N N RH R R N N RH RH R N N R RH N N RH R N R N RH
PIAZZA R R RH RH N R R R RH N N RH R R N N RH RH R N N R N RH RH N R R N RH N
RENFORT 1 R R R R N R R R RH N N RH R R N N RH RH R R R R N RH RH N N R R RH N
LEROY                                          N N RH RH R N N R R RH RH N R R R RH N N RH R R N R RH RH   CA     CA     CA     CA     CA   RH
MONTEILLET                       N N RH RH R N R F F RH RH N R R R RH N N RH R R N RH N N RH R N R R RH
CAUVIERE N N RH RH R N N R R RH RH N R R R RH N N RH R R N N RH RH R N N R RH N
LIBAULT N N RH RH R N N R R RH RH N R R R RH N N RH R R N N RH RH N N R R R RH
TOUZET R F EXT N N RH R R N N RH RH R N N R R RH RH   CA     CA     CA     CA     CA   RH RH N N R N N RH
ABDELALIM R F EXT N N RH R R N N RH RH R N N R R RH RH N R R R RH N N RH R R N N RH
ARRAGAIN R RH N N RH R R N N RH RH R N N R R RH RH N R N R R RH RH   CA     CA     CA     CA     CA   RH
MONTREUIL R R N N R R R N N R R R N N R R RH RH N R R R RH N N RH R R N N RH
WICKER R R RH RH J R R J RH J J RH R R R RH J J RH N N R R RH RH J J R R R J
vacances scolaires
Nom / Prénom
OCTOBRE 2026
ÉQUIPE DE NUIT
''';

  static const String novemberPlanningText = '''
D01 L02 M03 M04 J05 V06 S07 D08 L09 M10 M11 J12 V13 S14 D15 L16 M17 M18 J19 V20 S21 D22 L23 M24 M25 J26 V27 S28 D29 L30
Nov S45 Nov Nov Nov Nov Nov Nov S46 Nov Nov Nov Nov Nov Nov S47 Nov Nov Nov Nov Nov Nov S48 Nov Nov Nov Nov Nov Nov S49
RINAUDO N F EXT F R F EXT N RH RH N N N F R RH RH F EXT R N R RH N N RH R R N N RH RH N
TETON RH N F R R RH N N F F F R R RH RH N N R R RH N N RH R R N N RH RH N
PIAZZA N RH F R N N RH RH F F R F RH N N RH R R N N RH RH N R R R RH N N RH
RENFORT 1 N R R RNNR R R NNNNR RR R R R RNNR R RNR R R R
LEROY RH N N R R RH N N RH R F N N RH RH N R R N N RH RH N N R R CA RH RH CA
MONTEILLET RH N F N R RH N N RH F N R N RH RH N N N R CET RH RH CET R N R RH N N RH
CAUVIERE N RH F R N N RH RH N R F N N RH RH N N R R CA RH RH N R R N RH N N RH
LIBAULT RH N F R R CA RH RH CA CA F CA CA RH RH F F N R R RH RH N R R RH N N N RH
TOUZET RH F EXT F EXT F EXT F EXT F EXT RH RH CA CA F CET CET RH RH F EXT N R RH RH N N CFR N N R R RH RH F EXT
ABDELALIM RH F N N R R RH RH N N R R RH N N RH R N CA R RH RH CA CA CA CA CA RH RH CA
ARRAGAIN RH F N N R R RH RH N N R R RH N N RH R R N N RH RH R N N R N RH RH N
MONTREUIL RH F N N N R RH RH R F N N RH N N RH R R N N RH RH R N N R R RH RH N
WICKER J F RH J R RH N N RH R J F R RH RH J R J R RH J J RH R R J J RH RH R
vacances scolaires
Nom / Prénom
NOVEMBRE 2026
ÉQUIPE DE NUIT
''';

  /// Vérifie si la base ne contient les gardes que d'un seul agent et pré-charge l'équipe si nécessaire.
  static Future<void> seedTeamShiftsIfNeeded(DatabaseService db) async {
    final allShifts = db.getAllNightShifts();

    // Compter combien d'agents différents ont des gardes enregistrées
    final distinctAgents = allShifts.map((s) => s.agentId).toSet();

    // Si la base ne contient que l'utilisateur actuel (ou est vide), enrichir avec toute l'équipe
    if (distinctAgents.length <= 1) {
      await importPlanningTextToDb(db, octoberPlanningText);
      await importPlanningTextToDb(db, novemberPlanningText);
    }
  }

  /// Parse un texte de planning et enregistre les gardes et congés pour TOUS les agents.
  static Future<void> importPlanningTextToDb(DatabaseService db, String text) async {
    final parsed = PdfParserService.parsePlanningText(text);
    if (parsed.year == null || parsed.month == null) return;

    final year = parsed.year!;
    final month = parsed.month!;
    final userConfig = db.getUserConfig();
    final startTime = userConfig?.shiftStartTime ?? AppConstants.defaultShiftStartTime;
    final endTime = userConfig?.shiftEndTime ?? AppConstants.defaultShiftEndTime;

    // 1. Sauvegarder les membres d'équipe manquants
    final existingMembers = {for (final m in db.getAllTeamMembers()) m.id: m};
    for (final agentName in parsed.agentShifts.keys) {
      if (!existingMembers.containsKey(agentName)) {
        await db.saveTeamMember(
          TeamMember(
            id: agentName,
            firstName: agentName,
            lastName: '',
            trigramme: agentName,
          ),
        );
      }
    }

    // 2. Enregistrer les gardes et congés de chaque agent
    for (final entry in parsed.agentShifts.entries) {
      final agentId = entry.key;
      final days = entry.value;
      final vacations = parsed.agentVacations[agentId] ?? const <int, String>{};

      for (final day in days) {
        final date = DateTime(year, month, day);
        final coWorkers = parsed.agentShifts.entries
            .where((e) => e.key != agentId && e.value.contains(day))
            .map((e) => e.key)
            .toList();

        final shift = NightShift(
          id: '${agentId}_${year}_${month}_$day',
          date: date,
          agentId: agentId,
          agentTrigramme: agentId,
          startTime: startTime,
          endTime: endTime,
          isWorking: true,
          coWorkerIds: coWorkers,
          isManualOverride: false,
        );
        await db.saveNightShift(shift);
      }

      for (final vacEntry in vacations.entries) {
        final day = vacEntry.key;
        if (days.contains(day)) continue;

        final shift = NightShift(
          id: '${agentId}_${year}_${month}_$day',
          date: DateTime(year, month, day),
          agentId: agentId,
          agentTrigramme: agentId,
          startTime: startTime,
          endTime: endTime,
          isWorking: false,
          isVacation: true,
          vacationType: vacEntry.value,
          coWorkerIds: const [],
        );
        await db.saveNightShift(shift);
      }
    }
  }
}
