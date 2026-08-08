import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/transaction_model.dart';

class TransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get _userId => _auth.currentUser?.uid;

  // Get transactions collection reference
  CollectionReference get _transactionsRef =>
      _firestore.collection('transactions');

  // Add transaction
  Future<TransactionModel> addTransaction(TransactionModel transaction) async {
    if (_userId == null) throw Exception('User not logged in');

    final newTransaction = transaction.copyWith(
      userId: _userId!,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final docRef = await _transactionsRef.add(newTransaction.toMap());
    return newTransaction.copyWith(id: docRef.id);
  }

  // Get all transactions for current user
  Stream<List<TransactionModel>> getTransactions() {
    if (_userId == null) {
      return Stream.value([]);
    }

    return _transactionsRef
        .where('userId', isEqualTo: _userId!)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
    });
  }

  // Get transactions for current month
  Stream<List<TransactionModel>> getMonthlyTransactions() {
    if (_userId == null) {
      return Stream.value([]);
    }

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfNextMonth = DateTime(now.year, now.month + 1, 1);

    return _transactionsRef
        .where('userId', isEqualTo: _userId!)
        .where('date', isGreaterThanOrEqualTo: startOfMonth)
        .where('date', isLessThan: startOfNextMonth)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
    });
  }

  // Delete transaction
  Future<void> deleteTransaction(String id) async {
    if (_userId == null) throw Exception('User not logged in');
    final document = await _transactionsRef.doc(id).get();
    final data = document.data() as Map<String, dynamic>?;
    if (!document.exists || data?['userId'] != _userId) {
      throw Exception('Transaction not found');
    }
    
    await document.reference.delete();
  }

  // Update transaction
  Future<void> updateTransaction(TransactionModel transaction) async {
    if (_userId == null) throw Exception('User not logged in');
    if (transaction.id == null) throw Exception('Transaction ID is null');

    final updated = transaction.copyWith(
      updatedAt: DateTime.now(),
    );

    final document = await _transactionsRef.doc(transaction.id).get();
    final data = document.data() as Map<String, dynamic>?;
    if (!document.exists || data?['userId'] != _userId) {
      throw Exception('Transaction not found');
    }
    await document.reference.update(updated.toMap());
  }

  // Get total income
  Future<double> getTotalIncome() async {
    if (_userId == null) return 0.0;

    final snapshot = await _transactionsRef
        .where('userId', isEqualTo: _userId!)
        .where('type', isEqualTo: 'income')
        .get();

    double total = 0.0;
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['amount'] ?? 0.0).toDouble();
    }
    return total;
  }

  // Get total expense
  Future<double> getTotalExpense() async {
    if (_userId == null) return 0.0;

    final snapshot = await _transactionsRef
        .where('userId', isEqualTo: _userId!)
        .where('type', isEqualTo: 'expense')
        .get();

    double total = 0.0;
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['amount'] ?? 0.0).toDouble();
    }
    return total;
  }

  // Get category wise summary
  Future<Map<String, double>> getCategorySummary() async {
    if (_userId == null) return {};

    final snapshot = await _transactionsRef
        .where('userId', isEqualTo: _userId!)
        .where('type', isEqualTo: 'expense')
        .get();

    final Map<String, double> summary = {};
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final category = data['category'] ?? 'Other';
      final amount = (data['amount'] ?? 0.0).toDouble();
      summary[category] = (summary[category] ?? 0.0) + amount;
    }
    return summary;
  }
}
