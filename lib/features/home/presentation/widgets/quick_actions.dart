import 'package:flutter/material.dart';
import '../../../../core/constants/color_constants.dart';
import '../../../../core/theme/app_colors_extension.dart';

class QuickActions extends StatelessWidget {
  final VoidCallback onIncomeTap;
  final VoidCallback onExpenseTap;
  final VoidCallback onBudgetTap;
  final VoidCallback onAnalyticsTap;

  const QuickActions({
    super.key,
    required this.onIncomeTap,
    required this.onExpenseTap,
    required this.onBudgetTap,
    required this.onAnalyticsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildActionItem(
          context,
          icon: Icons.add_rounded,
          label: 'Income',
          color: AppColors.success,
          onTap: onIncomeTap,
        ),
        const SizedBox(width: 10),
        _buildActionItem(
          context,
          icon: Icons.remove_rounded,
          label: 'Expense',
          color: AppColors.error,
          onTap: onExpenseTap,
        ),
        const SizedBox(width: 10),
        _buildActionItem(
          context,
          icon: Icons.account_balance_wallet_rounded,
          label: 'Budget',
          color: AppColors.primary,
          onTap: onBudgetTap,
        ),
        const SizedBox(width: 10),
        _buildActionItem(
          context,
          icon: Icons.analytics_rounded,
          label: 'Analytics',
          color: const Color(0xff8B5CF6),
          onTap: onAnalyticsTap,
        ),
      ],
    );
  }

  // FIX: was a bordered box with a plain icon on top — flat, no color pop.
  // Now: icon sits inside a tinted circular chip (the color it represents),
  // card uses a soft shadow instead of a hairline border, and padding is
  // tighter so the row reads as a compact action bar, not four separate
  // spaced-out cards.
  Widget _buildActionItem(
      BuildContext context, {
        required IconData icon,
        required String label,
        required Color color,
        required VoidCallback onTap,
      }) {
    final colors = context.colors;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}