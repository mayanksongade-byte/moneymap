import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/color_constants.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../data/models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import 'add_transaction_screen.dart';
import '../../../../core/providers/currency_provider.dart';

class TransactionDetailsScreen extends StatelessWidget {
  final TransactionModel transaction;

  const TransactionDetailsScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final currency = context.watch<CurrencyProvider>();
    final isIncome = transaction.type.toLowerCase() == 'income';
    final accentColor = isIncome ? AppColors.success : AppColors.error;

    return Scaffold(
      backgroundColor: colors.background,
      body: CustomScrollView(
        slivers: [
          // Premium Header
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            elevation: 0,
            backgroundColor: accentColor,
            leadingWidth: 78,
            leading: Center(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 26),
                onPressed: () => _editTransaction(context),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
                onPressed: () => _confirmDelete(context),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [accentColor, accentColor.withValues(alpha: 0.8)],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 60),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                        ),
                        child: Text(transaction.icon, style: const TextStyle(fontSize: 40)),
                      ),
                      const SizedBox(height: 16),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${isIncome ? '+' : '-'} ${currency.format(transaction.amount, showDecimals: true)}',
                          style: const TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                      Text(
                        transaction.category,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            "Completed Successfully",
                            style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Transaction Details Card
                  Text("Transaction Details",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: colors.textPrimary)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colors.surfaceVariant),
                    ),
                    child: Column(
                      children: [
                        _buildInfoItem(context, Icons.calendar_month_rounded, "Date & Time",
                            DateFormat('dd MMMM yyyy, hh:mm a').format(transaction.date)),
                        const Divider(height: 32),
                        _buildInfoItem(context, _getPaymentIcon(transaction.paymentMode), "Payment Method", transaction.paymentMode),
                        const Divider(height: 32),
                        _buildInfoItem(context, Icons.description_rounded, "Note",
                            transaction.note.isEmpty ? "No description" : transaction.note),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPaymentIcon(String mode) {
    switch (mode.toLowerCase()) {
      case 'upi': return Icons.qr_code_2_rounded;
      case 'card': return Icons.credit_card_rounded;
      case 'bank': return Icons.account_balance_rounded;
      default: return Icons.payments_rounded;
    }
  }

  Widget _buildInfoItem(BuildContext context, IconData icon, String label, String value) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 20, color: colors.textSecondary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editTransaction(BuildContext context) async {
    HapticFeedback.lightImpact();
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddTransactionScreen(transactionToEdit: transaction)),
    );
    if (result == true && context.mounted) Navigator.pop(context);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Record?'),
        content: const Text('Are you sure you want to remove this record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final provider = Provider.of<TransactionProvider>(context, listen: false);
      final messenger = ScaffoldMessenger.of(context);

      provider.finalizeAllPending();
      messenger.removeCurrentSnackBar();

      provider.stageDeletion(transaction);
      Navigator.pop(context);

      messenger.showSnackBar(
        SnackBar(
          content: const Text('Transaction deleted'),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'UNDO',
            textColor: AppColors.primary,
            onPressed: () {
              provider.undoDeletion(transaction.id!);
            },
          ),
        ),
      ).closed.then((reason) {
        if (reason != SnackBarClosedReason.action) {
          provider.finalizeDeletion(transaction.id!);
        }
      });
    }
  }
}
