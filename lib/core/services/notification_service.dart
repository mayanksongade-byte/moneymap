import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../config/routes/app_router.dart';
import '../../config/routes/app_routes.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  // Stable IDs (Permanent)
  static const int morningReminderId = 1000;
  static const int eveningReminderId = 1001;
  
  // Stable IDs (Temporary Reminders)
  static const int tempMorningReminderId = 1002;
  static const int tempEveningReminderId = 1003;

  // Budget IDs
  static const int budget80Id = 2000;
  static const int budget100Id = 2001;
  static const int diagnosticId = 9999;

  // IMPORTANT: Changed channel ID to force Android to apply new HIGH IMPORTANCE settings
  static const String channelId = 'moneymap_urgent_alerts_v1';
  static const String channelName = 'MoneyMap Alerts';

  // Action Identifiers
  static const String actionAddTransaction = 'add_transaction';
  static const String actionRemindLater30 = 'remind_later_30';
  static const String actionAddExpense = 'add_expense';
  static const String actionRemindLater60 = 'remind_later_60';
  static const String actionViewBudget = 'view_budget';
  static const String actionViewStatistics = 'view_statistics';

  Future<void> init() async {
    try {
      tz.initializeTimeZones();
      try {
        final String timeZoneName = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(timeZoneName));
        debugPrint('[NOTIFICATION] Local Timezone: $timeZoneName');
      } catch (e) {
        debugPrint('[NOTIFICATION] Timezone error: $e');
      }

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      await _notificationsPlugin.initialize(
        const InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        ),
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          _handleNotificationTap(details);
        },
      );

      final launchDetails = await _notificationsPlugin.getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
        _handleNotificationTap(launchDetails.notificationResponse);
      }

      await _createNotificationChannel();
      debugPrint('[NOTIFICATION] Service Initialized with URGENT channel');
    } catch (e) {
      debugPrint('[NOTIFICATION] init EXCEPTION: $e');
    }
  }

  void _handleNotificationTap(NotificationResponse? details) {
    if (details == null) return;
    
    final payload = details.payload;
    final actionId = details.actionId;

    if (actionId != null) {
      switch (actionId) {
        case actionAddTransaction:
          AppRouter.router.push(AppRoutes.addTransaction);
          break;
        case actionAddExpense:
          AppRouter.router.push(AppRoutes.addTransaction, extra: {'initialType': 'expense'});
          break;
        case actionViewBudget:
          AppRouter.router.push(AppRoutes.budget);
          break;
        case actionViewStatistics:
          AppRouter.router.push(AppRoutes.statistics);
          break;
        case actionRemindLater30:
          scheduleTemporaryReminder(
            id: tempMorningReminderId,
            title: 'Good morning 👋',
            body: 'Start your day with a clear view of your money.',
            minutes: 30,
            payload: 'morning',
          );
          break;
        case actionRemindLater60:
          scheduleTemporaryReminder(
            id: tempEveningReminderId,
            title: 'How was your spending today? 💳',
            body: 'Take a moment to record today\'s expenses.',
            minutes: 60,
            payload: 'evening',
          );
          break;
      }
      return;
    }

    if (payload != null) {
      if (payload == 'morning' || payload == 'evening') {
        AppRouter.router.push(AppRoutes.addTransaction);
      } else if (payload == 'budget') {
        AppRouter.router.push(AppRoutes.budget);
      }
    }
  }

  Future<void> _createNotificationChannel() async {
    if (!Platform.isAndroid) return;
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: 'Instant reminders and budget alerts',
      importance: Importance.max, // High priority heads-up
      enableVibration: true,
      playSound: true,
      showBadge: true,
    );
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> scheduleMorningReminder(int hour, int minute) async {
    await _scheduleDaily(
      id: morningReminderId,
      title: 'Good morning 👋',
      body: 'Start your day with a clear view of your money.',
      hour: hour,
      minute: minute,
      payload: 'morning',
      actions: [
        const AndroidNotificationAction(actionAddTransaction, 'Add Transaction', showsUserInterface: true),
        const AndroidNotificationAction(actionRemindLater30, 'Remind Later', showsUserInterface: true),
      ],
    );
  }

  Future<void> scheduleEveningReminder(int hour, int minute) async {
    await _scheduleDaily(
      id: eveningReminderId,
      title: 'How was your spending today? 💳',
      body: 'Take a moment to record today\'s expenses.',
      hour: hour,
      minute: minute,
      payload: 'evening',
      actions: [
        const AndroidNotificationAction(actionAddExpense, 'Add Expense', showsUserInterface: true),
        const AndroidNotificationAction(actionRemindLater60, 'Remind in 1 Hour', showsUserInterface: true),
      ],
    );
  }

  Future<void> _scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
    List<AndroidNotificationAction>? actions,
  }) async {
    try {
      final nextTime = _nextInstanceOfTime(hour, minute);
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        nextTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId, channelName,
            importance: Importance.max,
            priority: Priority.max,
            actions: actions,
            showWhen: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('[NOTIFICATION] Schedule error for ID $id: $e');
    }
  }

  Future<void> scheduleTemporaryReminder({
    required int id,
    required String title,
    required String body,
    required int minutes,
    String? payload,
  }) async {
    try {
      await _notificationsPlugin.cancel(id);
      final scheduledDate = tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes));
      await _notificationsPlugin.zonedSchedule(
        id, title, body, scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId, channelName,
            importance: Importance.max,
            priority: Priority.max,
            showWhen: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('[NOTIFICATION] Temp Schedule error: $e');
    }
  }

  Future<void> showBudgetAlert({
    required int id,
    required String title,
    required String body,
    List<AndroidNotificationAction>? actions,
  }) async {
    try {
      await _notificationsPlugin.show(
        id, title, body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId, channelName,
            importance: Importance.max,
            priority: Priority.max,
            actions: actions,
            showWhen: true,
            onlyAlertOnce: false, // Ensures alert is delivered instantly every time it's triggered
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'budget',
      );
      debugPrint('[NOTIFICATION] Budget alert triggered instantly: $title');
    } catch (e) {
      debugPrint('[NOTIFICATION] Budget alert error: $e');
    }
  }

  Future<void> cancelReminder(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      final android = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
    }
  }
}

void debugPrint(String message) {
  if (kDebugMode) print(message);
}
