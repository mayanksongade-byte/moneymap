class CategoryModel {
  final String id;
  final String name;
  final String icon;
  final String type; // 'income' or 'expense'
  final String color;

  CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.type,
    required this.color,
  });

  // Pre-defined income categories
  static List<CategoryModel> get incomeCategories => [
    CategoryModel(
      id: 'salary',
      name: 'Salary',
      icon: '💰',
      type: 'income',
      color: '#10B981',
    ),
    CategoryModel(
      id: 'freelance',
      name: 'Freelance',
      icon: '📈',
      type: 'income',
      color: '#3B82F6',
    ),
    CategoryModel(
      id: 'investment',
      name: 'Investment',
      icon: '📊',
      type: 'income',
      color: '#F59E0B',
    ),
    CategoryModel(
      id: 'gift',
      name: 'Gift',
      icon: '🎁',
      type: 'income',
      color: '#8B5CF6',
    ),
  ];

  // Pre-defined expense categories
  static List<CategoryModel> get expenseCategories => [
    CategoryModel(
      id: 'food',
      name: 'Food',
      icon: '🍔',
      type: 'expense',
      color: '#EF4444',
    ),
    CategoryModel(
      id: 'transport',
      name: 'Transport',
      icon: '🚗',
      type: 'expense',
      color: '#F59E0B',
    ),
    CategoryModel(
      id: 'shopping',
      name: 'Shopping',
      icon: '🛒',
      type: 'expense',
      color: '#8B5CF6',
    ),
    CategoryModel(
      id: 'rent',
      name: 'Rent',
      icon: '🏠',
      type: 'expense',
      color: '#3B82F6',
    ),
    CategoryModel(
      id: 'health',
      name: 'Health',
      icon: '💊',
      type: 'expense',
      color: '#10B981',
    ),
    CategoryModel(
      id: 'entertainment',
      name: 'Entertainment',
      icon: '🎮',
      type: 'expense',
      color: '#EC4899',
    ),
    CategoryModel(
      id: 'education',
      name: 'Education',
      icon: '📚',
      type: 'expense',
      color: '#F59E0B',
    ),
    CategoryModel(
      id: 'utilities',
      name: 'Utilities',
      icon: '💡',
      type: 'expense',
      color: '#6B7280',
    ),
  ];

  // Get all categories
  static List<CategoryModel> get all => [
    ...incomeCategories,
    ...expenseCategories,
  ];

  // Get categories by type
  static List<CategoryModel> getByType(String type) {
    return all.where((c) => c.type == type).toList();
  }
}