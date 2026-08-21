import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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

  final Map<String, TransactionModel> _pendingDeletions = {};

  double _totalIncome = 0;
  double _totalExpense = 0;

  double _monthlyIncome = 0;
  double _monthlyExpense = 0;

  DateTime? _lastRefreshedAt;
  String _searchQuery = '';
  String _typeFilter = 'all';

  List<TransactionModel> get transactions =>
      _transactions.where((t) => t.id == null || !_pendingDeletions.containsKey(t.id)).toList();
  List<TransactionModel> get monthlyTransactions =>
      _monthlyTransactions.where((t) => t.id == null || !_pendingDeletions.containsKey(t.id)).toList();

  bool get isLoading => _isLoading;
  bool get isMonthlyLoading => _isMonthlyLoading;
  String? get error => _error;
  double get totalIncome => _totalIncome;
  double get totalExpense => _totalExpense;
  double get balance => _totalIncome - _totalExpense;
  double get monthlyIncome => _monthlyIncome;
  double get monthlyExpense => _monthlyExpense;
  double get monthlyBalance => _monthlyIncome - _monthlyExpense;
  DateTime? get lastRefreshedAt => _lastRefreshedAt;
  String get searchQuery => _searchQuery;
  String get typeFilter => _typeFilter;

  List<TransactionModel> get filteredTransactions {
    return transactions.where((t) {
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

  Future<bool> _hasInternet() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> loadTransactions() async {
    _transactionsSubscription?.cancel();
    _isLoading = true;
    _error = null;
    notifyListeners();

    bool hasDataReceived = false;

    // 1. Start listening to the stream immediately. 
    // Firestore will emit cached data almost instantly if it exists.
    _transactionsSubscription = _service.getTransactions().listen(
      (newTransactions) {
        hasDataReceived = true;
        _transactions = newTransactions;
        _calculateTotals();
        _isLoading = false;
        _error = null; // Data arrived (cache or server), clear error.
        _lastRefreshedAt = DateTime.now();
        notifyListeners();
      },
      onError: (error) {
        if (!hasDataReceived) {
          _error = error.toString();
          _isLoading = false;
          notifyListeners();
        }
      },
    );

    // 2. Smart Delay: If after 3 seconds, still loading and NO data received, check connectivity.
    // This allows offline users with cache to see their data, but users with no cache to see an error.
    Future.delayed(const Duration(seconds: 3), () async {
      if (!hasDataReceived && _isLoading) {
        if (!await _hasInternet()) {
          _error = "No internet connection. Please check your settings.";
          _isLoading = false;
          notifyListeners();
        }
      }
    });
  }

  Future<void> loadMonthlyTransactions() async {
    _monthlySubscription?.cancel();
    _isMonthlyLoading = true;
    _error = null;
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

  Future<bool> addTransaction(TransactionModel transaction) async {
    _error = null;
    _isLoading = true;
    
    final isExpense = transaction.type.toLowerCase() == 'expense';
    if (isExpense) {
      _monthlyExpense += transaction.amount;
      _totalExpense += transaction.amount;
    } else {
      _monthlyIncome += transaction.amount;
      _totalIncome += transaction.amount;
    }
    
    notifyListeners();

    try {
      // Use a timeout to stop the infinite loader if offline.
      // Firestore still queues this in its local cache for background sync.
      await _service.addTransaction(transaction).timeout(const Duration(seconds: 4));
      _isLoading = false;
      notifyListeners();
      return true;
    } on TimeoutException {
      // If it times out (offline), Firestore has already saved it locally.
      // We stop the loader so user can see their transaction.
      _isLoading = false;
      notifyListeners();
      return true; 
    } catch (e) {
      if (isExpense) {
        _monthlyExpense -= transaction.amount;
        _totalExpense -= transaction.amount;
      } else {
        _monthlyIncome -= transaction.amount;
        _totalIncome -= transaction.amount;
      }
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshTransactions() async {
    _isLoading = true;
    _isMonthlyLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _service.getTransactions().first.timeout(const Duration(seconds: 8)),
        _service.getMonthlyTransactions().first.timeout(const Duration(seconds: 8)),
      ]);
      _transactions = results[0];
      _monthlyTransactions = results[1];
      _calculateTotals();
      _calculateMonthlyTotals();
      _lastRefreshedAt = DateTime.now();
    } catch (e) {
      if (!await _hasInternet()) {
        _error = "Refresh failed. Check internet connection.";
      }
    } finally {
      _isLoading = false;
      _isMonthlyLoading = false;
      notifyListeners();
    }
  }

  void stageDeletion(TransactionModel transaction) {
    if (transaction.id == null) return;
    if (_pendingDeletions.containsKey(transaction.id)) return;
    _pendingDeletions[transaction.id!] = transaction;
    _calculateTotals();
    _calculateMonthlyTotals();
    notifyListeners();
  }

  void undoDeletion(String id) {
    if (_pendingDeletions.containsKey(id)) {
      _pendingDeletions.remove(id);
      _calculateTotals();
      _calculateMonthlyTotals();
      notifyListeners();
    }
  }

  Future<void> finalizeDeletion(String id) async {
    final transaction = _pendingDeletions.remove(id);
    if (transaction != null) {
      _transactions.removeWhere((t) => t.id == id);
      _monthlyTransactions.removeWhere((t) => t.id == id);
      try {
        await _service.deleteTransaction(id).timeout(const Duration(seconds: 4));
      } catch (e) {
        // Silently fail if offline, deletion is done in UI/cache
      }
      notifyListeners();
    }
  }

  void finalizeAllPending() {
    if (_pendingDeletions.isEmpty) return;
    final ids = _pendingDeletions.keys.toList();
    for (final id in ids) {
      finalizeDeletion(id);
    }
  }

  Future<bool> deleteTransaction(String id) async {
    try {
      await _service.deleteTransaction(id).timeout(const Duration(seconds: 4));
      return true;
    } catch (e) {
      return true; // Still true for cached UI
    }
  }

  Future<bool> restoreTransaction(TransactionModel transaction) async {
    return addTransaction(transaction);
  }

  Future<bool> updateTransaction(TransactionModel transaction) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.updateTransaction(transaction).timeout(const Duration(seconds: 4));
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return true;
    }
  }

  void _calculateTotals() {
    double income = 0;
    double expense = 0;
    for (final t in _transactions) {
      if (t.id != null && _pendingDeletions.containsKey(t.id)) continue;
      if (t.type.toLowerCase() == 'income') income += t.amount;
      else if (t.type.toLowerCase() == 'expense') expense += t.amount;
    }
    _totalIncome = income;
    _totalExpense = expense;
  }

  void _calculateMonthlyTotals() {
    double income = 0;
    double expense = 0;
    for (final t in _monthlyTransactions) {
      if (t.id != null && _pendingDeletions.containsKey(t.id)) continue;
      if (t.type.toLowerCase() == 'income') income += t.amount;
      else if (t.type.toLowerCase() == 'expense') expense += t.amount;
    }
    _monthlyIncome = income;
    _monthlyExpense = expense;
  }

  Map<String, double> getExpenseByCategory() {
    final Map<String, double> summary = {};
    for (var t in transactions.where((t) => t.type.toLowerCase() == 'expense')) {
      summary[t.category] = (summary[t.category] ?? 0) + t.amount;
    }
    return summary;
  }

  Map<String, double> getMonthlyExpenseByCategory() {
    final Map<String, double> summary = {};
    for (var t in monthlyTransactions.where((t) => t.type.toLowerCase() == 'expense')) {
      summary[t.category] = (summary[t.category] ?? 0) + t.amount;
    }
    return summary;
  }
}
