import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:moneymap/features/home/data/models/category_model.dart';
import 'package:moneymap/features/category/data/services/category_service.dart';

class CategoryProvider extends ChangeNotifier {
  // GetIt instance નો સીધો ઉપયોગ કરવાથી "undefined" એરર નહીં આવે
  final CategoryService _service = GetIt.instance<CategoryService>();

  StreamSubscription<List<CategoryModel>>? _subscription;

  List<CategoryModel> _customCategories = [];
  bool _isLoading = false;
  String? _error;

  List<CategoryModel> get customCategories => _customCategories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<CategoryModel> byType(String type) {
    final defaults = CategoryModel.getByType(type);
    final custom = _customCategories.where((c) => c.type == type).toList();
    return [...defaults, ...custom];
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
    _subscription?.cancel();
    _isLoading = true;
    notifyListeners();

    _subscription = _service.getCustomCategories().listen(
          (list) {
        _customCategories = list;
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
      await _service.addCategory(category).timeout(const Duration(seconds: 4));
      _isLoading = false;
      notifyListeners();
      return true;
    } on TimeoutException {
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
      await _service.updateCategory(category).timeout(const Duration(seconds: 4));
      _isLoading = false;
      notifyListeners();
      return true;
    } on TimeoutException {
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
      await _service.deleteCategory(id).timeout(const Duration(seconds: 4));
      notifyListeners();
      return true;
    } on TimeoutException {
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
