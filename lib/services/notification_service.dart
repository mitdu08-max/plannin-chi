import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';
import 'database_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String _channelId = 'night_shift_channel';
  static const String _channelName = 'Rappels de garde';
  static const String _channelDescription =
      'Rappels avant une garde de nuit, avec les collègues de service';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final DatabaseService _db = DatabaseService();

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Initialise le plugin (idempotent).
  Future<void> initialize() async {
    if (_isInitialized) return;

    tz_data.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _notifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    await _createNotificationChannel();
    _isInitialized = true;
  }

  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  void _onNotificationTapped(NotificationResponse response) {
    // L'ouverture de l'application sur le calendrier est gérée par le lancement
    // normal : rien de spécifique à faire ici pour l'instant.
  }

  /// Demande les autorisations nécessaires (Android 13+ et alarmes exactes).
  ///
  /// À appeler explicitement : sans `POST_NOTIFICATIONS`, aucune notification
  /// ne s'affiche sur Android 13+, et sans `SCHEDULE_EXACT_ALARM` le rappel
  /// peut être retardé.
  Future<bool> requestPermissions() async {
    await initialize();

    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;

    var granted = true;
    try {
      final notificationsGranted =
          await android.requestNotificationsPermission() ?? true;
      granted = notificationsGranted;

      // Android 12+ : autorisation « alarmes et rappels ».
      final exactGranted = await android.requestExactAlarmsPermission() ?? true;
      granted = granted && exactGranted;
    } on Object catch (e) {
      debugPrint('Demande d\'autorisation impossible : $e');
      return false;
    }

    return granted;
  }

  /// Vrai si l'utilisateur a autorisé l'affichage des notifications.
  Future<bool> areNotificationsAllowed() async {
    await initialize();
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.areNotificationsEnabled() ?? true;
  }

  /// Programme le rappel avant une garde.
  ///
  /// Le rappel est **unique** (pas de `matchDateTimeComponents`, qui provoquait
  /// une répétition annuelle de la notification à la même date).
  Future<void> scheduleShiftNotification({
    required NightShift shift,
    required List<TeamMember> coWorkers,
    required TimeOfDay shiftStartTime,
    required int notificationDelayMinutes,
  }) async {
    await initialize();
    if (!shift.isWorking) return;

    final notificationId = _generateNotificationId(shift.id);
    final scheduledDate = _calculateNotificationTime(
      shift.date,
      shiftStartTime,
      notificationDelayMinutes,
    );

    if (!scheduledDate.isAfter(DateTime.now())) return;

    final title = '🌙 Prise de poste ce soir';
    final body = _buildNotificationBody(coWorkers, shiftStartTime);

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final when = tz.TZDateTime.from(scheduledDate, tz.local);

    try {
      await _notifications.zonedSchedule(
        notificationId,
        title,
        body,
        when,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } on Object catch (e) {
      // Repli si les alarmes exactes ne sont pas autorisées par le système.
      debugPrint('Alarme exacte refusée, repli en mode inexact : $e');
      try {
        await _notifications.zonedSchedule(
          notificationId,
          title,
          body,
          when,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } on Object catch (e2) {
        debugPrint('Notification $notificationId non programmée : $e2');
      }
    }
  }

  /// Message : « Prise de poste ce soir à 19:00h avec Thomas et Julie. »
  String _buildNotificationBody(
    List<TeamMember> coWorkers,
    TimeOfDay shiftStartTime,
  ) {
    final time = '${shiftStartTime.hour.toString().padLeft(2, '0')}h'
        '${shiftStartTime.minute.toString().padLeft(2, '0') == '00' ? '' : shiftStartTime.minute.toString().padLeft(2, '0')}';

    if (coWorkers.isEmpty) {
      return 'Prise de poste ce soir à $time (Seul de garde).';
    }

    final names = coWorkers
        .map((c) => c.firstName.isNotEmpty ? c.firstName : c.trigramme)
        .join(' et ');
    return 'Prise de poste ce soir à $time avec $names. Bonne garde !';
  }

  DateTime _calculateNotificationTime(
    DateTime shiftDate,
    TimeOfDay shiftStartTime,
    int delayMinutes,
  ) {
    final shiftDateTime = DateTime(
      shiftDate.year,
      shiftDate.month,
      shiftDate.day,
      shiftStartTime.hour,
      shiftStartTime.minute,
    );
    return shiftDateTime.subtract(Duration(minutes: delayMinutes));
  }

  int _generateNotificationId(String shiftId) => shiftId.hashCode & 0x7FFFFFFF;

  Future<void> cancelShiftNotification(String shiftId) async {
    await _notifications.cancel(_generateNotificationId(shiftId));
  }

  Future<void> cancelAllNotifications() async {
    await initialize();
    await _notifications.cancelAll();
  }

  /// Replanifie tous les rappels des gardes à venir de l'utilisateur.
  Future<void> rescheduleAllNotifications({
    required String userId,
    required TimeOfDay shiftStartTime,
    required int notificationDelayMinutes,
  }) async {
    await initialize();
    await _notifications.cancelAll();

    final now = DateTime.now();
    final userShifts = _db
        .getAllNightShifts()
        .where((s) =>
            s.agentId == userId &&
            s.isWorking &&
            s.date.isAfter(now.subtract(const Duration(days: 1))))
        .toList();

    final teamMembers = _db.getAllTeamMembers();

    for (final shift in userShifts) {
      final coWorkers =
          teamMembers.where((m) => shift.coWorkerIds.contains(m.id)).toList();

      await scheduleShiftNotification(
        shift: shift,
        coWorkers: coWorkers,
        shiftStartTime: shift.startTime,
        notificationDelayMinutes: notificationDelayMinutes,
      );
    }
  }

  /// Notification de test immédiate.
  Future<void> sendTestNotification({
    required TimeOfDay shiftStartTime,
    required List<TeamMember> coWorkers,
  }) async {
    await initialize();

    await _notifications.show(
      999999,
      '🌙 Test de notification',
      _buildNotificationBody(coWorkers, shiftStartTime),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          enableVibration: true,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
