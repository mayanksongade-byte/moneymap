import 'dart:math' as math;
import 'dart:async';
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


enum StatsPeriod { d7, m1, y1, all }

extension StatsPeriodX on StatsPeriod {
  String get label => switch (this) {
    StatsPeriod.d7 => '7 Days',
    StatsPeriod.m1 => 'This Month',
    StatsPeriod.y1 => 'This Year',
    StatsPeriod.all => 'All Time',
  };

  String get short => switch (this) {
    StatsPeriod.d7 => '7D',
    StatsPeriod.m1 => '1M',
    StatsPeriod.y1 => '1Y',
    StatsPeriod.all => 'All',
  };
}

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with TickerProviderStateMixin {
  StatsPeriod _period = StatsPeriod.m1;
  bool _showIncome = false;
  int _touchedIndex = -1;
  int _touchedModeIndex = -1;
  bool _isExporting = false;

  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _animCtrl.forward();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tp = context.read<TransactionProvider>();
      final cp = context.read<CategoryProvider>();
      if (tp.transactions.isEmpty) tp.loadTransactions();
      cp.loadCategories();
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.mediumImpact();
    final tp = context.read<TransactionProvider>();
    final cp = context.read<CategoryProvider>();
    await Future.wait([
      tp.refreshTransactions(),
      Future.microtask(() => cp.loadCategories()),
    ]);
    _animCtrl.forward(from: 0);
  }

  void _changePeriod(StatsPeriod p) {
    if (_period == p) return;
    HapticFeedback.selectionClick();
    setState(() => _period = p);
    _animCtrl.forward(from: 0);
  }

  void _toggleType(bool showIncome) {
    if (_showIncome == showIncome) return;
    HapticFeedback.lightImpact();
    setState(() {
      _showIncome = showIncome;
      _touchedIndex = -1;
      _touchedModeIndex = -1;
    });
  }

  CategoryModel _getCategory(String categoryId, String name, String type, CategoryProvider cp) {
    // Try matching by ID first
    final byId = cp.byType(type).where((c) => c.id == categoryId).toList();
    if (byId.isNotEmpty) return byId.first;

    // Fallback to name (case-insensitive)
    final byName = cp.byType(type).where((c) => c.name.toLowerCase() == name.toLowerCase()).toList();
    if (byName.isNotEmpty) return byName.first;

    // Last resort: default with transaction's data if possible
    return CategoryModel(
      id: categoryId.isEmpty ? 'other' : categoryId,
      name: name,
      icon: '📊', // Default icon
      type: type,
      color: '#94A3B8', // Default color
    );
  }

  Color _hexToColor(String hex) {
    try {
      String h = hex.replaceAll('#', '').toUpperCase();
      if (h.length == 6) h = 'FF$h';
      // Ensure we have exactly 8 characters for ARGB
      if (h.length != 8) return Colors.blueGrey;
      return Color(int.parse('0x$h'));
    } catch (_) {
      return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tp = context.watch<TransactionProvider>();
    final cp = context.watch<CategoryProvider>();
    final currency = context.watch<CurrencyProvider>();

    final loading = tp.isLoading && tp.transactions.isEmpty;

    final now = DateTime.now();
    
    // Period Ranges
    final currentStart = switch (_period) {
      StatsPeriod.d7 => now.subtract(const Duration(days: 7)),
      StatsPeriod.m1 => DateTime(now.year, now.month, 1),
      StatsPeriod.y1 => DateTime(now.year, 1, 1),
      StatsPeriod.all => DateTime(1970),
    };
    
    final prevStart = switch (_period) {
      StatsPeriod.d7 => now.subtract(const Duration(days: 14)),
      StatsPeriod.m1 => DateTime(now.year, now.month - 1, 1),
      StatsPeriod.y1 => DateTime(now.year - 1, 1, 1),
      StatsPeriod.all => DateTime(1970),
    };
    final prevEnd = currentStart;

    double totalIncome = 0;
    double totalExpense = 0;
    double prevExpense = 0;
    final Map<String, ({String id, String name, double amount})> catData = {};
    final Map<String, double> modeMap = {};
    final Map<String, int> modeCount = {};
    final Map<int, double> trendMap = {};
    int currentTxCount = 0;

    for (final t in tp.transactions) {
      final d = t.date;
      final isInc = t.type.toLowerCase() == 'income';

      // Previous Period (Expense only for delta)
      if (_period != StatsPeriod.all && !isInc) {
        if (!d.isBefore(prevStart) && d.isBefore(prevEnd)) {
          prevExpense += t.amount;
        }
      }

      // Current Period
      if (d.isBefore(currentStart)) continue;
      
      currentTxCount++;
      if (isInc) {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
        final mode = t.paymentMode.isEmpty ? 'Cash' : t.paymentMode;
        modeMap[mode] = (modeMap[mode] ?? 0) + t.amount;
        modeCount[mode] = (modeCount[mode] ?? 0) + 1;
      }

      if (isInc == _showIncome) {
        final key = t.categoryId.isNotEmpty ? t.categoryId : t.category;
        final existing = catData[key];
        catData[key] = (
          id: t.categoryId,
          name: t.category,
          amount: (existing?.amount ?? 0) + t.amount,
        );
      }

      final bucket = switch (_period) {
        StatsPeriod.d7 => d.weekday,
        StatsPeriod.m1 => d.day,
        _ => d.month,
      };
      if (!isInc) {
        trendMap[bucket] = (trendMap[bucket] ?? 0) + t.amount;
      }
    }

    final sortedCats = catData.values.toList()..sort((a, b) => b.amount.compareTo(a.amount));
    final sortedModes = modeMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final netBalance = totalIncome - totalExpense;
    final savingsRate = totalIncome > 0 ? ((totalIncome - totalExpense) / totalIncome * 100) : 0.0;
    
    final expDelta = prevExpense > 0 ? ((totalExpense - prevExpense) / prevExpense * 100) : 0.0;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: _buildAppBar(colors),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _handleRefresh,
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: AnimatedBuilder(
                  animation: _animCtrl,
                  builder: (context, _) {
                    if (loading) return _buildSkeleton(colors);

                    return Column(
                      children: [
                        _staggered(0, _buildPeriodSelector(colors)),
                        const SizedBox(height: 24),
                        _staggered(1, _buildHeroCard(colors, currency, netBalance, totalIncome, totalExpense, _period.label, expDelta)),
                        const SizedBox(height: 16),
                        
                        if (currentTxCount == 0) ...[
                          const SizedBox(height: 16),
                          _staggered(2, _buildEmptyState(colors)),
                        ] else ...[
                          _staggered(2, Row(
                            children: [
                              Expanded(child: _buildMiniCard(colors, currency, "Income", totalIncome, const Color(0xFF10B981), Icons.arrow_downward_rounded, "+4.2%")),
                              const SizedBox(width: 12),
                              Expanded(child: _buildMiniCard(colors, currency, "Expense", totalExpense, const Color(0xFFF43F5E), Icons.arrow_upward_rounded, "+12%")),
                            ],
                          )),
                          const SizedBox(height: 16),
                          _staggered(3, _buildInsightsStrip(colors, currency, savingsRate, sortedCats, currentTxCount, totalExpense)),
                          const SizedBox(height: 28),
                          _staggered(4, _buildTrendChart(colors, currency, trendMap)),
                          const SizedBox(height: 32),
                          if (!_showIncome) ...[
                            _staggered(5, _buildPaymentMethods(colors, currency, sortedModes, modeCount, totalExpense)),
                            const SizedBox(height: 32),
                          ],
                          _staggered(6, _buildCategoryBreakdown(colors, currency, sortedCats, _showIncome ? totalIncome : totalExpense, cp)),
                          if (sortedCats.isNotEmpty) ...[
                            const SizedBox(height: 32),
                            _staggered(7, _buildFullBreakdown(colors, currency, sortedCats, _showIncome ? totalIncome : totalExpense, cp)),
                          ],
                        ],
                        const SizedBox(height: 120),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          if (_isExporting)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 1,
        onTap: (index) {
          // Navigation is handled by AppBottomNav internally.
          // We only need this callback if we want to perform extra actions on tap.
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppColorsExtension colors) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
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
              child: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary, size: 18),
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
                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: -0.5),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  "Your money, clearly explained",
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _showExportSheet,
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.file_download_rounded, color: AppColors.primary, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(AppColorsExtension colors) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border.withValues(alpha: 0.3)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - 8) / 4;
          return Stack(
            children: [
              AnimatedAlign(
                alignment: Alignment(
                  -1.0 + (_period.index * 2 / 3),
                  0,
                ),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: Container(
                  width: itemWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: StatsPeriod.values.map((p) {
                  final selected = _period == p;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _changePeriod(p),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: Text(
                          p.short,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                            color: selected ? Colors.black : colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroCard(AppColorsExtension colors, CurrencyProvider currency, double balance, double income, double expense, String period, double expDelta) {
    final ratio = income > 0 ? (expense / income).clamp(0.0, 1.0) : (expense > 0 ? 1.0 : 0.0);
    final isIncrease = expDelta >= 0;
    
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B2A5B), Color(0xFF2563EB), Color(0xFF3B82F6)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.white.withValues(alpha: 0.15), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -20,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.white.withValues(alpha: 0.1), Colors.transparent],
                ),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        const Text("Net Balance", style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(period, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const Spacer(),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: balance),
                  duration: const Duration(seconds: 1),
                  curve: Curves.easeOutQuart,
                  builder: (context, value, _) => Text(
                    currency.format(value),
                    style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -1),
                  ),
                ),
                const SizedBox(height: 8),
                if (_period != StatsPeriod.all)
                  Row(
                    children: [
                      Icon(
                        isIncrease ? Icons.trending_up_rounded : Icons.trending_down_rounded, 
                        color: isIncrease ? Colors.redAccent : Colors.greenAccent, 
                        size: 16
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "${expDelta.abs().toStringAsFixed(0)}% spending vs last ${_period == StatsPeriod.d7 ? '7D' : 'month'}", 
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w500)
                      ),
                    ],
                  ),
                const Spacer(),
                Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation(ratio > 0.8 ? Colors.redAccent : Colors.greenAccent),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildLegend("In", currency.format(income), Colors.greenAccent),
                        const SizedBox(width: 16),
                        _buildLegend("Out", currency.format(expense), Colors.redAccent),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String label, String amount, Color color) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                "$label $amount", 
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCard(AppColorsExtension colors, CurrencyProvider currency, String label, double amount, Color accent, IconData icon, String delta) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, color: accent, size: 14),
              ),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            child: Text(currency.format(amount), 
              style: TextStyle(color: colors.textPrimary, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          ),
          const SizedBox(height: 4),
          Text(delta, style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildInsightsStrip(AppColorsExtension colors, CurrencyProvider currency, double savingsRate, List<({String id, String name, double amount})> sortedCats, int txCount, double totalExp) {
    final topCat = sortedCats.isNotEmpty ? sortedCats.first.name : "None";
    final avg = totalExp / (_period == StatsPeriod.d7 ? 7 : (_period == StatsPeriod.m1 ? 30 : 365));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          _buildInsightChip(colors, Icons.savings_rounded, "Savings", "${savingsRate.toStringAsFixed(0)}%", savingsRate > 20 ? const Color(0xFF10B981) : Colors.orange),
          _buildInsightChip(colors, Icons.local_fire_department_rounded, "Top Cat", topCat, Colors.red),
          _buildInsightChip(colors, Icons.analytics_rounded, "Avg/Day", currency.format(avg), Colors.blue),
          _buildInsightChip(colors, Icons.receipt_long_rounded, "Txns", txCount.toString(), Colors.purple),
        ],
      ),
    );
  }

  Widget _buildInsightChip(AppColorsExtension colors, IconData icon, String label, String value, Color accent) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 16),
          const SizedBox(width: 8),
          Text("$label: ", style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          Text(value, style: TextStyle(color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildTrendChart(AppColorsExtension colors, CurrencyProvider currency, Map<int, double> trendMap) {
    final sortedKeys = trendMap.keys.toList()..sort();
    final maxVal = trendMap.values.isNotEmpty ? trendMap.values.reduce(math.max) : 1000.0;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Spending Trend", style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text("Activity over time", style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.analytics_rounded, color: AppColors.primary, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (trendMap.isEmpty)
            _buildSmallEmptyState(colors, "No spending data for this period")
          else
            AspectRatio(
              aspectRatio: 1.8,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal * 1.3,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: colors.surface,
                      tooltipRoundedRadius: 12,
                      tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      tooltipBorder: BorderSide(color: colors.border.withValues(alpha: 0.5)),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          currency.format(rod.toY),
                          TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w900, fontSize: 13),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          String label = value.toInt().toString();
                          if (_period == StatsPeriod.d7) {
                            const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                            label = (value.toInt() >= 1 && value.toInt() <= 7) ? days[value.toInt() - 1] : label;
                          }
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 8,
                            child: Text(
                              label,
                              style: TextStyle(color: colors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(color: colors.border.withValues(alpha: 0.1), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: sortedKeys.map((k) {
                    final val = trendMap[k]!;
                    final isMax = val == maxVal;
                    return BarChartGroupData(
                      x: k,
                      barRods: [
                        BarChartRodData(
                          toY: val,
                          width: 14,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: isMax 
                              ? [const Color(0xFFEF4444), const Color(0xFFF97316)] 
                              : [AppColors.primary.withValues(alpha: 0.8), AppColors.primary.withValues(alpha: 0.4)],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods(AppColorsExtension colors, CurrencyProvider currency, List<MapEntry<String, double>> modes, Map<String, int> counts, double total) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Payment Methods", style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 24),
          if (modes.isEmpty)
            _buildSmallEmptyState(colors, "No payment data yet")
          else ...[
            Row(
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 4,
                          centerSpaceRadius: 40,
                          startDegreeOffset: -90,
                          sections: modes.asMap().entries.map((e) {
                            final i = e.key;
                            final entry = e.value;
                            final selected = _touchedModeIndex == i;
                            return PieChartSectionData(
                              color: _getModeColor(entry.key),
                              value: entry.value,
                              radius: selected ? 20 : 16,
                              showTitle: false,
                            );
                          }).toList(),
                          pieTouchData: PieTouchData(
                            touchCallback: (event, response) {
                              setState(() {
                                if (!event.isInterestedForInteractions || response == null || response.touchedSection == null) {
                                  _touchedModeIndex = -1;
                                  return;
                                }
                                _touchedModeIndex = response.touchedSection!.touchedSectionIndex;
                              });
                            },
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("${modes.length}", style: TextStyle(color: colors.textPrimary, fontSize: 20, fontWeight: FontWeight.w900)),
                          Text("Modes", style: TextStyle(color: colors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    children: modes.take(3).map((e) => _buildModeMini(colors, e.key, e.value, total)).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...modes.asMap().entries.map((e) {
              final i = e.key;
              final entry = e.value;
              final selected = _touchedModeIndex == i;
              return GestureDetector(
                onTap: () => setState(() => _touchedModeIndex = selected ? -1 : i),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected ? _getModeColor(entry.key).withValues(alpha: 0.05) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: selected ? _getModeColor(entry.key).withValues(alpha: 0.2) : Colors.transparent),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: _getModeColor(entry.key).withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: Icon(_getModeIcon(entry.key), color: _getModeColor(entry.key), size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.key, style: TextStyle(color: colors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                            Text("${counts[entry.key]} transactions", style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(currency.format(entry.value), style: TextStyle(color: colors.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
                          Text("${(entry.value / total * 100).toStringAsFixed(1)}%", style: TextStyle(color: colors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildModeMini(AppColorsExtension colors, String name, double amount, double total) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: _getModeColor(name), shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
          Text("${(amount / total * 100).toStringAsFixed(0)}%", style: TextStyle(color: colors.textPrimary, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(AppColorsExtension colors, CurrencyProvider currency, List<({String id, String name, double amount})> cats, double total, CategoryProvider cp) {
    if (cats.isEmpty) return _buildEmptyState(colors);
    final top5 = cats.take(5).toList();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_showIncome ? "Income Sources" : "Category Distribution", 
              style: TextStyle(color: colors.textPrimary, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            _buildTypeToggle(colors),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: colors.border.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              SizedBox(
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (cats.isNotEmpty)
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _hexToColor(_getCategory(cats.first.id, cats.first.name, _showIncome ? 'income' : 'expense', cp).color).withValues(alpha: 0.15),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    PieChart(
                      PieChartData(
                        sectionsSpace: 4,
                        centerSpaceRadius: 65,
                        sections: cats.asMap().entries.map((e) {
                          final i = e.key;
                          final entry = e.value;
                          final selected = _touchedIndex == i;
                          final cat = _getCategory(entry.id, entry.name, _showIncome ? 'income' : 'expense', cp);
                          final pct = (entry.amount / total * 100);
                          final isTiny = pct < 5;
                          return PieChartSectionData(
                            color: _hexToColor(cat.color),
                            value: entry.amount,
                            radius: selected ? 38 : 30,
                            title: pct > 2 ? "${pct.toStringAsFixed(0)}%" : "",
                            titleStyle: TextStyle(
                              color: Colors.white, 
                              fontSize: selected ? 14 : (isTiny ? 9 : 11), 
                              fontWeight: FontWeight.w900,
                              shadows: [Shadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 3)],
                            ),
                            titlePositionPercentageOffset: selected ? 0.5 : 0.6,
                            showTitle: true,
                          );
                        }).toList(),
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            setState(() {
                              if (!event.isInterestedForInteractions || response == null || response.touchedSection == null) {
                                _touchedIndex = -1;
                                return;
                              }
                              _touchedIndex = response.touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                      ),
                    ),
                    if (_touchedIndex != -1 && _touchedIndex < cats.length)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(cats[_touchedIndex].name, 
                            style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700)),
                          Text(currency.format(cats[_touchedIndex].amount), 
                            style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
                        ],
                      )
                    else
                      const Text("Summary", textAlign: TextAlign.center, 
                        style: TextStyle(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ...top5.asMap().entries.map((e) {
                final i = e.key;
                final entry = e.value;
                final cat = _getCategory(entry.id, entry.name, _showIncome ? 'income' : 'expense', cp);
                final pct = (entry.amount / total * 100);
                final color = _hexToColor(cat.color);
                final selected = _touchedIndex == i;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _touchedIndex = selected ? -1 : i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selected ? color.withValues(alpha: 0.05) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: selected ? color.withValues(alpha: 0.2) : Colors.transparent),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Text(cat.icon, style: const TextStyle(fontSize: 16)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.name,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              currency.format(entry.amount),
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${pct.toStringAsFixed(1)}%",
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              if (cats.length > 5) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    "+${cats.length - 5} more in the breakdown below",
                    style: TextStyle(
                      color: colors.textSecondary.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFullBreakdown(AppColorsExtension colors, CurrencyProvider currency, List<({String id, String name, double amount})> cats, double total, CategoryProvider cp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("All Categories", style: TextStyle(color: colors.textPrimary, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            Text("${cats.length} total", style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 16),
        ...cats.asMap().entries.map((e) {
          final i = e.key;
          final entry = e.value;
          final cat = _getCategory(entry.id, entry.name, _showIncome ? 'income' : 'expense', cp);
          final pct = (entry.amount / total * 100);
          final color = _hexToColor(cat.color);
          final selected = _touchedIndex == i;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _touchedIndex = selected ? -1 : i);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: selected ? color.withValues(alpha: 0.05) : colors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: selected ? color.withValues(alpha: 0.3) : colors.border.withValues(alpha: 0.5)),
                boxShadow: selected ? [
                  BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 15, offset: const Offset(0, 8))
                ] : null,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                            child: Center(child: Text(cat.icon, style: const TextStyle(fontSize: 20))),
                          ),
                          if (i < 3)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: colors.surface, width: 2)),
                                child: Text("${i + 1}", style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.name, style: TextStyle(color: colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                            Text("${pct.toStringAsFixed(1)}% of total", style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      Text(currency.format(entry.amount), style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: pct / 100),
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: value,
                        minHeight: 6,
                        backgroundColor: color.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTypeToggle(AppColorsExtension colors) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          _buildTypeBtn(colors, "Expense", !_showIncome, () => _toggleType(false)),
          _buildTypeBtn(colors, "Income", _showIncome, () => _toggleType(true)),
        ],
      ),
    );
  }

  Widget _buildTypeBtn(AppColorsExtension colors, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(color: active ? Colors.white : colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _buildEmptyState(AppColorsExtension colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bar_chart_rounded, 
              size: 56, 
              color: AppColors.primary.withValues(alpha: 0.3)
            ),
          ),
          const SizedBox(height: 28),
          Text(
            "No Activity Yet", 
            style: TextStyle(
              color: colors.textPrimary, 
              fontSize: 20, 
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            )
          ),
          const SizedBox(height: 12),
          Text(
            "Your financial statistics will appear here once you start adding transactions.", 
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSecondary, 
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w500,
            )
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () => context.push(
              AppRoutes.addTransaction,
              extra: {'initialType': 'income'},
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    "Add your first transaction",
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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

  Widget _buildSmallEmptyState(AppColorsExtension colors, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Icon(Icons.query_stats_rounded, color: colors.textDisabled, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton(AppColorsExtension colors) {
    return Column(
      children: [
        _buildSkeletonItem(48, double.infinity, 24),
        const SizedBox(height: 24),
        _buildSkeletonItem(220, double.infinity, 32),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildSkeletonItem(100, double.infinity, 24)),
            const SizedBox(width: 12),
            Expanded(child: _buildSkeletonItem(100, double.infinity, 24)),
          ],
        ),
        const SizedBox(height: 28),
        _buildSkeletonItem(200, double.infinity, 28),
      ],
    );
  }

  Widget _buildSkeletonItem(double height, double width, double radius) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOut,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Container(
            height: height,
            width: width,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
        );
      },
    );
  }

  Widget _staggered(int index, Widget child) {
    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, _) {
        final start = index * 0.1;
        final end = start + 0.6;
        final curve = CurvedAnimation(
          parent: _animCtrl,
          curve: Interval(start.clamp(0.0, 1.0), end.clamp(0.0, 1.0), curve: Curves.easeOutCubic),
        );
        return Opacity(
          opacity: curve.value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - curve.value)),
            child: child,
          ),
        );
      },
    );
  }

  void _showExportSheet() {
    final colors = context.colors;
    // Default to today (start of day to end of day)
    final now = DateTime.now();
    DateTimeRange selectedRange = DateTimeRange(
      start: DateTime(now.year, now.month, now.day),
      end: DateTime(now.year, now.month, now.day),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: EdgeInsets.fromLTRB(32, 12, 32, 32 + MediaQuery.of(context).viewInsets.bottom),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 24),
                Text("Export Report", style: TextStyle(color: colors.textPrimary, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text("Select date range and format", style: TextStyle(color: colors.textSecondary, fontSize: 15)),
                const SizedBox(height: 24),

                // Date Range Picker Trigger
                InkWell(
                  onTap: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      initialDateRange: selectedRange,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: Theme.of(context).colorScheme.copyWith(
                            primary: AppColors.primary,
                            onPrimary: Colors.white,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) setSheetState(() => selectedRange = picked);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.border.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedRange.start == selectedRange.end 
                                  ? "Selected Date" 
                                  : "Selected Range",
                                style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                selectedRange.start == selectedRange.end
                                    ? DateFormat('dd MMM yyyy').format(selectedRange.start)
                                    : "${DateFormat('dd MMM').format(selectedRange.start)} - ${DateFormat('dd MMM yyyy').format(selectedRange.end)}",
                                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.edit_calendar_rounded, color: colors.textSecondary, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Format Options
                Row(
                  children: [
                    Expanded(child: _buildExportOpt(colors, "PDF", Icons.picture_as_pdf_rounded, Colors.red, true, selectedRange)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildExportOpt(colors, "Excel", Icons.table_chart_rounded, Colors.green, false, selectedRange)),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildExportOpt(AppColorsExtension colors, String label, IconData icon, Color color, bool isPdf, DateTimeRange range) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _handleExport(isPdf, range);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text("Download $label", style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Future<void> _handleExport(bool isPdf, DateTimeRange range) async {
    final tp = context.read<TransactionProvider>();
    final cur = context.read<CurrencyProvider>();
    final user = FirebaseAuth.instance.currentUser;

    // Filter Transactions (inclusive of both start and end dates)
    final startDate = DateTime(range.start.year, range.start.month, range.start.day);
    final endDate = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);

    final filtered = tp.transactions.where((t) {
      return !t.date.isBefore(startDate) && !t.date.isAfter(endDate);
    }).toList();

    final dateRangeStr = startDate == DateTime(range.end.year, range.end.month, range.end.day)
        ? DateFormat('dd MMM yyyy').format(startDate)
        : "${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}";

    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("No transactions found for $dateRangeStr"),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      if (isPdf) {
        await ExportHelper.exportToPdf(
          filtered, 
          userName: user?.displayName, 
          currencySymbol: cur.currencySymbol,
          dateRange: dateRangeStr,
        ).timeout(const Duration(seconds: 15));
      } else {
        await ExportHelper.exportToExcel(filtered)
            .timeout(const Duration(seconds: 15));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Export successful!"),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Export timed out. Please try again."),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Export failed: $e"), 
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // Removed old _buildOfflineIndicator as it's now a common widget

  IconData _getModeIcon(String mode) {
    switch (mode.toLowerCase()) {
      case 'upi': return Icons.qr_code_2_rounded;
      case 'card': return Icons.credit_card_rounded;
      case 'bank': return Icons.account_balance_rounded;
      case 'cash': return Icons.payments_rounded;
      default: return Icons.wallet_rounded;
    }
  }

  Color _getModeColor(String mode) {
    switch (mode.toLowerCase()) {
      case 'upi': return Colors.blue;
      case 'card': return Colors.purple;
      case 'bank': return Colors.teal;
      case 'cash': return Colors.orange;
      default: return Colors.indigo;
    }
  }
}
