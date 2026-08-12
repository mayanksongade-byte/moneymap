import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/color_constants.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../../core/theme/app_colors_extension.dart';

class BalanceCard extends StatefulWidget {
  final double balance;
  final double income;
  final double expense;
  final DateTime? lastUpdated;

  const BalanceCard({
    super.key,
    required this.balance,
    required this.income,
    required this.expense,
    this.lastUpdated,
  });

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  bool _hideBalance = false;

  @override
  bool get wantKeepAlive => true;

  AnimationController? _ctrl;
  AnimationController get _c => _ctrl!;

  double _fromBalance = 0;
  late DateTime _updatedAt;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _updatedAt = widget.lastUpdated ?? DateTime.now();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant BalanceCard old) {
    super.didUpdateWidget(old);
    if (widget.lastUpdated != null && widget.lastUpdated != old.lastUpdated) {
      _updatedAt = widget.lastUpdated!;
    }
    if (old.balance != widget.balance) {
      _fromBalance = old.balance;
      _c.reset();
      _c.forward();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ctrl?.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _hideBalance = !_hideBalance);
  }

  String get _updatedText {
    final now = DateTime.now();
    final d = now.difference(_updatedAt);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    return 'at ${DateFormat('h:mm a').format(_updatedAt)}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currency = context.watch<CurrencyProvider>();
    final monthlyChange = widget.income - widget.expense;
    final isPositiveChange = monthlyChange >= 0;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0038A8), // Deep Blue
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Background Decorative Circles
            Positioned(
              right: -25,
              top: -25,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Total Balance',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 18),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Balance Row
                  Row(
                    children: [
                      AnimatedBuilder(
                        animation: _c,
                        builder: (context, _) {
                          final val = _fromBalance + (widget.balance - _fromBalance) * Curves.easeOutCubic.transform(_c.value);
                          final balanceText = _hideBalance 
                              ? '${currency.currencySymbol} ••••••' 
                              : currency.format(val, showDecimals: true);
                          return Text(
                            balanceText,
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _toggle,
                        child: Icon(
                          _hideBalance ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: Colors.white.withOpacity(0.6),
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // Monthly Change Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: isPositiveChange ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPositiveChange ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, 
                            color: Colors.white, 
                            size: 9,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${isPositiveChange ? '+' : ''}${currency.format(monthlyChange)} this month',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Stats Section
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          'MONEY IN', 
                          widget.income, 
                          Icons.arrow_downward_rounded,
                          const Color(0xFF22C55E),
                        ),
                      ),
                      Container(
                        height: 32,
                        width: 1,
                        color: Colors.white.withOpacity(0.15),
                      ),
                      Expanded(
                        child: _buildStatItem(
                          'MONEY OUT', 
                          widget.expense, 
                          Icons.arrow_upward_rounded,
                          const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Footer
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 12, color: Colors.white.withOpacity(0.4)),
                      const SizedBox(width: 6),
                      Text(
                        'Updated $_updatedText',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.4),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, double amount, IconData icon, Color iconColor) {
    final currency = context.watch<CurrencyProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 12, color: iconColor),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          currency.format(amount, showDecimals: true),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
