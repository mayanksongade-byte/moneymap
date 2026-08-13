import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();

  bool _notificationsEnabled = true;
  bool _morningEnabled = true;
  TimeOfDay _morningTime = const TimeOfDay(hour: 8, minute: 0);

  bool _eveningEnabled = true;
  TimeOfDay _eveningTime = const TimeOfDay(hour: 20, minute: 0);

  // Budget alert tracking
  String _lastBudgetAlertMonth = ''; 
  bool _sent80Alert = false;
  bool _sent100Alert = false;
  bool _isInitialized = false;

  // Cache for initial check if data arrives before settings
  double? _pendingExpense;
  double? _pendingLimit;

  bool get notificationsEnabled => _notificationsEnabled;
  bool get morningEnabled => _morningEnabled;
  TimeOfDay get morningTime => _morningTime;
  bool get eveningEnabled => _eveningEnabled;
  TimeOfDay get eveningTime => _eveningTime;

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _morningEnabled = prefs.getBool('morning_reminder_enabled') ?? true;
      _morningTime = TimeOfDay(
        hour: prefs.getInt('morning_reminder_hour') ?? 8,
        minute: prefs.getInt('morning_reminder_minute') ?? 0,
      );
      _eveningEnabled = prefs.getBool('evening_reminder_enabled') ?? true;
      _eveningTime = TimeOfDay(
        hour: prefs.getInt('evening_reminder_hour') ?? 20,
        minute: prefs.getInt('evening_reminder_minute') ?? 0,
      );

      _lastBudgetAlertMonth = prefs.getString('last_budget_alert_month') ?? '';
      _sent80Alert = prefs.getBool('sent_80_alert') ?? false;
      _sent100Alert = prefs.getBool('sent_100_alert') ?? false;

      final currentMonth = "${DateTime.now().year}-${DateTime.now().month}";
      if (_lastBudgetAlertMonth != currentMonth) {
        await _resetBudgetAlerts(currentMonth);
      }

      _isInitialized = true;
      debugPrint('[NOTIFICATION PROVIDER] Settings loaded. Initialized: true');
      
      // Perform pending check if data arrived during load
      if (_pendingExpense != null) {
        checkBudgetStatus(_pendingExpense!, _pendingLimit);
      }

      notifyListeners();
      _applyScheduling();
    } catch (e) {
      debugPrint('[NOTIFICATION PROVIDER] Error loading settings: $e');
    }
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
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

  void checkBudgetStatus(double currentExpense, double? limit) {
    if (!_isInitialized) {
      _pendingExpense = currentExpense;
      _pendingLimit = limit;
      return;
    }

    if (!_notificationsEnabled || limit == null || limit <= 0) return;

    final currentMonth = "${DateTime.now().year}-${DateTime.now().month}";
    
    if (_lastBudgetAlertMonth != currentMonth) {
      _handleMonthChange(currentMonth);
    }

    final percent = (currentExpense / limit) * 100;
    debugPrint('[NOTIFICATION PROVIDER] Checking Budget: $currentExpense/$limit ($percent%)');

    if (percent >= 100 && !_sent100Alert) {
      _triggerBudget100Alert();
    } else if (percent >= 80 && !_sent80Alert && percent < 100) {
      _triggerBudget80Alert();
    }
  }

  void _handleMonthChange(String month) {
    _lastBudgetAlertMonth = month;
    _sent80Alert = false;
    _sent100Alert = false;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('last_budget_alert_month', month);
      prefs.setBool('sent_80_alert', false);
      prefs.setBool('sent_100_alert', false);
    });
    notifyListeners();
  }

  Future<void> _triggerBudget80Alert() async {
    _sent80Alert = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sent_80_alert', true);
    
    await _notificationService.showBudgetAlert(
      id: NotificationService.budget80Id,
      title: 'Budget check ⚠️',
      body: "You've used 80% of your monthly budget.",
      actions: [
        const AndroidNotificationAction(NotificationService.actionViewBudget, 'View Budget', showsUserInterface: true),
      ],
    );
    notifyListeners();
  }

  Future<void> _triggerBudget100Alert() async {
    _sent100Alert = true;
    _sent80Alert = true; // Mark 80 as sent to prevent it firing if expense drops
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sent_100_alert', true);
    await prefs.setBool('sent_80_alert', true);
    
    await _notificationService.showBudgetAlert(
      id: NotificationService.budget100Id,
      title: 'Budget exceeded',
      body: "You've crossed your monthly budget. Review your spending to stay in control.",
      actions: [
        const AndroidNotificationAction(NotificationService.actionViewBudget, 'View Budget', showsUserInterface: true),
        const AndroidNotificationAction(NotificationService.actionViewStatistics, 'View Statistics', showsUserInterface: true),
      ],
    );
    notifyListeners();
  }

  Future<void> _resetBudgetAlerts(String month) async {
    _lastBudgetAlertMonth = month;
    _sent80Alert = false;
    _sent100Alert = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_budget_alert_month', month);
    await prefs.setBool('sent_80_alert', false);
    await prefs.setBool('sent_100_alert', false);
  }

  void _applyScheduling() {
    if (!_notificationsEnabled) {
      _notificationService.cancelReminder(NotificationService.morningReminderId);
      _notificationService.cancelReminder(NotificationService.eveningReminderId);
      return;
    }

    if (_morningEnabled) {
      _notificationService.scheduleMorningReminder(_morningTime.hour, _morningTime.minute);
    } else {
      _notificationService.cancelReminder(NotificationService.morningReminderId);
    }

    if (_eveningEnabled) {
      _notificationService.scheduleEveningReminder(_eveningTime.hour, _eveningTime.minute);
    } else {
      _notificationService.cancelReminder(NotificationService.eveningReminderId);
    }
  }
}
