import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:moneymap/core/constants/color_constants.dart';
import 'package:moneymap/core/widgets/common/app_bottom_nav.dart';
import 'package:moneymap/features/home/data/models/category_model.dart';
import 'package:moneymap/features/home/presentation/providers/transaction_provider.dart';
import 'package:moneymap/features/category/presentation/providers/category_provider.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../../core/utils/export_helper.dart';

enum StatsPeriod { week, month, year, all }

extension StatsPeriodX on StatsPeriod {
  String get label => switch (this) {
        StatsPeriod.week => 'This Week',
        StatsPeriod.month => 'This Month',
        StatsPeriod.year => 'This Year',
        StatsPeriod.all => 'All Time',
      };

  String get short => switch (this) {
        StatsPeriod.week => '7D',
        StatsPeriod.month => '1M',
        StatsPeriod.year => '1Y',
        StatsPeriod.all => 'All',
      };

  String get prevLabel => switch (this) {
        StatsPeriod.week => 'vs last week',
        StatsPeriod.month => 'vs last month',
        StatsPeriod.year => 'vs last year',
        StatsPeriod.all => 'all time',
      };
}

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with TickerProviderStateMixin {
  final int _currentIndex = 1;
  int _touchedIndex = -1;
  int _touchedModeIndex = -1;
  StatsPeriod _period = StatsPeriod.month;
  bool _showIncome = false; 
  bool _isBusy = false;

  AnimationController? _ctrl;
  AnimationController get _c => _ctrl ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 950),
      );

  static const List<String> _fallbackHex = [
    '#2563EB',
    '#F97316',
    '#10B981',
    '#EF4444',
    '#0EA5E9',
    '#F59E0B',
    '#8B5CF6',
    '#EC4899',
  ];

  @override
  void initState() {
    super.initState();
    _c.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().loadTransactions();
      context.read<CategoryProvider>().loadCategories();
    });
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  // ---------------- helpers ----------------

  CategoryModel _resolveCategory(String name, int fallbackIndex) {
    final cp = context.read<CategoryProvider>();
    final merged = [...cp.byType('expense'), ...cp.byType('income')];
    return merged.firstWhere(
      (c) => c.name == name,
      orElse: () => CategoryModel(
        id: 'other',
        name: name,
        icon: '📌',
        type: 'expense',
        color: _fallbackHex[fallbackIndex % _fallbackHex.length],
      ),
    );
  }

  Color _catColor(CategoryModel c) {
    try {
      return Color(int.parse(c.color.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  DateTime? _dateOf(dynamic raw) =>
      raw is DateTime ? raw : DateTime.tryParse('$raw');

  ({DateTime start, DateTime end}) _range(StatsPeriod p, {int shift = 0}) {
    final now = DateTime.now();
    switch (p) {
      case StatsPeriod.week:
        final end = DateTime(now.year, now.month, now.day)
            .add(const Duration(days: 1))
            .subtract(Duration(days: 7 * shift));
        return (start: end.subtract(const Duration(days: 7)), end: end);
      case StatsPeriod.month:
        final s = DateTime(now.year, now.month - shift, 1);
        return (start: s, end: DateTime(s.year, s.month + 1, 1));
      case StatsPeriod.year:
        final s = DateTime(now.year - shift, 1, 1);
        return (start: s, end: DateTime(s.year + 1, 1, 1));
      case StatsPeriod.all:
        return (start: DateTime(1970), end: DateTime(2999));
    }
  }

  bool _inRange(DateTime d, ({DateTime start, DateTime end}) r) =>
      !d.isBefore(r.start) && d.isBefore(r.end);

  Future<void> _refresh() async {
    HapticFeedback.lightImpact();
    context.read<TransactionProvider>().loadTransactions();
    _c.forward(from: 0);
  }

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
  }

  void _setPeriod(StatsPeriod p) {
    if (p == _period) return;
    HapticFeedback.selectionClick();
    setState(() {
      _period = p;
      _touchedIndex = -1;
      _touchedModeIndex = -1;
    });
    _c.forward(from: 0);
  }

  void _showExportOptions() {
    final colors = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text('Export Financial Report', 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildExportBtn(isPdf: false, ctx: ctx)),
                const SizedBox(width: 12),
                Expanded(child: _buildExportBtn(isPdf: true, ctx: ctx)),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildExportBtn({required bool isPdf, required BuildContext ctx}) {
    final colors = context.colors;
    return InkWell(
      onTap: () {
        Navigator.pop(ctx);
        _exportData(isPdf);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isPdf ? Colors.red.withOpacity(0.06) : Colors.green.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isPdf ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(isPdf ? Icons.picture_as_pdf_rounded : Icons.table_chart_rounded,
                 color: isPdf ? Colors.red : Colors.green, size: 36),
            const SizedBox(height: 10),
            Text(isPdf ? 'Download PDF' : 'Download Excel',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Future<void> _exportData(bool isPdf) async {
    final provider = context.read<TransactionProvider>();
    if (provider.transactions.isEmpty) {
      _showToast('No transactions found to export', isError: true);
      return;
    }

    final currency = context.read<CurrencyProvider>();
    final user = FirebaseAuth.instance.currentUser;

    setState(() => _isBusy = true);
    try {
      if (isPdf) {
        await ExportHelper.exportToPdf(
          provider.transactions,
          userName: user?.displayName,
          currencySymbol: currency.currencySymbol,
        );
      } else {
        await ExportHelper.exportToExcel(provider.transactions);
      }
      _showToast('Export successful!');
    } catch (e) {
      _showToast('Export failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _showToast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final currency = context.watch<CurrencyProvider>();
    context.watch<CategoryProvider>();
    final loading = provider.isLoading && provider.transactions.isEmpty;

    final cur = _range(_period);
    final prev = _range(_period, shift: 1);

    double income = 0, expense = 0, prevExpense = 0, prevIncome = 0;
    final Map<String, double> expByCat = {};
    final Map<String, double> incByCat = {};
    final Map<String, double> spendByMode = {};
    final Map<String, int> modeCounts = {};
    final Map<int, double> spendBuckets = {}; // trend buckets
    int txCount = 0;

    for (final t in provider.transactions) {
      final d = _dateOf(t.date);
      if (d == null) continue;

      if (_inRange(d, prev) && _period != StatsPeriod.all) {
        if (t.type == 'income') {
          prevIncome += t.amount;
        } else {
          prevExpense += t.amount;
        }
      }

      if (!_inRange(d, cur)) continue;
      txCount++;
      if (t.type == 'income') {
        income += t.amount;
        incByCat[t.category] = (incByCat[t.category] ?? 0) + t.amount;
      } else {
        expense += t.amount;
        expByCat[t.category] = (expByCat[t.category] ?? 0) + t.amount;
        spendByMode[t.paymentMode] = (spendByMode[t.paymentMode] ?? 0) + t.amount;
        modeCounts[t.paymentMode] = (modeCounts[t.paymentMode] ?? 0) + 1;
        final key = switch (_period) {
          StatsPeriod.week => d.weekday,
          StatsPeriod.month => d.day,
          _ => d.month,
        };
        spendBuckets[key] = (spendBuckets[key] ?? 0) + t.amount;
      }
    }

    final map = _showIncome ? incByCat : expByCat;
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final sortedModes = spendByMode.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final sliceTotal = _showIncome ? income : expense;
    final hasData = sorted.isNotEmpty;

    final balance = income - expense;
    final savingsRate =
    income > 0 ? ((income - expense) / income * 100).clamp(-999, 100).toDouble() : 0.0;
    final expDelta =
        prevExpense > 0 ? ((expense - prevExpense) / prevExpense * 100) : null;
    final days = switch (_period) {
      StatsPeriod.week => 7,
      StatsPeriod.month => DateTime.now().day,
      StatsPeriod.year =>
        DateTime.now().difference(DateTime(DateTime.now().year)).inDays + 1,
      StatsPeriod.all => 30,
    };
    final avgPerDay = expense / math.max(days, 1);

    return Scaffold(
      backgroundColor: context.colors.background,
      extendBody: true,
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: context.colors.surface,
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _appBar(),
                SliverToBoxAdapter(
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) {
                      final t = Curves.easeOutCubic.transform(_c.value);
                      if (loading) return _skeleton();
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _periodSelector(),
                            const SizedBox(height: 16),
                            _stagger(
                                0, t, _hero(currency, balance, income, expense, expDelta, t)),
                            const SizedBox(height: 12),
                            _stagger(
                              1,
                              t,
                              Row(children: [
                                Expanded(
                                    child: _miniCard(
                                        currency,
                                        'Income',
                                        income * t,
                                        AppColors.success,
                                        Icons.south_west_rounded,
                                        prevIncome)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: _miniCard(
                                        currency,
                                        'Expense',
                                        expense * t,
                                        AppColors.error,
                                        Icons.north_east_rounded,
                                        prevExpense)),
                              ]),
                            ),
                            const SizedBox(height: 14),
                            _stagger(
                              2,
                              t,
                              _insightStrip(
                                  currency, savingsRate, sorted, avgPerDay, txCount),
                            ),
                            const SizedBox(height: 26),
                            _stagger(3, t, _trendCard(currency, spendBuckets, t)),
                            const SizedBox(height: 32),

                            if (!_showIncome && sortedModes.isNotEmpty) ...[
                              _stagger(4, t, _sectionTitle('Payment Methods')),
                              const SizedBox(height: 12),
                              _stagger(5, t, _paymentModeCompact(currency, sortedModes, modeCounts, expense, t)),
                              const SizedBox(height: 32),
                            ],

                            _stagger(
                              6,
                              t,
                              Row(children: [
                                _sectionTitle(_showIncome
                                    ? 'Income Sources'
                                    : 'Where Money Goes'),
                                const Spacer(),
                                _typeToggle(),
                              ]),
                            ),
                            const SizedBox(height: 12),
                            if (hasData)
                              _stagger(7, t, _donutCard(currency, sorted, sliceTotal, t))
                            else
                              _emptyState(),
                            if (hasData) ...[
                              const SizedBox(height: 32),
                              Row(children: [
                                _sectionTitle('Breakdown'),
                                const Spacer(),
                                Text('${sorted.length} categories',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: context.colors.textSecondary)),
                              ]),
                              const SizedBox(height: 12),
                              ...sorted.asMap().entries.map((e) {
                                final i = e.key;
                                final entry = e.value;
                                final pct = sliceTotal == 0
                                    ? 0.0
                                    : entry.value / sliceTotal * 100;
                                final cat = _resolveCategory(entry.key, i);
                                return _stagger(
                                  8 + i,
                                  t,
                                  _categoryRow(
                                    currency,
                                    rank: i + 1,
                                    icon: cat.icon,
                                    name: entry.key,
                                    amount: entry.value,
                                    percentage: pct,
                                    color: _catColor(cat),
                                    progress: t,
                                    selected: _touchedIndex == i,
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(() => _touchedIndex =
                                          _touchedIndex == i ? -1 : i);
                                    },
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_isBusy)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      bottomNavigationBar:
          AppBottomNav(currentIndex: _currentIndex, onTap: _onNavTap),
    );
  }

  // ---------------- pieces ----------------

  /// staggered slide + fade based on global progress
  Widget _stagger(int i, double t, Widget child) {
    final start = (i * 0.05).clamp(0.0, 0.6);
    final local = ((t - start) / (1 - start)).clamp(0.0, 1.0);
    return Opacity(
      opacity: local,
      child: Transform.translate(
        offset: Offset(0, 26 * (1 - local)),
        child: child,
      ),
    );
  }

  Widget _appBar() {
    final colors = context.colors;
    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: colors.background,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 90,
      titleSpacing: 16,
      title: Row(
        children: [
          GestureDetector(
            onTap: () => context.go(AppRoutes.home),
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
                  "Statistics",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.8,
                    color: colors.textPrimary,
                  ),
                ),
                Text("Your money, clearly explained", style: TextStyle(fontSize: 13, color: colors.textSecondary)),
              ],
            ),
          ),
          _iconBtn(Icons.file_download_outlined, _showExportOptions),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => Material(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, size: 20, color: context.colors.textPrimary),
          ),
        ),
      );

  Widget _sectionTitle(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w800,
      color: context.colors.textPrimary,
      letterSpacing: -0.4,
    ),
  );

  /// inline segmented control
  Widget _periodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border.withValues(alpha: .14)),
      ),
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth / StatsPeriod.values.length;
        return Stack(children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment(
                -1 + 2 * (_period.index / (StatsPeriod.values.length - 1)), 0),
            child: Container(
              width: w,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: .3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: StatsPeriod.values.map((p) {
              final active = p == _period;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _setPeriod(p),
                  child: SizedBox(
                    height: 34,
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w500,
                          color: active
                              ? Colors.white
                              : context.colors.textSecondary,
                        ),
                        child: Text(p.short),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ]);
      }),
    );
  }

  Widget _hero(
      CurrencyProvider currency, double balance, double income, double expense, double? delta, double t) {
    final usageRatio = income > 0 ? (expense / income) : (expense > 0 ? 1.0 : 0.0);
    final isOverspent = income > 0 && expense > income;
    final barProgress = usageRatio.clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1B2A5B), Color(0xFF2563EB), Color(0xFF3B82F6)],
            stops: [0, .55, 1],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: .32),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Stack(children: [
          Positioned(
            right: -40,
            top: -50,
            child: _orb(150, Colors.white.withValues(alpha: .12)),
          ),
          Positioned(
            left: -30,
            bottom: -60,
            child: _orb(130, Colors.white.withValues(alpha: .07)),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.account_balance_wallet_rounded,
                      size: 16, color: Colors.white.withValues(alpha: .85)),
                  const SizedBox(width: 7),
                  Text('Net Balance',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .85),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .2,
                      )),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_period.label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        currency.format(balance * t),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          height: 1,
                          letterSpacing: -1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Icon(
                      balance >= 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 20,
                      color: balance >= 0
                          ? const Color(0xFF86EFAC)
                          : const Color(0xFFFCA5A5),
                    ),
                  ),
                ]),
                if (delta != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(
                      delta <= 0
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      size: 13,
                      color: delta <= 0
                          ? const Color(0xFF86EFAC)
                          : const Color(0xFFFCA5A5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${delta.abs().toStringAsFixed(0)}% spending ${_period.prevLabel}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: .9),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600),
                    ),
                  ]),
                ],
                const SizedBox(height: 18),
                // Utilization Progress Bar
                Stack(
                  children: [
                    Container(
                      height: 10,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    LayoutBuilder(builder: (context, box) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        height: 10,
                        width: box.maxWidth * barProgress * t,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isOverspent 
                                ? [const Color(0xFFEF4444), const Color(0xFFF87171)]
                                : [const Color(0xFF4ADE80), const Color(0xFF86EFAC)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 10),
                Row(children: [
                  _legendDot(
                      const Color(0xFF4ADE80), 'In ${currency.format(income)}'),
                  const SizedBox(width: 16),
                  _legendDot(isOverspent ? const Color(0xFFEF4444) : Colors.white.withValues(alpha: .45),
                      'Out ${currency.format(expense)}'),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _orb(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );

  Widget _legendDot(Color c, String text) => Row(children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text,
            style: TextStyle(
                color: Colors.white.withValues(alpha: .9),
                fontSize: 11.5,
                fontWeight: FontWeight.w600)),
      ]);

  Widget _miniCard(
      CurrencyProvider currency, String title, double amount, Color color, IconData icon, double prev) {
    final delta = prev > 0 ? (amount - prev) / prev * 100 : null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: .14)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: color.withValues(alpha: .12)),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 14),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(currency.format(amount),
              maxLines: 1,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                  height: 1,
                  letterSpacing: -.5)),
        ),
        const SizedBox(height: 6),
        Text(
          delta == null
              ? '—'
              : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)}% ${_period.prevLabel}',
          style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: context.colors.textSecondary),
        ),
      ]),
    );
  }

  Widget _insightStrip(CurrencyProvider currency, double savingsRate,
      List<MapEntry<String, double>> sorted, double avgPerDay, int txCount) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: [
          _chip(
              Icons.savings_rounded,
              'Savings',
              '${savingsRate.toStringAsFixed(1)}%',
              savingsRate >= 20
                  ? AppColors.success
                  : savingsRate >= 0
                      ? AppColors.warning
                      : AppColors.error),
          if (sorted.isNotEmpty)
            _chip(Icons.local_fire_department_rounded, 'Top', sorted.first.key,
                AppColors.warning),
          _chip(Icons.timeline_rounded, 'Avg/day', currency.format(avgPerDay),
              AppColors.info),
          _chip(Icons.receipt_long_rounded, 'Txns', '$txCount',
              AppColors.primary),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .20)),
      ),
      child: Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text('$label ',
            style:
                TextStyle(fontSize: 12, color: context.colors.textSecondary)),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 96),
          child: Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
        ),
      ]),
    );
  }

  Widget _typeToggle() {
    Widget seg(String text, bool active, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primary.withValues(alpha: .12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(text,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color:
                      active ? AppColors.primary : context.colors.textSecondary,
                )),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: context.colors.border.withValues(alpha: .14)),
      ),
      child: Row(children: [
        seg('Expense', !_showIncome, () {
          HapticFeedback.selectionClick();
          setState(() {
            _showIncome = false;
            _touchedIndex = -1;
            _touchedModeIndex = -1;
          });
          _c.forward(from: .35);
        }),
        seg('Income', _showIncome, () {
          HapticFeedback.selectionClick();
          setState(() {
            _showIncome = true;
            _touchedIndex = -1;
            _touchedModeIndex = -1;
          });
          _c.forward(from: .35);
        }),
      ]),
    );
  }

  // ---- trend bar chart ----
  Widget _trendCard(CurrencyProvider currency, Map<int, double> buckets, double t) {
    final keys = switch (_period) {
      StatsPeriod.week => List.generate(7, (i) => i + 1),
      StatsPeriod.month => List.generate(math.max(DateTime.now().day, 1), (i) => i + 1),
      _ => List.generate(12, (i) => i + 1),
    };
    final maxV = buckets.values.isEmpty
        ? 1.0
        : buckets.values.reduce((a, b) => a > b ? a : b);

    String labelOf(int k) => switch (_period) {
          StatsPeriod.week => ['M', 'T', 'W', 'T', 'F', 'S', 'S'][(k - 1) % 7],
          StatsPeriod.month => k % 5 == 0 || k == 1 ? '$k' : '',
          _ => k % 3 == 0 ? DateFormat.MMM().format(DateTime(2024, k))[0] : '',
        };

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      decoration: _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Text('Spending Trend',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary)),
          const Spacer(),
          Text(
            switch (_period) {
              StatsPeriod.week => 'by day',
              StatsPeriod.month => 'by date',
              _ => 'by month',
            },
            style:
                TextStyle(fontSize: 11.5, color: context.colors.textSecondary, fontWeight: FontWeight.w600),
          ),
        ]),
        const SizedBox(height: 24),
        SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceBetween,
              maxY: maxV * 1.2,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  tooltipBgColor: context.colors.textPrimary,
                  tooltipRoundedRadius: 12,
                  getTooltipItem: (g, gi, r, ri) => BarTooltipItem(
                    currency.format(r.toY),
                    TextStyle(
                        color: context.colors.surface,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxV <= 0 ? 1.0 : maxV / 3,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: context.colors.border.withValues(alpha: .08),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, _) {
                      if (v.toInt() >= keys.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          labelOf(keys[v.toInt()]),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textSecondary),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: List.generate(keys.length, (i) {
                final v = (buckets[keys[i]] ?? 0) * t;
                final isMax = maxV > 0 && (buckets[keys[i]] ?? 0) == maxV;
                return BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: v,
                    width: keys.length > 20 ? 6 : 14,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: isMax
                          ? [const Color(0xFFF87171), const Color(0xFFEF4444)]
                          : [AppColors.primary.withOpacity(0.4), AppColors.primary],
                    ),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxV * 1.2,
                      color: context.colors.border.withValues(alpha: .05),
                    ),
                  ),
                ]);
              }),
            ),
          ),
        ),
      ]),
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: context.colors.border.withValues(alpha: .12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      );

  Widget _paymentModeCompact(CurrencyProvider currency, List<MapEntry<String, double>> sorted, Map<String, int> counts, double total, double t) {
    final selected = _touchedModeIndex >= 0 && _touchedModeIndex < sorted.length
        ? sorted[_touchedModeIndex]
        : null;
    
    IconData getModeIcon(String mode) {
      switch (mode.toLowerCase()) {
        case 'upi': return Icons.qr_code_2_rounded;
        case 'cash': return Icons.payments_rounded;
        case 'card': return Icons.credit_card_rounded;
        case 'bank': return Icons.account_balance_rounded;
        default: return Icons.wallet_rounded;
      }
    }

    Color getModeColor(String mode) {
      switch (mode.toLowerCase()) {
        case 'upi': return Colors.blue;
        case 'cash': return Colors.orange;
        case 'card': return Colors.purple;
        case 'bank': return Colors.teal;
        default: return AppColors.primary;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(children: [
        SizedBox(
          height: 160,
          child: Stack(alignment: Alignment.center, children: [
            PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (event, res) {
                    if (!event.isInterestedForInteractions || res?.touchedSection == null) return;
                    final i = res!.touchedSection!.touchedSectionIndex;
                    if (i != _touchedModeIndex) {
                      HapticFeedback.selectionClick();
                      setState(() => _touchedModeIndex = i);
                    }
                  },
                ),
                sections: List.generate(sorted.length, (i) {
                  final e = sorted[i];
                  final touched = i == _touchedModeIndex;
                  final color = getModeColor(e.key);
                  return PieChartSectionData(
                    color: touched ? color : color.withOpacity(0.75),
                    value: e.value,
                    radius: touched ? 20 : 14,
                    showTitle: false,
                  );
                }),
                centerSpaceRadius: 55,
                sectionsSpace: 3,
                startDegreeOffset: -90,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  selected != null ? selected.key.toUpperCase() : 'TOTAL OUT',
                  style: TextStyle(fontSize: 10, color: context.colors.textSecondary, fontWeight: FontWeight.w800, letterSpacing: 1),
                ),
                const SizedBox(height: 2),
                Text(
                  currency.format((selected?.value ?? total) * t),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: context.colors.textPrimary),
                ),
                if (selected == null)
                  Text(
                    '${counts.values.fold(0, (a, b) => a + b)} Transactions',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: context.colors.textDisabled),
                  ),
              ],
            ),
          ]),
        ),
        const SizedBox(height: 24),
        ...sorted.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          final color = getModeColor(e.key);
          final active = _touchedModeIndex == i;
          final count = counts[e.key] ?? 0;
          
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _touchedModeIndex = active ? -1 : i);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: active ? color.withOpacity(0.08) : context.colors.background.withOpacity(0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: active ? color.withOpacity(0.4) : context.colors.border.withOpacity(0.06), width: 1.2),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                    child: Icon(getModeIcon(e.key), color: color, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.key, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
                        Text('$count Transactions', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.colors.textSecondary)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(currency.format(e.value), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: context.colors.textPrimary)),
                      Text('${(e.value / total * 100).toStringAsFixed(1)}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ]),
    );
  }

  Widget _donutCard(
      CurrencyProvider currency, List<MapEntry<String, double>> sorted, double total, double t) {
    final selected = _touchedIndex >= 0 && _touchedIndex < sorted.length
        ? sorted[_touchedIndex]
        : null;
    final selPct =
    selected == null || total == 0 ? null : selected.value / total * 100;
    final topColor = sorted.isEmpty
        ? AppColors.primary
        : _catColor(_resolveCategory(sorted.first.key, 0));

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
      decoration: _cardDeco(),
      child: Column(children: [
        SizedBox(
          height: 250,
          child: Stack(alignment: Alignment.center, children: [
            Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    topColor.withValues(alpha: .16 * t),
                    topColor.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            Transform.scale(
              scale: .88 + t * .12,
              child: Opacity(
                opacity: t,
                child: PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (event, res) {
                        if (!event.isInterestedForInteractions ||
                            res?.touchedSection == null) return;
                        final i = res!.touchedSection!.touchedSectionIndex;
                        if (i != _touchedIndex) {
                          HapticFeedback.selectionClick();
                          setState(() => _touchedIndex = i);
                        }
                      },
                    ),
                    sections: _sections(sorted, total),
                    centerSpaceRadius: 76,
                    sectionsSpace: 3,
                    startDegreeOffset: -90,
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                    scale: Tween(begin: .92, end: 1.0).animate(anim),
                    child: child),
              ),
              child: Column(
                key: ValueKey(selected?.key ?? 'total'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: (selected == null ? AppColors.primary : topColor)
                          .withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      selPct != null
                          ? '${selPct.toStringAsFixed(1)}% OF TOTAL'
                          : (_showIncome ? 'TOTAL INCOME' : 'TOTAL SPENT'),
                      style: TextStyle(
                          fontSize: 10,
                          letterSpacing: .6,
                          fontWeight: FontWeight.w800,
                          color: selected == null
                              ? AppColors.primary
                              : topColor),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currency.format((selected?.value ?? total) * t),
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -.7,
                        color: context.colors.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    width: 120,
                    child: Text(
                      selected?.key ?? (_showIncome ? 'Income' : 'Expense'),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 4),
        Divider(color: context.colors.border.withValues(alpha: .14), height: 1),
        ...sorted.take(5).toList().asMap().entries.map((e) {
          final i = e.key;
          final entry = e.value;
          final cat = _resolveCategory(entry.key, i);
          final color = _catColor(cat);
          final pct = total == 0 ? 0.0 : entry.value / total * 100;
          final active = _touchedIndex == i;
          return _legendRow(
            currency,
            icon: cat.icon,
            name: entry.key,
            amount: entry.value,
            percentage: pct,
            color: color,
            active: active,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _touchedIndex = _touchedIndex == i ? -1 : i);
            },
          );
        }),
        if (sorted.length > 5)
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 2),
            child: Text(
              '+${sorted.length - 5} more in the breakdown below',
              style: TextStyle(
                  fontSize: 11.5, color: context.colors.textSecondary),
            ),
          )
        else
          const SizedBox(height: 8),
      ]),
    );
  }

  Widget _legendRow(
    CurrencyProvider currency, {
    required String icon,
    required String name,
    required double amount,
    required double percentage,
    required Color color,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: .08) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(icon, style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active
                    ? context.colors.textPrimary
                    : context.colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currency.format(amount),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 11, color: color),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  List<PieChartSectionData> _sections(
      List<MapEntry<String, double>> sorted, double total) {
    return List.generate(sorted.length, (i) {
      final e = sorted[i];
      final touched = i == _touchedIndex;
      final pct = total == 0 ? 0.0 : e.value / total * 100;
      final color = _catColor(_resolveCategory(e.key, i));
      return PieChartSectionData(
        color: touched ? color : color.withValues(alpha: .90),
        value: e.value,
        radius: touched ? 46 : 34,
        title: pct < 1 ? '' : '${pct.toStringAsFixed(0)}%',
        titlePositionPercentageOffset: .58,
        titleStyle: TextStyle(
          fontSize: touched ? 13 : 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [Shadow(color: Colors.black26, blurRadius: 3)],
        ),
      );
    });
  }
  Widget _categoryRow(
    CurrencyProvider currency, {
    required int rank,
    required String icon,
    required String name,
    required double amount,
    required double percentage,
    required Color color,
    required double progress,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        decoration: BoxDecoration(
          color:
              selected ? color.withValues(alpha: .07) : context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: .45)
                : context.colors.border.withValues(alpha: .14),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(children: [
          Row(children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(icon, style: const TextStyle(fontSize: 18)),
              ),
              if (rank <= 3)
                Positioned(
                  top: -4,
                  left: -4,
                  child: Container(
                    width: 17,
                    height: 17,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: context.colors.surface, width: 2),
                    ),
                    child: Text('$rank',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary)),
                  const SizedBox(height: 2),
                  Text('${percentage.toStringAsFixed(1)}% of total',
                      style: TextStyle(
                          fontSize: 11.5, color: context.colors.textSecondary)),
                ],
              ),
            ),
            Text(currency.format(amount),
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.3,
                    color: context.colors.textPrimary)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: AnimatedProgressBar(
              value: (percentage / 100) * progress,
              color: color,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      height: 230,
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.border.withValues(alpha: .16)),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .08),
              shape: BoxShape.circle),
          child: Icon(Icons.donut_large_rounded,
              size: 30, color: AppColors.primary.withValues(alpha: .75)),
        ),
        const SizedBox(height: 14),
        Text('Nothing to show for ${_period.label.toLowerCase()}',
            style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 14.5,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Add a transaction and insights appear instantly',
            style:
                TextStyle(color: context.colors.textSecondary, fontSize: 12.5)),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () => context.push(AppRoutes.addTransaction),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Transaction'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ]),
    );
  }

  // ---- shimmer skeleton ----
  Widget _skeleton() {
    Widget box(double h, {double r = 20, double? w}) => Container(
          height: h,
          width: w ?? double.infinity,
          decoration: BoxDecoration(
            color: context.colors.border.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(r),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(children: [
        box(42, r: 16),
        const SizedBox(height: 16),
        box(180, r: 28),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: box(110, r: 22)),
          const SizedBox(width: 12),
          Expanded(child: box(110, r: 22)),
        ]),
        const SizedBox(height: 20),
        box(200, r: 26),
        const SizedBox(height: 20),
        box(300, r: 26),
      ]),
    );
  }
}

/// smooth animated progress bar
class AnimatedProgressBar extends StatelessWidget {
  const AnimatedProgressBar(
      {super.key, required this.value, required this.color});
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      return Stack(children: [
        Container(
          height: 6,
          width: double.infinity,
          color: color.withValues(alpha: .10),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          height: 6,
          width: box.maxWidth * value,
          decoration: BoxDecoration(
            gradient:
                LinearGradient(colors: [color.withValues(alpha: .55), color]),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ]);
    });
  }
}
