import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moneymap/core/constants/color_constants.dart';
import 'package:moneymap/core/widgets/buttons/primary_button.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/providers/currency_provider.dart';

class SuccessScreen extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final VoidCallback onAddAnother;
  final VoidCallback onGoHome;

  const SuccessScreen({
    super.key,
    required this.transaction,
    required this.onAddAnother,
    required this.onGoHome,
  });

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
              MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  48,
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 80,
                  ),

                  const SizedBox(height: 16),

                  Text(
                    '🎉 Transaction Added!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Your transaction has been added successfully.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.colors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 32),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: context.colors.border.withValues(alpha: .3),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          context,
                          'Category',
                          '${transaction['icon']} ${transaction['category']}',
                        ),

                        Divider(color: context.colors.border),

                        _buildInfoRow(
                          context,
                          'Amount',
                          currency.format(transaction['amount'], showDecimals: true),
                          color: transaction['type'] == 'income'
                              ? AppColors.success
                              : AppColors.error,
                        ),

                        if ((transaction['note'] ?? '').toString().isNotEmpty) ...[
                          Divider(color: context.colors.border),
                          _buildInfoRow(
                            context,
                            'Note',
                            transaction['note'],
                          ),
                        ],

                        Divider(color: context.colors.border),

                        _buildInfoRow(
                          context,
                          'Date',
                          transaction['dateString'],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  PrimaryButton(
                    text: 'Add Another',
                    onPressed: onAddAnother,
                  ),

                  const SizedBox(height: 12),

                  PrimaryButton(
                    text: 'Go Home',
                    onPressed: onGoHome,
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color ?? context.colors.textPrimary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
