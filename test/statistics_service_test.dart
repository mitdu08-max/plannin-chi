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
}
