import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/models.dart';
import '../services/database_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final DatabaseService _db = DatabaseService();

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    tz_data.initializeTimeZones();

    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    await _createNotificationChannel();

    _isInitialized = true;
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'night_shift_channel',
      'Night Shift Notifications',
      description: 'Notifications for upcoming night shifts',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - could navigate to calendar screen
  }

  /// Schedule a shift notification
  Future<void> scheduleShiftNotification({
    required NightShift shift,
    required List<TeamMember> coWorkers,
    required TimeOfDay shiftStartTime,
    required int notificationDelayMinutes,
  }) async {
    if (!_isInitialized) await initialize();

    final notificationId = _generateNotificationId(shift.id);
    final scheduledDate = _calculateNotificationTime(shift.date, shiftStartTime, notificationDelayMinutes);

    // Don't schedule if the time has already passed
    if (scheduledDate.isBefore(DateTime.now())) return;

    final title = '🌙 Prise de poste ce soir';
    final body = _buildNotificationBody(shift, coWorkers, shiftStartTime);

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'night_shift_channel',
        'Night Shift Notifications',
        channelDescription: 'Notifications for upcoming night shifts',
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

    try {
      await _notifications.zonedSchedule(
        notificationId,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
    } catch (_) {
      // Fallback to inexact if exact alarms are not permitted by system
      try {
        await _notifications.zonedSchedule(
          notificationId,
          title,
          body,
          tz.TZDateTime.from(scheduledDate, tz.local),
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexact,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dateAndTime,
        );
      } catch (e) {
        print('Could not schedule notification $notificationId: $e');
      }
    }
  }

  /// Build the notification message body with colleagues
  String _buildNotificationBody(NightShift shift, List<TeamMember> coWorkers, TimeOfDay shiftStartTime) {
    final timeFormat = '${shiftStartTime.hour.toString().padLeft(2, '0')}:${shiftStartTime.minute.toString().padLeft(2, '0')}';

    if (coWorkers.isEmpty) {
      return 'Prise de poste ce soir à ${timeFormat}h (Seul de garde).';
    }

    final colleagueNames = coWorkers.map((c) => c.firstName.isNotEmpty ? c.firstName : c.trigramme).join(' et ');
    return 'Prise de poste ce soir à ${timeFormat}h avec $colleagueNames. Bonne garde !';
  }

  /// Calculate when to send the notification (shift time - delay)
  DateTime _calculateNotificationTime(DateTime shiftDate, TimeOfDay shiftStartTime, int delayMinutes) {
    final shiftDateTime = DateTime(
      shiftDate.year,
      shiftDate.month,
      shiftDate.day,
      shiftStartTime.hour,
      shiftStartTime.minute,
    );
    return shiftDateTime.subtract(Duration(minutes: delayMinutes));
  }

  /// Generate a unique notification ID from shift ID
  int _generateNotificationId(String shiftId) {
    return shiftId.hashCode & 0x7FFFFFFF; // Positive 31-bit integer
  }

  /// Cancel a specific shift notification
  Future<void> cancelShiftNotification(String shiftId) async {
    final notificationId = _generateNotificationId(shiftId);
    await _notifications.cancel(notificationId);
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Reschedule all notifications for user's upcoming shifts
  Future<void> rescheduleAllNotifications({
    required String userId,
    required TimeOfDay shiftStartTime,
    required int notificationDelayMinutes,
  }) async {
    if (!_isInitialized) await initialize();

    // Cancel all existing
    await cancelAllNotifications();

    // Get user's future shifts
    final now = DateTime.now();
    final allShifts = _db.getAllNightShifts();
    final userShifts = allShifts
        .where((s) =>
            s.agentId == userId &&
            s.isWorking &&
            s.date.isAfter(now.subtract(const Duration(days: 1))))
        .toList();

    // Get team members for colleague names
    final teamMembers = _db.getAllTeamMembers();

    // Schedule notifications for each shift
    for (final shift in userShifts) {
      final coWorkerMembers = teamMembers
          .where((m) => shift.coWorkerIds.contains(m.id))
          .toList();

      await scheduleShiftNotification(
        shift: shift,
        coWorkers: coWorkerMembers,
        shiftStartTime: shiftStartTime,
        notificationDelayMinutes: notificationDelayMinutes,
      );
    }
  }

  /// Send a test notification immediately
  Future<void> sendTestNotification({
    required TimeOfDay shiftStartTime,
    required List<TeamMember> coWorkers,
  }) async {
    if (!_isInitialized) await initialize();

    const testId = 999999;
    final now = DateTime.now();

    final title = '🌙 Test de notification';
    final body = _buildNotificationBody(
      NightShift(
        id: 'test',
        date: now,
        agentId: 'test',
        agentTrigramme: 'TST',
        startTime: shiftStartTime,
        endTime: const TimeOfDay(hour: 7, minute: 0),
        isWorking: true,
        coWorkerIds: coWorkers.map((c) => c.id).toList(),
      ),
      coWorkers,
      shiftStartTime,
    );

    await _notifications.show(
      testId,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'night_shift_channel',
          'Night Shift Notifications',
          channelDescription: 'Notifications for upcoming night shifts',
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

  /// Request notification permissions (Android 13+)
  Future<bool> requestPermissions() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    final granted = await androidPlugin?.requestNotificationsPermission();
    return granted ?? false;
  }
}