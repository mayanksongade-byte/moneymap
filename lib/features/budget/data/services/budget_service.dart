import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/budget_model.dart';

class BudgetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

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
    if (userId == null) throw Exception('Not logged in');

    await _firestore.collection('budgets').doc(userId).set({
      'userId': userId,
      'monthlyLimit': limit,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setCategoryLimit(String category, double limit) async {
    final userId = _userId;
    if (userId == null) throw Exception('Not logged in');

    await _firestore.collection('budgets').doc(userId).set({
      'userId': userId,
      'categoryLimits': {category: limit},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeCategoryLimit(String category) async {
    final userId = _userId;
    if (userId == null) throw Exception('Not logged in');

    await _firestore.collection('budgets').doc(userId).set({
      'categoryLimits': {category: FieldValue.delete()},
    }, SetOptions(merge: true));
  }
}