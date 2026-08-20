import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/color_constants.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/providers/currency_provider.dart';

class TransactionCard extends StatelessWidget {
  final String? id;
  final String category;
  final String note;
  final double amount;
  final String type; // 'income' or 'expense'
  final String date;
  final String icon;
  final String paymentMode;
  final VoidCallback? onTap;
  final Future<void> Function()? onDelete;

  const TransactionCard({
    super.key,
    this.id,
    required this.category,
    required this.note,
    required this.amount,
    required this.type,
    required this.date,
    required this.icon, 
    this.paymentMode = 'Cash',
    this.onTap,
    this.onDelete,
  });

  bool get isIncome => type.toLowerCase() == 'income';
  Color get amountColor => isIncome ? AppColors.success : AppColors.error;
  String get amountPrefix => isIncome ? '+ ' : '- ';

  Map<String, dynamic> _getPaymentDetails(String mode) {
    switch (mode.toLowerCase()) {
      case 'upi':
        return {'icon': Icons.qr_code_2_rounded, 'color': Colors.blue};
      case 'card':
        return {'icon': Icons.credit_card_rounded, 'color': Colors.purple};
      case 'bank':
        return {'icon': Icons.account_balance_rounded, 'color': Colors.teal};
      default: // Cash
        return {'icon': Icons.payments_rounded, 'color': Colors.orange};
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();
    final colors = context.colors;
    final payment = _getPaymentDetails(paymentMode);

    Widget cardContent = Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.surfaceVariant.withValues(alpha: 0.4), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(icon, style: const TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            category,
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: colors.textPrimary),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: (payment['color'] as Color).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              payment['icon'] as IconData,
                              size: 14,
                              color: (payment['color'] as Color),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$amountPrefix${currency.format(amount)}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: amountColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (onDelete != null && id != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Dismissible(
          key: Key(id!),
          direction: DismissDirection.endToStart,
          confirmDismiss: (dir) => Future.value(true),
          onDismissed: (dir) => onDelete?.call(),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
          ),
          child: cardContent,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: cardContent,
    );
  }
}
