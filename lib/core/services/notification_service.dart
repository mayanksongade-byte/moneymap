import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../config/routes/app_router.dart';
import '../../config/routes/app_routes.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  // IDs
  static const int morningReminderId = 1000;
  static const int eveningReminderId = 1001;
  static const int weeklySummaryId = 1004; 
  static const int budget80Id = 2000;
  static const int budget100Id = 2001;

  // Action IDs
  static const String actionAddExpense = 'action_add_expense';
  static const String actionViewBudget = 'action_view_budget';
  static const String actionViewStatistics = 'action_view_statistics';
  static const String actionDismiss = 'action_dismiss';

  static const String channelId = 'moneymap_smart_v20'; // Incrementing version to ensure fresh channel settings
  static const String channelName = 'MoneyMap Smart Insights';

  Future<void> init() async {
    try {
      tz.initializeTimeZones();
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));

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

      await _createNotificationChannel();
    } catch (e) {
      if (kDebugMode) debugPrint('[NOTIFICATION] init error: $e');
    }
  }

  void _handleNotificationTap(NotificationResponse? details) {
    if (details == null) return;
    
    final String? actionId = details.actionId;
    final String? payload = details.payload;

    if (actionId != null) {
      switch (actionId) {
        case actionAddExpense:
          AppRouter.router.push(AppRoutes.addTransaction, extra: {'initialType': 'expense'});
          break;
        case actionViewBudget:
          AppRouter.router.push(AppRoutes.budget);
          break;
        case actionViewStatistics:
          AppRouter.router.push(AppRoutes.statistics);
          break;
        case actionDismiss:
          break;
      }
      return;
    }

    if (details.id == weeklySummaryId || payload == 'statistics') {
      AppRouter.router.push(AppRoutes.statistics);
    } else if (payload == 'budget') {
      AppRouter.router.push(AppRoutes.budget);
    } else if (payload == 'morning' || payload == 'evening') {
      AppRouter.router.push(AppRoutes.addTransaction);
    }
  }

  Future<void> _createNotificationChannel() async {
    if (!Platform.isAndroid) return;
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      channelId, channelName,
      description: 'Smart insights and weekly recaps',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      showBadge: true,
    );
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> scheduleWeeklySummary({
    required int hour,
    required int minute,
    required String body,
  }) async {
    try {
      await _notificationsPlugin.cancel(weeklySummaryId);
      tz.TZDateTime scheduledDate = _nextInstanceOfSunday(hour, minute);

      await _notificationsPlugin.zonedSchedule(
        weeklySummaryId,
        'Weekly Financial Recap 📊',
        body,
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId, channelName,
            importance: Importance.max,
            priority: Priority.max,
            styleInformation: BigTextStyleInformation(body),
            actions: [
              const AndroidNotificationAction(actionViewStatistics, 'VIEW STATS', showsUserInterface: true),
            ],
          ),
          iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[NOTIFICATION] Weekly Schedule error: $e');
    }
  }

  tz.TZDateTime _nextInstanceOfSunday(int hour, int minute) {
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);
    while (scheduledDate.weekday != DateTime.sunday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> scheduleMorningReminder(int hour, int minute, {String? title, String? body}) async {
    await _scheduleDaily(
      morningReminderId, 
      title ?? 'Good morning, Mayank 👋', 
      body ?? 'Start your day with clarity. Track your expenses and stay on top of your money.', 
      hour, minute, 'morning',
      actions: [
        const AndroidNotificationAction(actionAddExpense, 'ADD EXPENSE', showsUserInterface: true),
        const AndroidNotificationAction(actionDismiss, 'LATER', showsUserInterface: true),
      ],
    );
  }

  Future<void> scheduleEveningReminder(int hour, int minute, {String? title, String? body}) async {
    await _scheduleDaily(
      eveningReminderId, 
      title ?? 'Quick money check 💰', 
      body ?? 'Before the day ends, take a moment to record today\'s expenses.',
      hour, minute, 'evening',
      actions: [
        const AndroidNotificationAction(actionAddExpense, 'ADD EXPENSE', showsUserInterface: true),
        const AndroidNotificationAction(actionDismiss, 'DONE', showsUserInterface: true),
      ],
    );
  }

  Future<void> _scheduleDaily(int id, String title, String body, int h, int m, String payload, {List<AndroidNotificationAction>? actions}) async {
    await _notificationsPlugin.cancel(id);
    await _notificationsPlugin.zonedSchedule(
      id, title, body, _nextInstanceOfTime(h, m),
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId, channelName, 
          importance: Importance.max, 
          priority: Priority.max,
          styleInformation: BigTextStyleInformation(body),
          actions: actions,
        )
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  Future<void> showBudgetAlert({
    required int id, 
    required String title, 
    required String body,
    List<AndroidNotificationAction>? actions,
  }) async {
    await _notificationsPlugin.show(id, title, body, NotificationDetails(
      android: AndroidNotificationDetails(
        channelId, channelName, 
        importance: Importance.max, 
        priority: Priority.max,
        styleInformation: BigTextStyleInformation(body),
        actions: actions,
      ),
    ));
  }

  Future<void> cancelReminder(int id) async => await _notificationsPlugin.cancel(id);

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      // 1. Notification Permission (Android 13+)
      await Permission.notification.request();

      // 2. Exact Alarm Permission (Android 14+)
      if (await Permission.scheduleExactAlarm.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }

      // 3. Plugin implementation for request
      final android = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      try { await android?.requestExactAlarmsPermission(); } catch (_) {}
    } else if (Platform.isIOS) {
      await _notificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }
}
