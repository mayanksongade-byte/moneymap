import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../auth/presentation/providers/app_auth_provider.dart';
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

  double _totalIncome = 0;
  double _totalExpense = 0;

  double _monthlyIncome = 0;
  double _monthlyExpense = 0;

  DateTime? _lastRefreshedAt;
  String _searchQuery = '';
  String _typeFilter = 'all';

  String? _currentUserId;
  AuthStatus? _currentStatus;

  final Set<String> _stagedDeletions = {};

  TransactionProvider();

  void updateAuth(String? id, AuthStatus status) {
    // Only reload if user ID changed OR status moved from initial to something else
    final isStatusResolved = status != AuthStatus.initial;
    final idChanged = _currentUserId != id;
    final statusBecameResolved = _currentStatus == AuthStatus.initial && isStatusResolved;

    if (!idChanged && !statusBecameResolved) return;

    if (kDebugMode) {
      print('DEBUG-TX: Auth updated. ID: $id, Status: $status. isResolved: $isStatusResolved');
    }

    _currentUserId = id;
    _currentStatus = status;
    
    if (id != null && isStatusResolved) {
      // Parallelize initial load
      Future.wait([
        loadTransactions(),
        loadMonthlyTransactions(),
      ]);
    } else if (isStatusResolved && id == null) {
      // Genuinely logged out
      _transactions = [];
      _monthlyTransactions = [];
      _totalIncome = 0;
      _totalExpense = 0;
      _monthlyIncome = 0;
      _monthlyExpense = 0;
      notifyListeners();
    }
  }

  // Deprecated - kept for compatibility during migration if needed
  void updateUserId(String? id) => updateAuth(id, AuthStatus.authenticated);

  Future<bool> checkServerReachability() => _service.checkServerReachability();

  // Cached filtered lists
  List<TransactionModel>? _memoizedTransactions;
  List<TransactionModel>? _memoizedMonthlyTransactions;

  List<TransactionModel> get transactions {
    if (_memoizedTransactions != null) return _memoizedTransactions!;
    _memoizedTransactions = _transactions
        .where((t) => t.id == null || !_stagedDeletions.contains(t.id))
        .toList();
    return _memoizedTransactions!;
  }

  List<TransactionModel> get monthlyTransactions {
    if (_memoizedMonthlyTransactions != null) return _memoizedMonthlyTransactions!;
    _memoizedMonthlyTransactions = _monthlyTransactions
        .where((t) => t.id == null || !_stagedDeletions.contains(t.id))
        .toList();
    return _memoizedMonthlyTransactions!;
  }

  void stageDeletion(String id) {
    _stagedDeletions.add(id);
    _invalidateMemoization();
    notifyListeners();
  }

  void unstageDeletion(String id) {
    _stagedDeletions.remove(id);
    _invalidateMemoization();
    notifyListeners();
  }

  void _invalidateMemoization() {
    _memoizedTransactions = null;
    _memoizedMonthlyTransactions = null;
  }

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
    final query = _searchQuery.trim().toLowerCase();
    final type = _typeFilter.toLowerCase();
    
    return transactions.where((t) {
      final matchesType = type == 'all' || t.type.toLowerCase() == type;
      final matchesSearch = query.isEmpty ||
          t.category.toLowerCase().contains(query) ||
          t.note.toLowerCase().contains(query);
      return matchesType && matchesSearch;
    }).toList();
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  void setTypeFilter(String type) {
    if (_typeFilter == type) return;
    _typeFilter = type;
    notifyListeners();
  }

  Future<void> loadTransactions() async {
    final uid = _currentUserId;
    if (uid == null) return;
    
    // If already loading and we have data, don't restart to avoid flicker/delays
    if (_transactionsSubscription != null && _isLoading && _transactions.isNotEmpty) return;

    _transactionsSubscription?.cancel();
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    _transactionsSubscription = _service.getTransactions(uid).listen(
      (newTransactions) {
        if (kDebugMode) print('DEBUG-TX: Received ${newTransactions.length} transactions (Cache: ${newTransactions.isEmpty ? '?' : 'Yes'})');
        _transactions = newTransactions;
        _invalidateMemoization();
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

  Future<void> loadMonthlyTransactions() async {
    final uid = _currentUserId;
    if (uid == null) return;

    if (_monthlySubscription != null && _isMonthlyLoading && _monthlyTransactions.isNotEmpty) return;

    _monthlySubscription?.cancel();
    
    _isMonthlyLoading = true;
    _error = null;
    notifyListeners();

    _monthlySubscription = _service.getMonthlyTransactions(uid).listen(
      (newMonthlyTransactions) {
        _monthlyTransactions = newMonthlyTransactions;
        _invalidateMemoization();
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
    // Removed global _isLoading to prevent background UI rebuilds/freezes
    try {
      await _service.addTransaction(transaction);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshTransactions() async {
    final uid = _currentUserId;
    if (uid == null) return;

    _isLoading = true;
    _isMonthlyLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        _service.getTransactions(uid).first,
        _service.getMonthlyTransactions(uid).first,
      ]);
      _lastRefreshedAt = DateTime.now();
    } catch (e) {
      // Ignore errors on refresh, the stream will handle updates.
    } finally {
      _isLoading = false;
      _isMonthlyLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteTransaction(String id) async {
    _error = null;
    try {
      await _service.deleteTransaction(id);
      
      // Once Firebase confirms, permanently remove from the underlying lists
      _transactions.removeWhere((t) => t.id == id);
      _monthlyTransactions.removeWhere((t) => t.id == id);
      
      // Ensure it's cleared from staged deletions too
      _stagedDeletions.remove(id);
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> restoreTransaction(TransactionModel transaction) async {
    return addTransaction(transaction);
  }

  Future<bool> updateTransaction(TransactionModel transaction) async {
    _error = null;
    try {
      await _service.updateTransaction(transaction);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false; 
    }
  }

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
