import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'Planning CHI';
  static const String appVersion = '1.0.0';

  // Default shift times
  static const int defaultShiftDurationHours = 10;
  static const int defaultNotificationDelayMinutes = 120; // 2 hours before shift
  static const TimeOfDay defaultShiftStartTime = TimeOfDay(hour: 19, minute: 0);
  static const TimeOfDay defaultShiftEndTime = TimeOfDay(hour: 7, minute: 0);

  // Team size
  static const int teamSize = 12;

  /// Noms d'agents connus, utilisés comme amorce par le parseur de planning.
  /// Les lignes non reconnues sont désormais détectées automatiquement,
  /// cette liste peut donc être adaptée sans casser l'import.
  static const List<String> knownAgentNames = [
    'RINAUDO', 'TETON', 'PIAZZA', 'RENFORT 1', 'RENFORT',
    'LEROY', 'MONTEILLET', 'CAUVIERE', 'LIBAULT', 'TOUZET',
    'ABDELALIM', 'ARRAGAIN', 'MONTREUIL', 'WICKER',
  ];

  // Notification
  static const String notificationChannelId = 'night_shift_notifications';
  static const String notificationChannelName = 'Night Shift Notifications';
  static const String notificationChannelDescription = 'Notifications for upcoming night shifts';

  // Hive Box Names
  static const String teamMembersBoxName = 'team_members';
  static const String nightShiftsBoxName = 'night_shifts';
  static const String userConfigBoxName = 'user_config';

  // Theme Colors (Dark mode optimized for night work)
  static const String primaryDarkColor = '#1E3A5F';
  static const String secondaryDarkColor = '#2C5F7C';
  static const String accentColor = '#FFB800';
  static const String backgroundDarkColor = '#0D1B2A';
  static const String surfaceDarkColor = '#1B2A4A';
  static const String textPrimaryDark = '#FFFFFF';
  static const String textSecondaryDark = '#B0C4DE';
  static const String successColor = '#4CAF50';
  static const String warningColor = '#FF9800';
  static const String errorColor = '#F44336';
  static const String infoColor = '#2196F3';

  // Shift codes for parsing
  static const List<String> workCodes = [
    'N', 'NUIT', 'GARDE', 'SERVICE', 'POSTE', 'NIGHT', 'G',
    '12H', '10H', '11H', '20H', '19H', '7H',
  ];

  static const List<String> restCodes = [
    'R', 'REPOS', 'CONGE', 'CONGÉ', 'OFF', 'LIBRE', 'VAC', 'VACANCES',
    'MALADIE', 'ABS', 'ABSENCE', '-', 'X',
  ];

  // Days in French
  static const List<String> daysFr = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'
  ];

  static const List<String> monthsFr = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
  ];
}