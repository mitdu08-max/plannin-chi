import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

part 'night_shift.g.dart';

@HiveType(typeId: 1)
class NightShift extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime date;

  @HiveField(2)
  final String agentId;

  @HiveField(3)
  final String agentTrigramme;

  @HiveField(4)
  final TimeOfDay startTime;

  @HiveField(5)
  final TimeOfDay endTime;

  @HiveField(6)
  final bool isWorking;

  @HiveField(7)
  final List<String> coWorkerIds;

  @HiveField(8)
  final bool isManualOverride;

  @HiveField(9, defaultValue: false)
  final bool isVacation;

  @HiveField(10, defaultValue: '')
  final String vacationType; // 'CA', 'CET', or 'CFR'

  NightShift({
    required this.id,
    required this.date,
    required this.agentId,
    required this.agentTrigramme,
    required this.startTime,
    required this.endTime,
    required this.isWorking,
    this.coWorkerIds = const [],
    this.isManualOverride = false,
    this.isVacation = false,
    this.vacationType = '',
  });

  /// Vrai si la garde franchit minuit (ex: 19h00 -> 07h00).
  bool get isOvernight {
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    return endMinutes < startMinutes;
  }

  /// Durée réelle de la garde.
  ///
  /// Correction : une garde de nuit (19h00 -> 07h00) traversait minuit et
  /// renvoyait une durée négative (-12h). On ajoute 24h quand l'heure de fin
  /// est antérieure à l'heure de début. Si les deux heures sont identiques,
  /// la durée est nulle (saisie incomplète).
  Duration get duration {
    final startMinutes = startTime.hour * 60 + startTime.minute;
    var endMinutes = endTime.hour * 60 + endTime.minute;
    if (endMinutes == startMinutes) return Duration.zero;
    if (endMinutes < startMinutes) endMinutes += 24 * 60;
    return Duration(minutes: endMinutes - startMinutes);
  }

  double get durationHours => duration.inMinutes / 60.0;

  /// Date/heure de prise de poste.
  DateTime get startDateTime => DateTime(
        date.year,
        date.month,
        date.day,
        startTime.hour,
        startTime.minute,
      );

  /// Date/heure de fin de poste (peut être le lendemain).
  DateTime get endDateTime => startDateTime.add(duration);

  bool get isWeekend {
    final weekday = date.weekday;
    return weekday == DateTime.saturday || weekday == DateTime.sunday;
  }

  String get dayOfWeek {
    const days = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche'
    ];
    return days[date.weekday - 1];
  }

  NightShift copyWith({
    String? id,
    DateTime? date,
    String? agentId,
    String? agentTrigramme,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    bool? isWorking,
    List<String>? coWorkerIds,
    bool? isManualOverride,
    bool? isVacation,
    String? vacationType,
  }) {
    return NightShift(
      id: id ?? this.id,
      date: date ?? this.date,
      agentId: agentId ?? this.agentId,
      agentTrigramme: agentTrigramme ?? this.agentTrigramme,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isWorking: isWorking ?? this.isWorking,
      coWorkerIds: coWorkerIds ?? this.coWorkerIds,
      isManualOverride: isManualOverride ?? this.isManualOverride,
      isVacation: isVacation ?? this.isVacation,
      vacationType: vacationType ?? this.vacationType,
    );
  }

  @override
  String toString() {
    return 'NightShift(id: $id, date: $date, agentId: $agentId, isWorking: $isWorking)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NightShift && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}