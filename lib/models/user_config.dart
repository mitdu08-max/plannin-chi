import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

part 'user_config.g.dart';

@HiveType(typeId: 2)
class UserConfig extends HiveObject {
  @HiveField(0)
  String userId;

  @HiveField(1)
  String userName;

  @HiveField(2)
  String userTrigramme;

  @HiveField(3)
  int shiftDurationHours;

  @HiveField(4)
  int notificationDelayMinutes;

  @HiveField(5)
  TimeOfDay shiftStartTime;

  @HiveField(6)
  TimeOfDay shiftEndTime;

  @HiveField(7)
  bool notificationsEnabled;

  @HiveField(8)
  bool darkModeEnabled;

  @HiveField(9)
  String themeColor;

  UserConfig({
    required this.userId,
    required this.userName,
    required this.userTrigramme,
    this.shiftDurationHours = 10,
    this.notificationDelayMinutes = 120,
    this.shiftStartTime = const TimeOfDay(hour: 19, minute: 0),
    this.shiftEndTime = const TimeOfDay(hour: 7, minute: 0),
    this.notificationsEnabled = true,
    this.darkModeEnabled = true,
    this.themeColor = '#1E3A5F',
  });

  UserConfig copyWith({
    String? userId,
    String? userName,
    String? userTrigramme,
    int? shiftDurationHours,
    int? notificationDelayMinutes,
    TimeOfDay? shiftStartTime,
    TimeOfDay? shiftEndTime,
    bool? notificationsEnabled,
    bool? darkModeEnabled,
    String? themeColor,
  }) {
    return UserConfig(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userTrigramme: userTrigramme ?? this.userTrigramme,
      shiftDurationHours: shiftDurationHours ?? this.shiftDurationHours,
      notificationDelayMinutes: notificationDelayMinutes ?? this.notificationDelayMinutes,
      shiftStartTime: shiftStartTime ?? this.shiftStartTime,
      shiftEndTime: shiftEndTime ?? this.shiftEndTime,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
      themeColor: themeColor ?? this.themeColor,
    );
  }

  @override
  String toString() {
    return 'UserConfig(userId: $userId, userName: $userName, shiftDurationHours: $shiftDurationHours)';
  }
}