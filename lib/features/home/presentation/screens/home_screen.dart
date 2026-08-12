import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:moneymap/core/constants/color_constants.dart';
import 'package:moneymap/core/widgets/common/app_bottom_nav.dart';
import 'package:moneymap/features/home/presentation/widgets/balance_card.dart';
import 'package:moneymap/features/home/presentation/widgets/quick_actions.dart';
import 'package:moneymap/features/home/presentation/widgets/transaction_card.dart';
import 'package:moneymap/features/home/presentation/providers/transaction_provider.dart';
import 'package:moneymap/features/budget/presentation/providers/budget_provider.dart';
import 'package:moneymap/features/home/data/models/transaction_model.dart';
import 'package:moneymap/features/auth/presentation/providers/app_auth_provider.dart';
import 'package:moneymap/core/theme/app_colors_extension.dart';
import 'package:moneymap/config/routes/app_routes.dart';
import 'package:moneymap/core/providers/currency_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _refreshTick = 0;
  bool _settled = false;

  final ScrollController _scrollController = ScrollController();
  late AnimationController _appearanceController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _appearanceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _appearanceController,
      curve: Curves.easeOutQuart,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bootstrap();
    });
  }

  void _bootstrap() {
    final txProvider = context.read<TransactionProvider>();
    final budgetProvider = context.read<BudgetProvider>();

    txProvider.loadTransactions();
    txProvider.loadMonthlyTransactions();
    budgetProvider.loadBudget();

    void onLoaded() {
      if (!mounted) return;
      if (!txProvider.isLoading) {
        txProvider.removeListener(onLoaded);
        setState(() => _settled = true);
        _appearanceController.forward();
      }
    }

    txProvider.addListener(onLoaded);
    onLoaded();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _appearanceController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    if (index == _currentIndex && index == 0) return;
    
    // Navigation is already handled inside AppBottomNav.dart
    // Just update the index if needed, though HomeScreen usually stays at 0.
    if (mounted) setState(() => _currentIndex = 0);
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning 👋';
    if (hour < 17) return 'Good Afternoon ☀️';
    return 'Good Evening 🌙';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      extendBody: true,
      bottomNavigationBar: AppBottomNav(currentIndex: _currentIndex, onTap: _onNavTap),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: colors.surface,
        displacement: 40,
        onRefresh: () async {
          HapticFeedback.mediumImpact();
          await context.read<TransactionProvider>().refreshTransactions();
          context.read<BudgetProvider>().loadBudget();
          if (mounted) setState(() => _refreshTick++);
        },
        child: Consumer2<TransactionProvider, BudgetProvider>(
          builder: (context, txProvider, budgetProvider, _) {
            final allTransactions = txProvider.transactions;
            final recentTransactions = allTransactions.take(5).toList();
            final groups = _groupByDay(recentTransactions);
            final isInitialLoad = (txProvider.isLoading || !_settled) && allTransactions.isEmpty;

            if (isInitialLoad) {
              return _buildSkeletonLoader(context);
            }

            return CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                _buildPremiumHeader(context),
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          // 2. Total Balance Hero Card
                          BalanceCard(
                            key: ValueKey('balance_$_refreshTick'),
                            balance: txProvider.balance,
                            income: txProvider.totalIncome,
                            expense: txProvider.totalExpense,
                            lastUpdated: txProvider.lastRefreshedAt,
                          ),
                          const SizedBox(height: 24),
                          // 3. Financial Snapshot (Cash Flow)
                          _buildCashFlowDashboard(context, txProvider),
                          const SizedBox(height: 24),
                          // 4. Quick Actions
                          QuickActions(
                            onIncomeTap: () => context.push(AppRoutes.addTransaction, extra: {'initialType': 'income'}),
                            onExpenseTap: () => context.push(AppRoutes.addTransaction, extra: {'initialType': 'expense'}),
                            onBudgetTap: () => context.push(AppRoutes.budget),
                            onAnalyticsTap: () => context.push(AppRoutes.statistics),
                          ),
                          const SizedBox(height: 40),
                          // 5. Spending Overview (REFINED PREMIUM STYLE)
                          _buildAnalyticsSnapshot(context, txProvider),
                          const SizedBox(height: 32),
                          // 6. Monthly Budget (REFINED PREMIUM STYLE)
                          if (budgetProvider.hasBudget) ...[
                            _buildPremiumBudget(context, budgetProvider, txProvider.monthlyExpense),
                            const SizedBox(height: 32),
                          ],
                          // 7. Spending Insight Banner (SMALLER & CLOSER TO RECENT ACTIVITY)
                          if (txProvider.monthlyTransactions.isNotEmpty) ...[
                            _buildSpendingInsight(context, txProvider),
                            const SizedBox(height: 12), 
                          ],
                          // 8. Recent Activity Header
                          if (allTransactions.isNotEmpty)
                            _buildSectionHeader(
                              context,
                              title: 'Recent Activity',
                              actionLabel: 'View All',
                              onAction: () => context.push(AppRoutes.allTransactions),
                            ),
                          if (allTransactions.isNotEmpty) const SizedBox(height: 4),
                        ],
                      ),
                    ),
                  ),
                ),
                if (allTransactions.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(context),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    sliver: SliverList.builder(
                      itemCount: recentTransactions.length,
                      itemBuilder: (context, index) {
                        final t = recentTransactions[index];
                        return TransactionCard(
                          id: t.id,
                          category: t.category,
                          note: t.note,
                          amount: t.amount,
                          type: t.type,
                          date: formatRelativeDate(t.date),
                          icon: t.icon,
                          paymentMode: t.paymentMode,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.push(AppRoutes.transactionDetails, extra: t);
                          },
                          onDelete: () => context.read<TransactionProvider>().deleteTransaction(t.id!),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(BuildContext context) {
    final colors = context.colors;
    final user = context.watch<AppAuthProvider>().user;
    final name = (user?.displayName?.split(' ').first ?? 'MoneyMapper').toUpperCase();
    final initial = name.isNotEmpty ? name[0] : 'M';

    return SliverAppBar(
      pinned: true,
      expandedHeight: 120,
      backgroundColor: colors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 16),
        centerTitle: false,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getGreeting(),
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              name,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => HapticFeedback.selectionClick(),
          icon: Icon(Icons.notifications_none_rounded, color: colors.textPrimary, size: 26),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => context.push(AppRoutes.profile),
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.surfaceVariant, width: 1.5),
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                initial,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCashFlowDashboard(BuildContext context, TransactionProvider provider) {
    final colors = context.colors;
    final currency = context.watch<CurrencyProvider>();
    final balance = provider.monthlyBalance;
    final income = provider.monthlyIncome;
    final expense = provider.monthlyExpense;
    final isPositive = balance >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.surfaceVariant.withValues(alpha: 0.8), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isPositive ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      color: isPositive ? AppColors.success : AppColors.error,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'THIS MONTH',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: colors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '${isPositive ? '+' : ''}${currency.format(balance)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildMiniStat('Income', income, AppColors.success),
                  const SizedBox(height: 8),
                  _buildMiniStat('Expense', expense, AppColors.error),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            alignment: Alignment.centerLeft,
            child: Text(
              isPositive ? 'Positive Money Flow' : 'Negative Money Flow',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, double amount, Color color) {
    final colors = context.colors;
    final currency = context.watch<CurrencyProvider>();
    return Row(
      children: [
        Text(
          '$label  ',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textSecondary),
        ),
        Text(
          currency.format(amount),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
  }

  Widget _buildAnalyticsSnapshot(BuildContext context, TransactionProvider provider) {
    final colors = context.colors;
    final currency = context.watch<CurrencyProvider>();
    final spent = provider.monthlyExpense;
    final categorySummary = provider.getMonthlyExpenseByCategory();

    if (spent == 0) return const SizedBox.shrink();

    final sorted = categorySummary.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Spending Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: colors.textPrimary, letterSpacing: -0.5),
            ),
            GestureDetector(
              onTap: () => context.push(AppRoutes.statistics),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text('This Month', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: colors.surfaceVariant.withValues(alpha: 0.5), width: 1.5),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currency.format(spent),
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: colors.textPrimary, letterSpacing: -1.0),
                  ),
                  Text(
                    'spent this month',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // REFINED DONUT CHART
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 4,
                            centerSpaceRadius: 42,
                            startDegreeOffset: -90,
                            sections: sorted.asMap().entries.map((e) {
                              final index = e.key;
                              final entry = e.value;
                              return PieChartSectionData(
                                color: _getThemeCategoryColor(entry.key, index),
                                value: entry.value,
                                title: '',
                                radius: 14,
                                badgeWidget: null,
                              );
                            }).toList(),
                          ),
                        ),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: colors.background,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
                          ),
                          child: Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 24),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  // CHART LEGEND WITH PERCENTAGES
                  Expanded(
                    child: Column(
                      children: sorted.take(3).toList().asMap().entries.map((e) {
                        final index = e.key;
                        final entry = e.value;
                        final pct = (entry.value / spent * 100).round();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(color: _getThemeCategoryColor(entry.key, index), shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.key,
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: colors.textPrimary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '$pct%',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: colors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                currency.format(entry.value),
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: colors.textPrimary),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static const List<Color> _fallbackPalette = [
    Colors.indigoAccent,
    Colors.pinkAccent,
    Colors.cyan,
    Colors.amber,
    Colors.deepOrangeAccent,
  ];

  Color _getThemeCategoryColor(String category, int index) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'dining':
        return Colors.orangeAccent;
      case 'shopping':
        return Colors.blueAccent;
      case 'transport':
      case 'travel':
        return Colors.tealAccent;
      case 'bills':
      case 'utilities':
        return Colors.redAccent;
      case 'education':
        return Colors.indigoAccent;
      case 'entertainment':
        return Colors.purpleAccent;
      default:
        return _fallbackPalette[index % _fallbackPalette.length];
    }
  }

  Widget _buildPremiumBudget(BuildContext context, BudgetProvider provider, double spent) {
    if (!provider.hasBudget) return const SizedBox.shrink();

    final colors = context.colors;
    final currency = context.watch<CurrencyProvider>();
    final limit = provider.monthlyLimit ?? 0;
    final percent = (spent / limit).clamp(0.0, 1.0);
    final remaining = (limit - spent).clamp(0.0, double.infinity);
    final isOver = spent > limit;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colors.surfaceVariant, width: 1.5),
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
              Text(
                'Monthly Budget',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: colors.textPrimary, letterSpacing: 0.2),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isOver ? AppColors.error : AppColors.success).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isOver ? 'OVER LIMIT' : 'ON TRACK',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: isOver ? AppColors.error : AppColors.success),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currency.format(spent),
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: colors.textPrimary),
                  ),
                  Text(
                    'of ${currency.format(limit)} spent',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textSecondary),
                  ),
                ],
              ),
              Text(
                '${(percent * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: colors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // CUSTOM GRADIENT PROGRESS BAR
          Stack(
            children: [
              Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colors.surfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percent,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isOver 
                        ? [AppColors.error, Colors.redAccent] 
                        : [AppColors.primary, const Color(0xff1D4ED8)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.surfaceVariant, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.success),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${DateTime.now().difference(DateTime(DateTime.now().year, DateTime.now().month + 1, 0)).inDays.abs()} days left',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.success),
                      ),
                      Text(
                        '${currency.format(remaining)} available',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingInsight(BuildContext context, TransactionProvider provider) {
    final colors = context.colors;
    final currency = context.watch<CurrencyProvider>();
    final transactions = provider.monthlyTransactions;
    if (transactions.isEmpty) return const SizedBox.shrink();

    final expenses = provider.getMonthlyExpenseByCategory();
    String? topCategory;
    double maxVal = 0;
    expenses.forEach((k, v) {
      if (v > maxVal) {
        maxVal = v;
        topCategory = k;
      }
    });

    if (topCategory == null) return const SizedBox.shrink();
    final totalSpent = provider.monthlyExpense;
    final pct = totalSpent > 0 ? (maxVal / totalSpent * 100).round() : 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(AppRoutes.statistics),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                const Color(0xFFC084FC).withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))
                  ],
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spending Insight',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: colors.textPrimary),
                    ),
                    Text(
                      '$topCategory is where most money went.',
                      style: TextStyle(fontSize: 11, color: colors.textSecondary, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currency.format(maxVal),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF8B5CF6)),
                  ),
                  Text(
                    '$pct% of total',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: colors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, {
        required String title,
        required String actionLabel,
        required VoidCallback onAction,
      }) {
    final colors = context.colors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: colors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            foregroundColor: AppColors.primary,
          ),
          child: Row(
            children: [
              Text(
                actionLabel,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionTimeline(BuildContext context, _DayGroup group, int groupIndex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...group.items.map((t) => TransactionCard(
          id: t.id,
          category: t.category,
          note: t.note,
          amount: t.amount,
          type: t.type,
          date: formatRelativeDate(t.date),
          icon: t.icon,
          paymentMode: t.paymentMode,
          onTap: () {
            HapticFeedback.lightImpact();
            context.push(AppRoutes.transactionDetails, extra: t);
          },
          onDelete: () => context.read<TransactionProvider>().deleteTransaction(t.id!),
        )),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: 60, color: colors.textDisabled.withValues(alpha: 0.2)),
          const SizedBox(height: 24),
          Text(
            'Ready to save?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: colors.textPrimary),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Your financial overview will appear here after your first transaction.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => context.push(AppRoutes.addTransaction),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: const Text('Add Transaction', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Row(
            children: [
              _ShimmerBox(width: 120, height: 14, radius: 6),
            ],
          ),
          const SizedBox(height: 8),
          const _ShimmerBox(width: 160, height: 24, radius: 8),
          const SizedBox(height: 24),
          _ShimmerBox(width: double.infinity, height: 190, radius: 24),
          const SizedBox(height: 24),
          _ShimmerBox(width: double.infinity, height: 76, radius: 20),
          const SizedBox(height: 24),
          Row(
            children: List.generate(4, (i) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 3 ? 0 : 12),
                  child: const _ShimmerBox(width: double.infinity, height: 74, radius: 18),
                ),
              );
            }),
          ),
          const SizedBox(height: 32),
          const _ShimmerBox(width: 140, height: 18, radius: 6),
          const SizedBox(height: 16),
          ...List.generate(4, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                const _ShimmerBox(width: 44, height: 44, radius: 14),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _ShimmerBox(width: 100, height: 12, radius: 4),
                      SizedBox(height: 8),
                      _ShimmerBox(width: 70, height: 10, radius: 4),
                    ],
                  ),
                ),
                const _ShimmerBox(width: 60, height: 14, radius: 4),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final base = colors.surfaceVariant.withValues(alpha: 0.5);
    final highlight = colors.surfaceVariant.withValues(alpha: 0.15);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1.0 + 3 * t, 0),
                end: Alignment(1.0 + 3 * t, 0),
                colors: [base, highlight, base],
                stops: const [0.35, 0.5, 0.65],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DayGroup {
  _DayGroup(this.label, this.items);
  final String label;
  final List<TransactionModel> items;
}

List<_DayGroup> _groupByDay(List<TransactionModel> items) {
  final map = <String, List<TransactionModel>>{};
  for (final t in items) {
    final dateKey = formatRelativeDate(t.date);
    map.putIfAbsent(dateKey, () => []).add(t);
  }
  return map.entries.map((e) => _DayGroup(e.key, e.value)).toList();
}

String formatRelativeDate(DateTime date) {
  final now = DateTime.now();
  String relative;
  if (date.day == now.day && date.month == now.month && date.year == now.year) {
    relative = 'Today';
  } else if (date.day == now.subtract(const Duration(days: 1)).day &&
      date.month == now.subtract(const Duration(days: 1)).month &&
      date.year == now.subtract(const Duration(days: 1)).year) {
    relative = 'Yesterday';
  } else {
    relative = DateFormat('MMM dd').format(date);
  }
  return '$relative, ${DateFormat('h:mm a').format(date)}';
}
