import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    HapticFeedback.selectionClick();

    if (index == 0) {
      context.go(AppRoutes.home);
    } else if (index == 1) {
      context.push(AppRoutes.statistics);
    } else if (index == 2) {
      context.push(AppRoutes.addTransaction);
    }
  }

  Future<void> _exportData(bool isPdf) async {
    final transactions = context.read<TransactionProvider>().transactions;
    if (transactions.isEmpty) {
      _showToast('No transactions found to export', isError: true);
      return;
    }

    setState(() => _isBusy = true);
    try {
      if (isPdf) {
        await ExportHelper.exportToPdf(transactions);
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final authProvider = context.watch<AppAuthProvider>();
    final user = _user;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: colors.background,
        title: Text("My Profile",
            style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary),
          onPressed: () => context.go(AppRoutes.home),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _HeaderCard(user: user, isGuest: authProvider.isGuest, onEdit: _editProfile),
              const SizedBox(height: 24),
              const _SectionLabel('My Finances'),
              _MenuTile(
                icon: Icons.bar_chart_rounded,
                title: 'Financial Statistics',
                onTap: () => context.push(AppRoutes.statistics),
              ),
              _MenuTile(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Budget Planning',
                onTap: () => context.push(AppRoutes.budget),
              ),
              _MenuTile(
                icon: Icons.category_outlined,
                title: 'Category Management',
                onTap: () => context.push(AppRoutes.categoryManagement),
              ),
              const SizedBox(height: 24),
              const _SectionLabel('Settings'),
              _MenuTile(
                icon: Icons.settings_outlined,
                title: 'App Settings',
                onTap: () => context.push(AppRoutes.settings),
              ),
              _MenuTile(
                icon: Icons.picture_as_pdf_outlined,
                title: 'Export Data',
                onTap: () => _exportData(true),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: _logout,
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Logout Account'),
              ),
              const SizedBox(height: 40),
              Center(child: Text('v$_appVersion', style: TextStyle(color: colors.textDisabled))),
            ],
          ),
          if (_isBusy) const Center(child: CircularProgressIndicator()),
        ],
      ),
      bottomNavigationBar: AppBottomNav(currentIndex: _currentIndex, onTap: _onNavTap),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final User? user;
  final bool isGuest;
  final VoidCallback onEdit;
  const _HeaderCard({required this.user, required this.isGuest, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final name = isGuest ? 'Guest User' : (user?.displayName ?? 'User');
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const CircleAvatar(radius: 30, backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white)),
          const SizedBox(width: 16),
          Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit, color: Colors.white)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
  );
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _MenuTile({required this.icon, required this.title, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: AppColors.primary),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}
