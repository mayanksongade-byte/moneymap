import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:moneymap/core/constants/color_constants.dart';
import 'package:moneymap/core/widgets/inputs/app_text_field.dart';
import 'package:moneymap/features/home/data/models/category_model.dart';
import 'package:moneymap/features/home/data/models/transaction_model.dart';
import 'package:moneymap/features/home/presentation/widgets/category_grid.dart';
import 'package:moneymap/features/home/presentation/widgets/type_toggle.dart';
import 'package:moneymap/features/home/presentation/providers/transaction_provider.dart';
import 'package:moneymap/features/category/presentation/providers/category_provider.dart';
import 'success_screen.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../widgets/premium_amount_field.dart';

class AddTransactionScreen extends StatefulWidget {
  final TransactionModel? transactionToEdit;

  const AddTransactionScreen({super.key, this.transactionToEdit});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String _selectedType = 'expense';
  String? _selectedCategoryId;
  String _selectedPaymentMode = 'Cash';
  DateTime _selectedDate = DateTime.now();
  bool _isUploading = false;

  final List<Map<String, dynamic>> _paymentModes = [
    {'name': 'Cash', 'icon': Icons.payments_rounded, 'color': Colors.orange},
    {'name': 'UPI', 'icon': Icons.qr_code_2_rounded, 'color': Colors.blue},
    {'name': 'Card', 'icon': Icons.credit_card_rounded, 'color': Colors.purple},
    {'name': 'Bank', 'icon': Icons.account_balance_rounded, 'color': Colors.teal},
  ];

  List<CategoryModel> get _categories {
    return Provider.of<CategoryProvider>(context, listen: false).byType(_selectedType);
  }

  CategoryModel? get _selectedCategory {
    if (_selectedCategoryId == null) return null;
    try {
      return _categories.firstWhere((c) => c.id == _selectedCategoryId);
    } catch (_) {
      return null;
    }
  }

  bool get _isEditMode => widget.transactionToEdit != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.transactionToEdit;
    if (editing != null) {
      _amountController.text = editing.amount.toString();
      _noteController.text = editing.note;
      _selectedType = editing.type;
      _selectedCategoryId = editing.categoryId;
      _selectedDate = editing.date;
      _selectedPaymentMode = editing.paymentMode;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CategoryProvider>(context, listen: false).loadCategories();
    });
    _amountController.addListener(_onFormChanged);
    _noteController.addListener(_onFormChanged);
  }

  void _onFormChanged() => setState(() {});

  @override
  void dispose() {
    _amountController.removeListener(_onFormChanged);
    _noteController.removeListener(_onFormChanged);
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category'), backgroundColor: AppColors.error),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isUploading = true);

    final provider = Provider.of<TransactionProvider>(context, listen: false);

    final category = _categories.firstWhere((c) => c.id == _selectedCategoryId);

    if (_isEditMode) {
      final original = widget.transactionToEdit!;
      final updated = original.copyWith(
        amount: double.parse(_amountController.text),
        type: _selectedType,
        category: category.name,
        categoryId: category.id,
        icon: category.icon,
        note: _noteController.text,
        date: _selectedDate,
        paymentMode: _selectedPaymentMode,
      );

      final success = await provider.updateTransaction(updated);
      if (mounted) {
        setState(() => _isUploading = false);
        if (success) {
          Navigator.pop(context, true);
        } else {
          _showError(provider.error ?? 'Update failed');
        }
      }
      return;
    }

    final transaction = TransactionModel(
      userId: user.uid,
      amount: double.parse(_amountController.text),
      type: _selectedType,
      category: category.name,
      categoryId: category.id,
      icon: category.icon,
      note: _noteController.text,
      date: _selectedDate,
      paymentMode: _selectedPaymentMode,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await provider.addTransaction(transaction);
    if (mounted) {
      setState(() => _isUploading = false);
      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SuccessScreen(
              transaction: {
                'amount': transaction.amount,
                'type': transaction.type,
                'category': transaction.category,
                'icon': transaction.icon,
                'note': transaction.note,
                'paymentMode': transaction.paymentMode,
                'dateString': DateFormat('dd MMM yyyy').format(transaction.date),
              },
              onAddAnother: () => Navigator.pop(context),
              onGoHome: () => Navigator.pop(context, true),
            ),
          ),
        );
      } else {
        _showError(provider.error ?? 'Submission failed');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.error));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(90),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: colors.background,
          elevation: 0,
          toolbarHeight: 90,
          titleSpacing: 16,
          title: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: colors.textPrimary),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(_isEditMode ? "Edit Transaction" : "Add Transaction",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: -0.5, color: colors.textPrimary)),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TypeToggle(
                    selectedType: _selectedType,
                    onTypeChanged: (type) => setState(() {
                      _selectedType = type;
                      _selectedCategoryId = null;
                    }),
                  ),
                  const SizedBox(height: 24),
                  PremiumAmountField(controller: _amountController),
                  const SizedBox(height: 20),
                  
                  // note field
                  AppTextField(
                    label: 'Note / Description',
                    hint: 'What was this for?',
                    prefixIcon: Icons.edit_note_rounded,
                    controller: _noteController,
                  ),
                  const SizedBox(height: 20),
                  
                  // Payment Mode Selection
                  const Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _paymentModes.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final mode = _paymentModes[index];
                        final isSelected = _selectedPaymentMode == mode['name'];
                        return GestureDetector(
                          onTap: () => setState(() => _selectedPaymentMode = mode['name']),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? (mode['color'] as Color).withOpacity(0.15) : colors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? mode['color'] as Color : colors.border,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(mode['icon'], size: 18, color: isSelected ? mode['color'] as Color : colors.textSecondary),
                                const SizedBox(width: 8),
                                Text(
                                  mode['name'],
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? mode['color'] as Color : colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Date Picker UI
                  _buildDatePicker(colors),

                  const SizedBox(height: 32),
                  const Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  CategoryGrid(
                    categories: _categories,
                    selectedCategoryId: _selectedCategoryId,
                    onCategorySelected: (id) => setState(() => _selectedCategoryId = id),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          
          // Submit Button
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: _buildSubmitButton(),
          ),
          
          if (_isUploading)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(AppColorsExtension colors) {
    return InkWell(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Icon(Icons.edit_calendar_rounded, size: 18, color: colors.textDisabled),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(colors: [AppColors.primary, Color(0xff1D4ED8)]),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: ElevatedButton(
        onPressed: _isUploading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: Text(
          _isEditMode ? "Save Changes" : "Confirm Transaction",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}
