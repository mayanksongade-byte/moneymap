import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../config/routes/app_router.dart';
import '../../config/routes/app_routes.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  bool _sent80Alert = false;
  bool _sent100Alert = false;
  int _lastMonth = -1;

  Future<void> init() async {
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        if (details.payload != null && details.payload!.isNotEmpty) {
          AppRouter.router.push(details.payload!);
        }
      },
    );
  }

  Future<void> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    await androidImplementation?.requestNotificationsPermission();
  }

  void checkBudgetAndNotify(double currentExpense, double? limit) {
    if (limit == null || limit <= 0) return;

    final now = DateTime.now();
    if (_lastMonth != now.month) {
      _lastMonth = now.month;
      _sent80Alert = false;
      _sent100Alert = false;
    }

    final percentage = (currentExpense / limit) * 100;

    if (percentage >= 100 && !_sent100Alert) {
      showInstantNotification(
        id: 101,
        title: 'Budget Exceeded! ⚠️ (${percentage.toStringAsFixed(0)}%)',
        body: 'Spent ₹${currentExpense.toInt()} of ₹${limit.toInt()}. You are over budget!',
        payload: AppRoutes.budget,
      );
      _sent100Alert = true;
      _sent80Alert = true; 
    } else if (percentage >= 80 && !_sent80Alert && percentage < 100) {
      showInstantNotification(
        id: 100,
        title: 'Budget Alert 💸 (${percentage.toStringAsFixed(0)}%)',
        body: 'You have used ${percentage.toStringAsFixed(0)}% of your budget (₹${currentExpense.toInt()}/₹${limit.toInt()}).',
        payload: AppRoutes.budget,
      );
      _sent80Alert = true;
    }
  }

  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'budget_alerts',
      'Budget Alerts',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      id, 
      title, 
      body, 
      platformChannelSpecifics,
      payload: payload ?? AppRoutes.budget,
    );
  }

  Future<void> scheduleDailyReminder({
    required int id,
    required int hour,
    required int minute,
  }) async {
    await _notificationsPlugin.zonedSchedule(
      id,
      'MoneyMap Reminder 💰',
      'Did you forget to add today\'s expenses? Add them now!',
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminders',
          'Daily Reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: AppRoutes.addTransaction,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
