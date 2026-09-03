import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:moneymap/features/auth/presentation/providers/app_auth_provider.dart';
import 'package:moneymap/features/home/data/models/category_model.dart';
import 'package:moneymap/features/category/data/services/category_service.dart';

class CategoryProvider extends ChangeNotifier {
  final CategoryService _service = GetIt.instance<CategoryService>();

  StreamSubscription<List<CategoryModel>>? _subscription;

  List<CategoryModel> _customCategories = [];
  bool _isLoading = false;
  String? _error;

  String? _currentUserId;
  AuthStatus? _currentStatus;

  void updateAuth(String? id, AuthStatus status) {
    final isStatusResolved = status != AuthStatus.initial;
    final idChanged = _currentUserId != id;
    final statusBecameResolved = _currentStatus == AuthStatus.initial && isStatusResolved;

    if (!idChanged && !statusBecameResolved) return;

    _currentUserId = id;
    _currentStatus = status;
    
    if (id != null && isStatusResolved) {
      loadCategories();
    } else if (isStatusResolved && id == null) {
      _customCategories = [];
      notifyListeners();
    }
  }

  void updateUserId(String? id) => updateAuth(id, AuthStatus.authenticated);

  List<CategoryModel> get customCategories => _customCategories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final Map<String, List<CategoryModel>> _memoizedByType = {};

  List<CategoryModel> byType(String type) {
    if (_memoizedByType.containsKey(type)) return _memoizedByType[type]!;
    
    final defaults = CategoryModel.getByType(type);
    final custom = _customCategories.where((c) => c.type == type).toList();
    final result = [...defaults, ...custom];
    _memoizedByType[type] = result;
    return result;
  }

  void _invalidateCache() {
    _memoizedByType.clear();
  }

  CategoryModel? findByName(String name, {required String type}) {
    try {
      return byType(type).firstWhere(
            (c) => c.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  bool isCustom(String categoryId) {
    return _customCategories.any((c) => c.id == categoryId);
  }

  void loadCategories() {
    final uid = _currentUserId;
    if (uid == null) return;
    
    if (_subscription != null && _isLoading && _customCategories.isNotEmpty) return;

    _subscription?.cancel();
    
    _isLoading = true;
    notifyListeners();

    _subscription = _service.getCustomCategories(uid).listen(
          (list) {
        _customCategories = list;
        _invalidateCache();
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

  Future<bool> addCategory(CategoryModel category) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _service.addCategory(category);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCategory(CategoryModel category) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _service.updateCategory(category);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCategory(String id) async {
    try {
      await _service.deleteCategory(id);
      notifyListeners();
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
