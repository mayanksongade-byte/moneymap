import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../home/data/models/category_model.dart';

class CategoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  /// Helper to ensure operation is performed online.
  Future<T> _runOnlineWrite<T>(Future<T> Function(Transaction) action) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'Not logged in';

      // Pre-flight reachability check
      await _firestore.collection('categories')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
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

  Stream<List<CategoryModel>> getCustomCategories(String userId) {
    return _firestore
        .collection('categories')
        .where('userId', isEqualTo: userId)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) => snapshot.docs.map((doc) {
      final data = doc.data();
      return CategoryModel(
        id: doc.id,
        name: data['name'] ?? '',
        icon: data['icon'] ?? '📌',
        type: data['type'] ?? 'expense',
        color: data['color'] ?? '#6B7280',
      );
    }).toList());
  }

  Future<void> addCategory(CategoryModel category) async {
    final userId = _userId;
    if (userId == null) throw 'Not logged in';

    final docRef = _firestore.collection('categories').doc();

    await _runOnlineWrite((tx) async {
      tx.set(docRef, {
        'userId': userId,
        'name': category.name,
        'icon': category.icon,
        'type': category.type,
        'color': category.color,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> updateCategory(CategoryModel category) async {
    await _runOnlineWrite((tx) async {
      tx.update(_firestore.collection('categories').doc(category.id), {
        'name': category.name,
        'icon': category.icon,
        'type': category.type,
        'color': category.color,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> deleteCategory(String id) async {
    await _runOnlineWrite((tx) async {
      tx.delete(_firestore.collection('categories').doc(id));
    });
  }
}
