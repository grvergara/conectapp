import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/reminder.dart';
import 'local_storage_service.dart';
import 'firestore_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request notification permissions for Android 13+
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final androidPlugin =
    _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }
  }

  // Handle notification tap and actions
  Future<void> _onNotificationTapped(
      NotificationResponse notificationResponse) async {
    final payload = notificationResponse.payload;
    final actionId = notificationResponse.actionId;

    if (payload != null && actionId != null) {
      await _handleNotificationAction(payload, actionId);
    }
  }

  Future<void> _handleNotificationAction(String reminderId, String action) async {
    try {
      final localStorage = await LocalStorageService.getInstance();
      final firestoreService = FirestoreService();
      final reminder = await localStorage.getReminder(reminderId);

      if (reminder == null) return;

      Reminder updatedReminder;

      if (action == 'complete') {
        updatedReminder = reminder.copyWith(state: ReminderState.completed);
      } else if (action == 'skip') {
        updatedReminder = reminder.copyWith(state: ReminderState.skipped);
      } else {
        return;
      }

      // Update locally
      await localStorage.updateReminder(updatedReminder);

      // Update in Firestore
      await firestoreService.updateReminderInFirestore(updatedReminder);

      // Handle recurring reminders
      if (reminder.frequency != ReminderFrequency.nonRepeat) {
        final nextOccurrence = reminder.getNextOccurrence();
        if (nextOccurrence != null) {
          final nextReminder = reminder.copyWith(
            dateTime: nextOccurrence,
            state: ReminderState.pending,
          );
          await scheduleNotification(nextReminder);
        }
      }
    } catch (e) {
      print('Error handling notification action: $e');
    }
  }

  // Schedule a notification
  Future<void> scheduleNotification(Reminder reminder) async {
    if (reminder.dateTime.isBefore(DateTime.now())) {
      print('Cannot schedule notification for past date');
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      'posture_reminders',
      'Posture Reminders',
      channelDescription: 'Notifications for posture reminders',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      actions: [
        const AndroidNotificationAction(
          'complete',
          'Complete',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          'skip',
          'Skip',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    try {
      await _notifications.zonedSchedule(
        reminder.id.hashCode,
        reminder.title,
        reminder.description,
        tz.TZDateTime.from(reminder.dateTime, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        //uiLocalNotificationDateInterpretation:
        //UILocalNotificationDateInterpretation.absoluteTime,
        payload: reminder.id,
      );
      print('Notification scheduled for ${reminder.dateTime}');
    } catch (e) {
      print('Error scheduling notification: $e');
    }
  }

  // Cancel a notification
  Future<void> cancelNotification(String reminderId) async {
    try {
      await _notifications.cancel(reminderId.hashCode);
      print('Notification cancelled for reminder: $reminderId');
    } catch (e) {
      print('Error cancelling notification: $e');
    }
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      print('All notifications cancelled');
    } catch (e) {
      print('Error cancelling all notifications: $e');
    }
  }

  // Reschedule notification (useful when editing)
  Future<void> rescheduleNotification(Reminder reminder) async {
    await cancelNotification(reminder.id);
    await scheduleNotification(reminder);
  }

  // Schedule recurring reminders
  Future<void> scheduleRecurringReminder(Reminder reminder) async {
    if (reminder.frequency == ReminderFrequency.nonRepeat) {
      await scheduleNotification(reminder);
      return;
    }

    // For recurring reminders, schedule the next occurrence
    final nextOccurrence = reminder.getNextOccurrence();
    if (nextOccurrence != null) {
      final nextReminder = reminder.copyWith(dateTime: nextOccurrence);
      await scheduleNotification(nextReminder);
    }
  }

  // Get pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }
}