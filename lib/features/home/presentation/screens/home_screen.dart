import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
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

// FIX: header used to be plain background color + name — now a dark
// gradient "hero" band (Cred / Jupiter / INDmoney style) that the balance
// card overlaps into. This single change is the biggest lever for making
// the screen read as a fintech app instead of a generic list screen.
Color _darken(Color color, [double amount = .35]) {
  return Color.lerp(color, Colors.black, amount)!;
}

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

  // loadTransactions() / loadMonthlyTransactions() / loadBudget() return
  // void (fire-and-forget, call notifyListeners() internally), so we listen
  // for txProvider's isLoading to flip false instead of awaiting a Future.
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
    HapticFeedback.mediumImpact();

    if (index == 1) {
      context.push(AppRoutes.statistics);
    } else if (index == 2) {
      context.push(AppRoutes.addTransaction);
    } else if (index == 3) {
      context.push(AppRoutes.profile);
    }

    if (mounted) setState(() => _currentIndex = 0);
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      extendBody: true,
      extendBodyBehindAppBar: true,
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
                _buildGradientHeroHeader(context),
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 2. Balance card — pulled up so it overlaps the
                          // gradient hero band above it (negative margin,
                          // not Transform, so following widgets close the
                          // gap correctly).
                          Container(
                            margin: const EdgeInsets.only(top: -38, bottom: 12),
                            child: BalanceCard(
                              key: ValueKey('balance_$_refreshTick'),
                              balance: txProvider.balance,
                              income: txProvider.totalIncome,
                              expense: txProvider.totalExpense,
                              lastUpdated: txProvider.lastRefreshedAt,
                            ),
                          ),
                          if (txProvider.monthlyTransactions.isNotEmpty) ...[
                            _buildSpendingInsight(context, txProvider),
                            const SizedBox(height: 12),
                          ],
                          // 3. Financial Snapshot (Cash Flow)
                          _buildCashFlowDashboard(context, txProvider),
                          const SizedBox(height: 16),
                          // 4. Quick Actions
                          QuickActions(
                            onIncomeTap: () => context.push(AppRoutes.addTransaction),
                            onExpenseTap: () => context.push(AppRoutes.addTransaction),
                            onBudgetTap: () => context.push(AppRoutes.budget),
                            onAnalyticsTap: () => context.push(AppRoutes.statistics),
                          ),
                          const SizedBox(height: 20),
                          // 5. Spending Insights & Analytics
                          _buildAnalyticsSnapshot(context, txProvider),
                          const SizedBox(height: 20),
                          // 6. Monthly Budget
                          _buildPremiumBudget(context, budgetProvider, txProvider.monthlyExpense),
                          const SizedBox(height: 20),
                          // 7. Recent Activity Header
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
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 160),
                    sliver: SliverList.builder(
                      itemCount: groups.length,
                      itemBuilder: (context, gi) {
                        final group = groups[gi];
                        return _buildTransactionTimeline(context, group, gi);
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

  // FIX: replaces the old flat SliverAppBar with a dark gradient "hero"
  // band with rounded bottom corners. The balance card (built above) is
  // pulled up on top of it via negative margin, giving the classic
  // fintech-app layered look instead of everything sitting flat on one
  // grey background.
  Widget _buildGradientHeroHeader(BuildContext context) {
    final user = context.watch<AppAuthProvider>().user;
    final name = user?.displayName?.split(' ').first ?? 'MoneyMapper';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'M';
    final darkPrimary = _darken(AppColors.primary, .45);

    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: 168,
      toolbarHeight: 56,
      backgroundColor: darkPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, darkPrimary],
              ),
            ),
            child: Stack(
              children: [
                // Subtle decorative glow — cheap but reads as "designed".
                Positioned(
                  right: -30,
                  top: -30,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreeting(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => HapticFeedback.selectionClick(),
          icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => context.push(AppRoutes.profile),
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1),
            ),
            child: CircleAvatar(
              radius: 15,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
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
    final isPositive = balance >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'THIS MONTH',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: colors.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Icon(
                    isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    color: isPositive ? AppColors.success : AppColors.error,
                    size: 17,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${isPositive ? '+' : '-'}${currency.format(balance.abs())}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (isPositive ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              isPositive ? 'POSITIVE FLOW' : 'NEGATIVE FLOW',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: isPositive ? AppColors.success : AppColors.error,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
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
        _buildSectionHeader(
          context,
          title: 'Spending Overview',
          actionLabel: 'Details',
          onAction: () => context.push(AppRoutes.statistics),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, 8),
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
                    'TOTAL SPENT THIS MONTH',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: colors.textSecondary, letterSpacing: 0.5),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                currency.format(spent),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: colors.textPrimary, letterSpacing: -1.0),
              ),
              const SizedBox(height: 16),
              // Segmented Spending Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 8,
                  child: Row(
                    children: sorted.take(5).toList().asMap().entries.map((e) {
                      final index = e.key;
                      final entry = e.value;
                      final pct = entry.value / spent;
                      return Expanded(
                        flex: (pct * 100).round().clamp(1, 100),
                        child: Container(
                          color: _getThemeCategoryColor(entry.key, index),
                          margin: const EdgeInsets.only(right: 2),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...sorted.take(3).toList().asMap().entries.map((e) {
                final index = e.key;
                final entry = e.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(color: _getThemeCategoryColor(entry.key, index), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colors.textPrimary),
                        ),
                      ),
                      Text(
                        currency.format(entry.value),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: colors.textSecondary),
                      ),
                    ],
                  ),
                );
              }),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
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
                'MONTHLY BUDGET',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: colors.textSecondary, letterSpacing: 0.5),
              ),
              Text(
                isOver ? 'OVER LIMIT' : 'ON TRACK',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: isOver ? AppColors.error : AppColors.success),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currency.format(spent),
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: colors.textPrimary),
                  ),
                  Text(
                    'of ${currency.format(limit)} spent',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textSecondary),
                  ),
                ],
              ),
              Text(
                '${(percent * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: colors.textPrimary.withValues(alpha: 0.8)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: colors.surfaceVariant.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation<Color>(isOver ? AppColors.error : AppColors.primary),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 12, color: colors.textDisabled),
              const SizedBox(width: 6),
              Text(
                isOver
                    ? 'Exceeded by ${currency.format(spent - limit)}'
                    : '${currency.format(remaining)} available for this month',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingInsight(BuildContext context, TransactionProvider provider) {
    final colors = context.colors;
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

    final now = DateTime.now();
    final currency = context.watch<CurrencyProvider>();
    final todaySpent = transactions
        .where((t) =>
    t.type.toLowerCase() == 'expense' &&
        t.date.day == now.day &&
        t.date.month == now.month)
        .fold(0.0, (sum, t) => sum + t.amount);

    String insightText = "You've made ${transactions.length} transactions this month.";
    if (todaySpent > 0) {
      insightText = "You spent ${currency.format(todaySpent)} today.";
    } else if (topCategory != null) {
      insightText = "$topCategory is where most of your money went.";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              insightText,
              style: TextStyle(fontSize: 13, color: colors.textPrimary, fontWeight: FontWeight.w700, height: 1.3),
            ),
          ),
        ],
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: colors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            foregroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(
            actionLabel,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionTimeline(BuildContext context, _DayGroup group, int groupIndex) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6, left: 4),
          child: Text(
            group.label.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 10,
              color: colors.textSecondary.withValues(alpha: 0.5),
              letterSpacing: 1.5,
            ),
          ),
        ),
        ...group.items.map((t) => Padding(
          padding: const EdgeInsets.only(bottom: 2.0),
          child: TransactionCard(
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
          ),
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
    final darkPrimary = _darken(AppColors.primary, .45);
    return Column(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
          child: Container(
            width: double.infinity,
            height: 168,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, darkPrimary],
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            physics: const NeverScrollableScrollPhysics(),
            children: [
              Transform.translate(
                offset: const Offset(0, -38),
                child: const _ShimmerBox(width: double.infinity, height: 190, radius: 24),
              ),
              const SizedBox(height: 4),
              const _ShimmerBox(width: double.infinity, height: 68, radius: 18),
              const SizedBox(height: 16),
              Row(
                children: List.generate(4, (i) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i == 3 ? 0 : 12),
                      child: const _ShimmerBox(width: double.infinity, height: 70, radius: 16),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              const _ShimmerBox(width: 140, height: 18, radius: 6),
              const SizedBox(height: 12),
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
        ),
      ],
    );
  }
}

/// Lightweight shimmer placeholder — no external package required.
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
  if (date.day == now.day && date.month == now.month && date.year == now.year) return 'Today';
  final yesterday = now.subtract(const Duration(days: 1));
  if (date.day == yesterday.day && date.month == yesterday.month && date.year == yesterday.year) return 'Yesterday';

  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${date.day} ${months[date.month - 1]}';
}