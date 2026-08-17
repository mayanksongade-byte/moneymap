import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/color_constants.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../data/models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import '../../../category/presentation/providers/category_provider.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../../core/providers/currency_provider.dart';

enum _SortBy { newest, oldest, highest, lowest }

class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({super.key});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  String _typeFilter = 'all'; 
  _SortBy _sortBy = _SortBy.newest;
  String _searchQuery = '';
  bool _isSearchVisible = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;
    
    String day = '';
    if (diff == 0) day = 'Today';
    else if (diff == 1) day = 'Yesterday';
    else day = DateFormat('EEEE').format(date);
    
    return '$day, ${DateFormat('dd MMM').format(date)}';
  }

  List<TransactionModel> _applyFilters(List<TransactionModel> all) {
    final q = _searchQuery.toLowerCase().trim();
    final list = all.where((t) {
      final matchesType = _typeFilter == 'all' || t.type == _typeFilter;
      final matchesSearch = q.isEmpty || 
                            t.category.toLowerCase().contains(q) || 
                            t.note.toLowerCase().contains(q);
      return matchesType && matchesSearch;
    }).toList();

    switch (_sortBy) {
      case _SortBy.newest: list.sort((a, b) => b.date.compareTo(a.date)); break;
      case _SortBy.oldest: list.sort((a, b) => a.date.compareTo(b.date)); break;
      case _SortBy.highest: list.sort((a, b) => b.amount.compareTo(a.amount)); break;
      case _SortBy.lowest: list.sort((a, b) => a.amount.compareTo(b.amount)); break;
    }
    return list;
  }

  Map<String, List<TransactionModel>> _groupTransactions(List<TransactionModel> list) {
    final grouped = <String, List<TransactionModel>>{};
    for (var t in list) {
      final dateKey = DateFormat('yyyy-MM-dd').format(t.date);
      if (!grouped.containsKey(dateKey)) grouped[dateKey] = [];
      grouped[dateKey]!.add(t);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final provider = context.watch<TransactionProvider>();
    final currency = context.watch<CurrencyProvider>();

    final filtered = _applyFilters(provider.transactions);
    final grouped = _groupTransactions(filtered);
    final sortedKeys = grouped.keys.toList();
    
    if (_sortBy == _SortBy.oldest) {
      sortedKeys.sort((a, b) => a.compareTo(b));
    } else {
      sortedKeys.sort((a, b) => b.compareTo(a));
    }

    final totalIncome = filtered.where((t) => t.type == 'income').fold<double>(0, (s, t) => s + t.amount);
    final totalExpense = filtered.where((t) => t.type == 'expense').fold<double>(0, (s, t) => s + t.amount);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: _buildAppBar(colors),
      body: Column(
        children: [
          _buildFilterTabs(colors, provider),
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _buildSummaryGrid(colors, currency, filtered.length, totalIncome, totalExpense),
                ),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 64, color: colors.textDisabled.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          Text('No transactions found', style: TextStyle(color: colors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  )
                else
                  for (var dateKey in sortedKeys) ...[
                    SliverToBoxAdapter(
                      child: _DateHeader(
                        label: _formatDateHeader(grouped[dateKey]!.first.date),
                        total: grouped[dateKey]!.fold<double>(0, (s, t) => s + (t.type == 'income' ? t.amount : -t.amount)),
                        currency: currency,
                        colors: colors,
                      ),
                    ),
                    SliverList.builder(
                      itemCount: grouped[dateKey]!.length,
                      itemBuilder: (context, i) => _TransactionTile(
                        transaction: grouped[dateKey]![i],
                        currency: currency,
                        colors: colors,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.push(AppRoutes.transactionDetails, extra: grouped[dateKey]![i]);
                        },
                      ),
                    ),
                  ],
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppColorsExtension colors) {
    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      backgroundColor: colors.background,
      toolbarHeight: 90,
      title: _isSearchVisible 
        ? Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: colors.textPrimary, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(color: colors.textSecondary, fontSize: 14),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search_rounded, color: colors.textSecondary, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(Icons.close_rounded, color: colors.textSecondary, size: 20),
                  onPressed: () => setState(() {
                    _isSearchVisible = false;
                    _searchQuery = '';
                    _searchController.clear();
                  }),
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          )
        : Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary, size: 18),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('All Transactions', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: -0.5)),
                    Text('Manage your financial history', style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isSearchVisible = true);
                },
                child: _buildActionIcon(Icons.filter_alt_rounded, colors),
              ),
              const SizedBox(width: 10),
              PopupMenuButton<_SortBy>(
                onSelected: (v) {
                  HapticFeedback.selectionClick();
                  setState(() => _sortBy = v);
                },
                offset: const Offset(0, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                itemBuilder: (_) => [
                  _sortItem(_SortBy.newest, 'Newest First', colors),
                  _sortItem(_SortBy.oldest, 'Oldest First', colors),
                  _sortItem(_SortBy.highest, 'Highest Amount', colors),
                  _sortItem(_SortBy.lowest, 'Lowest Amount', colors),
                ],
                child: _buildActionIcon(Icons.swap_vert_rounded, colors),
              ),
            ],
          ),
    );
  }

  PopupMenuItem<_SortBy> _sortItem(_SortBy v, String label, AppColorsExtension colors) {
    final active = _sortBy == v;
    return PopupMenuItem(
      value: v,
      child: Row(
        children: [
          Icon(active ? Icons.check_circle_rounded : Icons.circle_outlined, size: 18, color: active ? AppColors.primary : colors.textDisabled),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: active ? AppColors.primary : colors.textPrimary, fontWeight: active ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, AppColorsExtension colors) {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Icon(icon, color: colors.textPrimary, size: 20),
    );
  }

  Widget _buildFilterTabs(AppColorsExtension colors, TransactionProvider provider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          _SegmentTab(label: 'All - ${provider.transactions.length}', icon: Icons.account_balance_wallet_rounded, selected: _typeFilter == 'all', colors: colors, onTap: () => setState(() => _typeFilter = 'all')),
          _SegmentTab(label: 'Income', icon: Icons.arrow_downward_rounded, selected: _typeFilter == 'income', colors: colors, activeColor: AppColors.success, onTap: () => setState(() => _typeFilter = 'income')),
          _SegmentTab(label: 'Expense', icon: Icons.arrow_upward_rounded, selected: _typeFilter == 'expense', colors: colors, activeColor: AppColors.error, onTap: () => setState(() => _typeFilter = 'expense')),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(AppColorsExtension colors, CurrencyProvider currency, int count, double income, double expense) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 1.6, // Increased height to prevent overflow
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: [
          _SummaryBox(title: 'Total Transactions', value: '$count', sub: 'All time', icon: Icons.receipt_long_rounded, iconColor: Colors.blue, colors: colors),
          _SummaryBox(title: 'Total Spent', value: '- ${currency.format(expense)}', sub: 'This month', icon: Icons.trending_down_rounded, iconColor: AppColors.error, valueColor: AppColors.error, colors: colors),
          _SummaryBox(title: 'Total Received', value: '+ ${currency.format(income)}', sub: 'This month', icon: Icons.trending_up_rounded, iconColor: AppColors.success, valueColor: AppColors.success, colors: colors),
          _SummaryBox(title: 'Net Balance', value: '${income >= expense ? '+' : '-'} ${currency.format((income - expense).abs())}', sub: 'This month', icon: Icons.pie_chart_rounded, iconColor: Colors.purple, valueColor: income >= expense ? AppColors.success : AppColors.error, colors: colors),
        ],
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color? activeColor;
  final AppColorsExtension colors;
  final VoidCallback onTap;

  const _SegmentTab({required this.label, required this.icon, required this.selected, this.activeColor, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = activeColor ?? AppColors.primary;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? active : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: selected ? Colors.white : colors.textSecondary),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: selected ? Colors.white : colors.textSecondary, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  final String title, value, sub;
  final IconData icon;
  final Color iconColor;
  final Color? valueColor;
  final AppColorsExtension colors;

  const _SummaryBox({required this.title, required this.value, required this.sub, required this.icon, required this.iconColor, this.valueColor, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textSecondary, fontSize: 9, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          FittedBox(child: Text(value, style: TextStyle(color: valueColor ?? colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w900))),
          Text(sub, style: TextStyle(color: colors.textDisabled, fontSize: 8, fontWeight: FontWeight.w500)),
          const Spacer(),
          Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 14, color: iconColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final String label;
  final double total;
  final CurrencyProvider currency;
  final AppColorsExtension colors;

  const _DateHeader({required this.label, required this.total, required this.currency, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 13, color: colors.textSecondary),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          Row(
            children: [
              Text(
                '${total >= 0 ? '+' : '-'} ${currency.format(total.abs())}',
                style: TextStyle(color: total >= 0 ? AppColors.success : AppColors.error, fontSize: 13, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: colors.textDisabled),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final CurrencyProvider currency;
  final AppColorsExtension colors;
  final VoidCallback onTap;

  const _TransactionTile({required this.transaction, required this.currency, required this.colors, required this.onTap});

  Map<String, dynamic> _getPaymentDetails(String mode) {
    switch (mode.toLowerCase()) {
      case 'upi':
        return {'icon': Icons.qr_code_2_rounded, 'color': Colors.blue};
      case 'card':
        return {'icon': Icons.credit_card_rounded, 'color': Colors.purple};
      case 'bank':
        return {'icon': Icons.account_balance_rounded, 'color': Colors.teal};
      default: // Cash
        return {'icon': Icons.payments_rounded, 'color': Colors.orange};
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final isIncome = t.type == 'income';
    final time = DateFormat('h:mm a').format(t.date);
    final payment = _getPaymentDetails(t.paymentMode);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: colors.background,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.border.withValues(alpha: 0.5)),
                ),
                alignment: Alignment.center,
                child: Text(t.icon, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(t.category, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.2))),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: (payment['color'] as Color).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            payment['icon'] as IconData,
                            size: 14,
                            color: (payment['color'] as Color),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(t.note.isNotEmpty ? '${t.note} • $time' : time, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Text(
                '${isIncome ? '+' : '-'} ${currency.format(t.amount)}',
                style: TextStyle(color: isIncome ? AppColors.success : AppColors.error, fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
