import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:moneymap/core/constants/color_constants.dart';
import 'package:moneymap/core/widgets/common/app_bottom_nav.dart';
import 'package:moneymap/core/widgets/common/common_error_widget.dart';
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
import 'package:moneymap/core/providers/notification_provider.dart';
import 'package:moneymap/core/utils/app_utils.dart';

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
      // Settle if loading finished OR if we already have transactions (e.g. from cache)
      if (!txProvider.isLoading || txProvider.transactions.isNotEmpty) {
        txProvider.removeListener(onLoaded);
        setState(() => _settled = true);
        if (txProvider.error == null) {
          _appearanceController.forward();
        }
      }
    }

    txProvider.addListener(onLoaded);
    onLoaded();
  }

  void _retry() {
    setState(() {
      _settled = false;
    });
    _bootstrap();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _appearanceController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    if (index == _currentIndex && index == 0) return;
    if (mounted) setState(() => _currentIndex = 0);
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning 👋';
    if (hour < 17) return 'Good Afternoon ☀️';
    return 'Good Evening 🌙';
  }

  Future<bool> _handleDelete(TransactionModel t) async {
    final provider = context.read<TransactionProvider>();
    final messenger = ScaffoldMessenger.of(context);
    
    if (t.id == null) return false;

    // 1. FAST Reachability check to prevent swiping while clearly offline
    final isOnline = await provider.checkServerReachability()
        .timeout(const Duration(milliseconds: 1500), onTimeout: () => false);
    
    if (!isOnline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please check your internet connection and try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false; // Blocks the Dismissible
    }

    // 2. Stage deletion locally (synchronous, fast)
    provider.stageDeletion(t.id!);

    // Show Undo SnackBar
    bool undone = false;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Transaction deleted'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            undone = true;
            provider.unstageDeletion(t.id!);
          },
        ),
      ),
    ).closed.then((reason) async {
      // Commit if not undone (reason != action)
      if (!undone && reason != SnackBarClosedReason.action) {
        final success = await provider.deleteTransaction(t.id!);
        if (!success) {
          // Restore if failed (Offline/Error)
          provider.unstageDeletion(t.id!);
          messenger.showSnackBar(
            SnackBar(
              content: Text(provider.error ?? 'Please check your internet connection and try again.'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      extendBody: true,
      bottomNavigationBar: AppBottomNav(currentIndex: _currentIndex, onTap: _onNavTap),
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: colors.surface,
            displacement: 40,
            onRefresh: () async {
              HapticFeedback.mediumImpact();
              final txProvider = context.read<TransactionProvider>();
              final budgetProvider = context.read<BudgetProvider>();
              
              await Future.wait([
                txProvider.refreshTransactions(),
                budgetProvider.refreshBudget(),
              ]);
              
              if (mounted) {
                setState(() => _refreshTick++);
              }
            },
            child: Consumer<TransactionProvider>(
              builder: (context, txProvider, _) {
                // Pre-filter/sort only once per rebuild
                final allTransactions = txProvider.transactions;
                final recentTransactions = allTransactions.take(5).toList();
                
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildCurrentState(context, txProvider, allTransactions, recentTransactions),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Removed old _buildOfflineIndicator as it's now a common widget

  Widget _buildCurrentState(
      BuildContext context,
      TransactionProvider txProvider,
      List<TransactionModel> allTransactions,
      List<TransactionModel> recentTransactions,
      ) {
    // Error handling for initial load
    if (txProvider.error != null && allTransactions.isEmpty && !txProvider.isLoading) {
      return CommonErrorWidget(
        key: const ValueKey('home_error'),
        message: 'Couldn\'t load your data. Please check your connection.',
        onRetry: _retry,
      );
    }

    final isInitialLoad = (txProvider.isLoading || !_settled) && allTransactions.isEmpty;

    if (isInitialLoad) {
      return _buildSkeletonLoader(context);
    }

    return CustomScrollView(
      key: const ValueKey('home_data'),
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
                  
                  // Guest Warning Banner
                  if (context.watch<AppAuthProvider>().isGuest) ...[
                    _buildGuestWarning(context),
                    const SizedBox(height: 12),
                  ],

                  RepaintBoundary(
                    child: Selector<TransactionProvider, Map<String, dynamic>>(
                      selector: (_, p) => {
                        'balance': p.balance,
                        'income': p.totalIncome,
                        'expense': p.totalExpense,
                        'lastRefreshedAt': p.lastRefreshedAt,
                      },
                      shouldRebuild: (prev, next) => !mapEquals(prev, next),
                      builder: (context, data, _) => BalanceCard(
                        key: ValueKey('balance_$_refreshTick'),
                        balance: data['balance'] as double,
                        income: data['income'] as double,
                        expense: data['expense'] as double,
                        lastUpdated: data['lastRefreshedAt'] as DateTime?,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildCashFlowDashboard(context),
                  const SizedBox(height: 24),
                  QuickActions(
                    onIncomeTap: () {
                      HapticFeedback.lightImpact();
                      context.push(AppRoutes.addTransaction, extra: {'initialType': 'income'});
                    },
                    onExpenseTap: () {
                      HapticFeedback.lightImpact();
                      context.push(AppRoutes.addTransaction, extra: {'initialType': 'expense'});
                    },
                    onBudgetTap: () {
                      HapticFeedback.lightImpact();
                      context.push(AppRoutes.budget);
                    },
                    onAnalyticsTap: () {
                      HapticFeedback.lightImpact();
                      context.push(AppRoutes.statistics);
                    },
                  ),
                  const SizedBox(height: 40),
                  _buildAnalyticsSnapshot(context),
                  const SizedBox(height: 32),
                  _buildPremiumBudget(context),
                  const SizedBox(height: 32),
                  _buildSpendingInsight(context),
                  const SizedBox(height: 12), 
                  if (allTransactions.isNotEmpty)
                    _buildSectionHeader(
                      context,
                      title: 'Recent Activity',
                      actionLabel: 'View All',
                      onAction: () {
                        HapticFeedback.lightImpact();
                        context.push(AppRoutes.allTransactions);
                      },
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
                  onDelete: () => _handleDelete(t),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildGuestWarning(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withValues(alpha: 0.15),
            Colors.orange.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.security_update_warning_rounded, color: Colors.orange, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure Your Data ⚠️',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  'Guest data is not synced. Login now to keep it safe.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              // Just push the login screen so user can go back
              context.push(AppRoutes.login);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              visualDensity: VisualDensity.compact,
            ),
            child: const FittedBox(child: Text('Login', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumHeader(BuildContext context) {
    final colors = context.colors;
    
    return Selector<AppAuthProvider, String>(
      selector: (_, auth) => auth.effectiveDisplayName,
      builder: (context, displayName, _) {
        final name = displayName.split(' ').first.toUpperCase();
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
                Flexible(
                  child: Text(
                    _getGreeting(),
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                Flexible(
                  child: Text(
                    name,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Consumer<NotificationProvider>(
              builder: (context, notificationProvider, _) {
                final unreadCount = notificationProvider.unreadCount;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        context.push(AppRoutes.notifications);
                      },
                      icon: Icon(
                        Icons.notifications_none_rounded,
                        color: colors.textPrimary,
                        size: 26,
                      ),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Center(
                            child: Text(
                              unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
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
      },
    );
  }

  Widget _buildCashFlowDashboard(BuildContext context) {
    final colors = context.colors;
    final currency = context.watch<CurrencyProvider>();
    
    return Selector<TransactionProvider, Map<String, double>>(
      selector: (_, p) => {
        'balance': p.monthlyBalance,
        'income': p.monthlyIncome,
        'expense': p.monthlyExpense,
      },
      shouldRebuild: (prev, next) => !mapEquals(prev, next),
      builder: (context, data, _) {
        final balance = data['balance']!;
        final income = data['income']!;
        final expense = data['expense']!;
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
                  Expanded(
                    child: Row(
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
                        Expanded(
                          child: Column(
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${isPositive ? '+' : ''}${currency.format(balance)}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildMiniStat(context, 'Income', income, AppColors.success),
                      const SizedBox(height: 8),
                      _buildMiniStat(context, 'Expense', expense, AppColors.error),
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
      },
    );
  }

  Widget _buildMiniStat(BuildContext context, String label, double amount, Color color) {
    final colors = context.colors;
    final currency = context.read<CurrencyProvider>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            '$label  ',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            currency.format(amount),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsSnapshot(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = context.watch<CurrencyProvider>();

    return Selector<TransactionProvider, Map<String, dynamic>>(
      selector: (_, p) => {
        'spent': p.monthlyExpense,
        'summary': p.getMonthlyExpenseByCategory(),
      },
      shouldRebuild: (prev, next) => !mapEquals(prev, next),
      builder: (context, data, _) {
        final spent = data['spent'] as double;
        final categorySummary = data['summary'] as Map<String, double>;

        if (spent == 0) return const SizedBox.shrink();

        final sorted = categorySummary.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Spending Overview',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: colors.textPrimary, letterSpacing: -0.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push(AppRoutes.statistics),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Text('This Month', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
                        SizedBox(width: 2),
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
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          currency.format(spent),
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: colors.textPrimary, letterSpacing: -1.0),
                        ),
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
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            RepaintBoundary(
                              child: PieChart(
                                PieChartData(
                                  sectionsSpace: 4,
                                  centerSpaceRadius: 42,
                                  startDegreeOffset: -90,
                                  sections: sorted.asMap().entries.map((e) {
                                    final index = e.key;
                                    final entry = e.value;
                                    return PieChartSectionData(
                                      color: _getThemeCategoryColor(entry.key, index, isDark),
                                      value: entry.value,
                                      title: '',
                                      radius: 14,
                                      badgeWidget: null,
                                    );
                                  }).toList(),
                                ),
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
                              child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 24),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
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
                                    decoration: BoxDecoration(color: _getThemeCategoryColor(entry.key, index, isDark), shape: BoxShape.circle),
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
                                  const SizedBox(width: 8),
                                  Flexible(
                                    flex: 0,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        currency.format(entry.value),
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: colors.textPrimary),
                                      ),
                                    ),
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
      },
    );
  }

  static const List<Color> _fallbackPalette = [
    Colors.indigoAccent,
    Colors.pinkAccent,
    Colors.cyan,
    Colors.amber,
    Colors.deepOrangeAccent,
  ];

  static const List<Color> _darkFallbackPalette = [
    Color(0xFF8C9EFF), // Indigo Accent 100
    Color(0xFFFF80AB), // Pink Accent 100
    Color(0xFF84FFFF), // Cyan Accent 100
    Color(0xFFFFE57F), // Amber Accent 100
    Color(0xFFFF9E80), // Deep Orange Accent 100
  ];

  Color _getThemeCategoryColor(String category, int index, bool isDark) {
    if (isDark) {
      switch (category.toLowerCase()) {
        case 'food':
        case 'dining':
          return const Color(0xFFFFD180); // Orange Accent 100
        case 'shopping':
          return const Color(0xFF82B1FF); // Blue Accent 100
        case 'transport':
        case 'travel':
          return const Color(0xFFA7FFEB); // Teal Accent 100
        case 'bills':
        case 'utilities':
          return const Color(0xFFFF8A80); // Red Accent 100
        case 'education':
          return const Color(0xFF8C9EFF); // Indigo Accent 100
        case 'entertainment':
          return const Color(0xFFEA80FC); // Purple Accent 100
        default:
          return _darkFallbackPalette[index % _darkFallbackPalette.length];
      }
    }

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

  Widget _buildPremiumBudget(BuildContext context) {
    final colors = context.colors;
    final currency = context.watch<CurrencyProvider>();

    return Selector2<BudgetProvider, TransactionProvider, Map<String, dynamic>>(
      selector: (_, bp, tp) => {
        'hasBudget': bp.hasBudget,
        'limit': bp.monthlyLimit ?? 0.0,
        'spent': tp.monthlyExpense,
      },
      shouldRebuild: (prev, next) => !mapEquals(prev, next),
      builder: (context, data, _) {
        if (!(data['hasBudget'] as bool)) return const SizedBox.shrink();

        final limit = data['limit'] as double;
        final spent = data['spent'] as double;
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
                  Expanded(
                    child: Text(
                      'Monthly Budget',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: colors.textPrimary, letterSpacing: 0.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            currency.format(spent),
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: colors.textPrimary),
                          ),
                        ),
                        Text(
                          'of ${currency.format(limit)} spent',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${(percent * 100).toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: colors.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
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
      },
    );
  }

  Widget _buildSpendingInsight(BuildContext context) {
    final colors = context.colors;
    final currency = context.watch<CurrencyProvider>();
    
    return Selector<TransactionProvider, List<TransactionModel>>(
      selector: (_, p) => p.monthlyTransactions,
      shouldRebuild: (prev, next) => listEquals(prev, next),
      builder: (context, transactions, _) {
        if (transactions.isEmpty) return const SizedBox.shrink();

        final provider = context.read<TransactionProvider>();
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
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          currency.format(maxVal),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF8B5CF6)),
                        ),
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
      },
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
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: colors.textPrimary,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

  Widget _buildEmptyState(BuildContext context) {
    final colors = context.colors;
    return Center(
      key: const ValueKey('home_empty'),
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
    return SafeArea(
      key: const ValueKey('home_loading'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          const Row(
            children: [
              RepaintBoundary(child: _ShimmerBox(width: 120, height: 14, radius: 6)),
            ],
          ),
          const SizedBox(height: 8),
          const RepaintBoundary(child: _ShimmerBox(width: 160, height: 24, radius: 8)),
          const SizedBox(height: 24),
          const RepaintBoundary(child: _ShimmerBox(width: double.infinity, height: 190, radius: 24)),
          const SizedBox(height: 24),
          const RepaintBoundary(child: _ShimmerBox(width: double.infinity, height: 76, radius: 20)),
          const SizedBox(height: 24),
          Row(
            children: List.generate(4, (i) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 3 ? 0 : 12),
                  child: const RepaintBoundary(child: _ShimmerBox(width: double.infinity, height: 74, radius: 18)),
                ),
              );
            }),
          ),
          const SizedBox(height: 32),
          const RepaintBoundary(child: _ShimmerBox(width: 140, height: 18, radius: 6)),
          const SizedBox(height: 16),
          ...List.generate(4, (i) => const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                RepaintBoundary(child: _ShimmerBox(width: 44, height: 44, radius: 14)),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RepaintBoundary(child: _ShimmerBox(width: 100, height: 12, radius: 4)),
                      SizedBox(height: 8),
                      RepaintBoundary(child: _ShimmerBox(width: 70, height: 10, radius: 4)),
                    ],
                  ),
                ),
                _ShimmerBox(width: 60, height: 14, radius: 4),
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
    relative = AppDateFormats.relativeDate.format(date);
  }
  return '$relative, ${AppDateFormats.timeOnly.format(date)}';
}
