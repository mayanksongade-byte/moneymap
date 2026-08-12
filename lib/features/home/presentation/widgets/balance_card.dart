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
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A58EE),
            Color(0xFF009FFD),
            Color(0xFF2AF598),
          ],
          stops: [0.0, 0.6, 1.0],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A58EE).withValues(alpha: 0.3),
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
              const Text(
                'TOTAL BALANCE',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final val = _fromBalance + (widget.balance - _fromBalance) * Curves.easeOutCubic.transform(_c.value);
                  return Text(
                    _hideBalance ? '${currency.currencySymbol} ••••••' : currency.format(val, showDecimals: true),
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1.0,
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _toggle,
                icon: Icon(
                  _hideBalance ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 12),
                const SizedBox(width: 4),
                Text(
                  '+ ${currency.format(widget.income - widget.expense)} this month',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(child: _buildStatItem('MONEY IN', widget.income, Icons.arrow_downward_rounded)),
              Container(width: 1, height: 30, color: Colors.white24),
              Expanded(child: _buildStatItem('MONEY OUT', widget.expense, Icons.arrow_upward_rounded)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 14, color: Colors.white60),
              const SizedBox(width: 6),
              Text(
                'Updated $_updatedText',
                style: const TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, double amount, IconData icon) {
    final currency = context.watch<CurrencyProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: label == 'MONEY IN' ? Colors.tealAccent.withValues(alpha: 0.2) : Colors.redAccent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 12, color: label == 'MONEY IN' ? Colors.tealAccent : Colors.redAccent),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          currency.format(amount, showDecimals: true),
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}
