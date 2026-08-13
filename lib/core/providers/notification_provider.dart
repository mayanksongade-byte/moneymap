import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart' hide debugPrint;
import '../../features/home/data/models/transaction_model.dart';

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

      _isInitialized = true;
      
      if (_pendingExpense != null) {
        checkBudgetStatus(_pendingExpense!, _pendingLimit);
      }

      _applyScheduling();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
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

  /// Updates daily activity status (Point 5 - Smart Evening Insight)
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
        customBody: "You haven't added any transactions today! 📝 Take 10 seconds to log your expenses now.",
      );
    } else {
      _notificationService.scheduleEveningReminder(_eveningTime.hour, _eveningTime.minute);
    }
  }

  // --- ACTIONS & TRIGGERS ---

  void notifyTransactionAdded(TransactionModel transaction, {required String formattedAmount, required String formattedBalance}) {
    if (!_notificationsEnabled) return;
    _notificationService.showTransactionAlert(
      transaction: transaction,
      formattedAmount: formattedAmount,
      formattedBalance: formattedBalance,
    );
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

    final remaining = limit - spent;
    _notificationService.showBudgetAlert(
      id: NotificationService.budget80Id,
      title: 'Budget Alert: 80% Reached! ⚠️',
      body: "You've spent $symbol${spent.toStringAsFixed(0)} of your $symbol${limit.toStringAsFixed(0)} limit. Only $symbol${remaining.toStringAsFixed(0)} left for this month. 💸",
    );

    SharedPreferences.getInstance().then((prefs) => prefs.setBool('sent_80_alert', true));
  }

  void _triggerBudget100Alert(double spent, double limit, String symbol) {
    _sent100Alert = true;
    _sent80Alert = true; 
    notifyListeners();

    _notificationService.showBudgetAlert(
      id: NotificationService.budget100Id,
      title: 'Budget Limit Exceeded! 🚨',
      body: "Warning: You've crossed your $symbol${limit.toStringAsFixed(0)} budget. 📉",
    );

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
      _notificationService.cancelReminder(NotificationService.weeklySummaryId);
      return;
    }
    if (_morningEnabled) _notificationService.scheduleMorningReminder(_morningTime.hour, _morningTime.minute);
    if (_eveningEnabled) _notificationService.scheduleEveningReminder(_eveningTime.hour, _eveningTime.minute);
  }
}
