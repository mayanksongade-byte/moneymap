import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/color_constants.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../auth/presentation/providers/app_auth_provider.dart';
import '../../../../core/widgets/common/app_bottom_nav.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../home/presentation/providers/transaction_provider.dart';
import '../../../../core/utils/export_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isBusy = false;
  String _appVersion = '1.0.0';
  final int _currentIndex = 3;
  bool _exportExpanded = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
    });
  }

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
  }

  Future<void> _exportData(bool isPdf) async {
    final transactions = context.read<TransactionProvider>().transactions;
    if (transactions.isEmpty) {
      _showToast('No transactions found to export', isError: true);
      return;
    }

    final currencyProvider = context.read<CurrencyProvider>();

    setState(() => _isBusy = true);
    try {
      if (isPdf) {
        await ExportHelper.exportToPdf(
          transactions, 
          userName: _user?.displayName,
          currencySymbol: currencyProvider.currencySymbol,
        );
      } else {
        await ExportHelper.exportToExcel(transactions);
      }
      _showToast('Export successful!');
    } catch (e) {
      _showToast('Export failed: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _editProfile() async {
    final authProvider = context.read<AppAuthProvider>();
    if (authProvider.isGuest) {
      _showToast("Please login to edit your profile.", isError: true);
      return;
    }

    final nameCtrl = TextEditingController(text: _user?.displayName ?? '');
    final colors = context.colors;

    final newName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Edit Profile',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Your Name',
                  filled: true,
                  fillColor: colors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != _user?.displayName) {
      setState(() => _isBusy = true);
      try {
        await _user!.updateDisplayName(newName);
        await FirebaseFirestore.instance.collection('users').doc(_user!.uid).set({
          'name': newName,
        }, SetOptions(merge: true));
        await _user!.reload();
        _showToast('Profile updated!');
      } catch (e) {
        _showToast('Error: $e', isError: true);
      } finally {
        if (mounted) setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _logout() async {
    final authProvider = context.read<AppAuthProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout')),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await authProvider.logout();
      if (mounted) context.go(AppRoutes.auth);
    }
  }

  void _showToast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final authProvider = context.watch<AppAuthProvider>();
    final txProvider = context.watch<TransactionProvider>();
    final user = _user;

    final creationDate = user?.metadata.creationTime ?? DateTime.now();
    final memberSince = DateFormat('MMM yyyy').format(creationDate);
    final diff = DateTime.now().difference(creationDate);
    final months = (diff.inDays / 30).floor();
    final duration = months == 0 ? 'Fresh' : '$months ${months == 1 ? 'month' : 'months'}';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: colors.background,
          toolbarHeight: 82,
          titleSpacing: 16,
          title: Row(
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _handleBack();
                },
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colors.border,
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "My Profile",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Personal info & preferences",
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                _HeaderCard(
                  user: user,
                  isGuest: authProvider.isGuest,
                  onEdit: _editProfile,
                  totalTransactions: txProvider.transactions.length,
                  monthlySpent: txProvider.monthlyExpense,
                  memberSince: memberSince,
                  membershipDuration: duration,
                ),
                const SizedBox(height: 24),
                _buildSectionLabel("My Finances"),
                _MenuTile(
                  icon: Icons.bar_chart_rounded,
                  title: 'Financial Statistics',
                  subtitle: 'View your spending patterns',
                  onTap: () => context.push(AppRoutes.statistics),
                ),
                _MenuTile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Budget Planning',
                  subtitle: 'Set monthly spending limits',
                  onTap: () => context.push(AppRoutes.budget),
                ),
                _MenuTile(
                  icon: Icons.category_outlined,
                  title: 'Category Management',
                  subtitle: 'Customise your categories',
                  onTap: () => context.push(AppRoutes.categoryManagement),
                ),
                const SizedBox(height: 12),
                _buildSectionLabel("Settings"),
                _MenuTile(
                  icon: Icons.settings_outlined,
                  title: 'App Settings',
                  subtitle: 'Theme, currency & alerts',
                  onTap: () => context.push(AppRoutes.settings),
                ),
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colors.border.withValues(alpha: 0.3)),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: _exportExpanded,
                      onExpansionChanged: (val) => setState(() => _exportExpanded = val),
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.file_copy_outlined, color: AppColors.primary, size: 22),
                      ),
                      title: const Text('Export Data', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      subtitle: Text('Excel & PDF reports', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                      trailing: Icon(_exportExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          child: Row(
                            children: [
                              Expanded(child: _buildExportButton(isPdf: false)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildExportButton(isPdf: true)),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: const Text('Logout Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(child: Text('v$_appVersion', style: TextStyle(color: colors.textDisabled, fontSize: 12))),
                const SizedBox(height: 100),
              ],
            ),
            if (_isBusy) const Center(child: CircularProgressIndicator()),
          ],
        ),
        bottomNavigationBar: AppBottomNav(currentIndex: _currentIndex, onTap: _onNavTap),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: context.colors.textDisabled,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildExportButton({required bool isPdf}) {
    final colors = context.colors;
    return InkWell(
      onTap: () => _exportData(isPdf),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isPdf ? Colors.red.withValues(alpha: 0.06) : Colors.green.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isPdf ? Colors.red.withValues(alpha: 0.12) : Colors.green.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Icon(isPdf ? Icons.picture_as_pdf_rounded : Icons.table_chart_rounded,
                 color: isPdf ? Colors.red : Colors.green, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isPdf ? 'Export as PDF' : 'Export as Excel',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: colors.textPrimary)),
                  Text(isPdf ? '.pdf format' : '.xlsx format',
                      style: TextStyle(fontSize: 10, color: colors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final User? user;
  final bool isGuest;
  final VoidCallback onEdit;
  final int totalTransactions;
  final double monthlySpent;
  final String memberSince;
  final String membershipDuration;

  const _HeaderCard({
    required this.user,
    required this.isGuest,
    required this.onEdit,
    required this.totalTransactions,
    required this.monthlySpent,
    required this.memberSince,
    required this.membershipDuration,
  });

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();
    final name = isGuest ? 'Guest User' : (user?.displayName ?? 'User');
    final email = isGuest ? 'guest@moneymap.com' : (user?.email ?? '');
    
    final displayName = (user?.displayName?.split(' ').first ?? (isGuest ? 'Guest' : 'User')).toUpperCase();
    final initial = displayName.isNotEmpty ? displayName[0] : 'U';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF1E40AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                child: CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.edit_rounded, size: 18, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  Icons.account_balance_wallet_rounded,
                  'Total Trx',
                  '$totalTransactions',
                  'All time',
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  Icons.trending_up_rounded,
                  'Spent',
                  currency.format(monthlySpent),
                  'Month',
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  Icons.calendar_month_rounded,
                  'Member',
                  memberSince,
                  membershipDuration,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, String subLabel) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 7,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _MenuTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: colors.textDisabled),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
