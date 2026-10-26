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

  Duration get duration {
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    return Duration(minutes: endMinutes - startMinutes);
  }

  double get durationHours => duration.inMinutes / 60.0;

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