import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:night_shift_planning/models/models.dart';
import 'package:night_shift_planning/services/statistics_service.dart';

NightShift _night(int year, int month, int day) => NightShift(
      id: '$year-$month-$day',
      date: DateTime(year, month, day),
      agentId: 'DUPONT',
      agentTrigramme: 'DUPONT',
      startTime: const TimeOfDay(hour: 19, minute: 0),
      endTime: const TimeOfDay(hour: 7, minute: 0),
      isWorking: true,
    );

void main() {
  group('StatisticsService.calculateMonthlyHours', () {
    test('utilise la durée réelle des gardes (12h)', () {
      final shifts = [_night(2026, 11, 3), _night(2026, 11, 5)];

      final hours = StatisticsService.calculateMonthlyHours(shifts, 2026, 11);

      expect(hours, 24.0);
    });

    test('retombe sur la durée forfaitaire si les horaires sont incomplets', () {
      final shift = NightShift(
        id: 'x',
        date: DateTime(2026, 11, 3),
        agentId: 'DUPONT',
        agentTrigramme: 'DUPONT',
        startTime: const TimeOfDay(hour: 19, minute: 0),
        endTime: const TimeOfDay(hour: 19, minute: 0),
        isWorking: true,
      );

      final hours = StatisticsService.calculateMonthlyHours(
        [shift],
        2026,
        11,
        shiftDurationHours: 10,
      );

      expect(hours, 10.0);
    });

    test('ignore les autres mois', () {
      final shifts = [_night(2026, 11, 3), _night(2026, 12, 3)];

      expect(StatisticsService.calculateMonthlyHours(shifts, 2026, 11), 12.0);
    });
  });

  group('StatisticsService.analyzeWeekendsMonth', () {
    test('un week-end à cheval sur deux mois est compté complet', () {
      // Samedi 31 octobre 2026 + dimanche 1er novembre 2026.
      final shifts = [_night(2026, 10, 31), _night(2026, 11, 1)];

      final analysis =
          StatisticsService.analyzeWeekendsMonth(shifts, 2026, 10);

      expect(analysis.fullWeekendsWorked, 1);
      expect(analysis.halfWeekendsWorked, 0);
    });

    test('un week-end avec seulement le samedi est un demi week-end', () {
      // Samedi 7 novembre 2026.
      final shifts = [_night(2026, 11, 7)];

      final analysis =
          StatisticsService.analyzeWeekendsMonth(shifts, 2026, 11);

      expect(analysis.fullWeekendsWorked, 0);
      expect(analysis.halfWeekendsWorked, 1);
    });

    test('sans garde le week-end, le samedi est compté en repos', () {
      final analysis = StatisticsService.analyzeWeekendsMonth([], 2026, 11);

      expect(analysis.fullWeekendsWorked, 0);
      expect(analysis.fullWeekendsRest, analysis.totalWeekends);
      expect(analysis.workedPercentage, 0.0);
    });
  });

  group('StatisticsService.getTopTeammates', () {
    test('compte les collègues des gardes de l\'utilisateur', () {
      final shifts = [
        _night(2026, 11, 3).copyWith(coWorkerIds: ['MARTIN', 'DURAND']),
        _night(2026, 11, 5).copyWith(coWorkerIds: ['MARTIN']),
      ];
      final members = [
        TeamMember(id: 'MARTIN', firstName: 'Paul', lastName: '', trigramme: 'MARTIN'),
        TeamMember(id: 'DURAND', firstName: 'Léa', lastName: '', trigramme: 'DURAND'),
      ];

      final stats =
          StatisticsService.getTopTeammates(shifts, 'DUPONT', members);

      expect(stats.first.teamMember.id, 'MARTIN');
      expect(stats.first.nightsTogether, 2);
    });
  });

  group('StatisticsService.getTeamStatistics', () {
    NightShift shiftFor(
      String agentId,
      int year,
      int month,
      int day, {
      String? trigramme,
      bool isWorking = true,
      bool isVacation = false,
      String vacationType = '',
    }) =>
        NightShift(
          id: '${agentId}_$year-$month-$day',
          date: DateTime(year, month, day),
          agentId: agentId,
          agentTrigramme: trigramme ?? agentId,
          startTime: const TimeOfDay(hour: 19, minute: 0),
          endTime: const TimeOfDay(hour: 7, minute: 0),
          isWorking: isWorking,
          isVacation: isVacation,
          vacationType: vacationType,
        );

    final members = [
      TeamMember(
        id: 'ARRAGAIN',
        firstName: 'ARRAGAIN',
        lastName: '',
        trigramme: 'ARRAGAIN',
      ),
      TeamMember(
        id: 'LEROY',
        firstName: 'LEROY',
        lastName: '',
        trigramme: 'LEROY',
      ),
      TeamMember(
        id: 'MONTEILLET',
        firstName: 'MONTEILLET',
        lastName: '',
        trigramme: 'MONTEILLET',
      ),
    ];

    test('calcule nuits, week-ends, heures et congés pour chaque membre sur l\'année', () {
      // Octobre 2026: 31 oct = samedi, 1 nov = dimanche (WE à cheval)
      // Novembre 2026: 7 nov = samedi (demi WE)
      final shifts = [
        // ARRAGAIN: 3 nuits (36h), 1 WE complet (31/10 + 01/11), 1 CA
        shiftFor('ARRAGAIN', 2026, 10, 31),
        shiftFor('ARRAGAIN', 2026, 11, 1),
        shiftFor('ARRAGAIN', 2026, 11, 4),
        shiftFor(
          'ARRAGAIN',
          2026,
          11,
          5,
          isWorking: false,
          isVacation: true,
          vacationType: 'CA',
        ),
        // LEROY: 4 nuits (48h), 1 demi WE (07/11)
        shiftFor('LEROY', 2026, 11, 2),
        shiftFor('LEROY', 2026, 11, 3),
        shiftFor('LEROY', 2026, 11, 6),
        shiftFor('LEROY', 2026, 11, 7),
        // Une garde en 2025 qui ne doit pas compter dans 2026
        shiftFor('ARRAGAIN', 2025, 12, 15),
      ];

      final summary = StatisticsService.getTeamStatistics(
        allShifts: shifts,
        allTeamMembers: members,
        year: 2026,
        shiftDurationHours: 12.0,
      );

      // Tri par défaut : nuits décroissant (LEROY 4 > ARRAGAIN 3 > MONTEILLET 0)
      expect(summary.agentStats.map((s) => s.teamMember.id).toList(), [
        'LEROY',
        'ARRAGAIN',
        'MONTEILLET',
      ]);

      final leroy = summary.agentStats[0];
      expect(leroy.totalNights, 4);
      expect(leroy.totalHours, 48.0);
      expect(leroy.fullWeekendsWorked, 0);
      expect(leroy.halfWeekendsWorked, 1);
      expect(leroy.weekendsWorked, 1);

      final arragain = summary.agentStats[1];
      expect(arragain.totalNights, 3);
      expect(arragain.totalHours, 36.0);
      expect(arragain.fullWeekendsWorked, 1);
      expect(arragain.halfWeekendsWorked, 0);
      expect(arragain.weekendsWorked, 1);
      expect(arragain.vacationDays, 1);

      final monteillet = summary.agentStats[2];
      expect(monteillet.totalNights, 0);
      expect(monteillet.totalHours, 0.0);

      expect(summary.totalTeamNights, 7);
      expect(summary.totalTeamHours, 84.0);
      expect(summary.activeAgentsCount, 2);
      expect(summary.coveredMonths, {10, 11});
    });

    test('associe les gardes par trigramme même si agentId diffère et trie par nom', () {
      final shifts = [
        shiftFor('legacy-id', 2026, 5, 2, trigramme: 'ARRAGAIN'),
        shiftFor('LEROY', 2026, 5, 3),
        shiftFor('LEROY', 2026, 5, 4),
      ];

      final summary = StatisticsService.getTeamStatistics(
        allShifts: shifts,
        allTeamMembers: members,
        year: 2026,
        month: 5,
        sortBy: TeamSortField.name,
        ascending: true,
      );

      expect(summary.agentStats.map((s) => s.teamMember.id).toList(), [
        'ARRAGAIN',
        'LEROY',
        'MONTEILLET',
      ]);
      expect(summary.agentStats.first.totalNights, 1);
    });

    test('génère un résumé texte lisible pour le presse-papiers', () {
      final shifts = [
        shiftFor('ARRAGAIN', 2026, 10, 31),
        shiftFor('ARRAGAIN', 2026, 11, 1),
      ];
      final summary = StatisticsService.getTeamStatistics(
        allShifts: shifts,
        allTeamMembers: [members.first],
        year: 2026,
      );

      final text = StatisticsService.buildTeamSummaryText(summary);
      expect(text, contains('Bilan Équipe — Année 2026 (2/12 mois)'));
      expect(text, contains('ARRAGAIN : 2 nuits · 1 WE · 24h'));
      expect(text, contains('Total équipe : 2 nuits · 24h'));
    });

    test('formatHours supprime le .0 sur les nombres entiers', () {
      expect(StatisticsService.formatHours(1452.0), '1452h');
      expect(StatisticsService.formatHours(1452.5), '1452.5h');
    });
  });
}
