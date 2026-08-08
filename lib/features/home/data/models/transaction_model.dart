import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String? id;
  final String userId;
  final double amount;
  final String type; // 'income' or 'expense'
  final String category;
  final String categoryId;
  final String icon;
  final String note;
  final String? imageUrl;
  final String paymentMode; // 'cash', 'upi', 'card', 'bank' etc.
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;

  TransactionModel({
    this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.category,
    required this.categoryId,
    required this.icon,
    required this.note,
    this.imageUrl,
    this.paymentMode = 'Cash', // Default to Cash
    required this.date,
    required this.createdAt,
    required this.updatedAt,
  });

  TransactionModel copyWith({
    String? id,
    String? userId,
    double? amount,
    String? type,
    String? category,
    String? categoryId,
    String? icon,
    String? note,
    String? imageUrl,
    String? paymentMode,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      categoryId: categoryId ?? this.categoryId,
      icon: icon ?? this.icon,
      note: note ?? this.note,
      imageUrl: imageUrl ?? this.imageUrl,
      paymentMode: paymentMode ?? this.paymentMode,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'amount': amount,
      'type': type,
      'category': category,
      'categoryId': categoryId,
      'icon': icon,
      'note': note,
      'imageUrl': imageUrl,
      'paymentMode': paymentMode,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      type: data['type'] ?? 'expense',
      category: data['category'] ?? '',
      categoryId: data['categoryId'] ?? '',
      icon: data['icon'] ?? '📌',
      note: data['note'] ?? '',
      imageUrl: data['imageUrl'],
      paymentMode: data['paymentMode'] ?? 'Cash',
      date: _asDateTime(data['date']),
      createdAt: _asDateTime(data['createdAt']),
      updatedAt: _asDateTime(data['updatedAt']),
    );
  }

  static DateTime _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
