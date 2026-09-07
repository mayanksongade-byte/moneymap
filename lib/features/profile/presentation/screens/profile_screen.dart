import 'package:flutter/material.dart';
import 'dart:async';
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

  void _showExportSheet() {
    final colors = context.colors;
    // Default to today (start of day to end of day)
    final now = DateTime.now();
    DateTimeRange selectedRange = DateTimeRange(
      start: DateTime(now.year, now.month, now.day),
      end: DateTime(now.year, now.month, now.day),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: EdgeInsets.fromLTRB(32, 12, 32, 32 + MediaQuery.of(context).viewInsets.bottom),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 24),
                Text("Export Report", style: TextStyle(color: colors.textPrimary, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text("Select date range and format", style: TextStyle(color: colors.textSecondary, fontSize: 15)),
                const SizedBox(height: 24),

                // Date Range Picker Trigger
                InkWell(
                  onTap: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      initialDateRange: selectedRange,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: Theme.of(context).colorScheme.copyWith(
                            primary: AppColors.primary,
                            onPrimary: Colors.white,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) setSheetState(() => selectedRange = picked);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.border.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedRange.start == selectedRange.end 
                                  ? "Selected Date" 
                                  : "Selected Range",
                                style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                selectedRange.start == selectedRange.end
                                    ? DateFormat('dd MMM yyyy').format(selectedRange.start)
                                    : "${DateFormat('dd MMM').format(selectedRange.start)} - ${DateFormat('dd MMM yyyy').format(selectedRange.end)}",
                                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.edit_calendar_rounded, color: colors.textSecondary, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Format Options
                Row(
                  children: [
                    Expanded(child: _buildExportOpt(colors, "PDF", Icons.picture_as_pdf_rounded, Colors.red, true, selectedRange)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildExportOpt(colors, "Excel", Icons.table_chart_rounded, Colors.green, false, selectedRange)),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildExportOpt(AppColorsExtension colors, String label, IconData icon, Color color, bool isPdf, DateTimeRange range) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _handleExport(isPdf, range);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text("Download $label", style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Future<void> _handleExport(bool isPdf, DateTimeRange range) async {
    final tp = context.read<TransactionProvider>();
    final cur = context.read<CurrencyProvider>();

    // Filter Transactions (inclusive of both start and end dates)
    final startDate = DateTime(range.start.year, range.start.month, range.start.day);
    final endDate = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);

    final filtered = tp.transactions.where((t) {
      return !t.date.isBefore(startDate) && !t.date.isAfter(endDate);
    }).toList();

    final dateRangeStr = startDate == DateTime(range.end.year, range.end.month, range.end.day)
        ? DateFormat('dd MMM yyyy').format(startDate)
        : "${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}";

    if (filtered.isEmpty) {
      _showToast("No transactions found for $dateRangeStr", isError: true);
      return;
    }

    setState(() => _isBusy = true);
    try {
      if (isPdf) {
        await ExportHelper.exportToPdf(
          filtered, 
          userName: _user?.displayName, 
          currencySymbol: cur.currencySymbol,
          dateRange: dateRangeStr,
        ).timeout(const Duration(seconds: 15));
      } else {
        await ExportHelper.exportToExcel(filtered)
            .timeout(const Duration(seconds: 15));
      }
      _showToast('Export successful!');
    } on TimeoutException {
      _showToast('Export timed out. Please try again.', isError: true);
    } catch (e) {
      _showToast('Export failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
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
    String? nameError;

    final newName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
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
                  const SizedBox(height: 8),
                  Text('Max 10 characters allowed', 
                      style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    maxLength: 10,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(10),
                    ],
                    onChanged: (val) {
                      if (nameError != null && val.trim().isNotEmpty) {
                        setModalState(() => nameError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Your Name',
                      errorText: nameError,
                      counterText: "",
                      filled: true,
                      fillColor: colors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      final text = nameCtrl.text.trim();
                      if (text.isEmpty) {
                        setModalState(() => nameError = "Name cannot be empty");
                        return;
                      }
                      Navigator.pop(ctx, text);
                    },
                    child: const Text('Save Changes'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != _user?.displayName) {
      setState(() => _isBusy = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // 1. Update Firebase Auth Profile (Immediate UI update)
          await user.updateDisplayName(newName);
          
          // 2. Update Firestore (Ensuring Online-First via Transaction)
          await FirebaseFirestore.instance.runTransaction((transaction) async {
            final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
            transaction.set(docRef, {
              'name': newName,
              'displayName': newName,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }).timeout(const Duration(seconds: 5));
          
          // 3. Force reload and refresh provider
          await user.reload();
          await authProvider.refreshUser();

          _showToast('Profile updated!');
        }
      } catch (e) {
        if (e is TimeoutException || (e is FirebaseException && (e.code == 'unavailable' || e.code == 'deadline-exceeded'))) {
          _showToast('Please check your internet connection and try again.', isError: true);
        } else {
          _showToast('Failed to update profile.', isError: true);
        }
        debugPrint("Update Profile Error: $e");
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
    if (!mounted) return;
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
                  name: authProvider.isGuest ? 'Guest User' : authProvider.effectiveDisplayName,
                  email: authProvider.isGuest ? 'guest@moneymap.com' : authProvider.effectiveEmail,
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
                _MenuTile(
                  icon: Icons.file_copy_outlined,
                  title: 'Export Data',
                  subtitle: 'Excel & PDF reports',
                  onTap: _showExportSheet,
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
}

class _HeaderCard extends StatelessWidget {
  final String name;
  final String email;
  final bool isGuest;
  final VoidCallback onEdit;
  final int totalTransactions;
  final double monthlySpent;
  final String memberSince;
  final String membershipDuration;

  const _HeaderCard({
    required this.name,
    required this.email,
    required this.isGuest,
    required this.onEdit,
    required this.totalTransactions,
    required this.monthlySpent,
    required this.memberSince,
    required this.membershipDuration,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AppAuthProvider>();
    final currency = context.watch<CurrencyProvider>();
    
    final displayName = (name.split(' ').first).toUpperCase();
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
