import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/color_constants.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../home/presentation/providers/transaction_provider.dart';
import '../../../category/presentation/providers/category_provider.dart';
import '../providers/budget_provider.dart';
import '../../../../core/providers/currency_provider.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _categorySearchController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final GlobalKey _inputSectionKey = GlobalKey();

  bool _isSaving = false;
  String? _inputError;
  bool _insightDismissed = false;
  String _categoryQuery = '';

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _monthShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  late DateTime _selectedMonth; // day is always 1

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BudgetProvider>(context, listen: false).loadBudget();
      Provider.of<TransactionProvider>(context, listen: false).loadTransactions();
      Provider.of<CategoryProvider>(context, listen: false).loadCategories();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _categorySearchController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  // ---------- Month helpers ----------
  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  int _daysInMonth(DateTime month) => DateTime(month.year, month.month + 1, 0).day;

  void _changeMonth(int delta) {
    final target = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    final now = DateTime.now();
    if (target.isAfter(DateTime(now.year, now.month))) return; // no future months
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMonth = target;
      _insightDismissed = false;
    });
  }

  bool _isInMonth(DateTime date, DateTime month) => date.year == month.year && date.month == month.month;

  double _monthExpense(TransactionProvider provider, DateTime month) {
    double total = 0;
    for (final t in provider.transactions) {
      if (t.type == 'expense' && _isInMonth(t.date, month)) total += t.amount;
    }
    return total;
  }

  double _monthExpenseForCategory(TransactionProvider provider, String category, DateTime month) {
    double total = 0;
    for (final t in provider.transactions) {
      if (t.type == 'expense' && t.category == category && _isInMonth(t.date, month)) {
        total += t.amount;
      }
    }
    return total;
  }

  // Average spend for a category over the last [months] months.
  double _avgCategorySpend(TransactionProvider provider, String category, int months) {
    double total = 0;
    int counted = 0;
    for (int i = 1; i <= months; i++) {
      final month = DateTime(DateTime.now().year, DateTime.now().month - i);
      final value = _monthExpenseForCategory(provider, category, month);
      if (value > 0) {
        total += value;
        counted++;
      }
    }
    return counted == 0 ? 0 : total / counted;
  }

  Future<void> _saveBudget(BudgetProvider budgetProvider) async {
    final value = double.tryParse(_controller.text.trim());
    if (value == null || value <= 0) {
      HapticFeedback.mediumImpact();
      setState(() => _inputError = 'Enter a valid amount');
      return;
    }
    setState(() => _inputError = null);
    setState(() => _isSaving = true);
    final success = await budgetProvider.setBudget(value);
    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        HapticFeedback.lightImpact();
        _controller.clear();
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Budget saved'), backgroundColor: AppColors.success),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(budgetProvider.error ?? 'Failed to save budget'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _focusBudgetInput() {
    Scrollable.ensureVisible(
      _inputSectionKey.currentContext!,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _inputFocusNode.requestFocus();
    });
  }

  void _applySuggestedAmount(double amount) {
    HapticFeedback.selectionClick();
    _controller.text = amount.toStringAsFixed(0);
    setState(() => _inputError = null);
    _focusBudgetInput();
  }

  void _copySummary(double spent, double limit, List<dynamic> categories, TransactionProvider txProvider, CurrencyProvider currency) {
    final buffer = StringBuffer();
    buffer.writeln('${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year} — Budget Summary');
    buffer.writeln('Spent: ${currency.format(spent)} of ${currency.format(limit)}');
    for (final c in categories) {
      final catSpent = _monthExpenseForCategory(txProvider, c.name, _selectedMonth);
      if (catSpent > 0) buffer.writeln('${c.name}: ${currency.format(catSpent)}');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Summary copied to clipboard')),
    );
  }

  // ---------- Category limit bottom sheet ----------
  Future<void> _showCategoryLimitSheet(
      BuildContext context,
      BudgetProvider budgetProvider,
      TransactionProvider txProvider,
      CurrencyProvider currencyProvider,
      String categoryName,
      String categoryIcon,
      double? currentLimit,
      ) async {
    HapticFeedback.lightImpact();
    final controller = TextEditingController(
      text: currentLimit != null ? currentLimit.toStringAsFixed(0) : '',
    );
    final colors = context.colors;
    String? sheetError;
    const quickAmounts = [1000.0, 2000.0, 5000.0, 10000.0];
    final suggested = _avgCategorySpend(txProvider, categoryName, 3);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(categoryIcon, style: const TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(categoryName,
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                          Text(
                            currentLimit != null ? 'Update spending limit' : 'Set a spending limit',
                            style: TextStyle(fontSize: 13, color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: colors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
                  onChanged: (_) {
                    if (sheetError != null) setSheetState(() => sheetError = null);
                  },
                  decoration: InputDecoration(
                    prefixText: '${currencyProvider.currencySymbol} ',
                    prefixStyle: TextStyle(color: colors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
                    hintText: '0',
                    hintStyle: TextStyle(color: colors.textHint),
                    filled: true,
                    fillColor: colors.surfaceVariant,
                    errorText: sheetError,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                if (currentLimit == null && suggested > 0) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      controller.text = suggested.toStringAsFixed(0);
                      controller.selection = TextSelection.collapsed(offset: controller.text.length);
                      setSheetState(() => sheetError = null);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Suggested ${currencyProvider.format(suggested)} — your 3-month average',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: quickAmounts.map((amt) {
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        controller.text = amt.toStringAsFixed(0);
                        controller.selection = TextSelection.collapsed(offset: controller.text.length);
                        setSheetState(() => sheetError = null);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          currencyProvider.format(amt),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    if (currentLimit != null)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final removedValue = currentLimit;
                            await budgetProvider.removeCategoryLimit(categoryName);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('$categoryName limit removed'),
                                  action: SnackBarAction(
                                    label: 'Undo',
                                    onPressed: () => budgetProvider.setCategoryLimit(categoryName, removedValue),
                                  ),
                                ),
                              );
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    if (currentLimit != null) const SizedBox(width: 12),
                    Expanded(
                      flex: currentLimit != null ? 1 : 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          final value = double.tryParse(controller.text.trim());
                          if (value == null || value <= 0) {
                            HapticFeedback.mediumImpact();
                            setSheetState(() => sheetError = 'Enter a valid amount');
                            return;
                          }
                          Navigator.pop(ctx);
                          await budgetProvider.setCategoryLimit(categoryName, value);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _progressColor(double progress, bool isOver) {
    if (isOver) return AppColors.error;
    if (progress > 0.8) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final transactionProvider = Provider.of<TransactionProvider>(context);
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final currencyProvider = Provider.of<CurrencyProvider>(context);

    final spent = _monthExpense(transactionProvider, _selectedMonth);
    final limit = budgetProvider.monthlyLimit ?? 0;
    final progress = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final isOverBudget = limit > 0 && spent > limit;

    // Pacing insight (only meaningful for the current month)
    final daysInMonth = _daysInMonth(_selectedMonth);
    final today = DateTime.now().day;
    final daysRemaining = _isCurrentMonth ? (daysInMonth - today + 1).clamp(1, daysInMonth) : 0;
    final idealSpendToDate = (limit > 0 && _isCurrentMonth) ? (limit / daysInMonth) * today : 0;
    final isAheadOfPace = _isCurrentMonth && spent > idealSpendToDate;
    final dailyAllowance =
    (_isCurrentMonth && limit > 0 && !isOverBudget) ? ((limit - spent) / daysRemaining) : 0.0;

    // Month-over-month comparison + top category
    final prevMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    final prevMonthSpend = _monthExpense(transactionProvider, prevMonth);
    final momChangePct = prevMonthSpend > 0 ? ((spent - prevMonthSpend) / prevMonthSpend) * 100 : null;

    final allExpenseCategories = [...categoryProvider.byType('expense')];

    dynamic topCategory;
    double topCategorySpend = 0;
    for (final c in allExpenseCategories) {
      final s = _monthExpenseForCategory(transactionProvider, c.name, _selectedMonth);
      if (s > topCategorySpend) {
        topCategorySpend = s;
        topCategory = c;
      }
    }

    // Category limits vs total budget mismatch
    double sumOfCategoryLimits = 0;
    for (final c in allExpenseCategories) {
      final l = budgetProvider.limitForCategory(c.name);
      if (l != null) sumOfCategoryLimits += l;
    }
    final categoryLimitsExceedBudget = limit > 0 && sumOfCategoryLimits > limit;

    // Rollover suggestion
    final prevMonthUnused = (_isCurrentMonth && limit > 0 && prevMonthSpend > 0 && prevMonthSpend < limit)
        ? (limit - prevMonthSpend)
        : 0.0;

    // Sorted + filtered categories
    var expenseCategories = [...allExpenseCategories];
    if (_categoryQuery.trim().isNotEmpty) {
      expenseCategories = expenseCategories
          .where((c) => c.name.toLowerCase().contains(_categoryQuery.trim().toLowerCase()))
          .toList();
    }
    expenseCategories.sort((a, b) {
      final aLimit = budgetProvider.limitForCategory(a.name);
      final bLimit = budgetProvider.limitForCategory(b.name);
      final aSpent = _monthExpenseForCategory(transactionProvider, a.name, _selectedMonth);
      final bSpent = _monthExpenseForCategory(transactionProvider, b.name, _selectedMonth);
      final aOver = aLimit != null && aLimit > 0 && aSpent > aLimit;
      final bOver = bLimit != null && bLimit > 0 && bSpent > bLimit;
      if (aOver != bOver) return aOver ? -1 : 1;
      final aHasLimit = aLimit != null && aLimit > 0;
      final bHasLimit = bLimit != null && bLimit > 0;
      if (aHasLimit != bHasLimit) return aHasLimit ? -1 : 1;
      if (aSpent != bSpent) return bSpent.compareTo(aSpent);
      return 0;
    });

    final now = DateTime.now();
    final trendMonths = List.generate(6, (i) => DateTime(now.year, now.month - (5 - i)));
    final trendValues = trendMonths.map((m) => _monthExpense(transactionProvider, m)).toList();
    final trendMax = trendValues.fold<double>(0, (a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(90),
        child: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: colors.background,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Budget",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.8,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text("Track your monthly spending", style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _copySummary(spent, limit, allExpenseCategories, transactionProvider, currencyProvider),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(Icons.ios_share_rounded, size: 18, color: colors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
      body: budgetProvider.isLoading
          ? _buildLoadingSkeleton(colors)
          : Column(
        children: [
          _buildMonthSelector(colors),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: SingleChildScrollView(
                key: ValueKey(_selectedMonth),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_isCurrentMonth) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration:
                        BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Icon(Icons.history_rounded, size: 16, color: colors.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Viewing ${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year} · limits shown reflect your current settings',
                                style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (isOverBudget) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.error.withValues(alpha: .25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_rounded, color: AppColors.error, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _isCurrentMonth
                                    ? "You've exceeded your budget by ${currencyProvider.format(spent - limit)}"
                                    : "You went ${currencyProvider.format(spent - limit)} over budget this month",
                                style:
                                const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (!_insightDismissed && (momChangePct != null || topCategory != null)) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: .06),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.insights_rounded, size: 18, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text('Insight',
                                    style: TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.w700, color: colors.textSecondary)),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => setState(() => _insightDismissed = true),
                                  child: Icon(Icons.close_rounded, size: 16, color: colors.textDisabled),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (momChangePct != null)
                              Text(
                                momChangePct >= 0
                                    ? "You've spent ${momChangePct.toStringAsFixed(0)}% more than last month"
                                    : "You've spent ${momChangePct.abs().toStringAsFixed(0)}% less than last month",
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary),
                              ),
                            if (topCategory != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${topCategory.name} is your top spending category · ${currencyProvider.format(topCategorySpend)}',
                                style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (prevMonthUnused > 0) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.savings_outlined, size: 18, color: AppColors.success),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'You had ${currencyProvider.format(prevMonthUnused)} left unused in ${_monthNames[prevMonth.month - 1]}',
                                style: const TextStyle(
                                    fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.success),
                              ),
                            ),
                            TextButton(
                              onPressed: () => _applySuggestedAmount(limit + prevMonthUnused),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.success,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              child: const Text('Add it', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (budgetProvider.hasBudget) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: colors.border.withValues(alpha: .15)),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: .04), blurRadius: 20, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text("Monthly Budget",
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600, color: colors.textSecondary)),
                            const SizedBox(height: 24),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 170,
                                  height: 170,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: _progressColor(progress, isOverBudget).withValues(alpha: .18),
                                        blurRadius: 40,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: progress),
                                  duration: const Duration(milliseconds: 700),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, animatedProgress, _) => SizedBox(
                                    width: 180,
                                    height: 180,
                                    child: CircularProgressIndicator(
                                      value: animatedProgress,
                                      strokeWidth: 12,
                                      strokeCap: StrokeCap.round,
                                      backgroundColor: colors.surfaceVariant,
                                      valueColor: AlwaysStoppedAnimation(_progressColor(progress, isOverBudget)),
                                    ),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text("Remaining", style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                                    const SizedBox(height: 6),
                                    Text(
                                      currencyProvider.format((limit - spent).clamp(0, double.infinity)),
                                      style: TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -.5,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _progressColor(progress, isOverBudget).withValues(alpha: .12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        "${(progress * 100).toStringAsFixed(0)}% used",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: _progressColor(progress, isOverBudget),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (_isCurrentMonth && limit > 0 && !isOverBudget) ...[
                              const SizedBox(height: 20),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: (isAheadOfPace ? AppColors.warning : AppColors.success)
                                      .withValues(alpha: .08),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isAheadOfPace ? Icons.trending_up_rounded : Icons.check_circle_rounded,
                                      size: 18,
                                      color: isAheadOfPace ? AppColors.warning : AppColors.success,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        isAheadOfPace
                                            ? "Spending faster than planned · ${currencyProvider.format(dailyAllowance)}/day left for $daysRemaining days"
                                            : "On track · ${currencyProvider.format(dailyAllowance)}/day left for $daysRemaining days",
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: isAheadOfPace ? AppColors.warning : AppColors.success,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    decoration: BoxDecoration(
                                        color: colors.surfaceVariant, borderRadius: BorderRadius.circular(18)),
                                    child: Column(
                                      children: [
                                        Text("Spent", style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                                        const SizedBox(height: 6),
                                        Text(
                                          currencyProvider.format(spent),
                                          style: TextStyle(
                                              fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    decoration: BoxDecoration(
                                        color: colors.surfaceVariant, borderRadius: BorderRadius.circular(18)),
                                    child: Column(
                                      children: [
                                        Text("Budget", style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                                        const SizedBox(height: 6),
                                        Text(
                                          currencyProvider.format(limit),
                                          style: TextStyle(
                                              fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: colors.border.withValues(alpha: .15)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Spending Trend',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                            const SizedBox(height: 4),
                            Text('Last 6 months',
                                style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
                            const SizedBox(height: 18),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(trendMonths.length, (i) {
                                final m = trendMonths[i];
                                final v = trendValues[i];
                                final barHeight = trendMax > 0 ? (v / trendMax) * 70 : 0.0;
                                final isCurrent = m.year == now.year && m.month == now.month;
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      v > 0 ? '${currencyProvider.currencySymbol}${(v / 1000).toStringAsFixed(v >= 1000 ? 1 : 0)}${v >= 1000 ? 'k' : ''}' : '',
                                      style: TextStyle(fontSize: 9, color: colors.textSecondary),
                                    ),
                                    const SizedBox(height: 4),
                                    TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0, end: barHeight.clamp(4.0, 70.0)),
                                      duration: const Duration(milliseconds: 600),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, height, _) => Container(
                                        width: 22,
                                        height: height,
                                        decoration: BoxDecoration(
                                          color: isCurrent
                                              ? AppColors.primary
                                              : AppColors.primary.withValues(alpha: .25),
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _monthShort[m.month - 1],
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                        color: isCurrent ? colors.textPrimary : colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: colors.border.withValues(alpha: .15)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: .10), shape: BoxShape.circle),
                              child: const Icon(Icons.savings_rounded, color: AppColors.primary, size: 30),
                            ),
                            const SizedBox(height: 16),
                            Text("No budget set yet",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                            const SizedBox(height: 6),
                            Text(
                              "Set a monthly budget to start tracking your spending",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: colors.textSecondary),
                            ),
                            const SizedBox(height: 18),
                            ElevatedButton(
                              onPressed: _focusBudgetInput,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('Set Budget', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    if (_isCurrentMonth) ...[
                      Text(
                        budgetProvider.hasBudget ? 'Update Total Budget' : 'Set Total Monthly Budget',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        key: _inputSectionKey,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _inputFocusNode,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(color: colors.textPrimary, fontSize: 15),
                              onChanged: (_) {
                                if (_inputError != null) setState(() => _inputError = null);
                              },
                              decoration: InputDecoration(
                                hintText:
                                budgetProvider.hasBudget ? 'Current: ${currencyProvider.format(limit)}' : 'e.g. 20000',
                                hintStyle: TextStyle(color: colors.textHint),
                                prefixText: '${currencyProvider.currencySymbol} ',
                                prefixStyle: TextStyle(color: colors.textPrimary, fontSize: 15),
                                errorText: _inputError,
                                filled: true,
                                fillColor: colors.surfaceVariant,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: _isSaving ? null : () => _saveBudget(budgetProvider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Save',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: Text('Category Budgets',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isCurrentMonth
                          ? 'Tap a category to set or update its own limit'
                          : 'Spending by category this month',
                      style: TextStyle(fontSize: 12, color: colors.textSecondary),
                    ),
                    if (categoryLimitsExceedBudget) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.warning),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Category limits add up to ${currencyProvider.format(sumOfCategoryLimits)}, more than your ${currencyProvider.format(limit)} budget',
                              style: const TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),

                    if (allExpenseCategories.length > 5) ...[
                      TextField(
                        controller: _categorySearchController,
                        onChanged: (v) => setState(() => _categoryQuery = v),
                        style: TextStyle(color: colors.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search categories',
                          hintStyle: TextStyle(color: colors.textHint, fontSize: 13),
                          prefixIcon: Icon(Icons.search_rounded, size: 18, color: colors.textSecondary),
                          filled: true,
                          fillColor: colors.surfaceVariant,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          border:
                          OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (expenseCategories.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text('No categories match your search',
                              style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                        ),
                      ),

                    ...expenseCategories.map((category) {
                      final catSpent = _monthExpenseForCategory(transactionProvider, category.name, _selectedMonth);
                      final catLimit = budgetProvider.limitForCategory(category.name);
                      final hasLimit = catLimit != null && catLimit > 0;
                      final catProgress = hasLimit ? (catSpent / catLimit).clamp(0.0, 1.0) : 0.0;
                      final catOver = hasLimit && catSpent > catLimit;
                      final catColor = _progressColor(catProgress, catOver);

                      if (catSpent == 0 && !hasLimit && !_isCurrentMonth) {
                        return const SizedBox.shrink();
                      }

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _isCurrentMonth
                              ? () => _showCategoryLimitSheet(
                              context, budgetProvider, transactionProvider, currencyProvider, category.name, category.icon, catLimit)
                              : null,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: catOver ? Border.all(color: AppColors.error.withValues(alpha: .35)) : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: (hasLimit ? catColor : AppColors.primary).withValues(alpha: .12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(category.icon, style: const TextStyle(fontSize: 18)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(category.name,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: colors.textPrimary)),
                                          ),
                                          if (hasLimit)
                                            Text(
                                              '${(catProgress * 100).toStringAsFixed(0)}%',
                                              style:
                                              TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: catColor),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      if (hasLimit) ...[
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: TweenAnimationBuilder<double>(
                                            tween: Tween(begin: 0, end: catProgress),
                                            duration: const Duration(milliseconds: 600),
                                            curve: Curves.easeOutCubic,
                                            builder: (context, animatedValue, _) => LinearProgressIndicator(
                                              value: animatedValue,
                                              minHeight: 6,
                                              backgroundColor: colors.surfaceVariant,
                                              valueColor: AlwaysStoppedAnimation(catColor),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${currencyProvider.format(catSpent)} / ${currencyProvider.format(catLimit)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: catOver ? AppColors.error : colors.textSecondary,
                                            fontWeight: catOver ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                        ),
                                      ] else
                                        Text(
                                          'Spent ${currencyProvider.format(catSpent)} · No limit set',
                                          style: TextStyle(fontSize: 11, color: colors.textDisabled),
                                        ),
                                    ],
                                  ),
                                ),
                                if (_isCurrentMonth) ...[
                                  const SizedBox(width: 8),
                                  Icon(hasLimit ? Icons.edit_outlined : Icons.add_circle_outline,
                                      size: 18, color: colors.textDisabled),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector(dynamic colors) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! > 250) {
          _changeMonth(-1);
        } else if (details.primaryVelocity! < -250) {
          _changeMonth(1);
        }
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border.withValues(alpha: .20)),
        ),
        child: Row(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _changeMonth(-1),
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  child: Icon(Icons.chevron_left_rounded, size: 26, color: colors.textPrimary),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: colors.textPrimary),
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _isCurrentMonth ? null : () => _changeMonth(1),
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 26,
                    color: _isCurrentMonth ? colors.textDisabled : colors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton(dynamic colors) {
    Widget block({double height = 16, double width = double.infinity, double radius = 8}) => Container(
      height: height,
      width: width,
      decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(radius)),
    );

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          block(height: 48, radius: 18),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(28)),
            child: Column(
              children: [
                block(height: 14, width: 120),
                const SizedBox(height: 24),
                Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: colors.surfaceVariant)),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(child: block(height: 60, radius: 18)),
                    const SizedBox(width: 12),
                    Expanded(child: block(height: 60, radius: 18)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          block(height: 18, width: 160),
          const SizedBox(height: 10),
          block(height: 48, radius: 12),
          const SizedBox(height: 28),
          block(height: 18, width: 150),
          const SizedBox(height: 12),
          ...List.generate(
            4,
                (i) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Container(
                      width: 40,
                      height: 40,
                      decoration:
                      BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(12))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        block(height: 12, width: 100),
                        const SizedBox(height: 8),
                        block(height: 8, width: 140),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
