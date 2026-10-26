import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:night_shift_planning/models/models.dart';

NightShift _shift({
  required TimeOfDay start,
  required TimeOfDay end,
  bool isWorking = true,
}) {
  return NightShift(
    id: 'test',
    date: DateTime(2026, 11, 1),
    agentId: 'DUPONT',
    agentTrigramme: 'DUPONT',
    startTime: start,
    endTime: end,
    isWorking: isWorking,
  );
}

void main() {
  group('NightShift.duration', () {
    test('une garde de nuit ne renvoie plus une durée négative', () {
      final shift = _shift(
        start: const TimeOfDay(hour: 19, minute: 0),
        end: const TimeOfDay(hour: 7, minute: 0),
      );

      expect(shift.isOvernight, isTrue);
      expect(shift.duration.inMinutes, 12 * 60);
      expect(shift.durationHours, 12.0);
    });

    test('une garde de 10h est correctement calculée', () {
      final shift = _shift(
        start: const TimeOfDay(hour: 21, minute: 0),
        end: const TimeOfDay(hour: 7, minute: 0),
      );

      expect(shift.durationHours, 10.0);
    });

    test('une garde en journée reste positive', () {
      final shift = _shift(
        start: const TimeOfDay(hour: 8, minute: 0),
        end: const TimeOfDay(hour: 17, minute: 30),
      );

      expect(shift.isOvernight, isFalse);
      expect(shift.duration.inMinutes, 9 * 60 + 30);
    });

    test('des horaires identiques donnent une durée nulle', () {
      final shift = _shift(
        start: const TimeOfDay(hour: 19, minute: 0),
        end: const TimeOfDay(hour: 19, minute: 0),
      );

      expect(shift.duration, Duration.zero);
    });

    test('endDateTime tombe le lendemain pour une garde de nuit', () {
      final shift = _shift(
        start: const TimeOfDay(hour: 19, minute: 0),
        end: const TimeOfDay(hour: 7, minute: 0),
      );

      expect(shift.startDateTime, DateTime(2026, 11, 1, 19));
      expect(shift.endDateTime, DateTime(2026, 11, 2, 7));
    });
  });
}
