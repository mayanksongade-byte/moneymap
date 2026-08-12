import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();

  bool _morningEnabled = true;
  TimeOfDay _morningTime = const TimeOfDay(hour: 8, minute: 0);

  bool _eveningEnabled = true;
  TimeOfDay _eveningTime = const TimeOfDay(hour: 20, minute: 0);

  bool get morningEnabled => _morningEnabled;
  TimeOfDay get morningTime => _morningTime;
  bool get eveningEnabled => _eveningEnabled;
  TimeOfDay get eveningTime => _eveningTime;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    _morningEnabled = prefs.getBool('morning_reminder_enabled') ?? true;
    final morningHour = prefs.getInt('morning_reminder_hour') ?? 8;
    final morningMinute = prefs.getInt('morning_reminder_minute') ?? 0;
    _morningTime = TimeOfDay(hour: morningHour, minute: morningMinute);

    _eveningEnabled = prefs.getBool('evening_reminder_enabled') ?? true;
    final eveningHour = prefs.getInt('evening_reminder_hour') ?? 20;
    final eveningMinute = prefs.getInt('evening_reminder_minute') ?? 0;
    _eveningTime = TimeOfDay(hour: eveningHour, minute: eveningMinute);

    notifyListeners();
    _applyScheduling();
  }

  Future<void> setMorningEnabled(bool value) async {
    _morningEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('morning_reminder_enabled', value);
    notifyListeners();
    _applyScheduling();
  }

  Future<void> setMorningTime(TimeOfDay time) async {
    _morningTime = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('morning_reminder_hour', time.hour);
    await prefs.setInt('morning_reminder_minute', time.minute);
    notifyListeners();
    _applyScheduling();
  }

  Future<void> setEveningEnabled(bool value) async {
    _eveningEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('evening_reminder_enabled', value);
    notifyListeners();
    _applyScheduling();
  }

  Future<void> setEveningTime(TimeOfDay time) async {
    _eveningTime = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('evening_reminder_hour', time.hour);
    await prefs.setInt('evening_reminder_minute', time.minute);
    notifyListeners();
    _applyScheduling();
  }

  void _applyScheduling() {
    // Handle Morning Reminder
    if (_morningEnabled) {
      _notificationService.scheduleDailyReminder(
        id: NotificationService.morningReminderId,
        hour: _morningTime.hour,
        minute: _morningTime.minute,
      );
    } else {
      _notificationService.cancelReminder(NotificationService.morningReminderId);
    }

    // Handle Evening Reminder
    if (_eveningEnabled) {
      _notificationService.scheduleDailyReminder(
        id: NotificationService.eveningReminderId,
        hour: _eveningTime.hour,
        minute: _eveningTime.minute,
      );
    } else {
      _notificationService.cancelReminder(NotificationService.eveningReminderId);
    }
  }
}
