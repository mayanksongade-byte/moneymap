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
          subLabel: 'Money In',
          color: AppColors.success,
          onTap: onIncomeTap,
        ),
        const SizedBox(width: 8),
        _buildActionItem(
          context,
          icon: Icons.remove_rounded,
          label: 'Expense',
          subLabel: 'Money Out',
          color: AppColors.error,
          onTap: onExpenseTap,
        ),
        const SizedBox(width: 8),
        _buildActionItem(
          context,
          icon: Icons.account_balance_wallet_rounded,
          label: 'Budget',
          subLabel: 'Limits',
          color: AppColors.primary,
          onTap: onBudgetTap,
        ),
        const SizedBox(width: 8),
        _buildActionItem(
          context,
          icon: Icons.analytics_rounded,
          label: 'Analytics',
          subLabel: 'Reports',
          color: const Color(0xff8B5CF6),
          onTap: onAnalyticsTap,
        ),
      ],
    );
  }

  Widget _buildActionItem(
      BuildContext context, {
        required IconData icon,
        required String label,
        required String subLabel,
        required Color color,
        required VoidCallback onTap,
      }) {
    final colors = context.colors;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.surfaceVariant.withValues(alpha: 0.5), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    subLabel,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
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
