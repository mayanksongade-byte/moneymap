import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/budget_model.dart';
import '../../data/services/budget_service.dart';

class BudgetProvider extends ChangeNotifier {
  final BudgetService _service = BudgetService();
  StreamSubscription<BudgetModel>? _subscription;

  BudgetModel _budget = const BudgetModel();
  bool _isLoading = false;
  String? _error;

  BudgetModel get budget => _budget;
  double? get monthlyLimit => _budget.monthlyLimit;
  Map<String, double> get categoryLimits => _budget.categoryLimits;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasBudget => _budget.monthlyLimit != null && _budget.monthlyLimit! > 0;

  double? limitForCategory(String category) => _budget.categoryLimits[category];

  void loadBudget() {
    _subscription?.cancel();
    _isLoading = true;
    _error = null;
    notifyListeners();

    _subscription = _service.getBudget().listen(
          (budget) {
        _budget = budget;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<bool> setBudget(double limit) async {
    try {
      await _service.setMonthlyLimit(limit);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> setCategoryLimit(String category, double limit) async {
    try {
      await _service.setCategoryLimit(category, limit);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeCategoryLimit(String category) async {
    try {
      await _service.removeCategoryLimit(category);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
