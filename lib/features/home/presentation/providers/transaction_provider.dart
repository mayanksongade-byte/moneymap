import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/transaction_model.dart';
import '../../data/services/transaction_service.dart';

class TransactionProvider extends ChangeNotifier {
  final TransactionService _service = TransactionService();

  StreamSubscription<List<TransactionModel>>? _transactionsSubscription;
  StreamSubscription<List<TransactionModel>>? _monthlySubscription;

  List<TransactionModel> _transactions = [];
  List<TransactionModel> _monthlyTransactions = [];

  bool _isLoading = false;
  bool _isMonthlyLoading = false;
  String? _error;

  // All-time totals
  double _totalIncome = 0;
  double _totalExpense = 0;

  // Monthly totals
  double _monthlyIncome = 0;
  double _monthlyExpense = 0;

  DateTime? _lastRefreshedAt;

  // Search and Filter State
  String _searchQuery = '';
  String _typeFilter = 'all';

  // Getters
  List<TransactionModel> get transactions => _transactions;
  List<TransactionModel> get monthlyTransactions => _monthlyTransactions;

  // Independent loading states
  bool get isLoading => _isLoading;
  bool get isMonthlyLoading => _isMonthlyLoading;

  String? get error => _error;

  // All-time Getters
  double get totalIncome => _totalIncome;
  double get totalExpense => _totalExpense;
  double get balance => _totalIncome - _totalExpense;

  // Monthly Getters
  double get monthlyIncome => _monthlyIncome;
  double get monthlyExpense => _monthlyExpense;
  double get monthlyBalance => _monthlyIncome - _monthlyExpense;

  DateTime? get lastRefreshedAt => _lastRefreshedAt;
  String get searchQuery => _searchQuery;
  String get typeFilter => _typeFilter;

  /// Returns the filtered list of transactions based on current search and type filters.
  List<TransactionModel> get filteredTransactions {
    return _transactions.where((t) {
      final matchesType = _typeFilter == 'all' || t.type.toLowerCase() == _typeFilter.toLowerCase();
      final query = _searchQuery.trim().toLowerCase();
      final matchesSearch = query.isEmpty ||
          t.category.toLowerCase().contains(query) ||
          t.note.toLowerCase().contains(query);
      return matchesType && matchesSearch;
    }).toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setTypeFilter(String type) {
    _typeFilter = type;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _typeFilter = 'all';
    notifyListeners();
  }

  // Load all transactions (Bind persistent stream)
  void loadTransactions() {
    _transactionsSubscription?.cancel();
    _isLoading = true;
    notifyListeners();

    _transactionsSubscription = _service.getTransactions().listen(
          (newTransactions) {
        _transactions = newTransactions;
        _calculateTotals();
        _isLoading = false;
        _error = null;
        _lastRefreshedAt = DateTime.now();
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // Load current month transactions (Bind persistent stream)
  void loadMonthlyTransactions() {
    _monthlySubscription?.cancel();
    _isMonthlyLoading = true;
    notifyListeners();

    _monthlySubscription = _service.getMonthlyTransactions().listen(
          (newMonthlyTransactions) {
        _monthlyTransactions = newMonthlyTransactions;
        _calculateMonthlyTotals();
        _isMonthlyLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        _isMonthlyLoading = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _transactionsSubscription?.cancel();
    _monthlySubscription?.cancel();
    super.dispose();
  }

  // Add transaction
  Future<bool> addTransaction(TransactionModel transaction) async {
    _error = null;
    _isLoading = true;
    notifyListeners();
    try {
      await _service.addTransaction(transaction);
      _isLoading = false;
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      return false;
    } finally {
      notifyListeners();
    }
  }

  /// Robust Refresh: Awaits the first valid emission of both datasets from Firestore.
  Future<void> refreshTransactions() async {
    _isLoading = true;
    _isMonthlyLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Fetch the first snapshot from both streams to ensure data is current
      final results = await Future.wait([
        _service.getTransactions().first,
        _service.getMonthlyTransactions().first,
      ]);

      _transactions = results[0];
      _monthlyTransactions = results[1];

      _calculateTotals();
      _calculateMonthlyTotals();

      _lastRefreshedAt = DateTime.now();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _isMonthlyLoading = false;
      notifyListeners();
    }
  }

  // Delete transaction
  Future<bool> deleteTransaction(String id) async {
    try {
      await _service.deleteTransaction(id);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> restoreTransaction(TransactionModel transaction) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _service.addTransaction(transaction);
      _isLoading = false;
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      return false;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> updateTransaction(TransactionModel transaction) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _service.updateTransaction(transaction);
      _isLoading = false;
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      return false;
    } finally {
      notifyListeners();
    }
  }

  /// Single-pass calculation for all-time totals
  void _calculateTotals() {
    double income = 0;
    double expense = 0;

    for (final t in _transactions) {
      if (t.type.toLowerCase() == 'income') {
        income += t.amount;
      } else if (t.type.toLowerCase() == 'expense') {
        expense += t.amount;
      }
    }

    _totalIncome = income;
    _totalExpense = expense;
  }

  /// Single-pass calculation for monthly totals
  void _calculateMonthlyTotals() {
    double income = 0;
    double expense = 0;

    for (final t in _monthlyTransactions) {
      if (t.type.toLowerCase() == 'income') {
        income += t.amount;
      } else if (t.type.toLowerCase() == 'expense') {
        expense += t.amount;
      }
    }

    _monthlyIncome = income;
    _monthlyExpense = expense;
  }

  Map<String, double> getExpenseByCategory() {
    final Map<String, double> summary = {};
    for (var t in _transactions.where((t) => t.type.toLowerCase() == 'expense')) {
      summary[t.category] = (summary[t.category] ?? 0) + t.amount;
    }
    return summary;
  }

  Map<String, double> getMonthlyExpenseByCategory() {
    final Map<String, double> summary = {};
    for (var t in _monthlyTransactions.where((t) => t.type.toLowerCase() == 'expense')) {
      summary[t.category] = (summary[t.category] ?? 0) + t.amount;
    }
    return summary;
  }
}