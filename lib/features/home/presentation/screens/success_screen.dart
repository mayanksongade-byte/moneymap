import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:moneymap/core/constants/color_constants.dart';
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

  Widget? _getPaymentIcon(String? mode) {
    switch (mode?.toLowerCase()) {
      case 'cash':
        return const Icon(Icons.payments_rounded, size: 24, color: Colors.grey);
      case 'upi':
        return const Icon(Icons.qr_code_2_rounded, size: 24, color: Colors.grey);
      case 'bank':
        return const Icon(Icons.account_balance_rounded, size: 24, color: Colors.grey);
      case 'card':
        return const Icon(Icons.credit_card_rounded, size: 24, color: Colors.grey);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              // 1. Checkmark Header
              _buildAnimatedHeader(),

              const SizedBox(height: 24),
              Text(
                'Transaction Added!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: colors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your transaction has been added successfully.',
                style: TextStyle(
                  fontSize: 14,
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 32),

              // 2. Transaction Details Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildRow(
                      context,
                      icon: Icons.grid_view_rounded,
                      iconColor: Colors.teal,
                      label: 'Category',
                      value: transaction['category'] ?? 'General',
                      trailing: Text(transaction['icon'] ?? '📌', style: const TextStyle(fontSize: 18)),
                    ),
                    _buildDivider(colors),
                    _buildRow(
                      context,
                      icon: Icons.account_balance_wallet_outlined,
                      iconColor: Colors.redAccent,
                      label: 'Amount',
                      value: '',
                      trailing: Text(
                        currency.format(transaction['amount'] ?? 0.0),
                        style: TextStyle(
                          color: transaction['type'] == 'income' ? AppColors.success : AppColors.error,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    _buildDivider(colors),
                    _buildRow(
                      context,
                      icon: Icons.calendar_today_outlined,
                      iconColor: Colors.blue,
                      label: 'Date',
                      value: transaction['dateString'] ?? '',
                    ),
                    _buildDivider(colors),
                    _buildRow(
                      context,
                      icon: Icons.credit_card_outlined,
                      iconColor: Colors.indigo,
                      label: 'Payment Method',
                      value: transaction['paymentMode'] ?? 'Cash',
                      trailing: _getPaymentIcon(transaction['paymentMode']),
                    ),
                    _buildDivider(colors),
                    _buildRow(
                      context,
                      icon: Icons.description_outlined,
                      iconColor: Colors.orange,
                      label: 'Note',
                      value: (transaction['note'] ?? '').toString().isEmpty ? '-' : transaction['note'],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 3. Insight Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFDCFCE7)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Color(0xFFBBF7D0), shape: BoxShape.circle),
                      child: const Icon(Icons.verified_user_outlined, color: Color(0xFF166534), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Smart move!",
                            style: TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                          Text(
                            "You've taken a step towards better financial tracking.",
                            style: TextStyle(color: const Color(0xFF166534).withOpacity(0.8), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.trending_up_rounded, color: Color(0xFF22C55E), size: 32),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 4. Buttons
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: onAddAnother,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                  label: const Text('Add Another Transaction', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: onGoHome,
                  icon: const Icon(Icons.home_outlined, size: 20),
                  label: const Text('Go to Home', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedHeader() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7).withOpacity(0.6),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 44),
        ),
        // Confetti dots
        ...List.generate(8, (i) {
          final angle = (i * 45) * math.pi / 180;
          final distance = 60.0;
          return Transform.translate(
            offset: Offset(math.cos(angle) * distance, math.sin(angle) * distance),
            child: Container(
              width: i % 2 == 0 ? 6 : 4,
              height: i % 2 == 0 ? 6 : 4,
              decoration: BoxDecoration(
                color: i % 2 == 0 ? const Color(0xFF22C55E) : const Color(0xFF3B82F6),
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRow(BuildContext context, {required IconData icon, required Color iconColor, required String label, required String value, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: context.colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                if (value.isNotEmpty)
                  Text(value, style: TextStyle(color: context.colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildDivider(AppColorsExtension colors) {
    return Padding(
      padding: const EdgeInsets.only(left: 48, top: 8, bottom: 8),
      child: Divider(color: colors.border.withOpacity(0.3), height: 1),
    );
  }
}
