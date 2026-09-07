import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/transaction_model.dart';

class TransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _manualUserId;

  void updateAuth(String? userId) {
    _manualUserId = userId;
  }

  // Get current user ID
  String? get _userId => _auth.currentUser?.uid ?? _manualUserId;

  // Get transactions collection reference
  CollectionReference get _transactionsRef =>
      _firestore.collection('transactions');

  /// Helper to ensure operation is performed online and NOT queued if offline.
  Future<T> _runOnlineWrite<T>(Future<T> Function(Transaction) action) async {
    try {
      // 1. Pre-flight check: Verify we can actually reach the server.
      // This is crucial because runTransaction.timeout() doesn't cancel the native operation.
      final user = _auth.currentUser;
      if (user == null) throw 'User not logged in';
      
      final isReachable = await checkServerReachability();
      if (!isReachable) {
        throw 'Please check your internet connection and try again.';
      }

      // 2. Perform the actual write in a transaction
      return await _firestore.runTransaction(action).timeout(const Duration(seconds: 5));
    } catch (e) {
      if (kDebugMode) print('DEBUG: Firestore write error: $e');
      if (e is String) rethrow; // Re-throw our custom error message
      
      if (e is TimeoutException || 
          (e is FirebaseException && (e.code == 'unavailable' || e.code == 'deadline-exceeded'))) {
        throw 'Please check your internet connection and try again.';
      }
      rethrow;
    }
  }

  /// Verifies if the Firebase backend is reachable via a server-source read.
  Future<bool> checkServerReachability() async {
    try {
      final userId = _userId;
      if (userId == null) return false;

      // Fast server-only metadata check
      await _transactionsRef
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 2));
      return true;
    } catch (e) {
      if (kDebugMode) print('DEBUG: Reachability check failed: $e');
      return false;
    }
  }

  // Add transaction
  Future<TransactionModel> addTransaction(TransactionModel transaction) async {
    final userId = _userId;
    if (userId == null) throw 'User not logged in';

    final newTransaction = transaction.copyWith(
      userId: userId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final docRef = _transactionsRef.doc();
    
    final isOnline = await checkServerReachability();
    
    if (isOnline) {
      await _runOnlineWrite((tx) async {
        tx.set(docRef, newTransaction.toMap());
      });
    } else {
      // Offline fallback: Direct set() supports persistence
      await docRef.set(newTransaction.toMap());
    }

    return newTransaction.copyWith(id: docRef.id);
  }

  // Get all transactions for a user
  Stream<List<TransactionModel>> getTransactions(String userId) {
    return _transactionsRef
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
    });
  }

  // Get transactions for current month
  Stream<List<TransactionModel>> getMonthlyTransactions(String userId) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfNextMonth = DateTime(now.year, now.month + 1, 1);

    return _transactionsRef
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: startOfMonth)
        .where('date', isLessThan: startOfNextMonth)
        .orderBy('date', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
    });
  }

  // Delete transaction
  Future<void> deleteTransaction(String id) async {
    if (_userId == null) throw 'User not logged in';
    
    final docRef = _firestore.collection('transactions').doc(id);
    final isOnline = await checkServerReachability();

    if (isOnline) {
      await _runOnlineWrite((tx) async {
        tx.delete(docRef);
      });
    } else {
      await docRef.delete();
    }
  }

  // Update transaction
  Future<void> updateTransaction(TransactionModel transaction) async {
    if (_userId == null) throw 'User not logged in';
    if (transaction.id == null) throw 'Transaction ID is null';

    final updated = transaction.copyWith(
      updatedAt: DateTime.now(),
    );

    final docRef = _firestore.collection('transactions').doc(transaction.id);
    final isOnline = await checkServerReachability();

    if (isOnline) {
      await _runOnlineWrite((tx) async {
        tx.update(docRef, updated.toMap());
      });
    } else {
      await docRef.update(updated.toMap());
    }
  }

  // Get total income
  Future<double> getTotalIncome() async {
    final userId = _userId;
    if (userId == null) return 0.0;

    final snapshot = await _transactionsRef
        .where('userId', isEqualTo: userId)
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
    final userId = _userId;
    if (userId == null) return 0.0;

    final snapshot = await _transactionsRef
        .where('userId', isEqualTo: userId)
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
    final userId = _userId;
    if (userId == null) return {};

    final snapshot = await _transactionsRef
        .where('userId', isEqualTo: userId)
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
