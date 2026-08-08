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
  // FIX: balance now starts hidden by default — matches how fintech apps
  // (Cred, Jupiter, revolut) behave on cold start, so nothing sensitive
  // flashes on screen before the user chooses to reveal it.
  bool _hideBalance = true;

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
    if (d.inSeconds < 60) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return DateFormat('MMM dd').format(_updatedAt);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currency = context.watch<CurrencyProvider>();
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.surfaceVariant, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
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
                'Total Balance',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              // FIX: premium touch — proper tap target with splash +
              // tooltip + a small rotation/fade as the icon swaps, instead
              // of a bare GestureDetector snapping between two icons.
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _toggle,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Tooltip(
                      message: _hideBalance ? 'Show balance' : 'Hide balance',
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, anim) => ScaleTransition(
                          scale: anim,
                          child: FadeTransition(opacity: anim, child: child),
                        ),
                        child: Icon(
                          _hideBalance ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          key: ValueKey(_hideBalance),
                          color: colors.textDisabled,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // FIX: smooth crossfade+slight-scale when toggling hide/show,
          // instead of the amount just snapping to dots instantly.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.94, end: 1.0).animate(anim),
                alignment: Alignment.centerLeft,
                child: child,
              ),
            ),
            child: _hideBalance
                ? Text(
              '${currency.currencySymbol} ••••••',
              key: const ValueKey('hidden'),
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
                letterSpacing: -1.2,
              ),
            )
                : AnimatedBuilder(
              key: const ValueKey('visible'),
              animation: _c,
              builder: (context, _) {
                final val = _fromBalance +
                    (widget.balance - _fromBalance) * Curves.easeOutCubic.transform(_c.value);
                return Text(
                  currency.format(val, showDecimals: true),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                    letterSpacing: -1.2,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildStat(context, 'Income', widget.income, AppColors.success, Icons.arrow_downward_rounded),
              const SizedBox(width: 24),
              _buildStat(context, 'Expense', widget.expense, AppColors.error, Icons.arrow_upward_rounded),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: colors.surfaceVariant, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.history_rounded, size: 14, color: colors.textDisabled),
                  const SizedBox(width: 6),
                  Text(
                    'Updated $_updatedText',
                    style: TextStyle(fontSize: 11, color: colors.textDisabled, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const Icon(Icons.security_rounded, size: 14, color: AppColors.success),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(BuildContext context, String label, double amount, Color color, IconData icon) {
    final currency = context.watch<CurrencyProvider>();
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
          child: Text(
            _hideBalance ? '••••' : currency.format(amount),
            key: ValueKey('$label-$_hideBalance-$amount'),
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}