import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../config/routes/app_router.dart';
import '../../config/routes/app_routes.dart';
import '../../features/home/data/models/transaction_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static const int morningReminderId = 1000;
  static const int eveningReminderId = 1001;
  static const int weeklySummaryId = 1004; 
  static const int budget80Id = 2000;
  static const int budget100Id = 2001;

  static const String actionAddTransaction = 'add_transaction';
  static const String actionViewBudget = 'view_budget';
  static const String actionViewStatistics = 'view_statistics';

  static const String channelId = 'moneymap_smart_v16';
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
      debugPrint('[NOTIFICATION] init error: $e');
    }
  }

  void _handleNotificationTap(NotificationResponse? details) {
    if (details == null) return;
    
    if (details.actionId == actionViewBudget || details.payload == 'budget') {
      AppRouter.router.push(AppRoutes.budget);
    } else if (details.id == weeklySummaryId || details.payload == 'statistics') {
      AppRouter.router.push(AppRoutes.statistics);
    } else {
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
          ),
          iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (e) {
      debugPrint('[NOTIFICATION] Weekly Schedule error: $e');
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

  Future<void> scheduleMorningReminder(int hour, int minute) async {
    await _scheduleDaily(morningReminderId, 'Good Morning! ☀️', 'Track your morning expenses now.', hour, minute);
  }

  Future<void> scheduleEveningReminder(int hour, int minute, {String? customBody}) async {
    await _scheduleDaily(eveningReminderId, 'Day Wrap-up 🌙', customBody ?? 'Record today\'s spending.', hour, minute);
  }

  Future<void> _scheduleDaily(int id, String title, String body, int h, int m) async {
    await _notificationsPlugin.cancel(id);
    await _notificationsPlugin.zonedSchedule(
      id, title, body, _nextInstanceOfTime(h, m),
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId, channelName, 
          importance: Importance.max, 
          priority: Priority.max,
          styleInformation: BigTextStyleInformation(body),
        )
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
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

  Future<void> showTransactionAlert({required TransactionModel transaction, required String formattedAmount, required String formattedBalance}) async {
    final isExpense = transaction.type.toLowerCase() == 'expense';
    final title = isExpense ? 'Money Out! 💸' : 'Money In! 💰';
    final body = '${transaction.category}: $formattedAmount\nUpdated Balance: $formattedBalance';
    
    final int notificationId = (transaction.id?.hashCode ?? DateTime.now().millisecondsSinceEpoch) & 0x7FFFFFFF;

    await _notificationsPlugin.show(notificationId, title, body, NotificationDetails(
      android: AndroidNotificationDetails(
        channelId, channelName, 
        importance: Importance.max, 
        priority: Priority.max,
        styleInformation: BigTextStyleInformation(body),
      ),
    ));
  }

  Future<void> cancelReminder(int id) async => await _notificationsPlugin.cancel(id);

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      final android = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      try { await android?.requestExactAlarmsPermission(); } catch (_) {}
    }
  }
}

void debugPrint(String message) {
  if (kDebugMode) print(message);
}
