import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../home/data/models/category_model.dart';

class CategoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  Stream<List<CategoryModel>> getCustomCategories() {
    final userId = _userId;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('categories')
        .where('userId', isEqualTo: userId)
        .snapshots()
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
    if (userId == null) throw Exception('Not logged in');

    await _firestore.collection('categories').add({
      'userId': userId,
      'name': category.name,
      'icon': category.icon,
      'type': category.type,
      'color': category.color,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateCategory(CategoryModel category) async {
    await _firestore.collection('categories').doc(category.id).update({
      'name': category.name,
      'icon': category.icon,
      'type': category.type,
      'color': category.color,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteCategory(String id) async {
    await _firestore.collection('categories').doc(id).delete();
  }
}
