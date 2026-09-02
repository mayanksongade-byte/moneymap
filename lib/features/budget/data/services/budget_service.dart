import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/budget_model.dart';

class BudgetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  /// Helper to ensure operation is performed online.
  Future<T> _runOnlineWrite<T>(Future<T> Function(Transaction) action) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'Not logged in';

      // Pre-flight reachability check
      await _firestore.collection('budgets')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 2))
          .catchError((_) => throw 'Please check your internet connection and try again.');

      return await _firestore.runTransaction(action).timeout(const Duration(seconds: 5));
    } catch (e) {
      if (kDebugMode) print('DEBUG: Firestore write error: $e');
      if (e is String) rethrow;
      if (e is TimeoutException || 
          (e is FirebaseException && (e.code == 'unavailable' || e.code == 'deadline-exceeded'))) {
        throw 'Please check your internet connection and try again.';
      }
      rethrow;
    }
  }

  /// Streams the user's full budget doc (overall limit + per-category limits).
  Stream<BudgetModel> getBudget() {
    final userId = _userId;
    if (userId == null) return Stream.value(const BudgetModel());

    return _firestore.collection('budgets').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return const BudgetModel();
      return BudgetModel.fromMap(doc.data());
    });
  }

  Future<void> setMonthlyLimit(double limit) async {
    final userId = _userId;
    if (userId == null) throw 'Not logged in';

    await _runOnlineWrite((tx) async {
      tx.set(_firestore.collection('budgets').doc(userId), {
        'userId': userId,
        'monthlyLimit': limit,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> setCategoryLimit(String category, double limit) async {
    final userId = _userId;
    if (userId == null) throw 'Not logged in';

    await _runOnlineWrite((tx) async {
      tx.set(_firestore.collection('budgets').doc(userId), {
        'userId': userId,
        'categoryLimits': {category: limit},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> removeCategoryLimit(String category) async {
    final userId = _userId;
    if (userId == null) throw 'Not logged in';

    await _runOnlineWrite((tx) async {
      tx.set(_firestore.collection('budgets').doc(userId), {
        'categoryLimits': {category: FieldValue.delete()},
      }, SetOptions(merge: true));
    });
  }
}
