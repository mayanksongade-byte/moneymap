// lib/features/home/presentation/screens/add_transaction_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:moneymap/features/home/data/models/category_model.dart';
import 'package:moneymap/features/home/data/models/transaction_model.dart';
import 'package:moneymap/features/home/presentation/widgets/type_toggle.dart';
import 'package:moneymap/features/home/presentation/providers/transaction_provider.dart';
import 'package:moneymap/features/category/presentation/providers/category_provider.dart';
import 'package:moneymap/core/providers/notification_provider.dart';
import 'package:moneymap/core/providers/currency_provider.dart';
import 'package:moneymap/core/theme/app_colors_extension.dart';
import 'success_screen.dart';

class AddTransactionScreen extends StatefulWidget {
  final TransactionModel? transactionToEdit;
  final String? initialType;

  const AddTransactionScreen({super.key, this.transactionToEdit, this.initialType});

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
    {'name': 'Bank', 'icon': Icons.account_balance_rounded, 'color': Colors.teal},
    {'name': 'Card', 'icon': Icons.credit_card_rounded, 'color': Colors.purple},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) {
      _selectedType = widget.initialType!;
    }
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
  }

  @override
  void dispose() {
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
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category'), backgroundColor: Colors.red),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isUploading = true);

    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final categoryProv = Provider.of<CategoryProvider>(context, listen: false);
    final notifProv = Provider.of<NotificationProvider>(context, listen: false);
    final currProv = Provider.of<CurrencyProvider>(context, listen: false);

    final categories = categoryProv.byType(_selectedType);
    final category = categories.firstWhere((c) => c.id == _selectedCategoryId);
    final amount = double.tryParse(_amountController.text) ?? 0.0;

    final transaction = TransactionModel(
      id: widget.transactionToEdit?.id,
      userId: user.uid,
      amount: amount,
      type: _selectedType,
      category: category.name,
      categoryId: category.id,
      icon: category.icon,
      note: _noteController.text,
      date: _selectedDate,
      paymentMode: _selectedPaymentMode,
      createdAt: widget.transactionToEdit?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    bool success = widget.transactionToEdit != null
        ? await provider.updateTransaction(transaction)
        : await provider.addTransaction(transaction);

    if (mounted) {
      setState(() => _isUploading = false);
      if (success) {
        // --- TRIGGER INSTANT NOTIFICATION (Point 5) ---
        if (widget.transactionToEdit == null) {
          notifProv.notifyTransactionAdded(
            transaction,
            formattedAmount: currProv.format(transaction.amount),
            formattedBalance: currProv.format(provider.balance),
          );
        }

        if (widget.transactionToEdit != null) {
          Navigator.pop(context, true);
        } else {
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
                onAddAnother: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const AddTransactionScreen()),
                ),
                onGoHome: () => Navigator.of(context).popUntil((route) => route.isFirst),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>().byType(_selectedType);
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: _buildAppBar(colors),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  TypeToggle(
                    selectedType: _selectedType,
                    onTypeChanged: (type) => setState(() {
                      _selectedType = type;
                      _selectedCategoryId = null;
                    }),
                  ),
                  const SizedBox(height: 24),
                  _buildAmountCard(),
                  const SizedBox(height: 20),
                  _buildPaymentModeSection(colors),
                  const SizedBox(height: 20),
                  _buildNoteField(colors),
                  const SizedBox(height: 20),
                  _buildDatePickerSection(colors),
                  const SizedBox(height: 30),
                  _buildCategoryHeader(colors),
                  const SizedBox(height: 16),
                  _buildCategoryGrid(categories, colors),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: _buildSubmitButton(),
          ),
          if (_isUploading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppColorsExtension colors) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 90,
      title: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(Icons.chevron_left, color: colors.textPrimary, size: 28),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.transactionToEdit != null ? "Edit Transaction" : "Add Transaction",
                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 20),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "Track your money smarter",
                  style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF).withValues(alpha: Theme.of(context).brightness == Brightness.light ? 1.0 : 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.currency_rupee, size: 14, color: Color(0xFF4F46E5)),
                const SizedBox(width: 4),
                Text(
                  "New",
                  style: TextStyle(color: const Color(0xFF4F46E5), fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard() {
    final isExpense = _selectedType == 'expense';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isExpense
              ? [const Color(0xFFF87171), const Color(0xFFEF4444)]
              : [const Color(0xFF34D399), const Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: (isExpense ? Colors.red : Colors.green).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isExpense ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      const Text(
                        "₹ ",
                        style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          cursorColor: Colors.white,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                          ),
                          decoration: const InputDecoration(
                            hintText: "0.00",
                            hintStyle: TextStyle(color: Colors.white70),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            filled: true,
                            fillColor: Colors.transparent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 1.5,
                    width: double.infinity,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Enter amount",
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white.withValues(alpha: 0.3),
            ),
            GestureDetector(
              onTap: _selectDate,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat('dd').format(_selectedDate),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  Text(
                    DateFormat('MMM yyyy').format(_selectedDate),
                    style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentModeSection(AppColorsExtension colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Payment Mode", style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(
          children: _paymentModes.map((mode) {
            final isSelected = _selectedPaymentMode == mode['name'];
            final Color modeColor = mode['color'] as Color;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedPaymentMode = mode['name']),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? modeColor.withValues(alpha: 0.15) : colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? modeColor.withValues(alpha: 0.5) : colors.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(mode['icon'], color: isSelected ? modeColor : colors.textPrimary, size: 22),
                      const SizedBox(height: 4),
                      FittedBox(
                        child: Text(
                          mode['name'],
                          style: TextStyle(
                            color: isSelected ? modeColor : colors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNoteField(AppColorsExtension colors) {
    return Container(
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.border)),
      child: TextFormField(
        controller: _noteController,
        style: TextStyle(color: colors.textPrimary),
        decoration: InputDecoration(
          hintText: "Note (Optional)",
          hintStyle: TextStyle(color: colors.textDisabled),
          prefixIcon: Icon(Icons.description_outlined, color: colors.textPrimary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildDatePickerSection(AppColorsExtension colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.border)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF3B82F6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.calendar_today_outlined, color: Color(0xFF3B82F6), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Transaction Date", style: TextStyle(color: colors.textSecondary, fontSize: 11)),
                Text(DateFormat('dd MMM yyyy').format(_selectedDate), style: TextStyle(color: colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _selectDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Today", style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w700, fontSize: 12)),
                  Icon(Icons.keyboard_arrow_down, size: 16, color: colors.textSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(AppColorsExtension colors) {
    return Text("Select Category", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colors.textPrimary));
  }

  Widget _buildCategoryGrid(List<CategoryModel> categories, AppColorsExtension colors) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final isSelected = _selectedCategoryId == cat.id;
        final catColor = Color(int.parse(cat.color.replaceFirst('#', '0xFF')));
        return GestureDetector(
          onTap: () => setState(() => _selectedCategoryId = cat.id),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? catColor.withValues(alpha: 0.15) : colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? catColor.withValues(alpha: 0.6) : Colors.transparent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected ? catColor.withValues(alpha: 0.1) : colors.shadow.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: catColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Center(child: Text(cat.icon, style: const TextStyle(fontSize: 22))),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    cat.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? catColor : colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity, height: 60,
      child: ElevatedButton(
        onPressed: _isUploading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Color(0xFF2563EB), size: 16),
            ),
            const SizedBox(width: 12),
            Text(widget.transactionToEdit != null ? "Save Transaction" : "Add Transaction", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
