import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/notification_service.dart' hide debugPrint;
import '../../features/home/data/models/transaction_model.dart';
import '../models/notification_history_model.dart';

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

  // Notification History
  List<NotificationHistoryModel> _history = [];
  List<NotificationHistoryModel> get history => _history;
  int get unreadCount => _history.where((n) => !n.isRead).length;

  // Track which IDs have been handled (added or deleted) so they don't reappear
  Set<String> _handledIds = {};

  // Cache for initial check
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

      // Load handled IDs
      final List<String> handledList = prefs.getStringList('handled_notification_ids') ?? [];
      _handledIds = handledList.toSet();

      await _loadHistory(prefs);
      
      _isInitialized = true;
      
      _checkAndRecordScheduledReminders();

      if (_pendingExpense != null) {
        checkBudgetStatus(_pendingExpense!, _pendingLimit);
      }

      _applyScheduling();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  // --- HISTORY MANAGEMENT ---

  Future<void> _loadHistory(SharedPreferences prefs) async {
    final String? historyJson = prefs.getString('notification_history');
    if (historyJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(historyJson);
        _history = decoded.map((item) => NotificationHistoryModel.fromJson(item)).toList();
        _history.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } catch (e) {
        debugPrint('Error decoding notification history: $e');
        _history = [];
      }
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_history.map((n) => n.toJson()).toList());
    await prefs.setString('notification_history', encoded);
    
    // Also save handled IDs
    await prefs.setStringList('handled_notification_ids', _handledIds.toList());
  }

  void addNotification(NotificationHistoryModel notification) {
    // Avoid adding if it's already in history or has been handled/deleted before
    if (_handledIds.contains(notification.id)) return;
    
    _history.insert(0, notification);
    _handledIds.add(notification.id);
    _saveHistory();
    notifyListeners();
  }

  void markAsRead(String id) {
    final index = _history.indexWhere((n) => n.id == id);
    if (index != -1) {
      _history[index].isRead = true;
      _saveHistory();
      notifyListeners();
    }
  }

  void markAllAsRead() {
    for (var n in _history) {
      n.isRead = true;
    }
    _saveHistory();
    notifyListeners();
  }

  void deleteNotification(String id) {
    _history.removeWhere((n) => n.id == id);
    // Keep it in _handledIds so it doesn't reappear on app restart
    _saveHistory();
    notifyListeners();
  }

  void clearHistory() {
    _history.clear();
    // Note: We don't clear _handledIds here to prevent old daily reminders from popping back
    _saveHistory();
    notifyListeners();
  }

  // --- SMART NOTIFICATION LOGIC ---

  void updateSmartInsights(List<TransactionModel> transactions, String symbol) {
    if (!_notificationsEnabled || !_isInitialized) return;

    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    
    final weeklyExpenses = transactions.where((t) => 
      t.type.toLowerCase() == 'expense' && t.date.isAfter(sevenDaysAgo)
    ).toList();

    if (weeklyExpenses.isEmpty) {
      _notificationService.scheduleWeeklySummary(
        hour: 11,
        minute: 30,
        body: "No expenses recorded this week. Tracking helps you save more! 📝",
      );
      return;
    }

    double totalSpent = 0;
    Map<String, double> categoryMap = {};

    for (var t in weeklyExpenses) {
      totalSpent += t.amount;
      categoryMap[t.category] = (categoryMap[t.category] ?? 0) + t.amount;
    }

    if (categoryMap.isEmpty) return;

    String topCategory = categoryMap.entries.first.key;
    double maxAmount = categoryMap.entries.first.value;
    categoryMap.forEach((key, value) {
      if (value > maxAmount) {
        topCategory = key;
        maxAmount = value;
      }
    });

    final String message = "Weekly Recap: You spent $symbol${totalSpent.toStringAsFixed(0)} this week. 📊 Your biggest expense was $topCategory ($symbol${maxAmount.toStringAsFixed(0)}).";

    _notificationService.scheduleWeeklySummary(hour: 11, minute: 30, body: message);
  }

  void updateDailyActivityInsight(List<TransactionModel> transactions) {
    if (!_notificationsEnabled || !_isInitialized || !_eveningEnabled) return;

    final now = DateTime.now();
    final todayLogs = transactions.where((t) => 
      t.date.year == now.year && t.date.month == now.month && t.date.day == now.day
    ).toList();

    if (todayLogs.isEmpty) {
      _notificationService.scheduleEveningReminder(
        _eveningTime.hour, 
        _eveningTime.minute,
        title: 'Quick money check 💰',
        body: "You haven't added any transactions today! 📝 Take 10 seconds to log your expenses now.",
      );
    } else {
      _notificationService.scheduleEveningReminder(
        _eveningTime.hour, 
        _eveningTime.minute,
        title: 'Quick money check 💰',
        body: "Before the day ends, take a moment to record today's expenses.",
      );
    }
  }

  // --- ACTIONS & TRIGGERS ---

  void notifyTransactionAdded(TransactionModel transaction, {required String formattedAmount, required String formattedBalance}) {
    return;
  }

  void checkBudgetStatus(double currentExpense, double? limit, {String currencySymbol = '₹'}) {
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

    if (percent >= 100 && !_sent100Alert) {
      _triggerBudget100Alert(currentExpense, limit, currencySymbol);
    } else if (percent >= 80 && !_sent80Alert && percent < 100) {
      _triggerBudget80Alert(currentExpense, limit, currencySymbol);
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

  void _triggerBudget80Alert(double spent, double limit, String symbol) {
    _sent80Alert = true;
    notifyListeners();

    final title = 'Budget Alert: 80% Reached! ⚠️';
    final remaining = limit - spent;
    final body = "You've spent $symbol${spent.toStringAsFixed(0)} of your $symbol${limit.toStringAsFixed(0)} limit. Only $symbol${remaining.toStringAsFixed(0)} left for this month. 💸";
    
    _notificationService.showBudgetAlert(
      id: NotificationService.budget80Id,
      title: title,
      body: body,
      actions: [
        const AndroidNotificationAction(NotificationService.actionViewBudget, 'VIEW BUDGET', showsUserInterface: true),
        const AndroidNotificationAction(NotificationService.actionDismiss, 'DISMISS', showsUserInterface: true),
      ],
    );

    addNotification(NotificationHistoryModel(
      id: 'budget_80_${DateTime.now().year}_${DateTime.now().month}',
      type: 'budget_alert',
      title: title,
      message: body,
      createdAt: DateTime.now(),
    ));

    SharedPreferences.getInstance().then((prefs) => prefs.setBool('sent_80_alert', true));
  }

  void _triggerBudget100Alert(double spent, double limit, String symbol) {
    _sent100Alert = true;
    _sent80Alert = true; 
    notifyListeners();

    final title = 'Budget Limit Exceeded! 🚨';
    final body = "Stop! You've crossed your $symbol${limit.toStringAsFixed(0)} monthly budget. 📉";

    _notificationService.showBudgetAlert(
      id: NotificationService.budget100Id,
      title: title,
      body: body,
      actions: [
        const AndroidNotificationAction(NotificationService.actionViewBudget, 'REVIEW BUDGET', showsUserInterface: true),
        const AndroidNotificationAction(NotificationService.actionViewStatistics, 'VIEW SPENDING', showsUserInterface: true),
      ],
    );

    addNotification(NotificationHistoryModel(
      id: 'budget_100_${DateTime.now().year}_${DateTime.now().month}',
      type: 'budget_exceeded',
      title: title,
      message: body,
      createdAt: DateTime.now(),
    ));

    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('sent_100_alert', true);
      prefs.setBool('sent_80_alert', true);
    });
  }

  // --- SETTINGS ---

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    if (value) await _notificationService.requestPermissions();
    _applyScheduling();
    notifyListeners();
  }

  Future<void> setMorningEnabled(bool value) async {
    _morningEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('morning_reminder_enabled', value);
    _applyScheduling();
    notifyListeners();
  }

  Future<void> setMorningTime(TimeOfDay time) async {
    _morningTime = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('morning_reminder_hour', time.hour);
    await prefs.setInt('morning_reminder_minute', time.minute);
    _applyScheduling();
    notifyListeners();
  }

  Future<void> setEveningEnabled(bool value) async {
    _eveningEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('evening_reminder_enabled', value);
    _applyScheduling();
    notifyListeners();
  }

  Future<void> setEveningTime(TimeOfDay time) async {
    _eveningTime = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('evening_reminder_hour', time.hour);
    await prefs.setInt('evening_reminder_minute', time.minute);
    _applyScheduling();
    notifyListeners();
  }

  void _applyScheduling() {
    if (!_notificationsEnabled) {
      _notificationService.cancelReminder(NotificationService.morningReminderId);
      _notificationService.cancelReminder(NotificationService.eveningReminderId);
      _notificationService.cancelReminder(NotificationService.weeklySummaryId);
      return;
    }
    if (_morningEnabled) {
      _notificationService.scheduleMorningReminder(
        _morningTime.hour, 
        _morningTime.minute,
        title: 'Good morning, Mayank 👋',
        body: 'Start your day with clarity. Track your expenses and stay on top of your money.',
      );
    }
    if (_eveningEnabled) {
      _notificationService.scheduleEveningReminder(
        _eveningTime.hour, 
        _eveningTime.minute,
        title: 'Quick money check 💰',
        body: "Before the day ends, take a moment to record today's expenses.",
      );
    }
  }

  void _checkAndRecordScheduledReminders() {
    if (!_notificationsEnabled) return;

    final now = DateTime.now();
    
    // Check Morning Reminder
    if (_morningEnabled) {
      final morningDt = DateTime(now.year, now.month, now.day, _morningTime.hour, _morningTime.minute);
      if (now.isAfter(morningDt)) {
        final id = 'morning_${now.year}_${now.month}_${now.day}';
        // Only add if it's NOT already in handled list
        if (!_handledIds.contains(id)) {
          addNotification(NotificationHistoryModel(
            id: id,
            type: 'morning_reminder',
            title: 'Good morning, Mayank 👋',
            message: 'Start your day with clarity. Track your expenses and stay on top of your money.',
            createdAt: morningDt,
          ));
        }
      }
    }

    // Check Evening Reminder
    if (_eveningEnabled) {
      final eveningDt = DateTime(now.year, now.month, now.day, _eveningTime.hour, _eveningTime.minute);
      if (now.isAfter(eveningDt)) {
        final id = 'evening_${now.year}_${now.month}_${now.day}';
        // Only add if it's NOT already in handled list
        if (!_handledIds.contains(id)) {
          addNotification(NotificationHistoryModel(
            id: id,
            type: 'evening_reminder',
            title: 'Quick money check 💰',
            message: "Before the day ends, take a moment to record today's expenses.",
            createdAt: eveningDt,
          ));
        }
      }
    }
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
}
