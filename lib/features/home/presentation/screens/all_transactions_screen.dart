import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/color_constants.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../data/models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import '../../../category/presentation/providers/category_provider.dart';
import 'add_transaction_screen.dart';
import '../../../../core/providers/currency_provider.dart';

enum _SortBy { newest, oldest, highest, lowest }

class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({super.key});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  String _searchQuery = '';
  String _typeFilter = 'all'; // all | income | expense
  _SortBy _sortBy = _SortBy.newest;

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ---------- date helpers ----------
  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  String _sectionLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7 && diff > 0) return DateFormat('EEEE').format(date); // Monday...
    return '${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  String _timeLabel(DateTime date) => DateFormat('h:mm a').format(date);

  // ---------- filtering / sorting / grouping ----------
  List<TransactionModel> _applyFilters(List<TransactionModel> all) {
    final q = _searchQuery.trim().toLowerCase();
    final list = all.where((t) {
      final matchesType = _typeFilter == 'all' || t.type == _typeFilter;
      final matchesSearch = q.isEmpty ||
          t.category.toLowerCase().contains(q) ||
          t.note.toLowerCase().contains(q) ||
          t.amount.toStringAsFixed(0).contains(q);
      return matchesType && matchesSearch;
    }).toList();

    switch (_sortBy) {
      case _SortBy.newest:
        list.sort((a, b) => b.date.compareTo(a.date));
        break;
      case _SortBy.oldest:
        list.sort((a, b) => a.date.compareTo(b.date));
        break;
      case _SortBy.highest:
        list.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case _SortBy.lowest:
        list.sort((a, b) => a.amount.compareTo(b.amount));
        break;
    }
    return list;
  }

  List<_Section> _group(List<TransactionModel> list) {
    final out = <_Section>[];
    for (final t in list) {
      final label = _sectionLabel(t.date);
      if (out.isNotEmpty && out.last.label == label) {
        out.last.items.add(t);
      } else {
        out.add(_Section(label, [t]));
      }
    }
    return out;
  }

  // ---------- actions ----------
  Future<void> _openEdit(TransactionModel t) async {
    HapticFeedback.selectionClick();
    final provider = context.read<TransactionProvider>();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddTransactionScreen(transactionToEdit: t)),
    );
    if (result == true) provider.loadTransactions();
  }

  Future<bool> _confirmDelete(TransactionModel t, CurrencyProvider currency) async {
    final colors = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Delete transaction?', style: TextStyle(color: colors.textPrimary, fontSize: 17)),
        content: Text(
          '${t.category} • ${currency.format(t.amount)}',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _delete(TransactionModel t) async {
    final provider = context.read<TransactionProvider>();
    HapticFeedback.mediumImpact();
    final success = await provider.deleteTransaction(t.id!);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: success ? null : AppColors.error,
        content: Text(success
            ? 'Transaction deleted'
            : (provider.error ?? 'Failed to delete transaction')),
        action: success
            ? SnackBarAction(label: 'UNDO', onPressed: () => provider.restoreTransaction(t))
            : null,
      ),
    );
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final provider = context.watch<TransactionProvider>();
    final currency = context.watch<CurrencyProvider>();
    context.watch<CategoryProvider>(); // colors/icons refresh સાથે rebuild

    final isLoading = provider.isLoading && provider.transactions.isEmpty;
    final filtered = _applyFilters(provider.transactions);
    final sections = _group(filtered);

    final income = filtered.where((t) => t.type == 'income').fold<double>(0, (s, t) => s + t.amount);
    final expense = filtered.where((t) => t.type == 'expense').fold<double>(0, (s, t) => s + t.amount);

    return Scaffold(
      backgroundColor: colors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => provider.loadTransactions(),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverAppBar(
              pinned: true,
              elevation: 0,
              automaticallyImplyLeading: false,
              backgroundColor: colors.surface,
              surfaceTintColor: Colors.transparent,
              toolbarHeight: 82,
              titleSpacing: 16,
              title: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: colors.border,
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('All Transactions',
                            style: TextStyle(
                              color: colors.textPrimary, 
                              fontWeight: FontWeight.bold, 
                              fontSize: 22,
                            )),
                        const SizedBox(height: 2),
                        Text('Manage your financial history',
                            style: TextStyle(
                              color: colors.textSecondary, 
                              fontSize: 13,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                PopupMenuButton<_SortBy>(
                  icon: Icon(Icons.swap_vert_rounded, color: colors.textPrimary),
                  color: colors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onSelected: (v) => setState(() => _sortBy = v),
                  itemBuilder: (_) => [
                    _sortItem(_SortBy.newest, 'Newest first', colors),
                    _sortItem(_SortBy.oldest, 'Oldest first', colors),
                    _sortItem(_SortBy.highest, 'Highest amount', colors),
                    _sortItem(_SortBy.lowest, 'Lowest amount', colors),
                  ],
                ),
                const SizedBox(width: 8),
              ],
            ),

            // Summary + search + chips
            SliverToBoxAdapter(
              child: Container(
                color: colors.surface,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: Column(
                  children: [
                    _SummaryBar(
                      count: filtered.length,
                      income: income,
                      expense: expense,
                      currency: currency,
                      colors: colors,
                    ),
                    const SizedBox(height: 14),
                    _SearchField(
                      controller: _searchController,
                      colors: colors,
                      hasText: _searchQuery.isNotEmpty,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      onClear: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _FilterChip(
                          label: 'All',
                          count: provider.transactions.length,
                          selected: _typeFilter == 'all',
                          colors: colors,
                          onTap: () => setState(() => _typeFilter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Income',
                          selected: _typeFilter == 'income',
                          colors: colors,
                          activeColor: AppColors.success,
                          onTap: () => setState(() => _typeFilter = 'income'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Expense',
                          selected: _typeFilter == 'expense',
                          colors: colors,
                          activeColor: AppColors.error,
                          onTap: () => setState(() => _typeFilter = 'expense'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (isLoading)
              SliverList.builder(
                itemCount: 7,
                itemBuilder: (_, i) => _SkeletonTile(colors: colors),
              )
            else if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  colors: colors,
                  isFiltered: provider.transactions.isNotEmpty,
                  onReset: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _typeFilter = 'all';
                    });
                  },
                ),
              )
            else
              for (final section in sections) ...[
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _DateHeaderDelegate(
                    label: section.label,
                    total: section.items.fold<double>(
                      0,
                          (s, t) => s + (t.type == 'income' ? t.amount : -t.amount),
                    ),
                    currency: currency,
                    colors: colors,
                  ),
                ),
                SliverList.builder(
                  itemCount: section.items.length,
                  itemBuilder: (context, i) {
                    final t = section.items[i];
                    return _TransactionTile(
                      key: ValueKey(t.id),
                      transaction: t,
                      time: _timeLabel(t.date),
                      currency: currency,
                      colors: colors,
                      onTap: () => _openEdit(t),
                      confirmDelete: () => _confirmDelete(t, currency),
                      onDelete: () => _delete(t),
                    );
                  },
                ),
              ],

            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          HapticFeedback.lightImpact();
          final tp = context.read<TransactionProvider>();
          final res = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
          );
          if (res == true) tp.loadTransactions();
        },
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
      ),
    );
  }

  PopupMenuItem<_SortBy> _sortItem(_SortBy v, String label, AppColorsExtension colors) {
    final active = _sortBy == v;
    return PopupMenuItem(
      value: v,
      child: Row(
        children: [
          Icon(active ? Icons.check_rounded : Icons.remove, size: 18,
              color: active ? AppColors.primary : Colors.transparent),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                color: active ? AppColors.primary : colors.textPrimary,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                fontSize: 14,
              )),
        ],
      ),
    );
  }
}

class _Section {
  _Section(this.label, this.items);
  final String label;
  final List<TransactionModel> items;
}

// ---------------- Summary bar ----------------
class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.count,
    required this.income,
    required this.expense,
    required this.currency,
    required this.colors,
  });

  final int count;
  final double income, expense;
  final CurrencyProvider currency;
  final AppColorsExtension colors;

  @override
  Widget build(BuildContext context) {
    final net = income - expense;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _cell('Income', currency.format(income), AppColors.success),
          _divider(),
          _cell('Expense', currency.format(expense), AppColors.error),
          _divider(),
          _cell('Net', currency.format(net), net >= 0 ? AppColors.success : AppColors.error,
              sub: '$count txn'),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 30, color: colors.textDisabled.withOpacity(0.25));

  Widget _cell(String label, String value, Color color, {String? sub}) => Expanded(
    child: Column(
      children: [
        Text(sub ?? label,
            style: TextStyle(fontSize: 11, color: colors.textSecondary, fontWeight: FontWeight.w500)),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        ),
      ],
    ),
  );
}

// ---------------- Search ----------------
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.colors,
    required this.hasText,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final AppColorsExtension colors;
  final bool hasText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: TextStyle(color: colors.textPrimary, fontSize: 14.5),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search category, note or amount',
        hintStyle: TextStyle(color: colors.textHint, fontSize: 14),
        prefixIcon: Icon(Icons.search_rounded, color: colors.textSecondary, size: 21),
        suffixIcon: hasText
            ? IconButton(
          icon: Icon(Icons.close_rounded, color: colors.textSecondary, size: 19),
          onPressed: onClear,
        )
            : null,
        filled: true,
        fillColor: colors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.6)),
        ),
      ),
    );
  }
}

// ---------------- Filter chip ----------------
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.colors,
    this.activeColor,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppColorsExtension colors;
  final Color? activeColor;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? AppColors.primary;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.14) : colors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.transparent, width: 1.2),
        ),
        child: Text(
          count != null && count! > 0 ? '$label · $count' : label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? color : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ---------------- Sticky date header ----------------
class _DateHeaderDelegate extends SliverPersistentHeaderDelegate {
  _DateHeaderDelegate({
    required this.label,
    required this.total,
    required this.currency,
    required this.colors,
  });

  final String label;
  final double total;
  final CurrencyProvider currency;
  final AppColorsExtension colors;

  @override
  double get minExtent => 40;
  @override
  double get maxExtent => 40;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: colors.background,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: colors.textSecondary,
              )),
          const Spacer(),
          Text(
            '${total >= 0 ? '+' : '-'}${currency.format(total.abs())}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: total >= 0 ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DateHeaderDelegate old) =>
      old.label != label || old.total != total;
}

// ---------------- Transaction tile ----------------
class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    super.key,
    required this.transaction,
    required this.time,
    required this.currency,
    required this.colors,
    required this.onTap,
    required this.confirmDelete,
    required this.onDelete,
  });

  final TransactionModel transaction;
  final String time;
  final CurrencyProvider currency;
  final AppColorsExtension colors;
  final VoidCallback onTap;
  final Future<bool> Function() confirmDelete;
  final VoidCallback onDelete;

  IconData _getPaymentIcon(String mode) {
    switch (mode.toLowerCase()) {
      case 'upi': return Icons.qr_code_2_rounded;
      case 'card': return Icons.credit_card_rounded;
      case 'bank': return Icons.account_balance_rounded;
      default: return Icons.payments_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final isIncome = t.type == 'income';

    final category = context.read<CategoryProvider>().findByName(t.category, type: t.type);
    
    // Safely parse the color hex string to a Color object
    Color accent;
    if (category?.color != null) {
      try {
        final hexColor = category!.color.replaceFirst('#', '');
        accent = Color(int.parse('0xFF$hexColor'));
      } catch (_) {
        accent = isIncome ? AppColors.success : AppColors.error;
      }
    } else {
      accent = isIncome ? AppColors.success : AppColors.error;
    }

    final icon = (category?.icon ?? t.icon);

    return Dismissible(
      key: ValueKey('dis_${t.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => confirmDelete(),
      onDismissed: (_) => onDelete(),
      background: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.only(right: 22),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(icon, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                t.category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: colors.background,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: colors.border.withOpacity(0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_getPaymentIcon(t.paymentMode), size: 9, color: colors.textSecondary),
                                  const SizedBox(width: 3),
                                  Text(
                                    t.paymentMode,
                                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: colors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          t.note.trim().isEmpty ? time : '${t.note} · $time',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${isIncome ? '+' : '-'} ${currency.format(t.amount, showDecimals: true)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isIncome ? AppColors.success : AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- Skeleton ----------------
class _SkeletonTile extends StatefulWidget {
  const _SkeletonTile({required this.colors});
  final AppColorsExtension colors;

  @override
  State<_SkeletonTile> createState() => _SkeletonTileState();
}

class _SkeletonTileState extends State<_SkeletonTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.colors.surfaceVariant;
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Container(
          height: 70,
          decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

// ---------------- Empty state ----------------
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.colors, required this.isFiltered, required this.onReset});
  final AppColorsExtension colors;
  final bool isFiltered;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFiltered ? Icons.search_off_rounded : Icons.receipt_long_rounded,
                size: 38,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isFiltered ? 'No matching transactions' : 'No transactions yet',
              style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              isFiltered
                  ? 'Try changing the search or filters.'
                  : 'Add your first transaction to start tracking.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
            if (isFiltered) ...[
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Clear filters'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
