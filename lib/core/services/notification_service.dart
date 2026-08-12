import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  // Stable IDs for reminders (STEP 4)
  static const int morningReminderId = 1000;
  static const int eveningReminderId = 1001;
  static const int _oldDailyReminderId = 999; // Step 3 cleanup

  Future<void> init() async {
    try {
      tz.initializeTimeZones();
      
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          // Future navigation logic
        },
      );

      await _createNotificationChannel();
      
      // Clean up Step 3 specific ID if it exists using the stable method
      await cancelReminder(_oldDailyReminderId);
      
    } catch (e) {
      debugPrint('Notification Service Init Error: $e');
    }
  }

  Future<void> _createNotificationChannel() async {
    if (!Platform.isAndroid) return;

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'moneymap_main_channel',
      'MoneyMap Alerts',
      description: 'Important financial updates and reminders',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      showBadge: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<bool> isPermissionGranted() async {
    if (!Platform.isAndroid) return true;
    
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
            
    return await androidImplementation?.areNotificationsEnabled() ?? false;
  }

  Future<void> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            _notificationsPlugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        
        await androidImplementation?.requestNotificationsPermission();
      } else if (Platform.isIOS) {
        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
      }
    } catch (e) {
      debugPrint('Notification Permission Request Error: $e');
    }
  }

  /// Schedule repeating daily notification at custom time
  Future<void> scheduleDailyReminder({
    required int id,
    required int hour,
    required int minute,
  }) async {
    try {
      final granted = await isPermissionGranted();
      if (!granted) return;

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'moneymap_main_channel',
        'MoneyMap Alerts',
        channelDescription: 'Important financial updates and reminders',
        importance: Importance.high,
        priority: Priority.high,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      await _notificationsPlugin.zonedSchedule(
        id,
        'MoneyMap Reminder',
        'Don\'t forget to track today\'s expenses.',
        _nextInstanceOfTime(hour, minute),
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      
      debugPrint('Reminder $id scheduled for $hour:$minute');
    } catch (e) {
      debugPrint('Error scheduling reminder $id: $e');
    }
  }

  /// Cancel a specific reminder - matches NotificationProvider call
  Future<void> cancelReminder(int id) async {
    await _notificationsPlugin.cancel(id);
    debugPrint('Reminder $id cancelled');
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

// Global debug print for service layer
void debugPrint(String message) {
  if (kDebugMode) {
    print('[NotificationService] $message');
  }
}
