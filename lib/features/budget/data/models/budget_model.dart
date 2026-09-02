class BudgetModel {
  final double? monthlyLimit;
  final Map<String, double> categoryLimits; // categoryName -> limit

  const BudgetModel({
    this.monthlyLimit,
    this.categoryLimits = const {},
  });

  factory BudgetModel.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const BudgetModel();

    final rawLimits = data['categoryLimits'] as Map<String, dynamic>? ?? {};
    final limits = rawLimits.map((key, value) => MapEntry(key, (value as num).toDouble()));

    return BudgetModel(
      monthlyLimit: (data['monthlyLimit'] as num?)?.toDouble(),
      categoryLimits: limits,
    );
  }
}
