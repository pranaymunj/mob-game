// notification_service.dart — Local notifications (free; no APNs needed).
// Schedules a daily "keep your streak" reminder. Remote push ("a rival took
// your turf") requires APNs + a paid Apple Developer account — see the launch
// guide — and would be added as a server push later.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _streakReminderId = 1001;

  // Initialize only — deliberately does NOT ask for permission. Prompting at
  // launch (before the player knows what Claimr is) tanks opt-in and is the
  // first thing a new user would see. See [enableReminders].
  Future<void> init() async {
    const settings = InitializationSettings(
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings: settings);
  }

  // Ask for permission and start the daily nudge. Call this only after the
  // player has felt the value (e.g. right after their first claim).
  Future<void> enableReminders() async {
    final ios = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    final android = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    if (ios == false || android == false) return; // declined — respect it
    await scheduleDailyStreakReminder();
  }

  // Turn the daily nudge off again (respects the settings toggle).
  Future<void> cancelReminders() async {
    await _plugin.cancel(id: _streakReminderId);
  }

  // A recurring daily nudge so players don't lose their streak.
  Future<void> scheduleDailyStreakReminder() async {
    const details = NotificationDetails(
      iOS: DarwinNotificationDetails(),
      android: AndroidNotificationDetails(
        'streak_reminders',
        'Streak reminders',
        channelDescription: 'Daily nudge to keep your Claimr streak',
        importance: Importance.defaultImportance,
      ),
    );
    await _plugin.periodicallyShow(
      id: _streakReminderId,
      title: '🔥 Keep your streak!',
      body: 'Open Claimr and claim some turf today.',
      repeatInterval: RepeatInterval.daily,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}
