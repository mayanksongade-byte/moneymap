import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:moneymap/core/constants/color_constants.dart';
import 'package:moneymap/core/providers/currency_provider.dart';
import 'package:moneymap/core/providers/notification_provider.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../config/routes/app_routes.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light Mode';
      case ThemeMode.dark:
        return 'Dark Mode';
      case ThemeMode.system:
        return 'System Default';
    }
  }

  Future<void> _selectTime(BuildContext context, NotificationProvider provider, bool isMorning) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isMorning ? provider.morningTime : provider.eveningTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: Theme.of(context).brightness,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (isMorning) {
        provider.setMorningTime(picked);
      } else {
        provider.setEveningTime(picked);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final colors = context.colors;

    return Scaffold(
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
                // FIX: Check if we can pop, otherwise go to Home
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.home);
                }
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
                    "Settings",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "App preferences & customisation",
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
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          _buildSectionLabel("Appearance"),
          _buildSettingsTile(
            icon: Icons.palette_outlined,
            title: "App Theme",
            subtitle: _themeModeLabel(themeProvider.themeMode),
            onTap: () => _showThemeDialog(themeProvider),
          ),
          _buildSettingsTile(
            icon: Icons.payments_outlined,
            title: "Global Currency",
            subtitle: "Current: ${currencyProvider.selectedCurrency} (${currencyProvider.currencySymbol})",
            onTap: () => _showCurrencyDialog(currencyProvider),
          ),
          const SizedBox(height: 12),
          _buildSectionLabel("Notifications"),
          _buildGlobalNotificationTile(notificationProvider),
          if (notificationProvider.notificationsEnabled) ...[
            const SizedBox(height: 8),
            _buildToggleTile(
              icon: Icons.warning_amber_rounded,
              title: "Budget Alerts",
              subtitle: "Get notified when you approach or exceed budget limits",
              value: notificationProvider.budgetAlertsEnabled,
              onChanged: (v) => notificationProvider.setBudgetAlertsEnabled(v),
            ),
            _buildToggleTile(
              icon: Icons.alarm_rounded,
              title: "Reminders",
              subtitle: "Daily morning and evening tracking reminders",
              value: notificationProvider.remindersEnabled,
              onChanged: (v) => notificationProvider.setRemindersEnabled(v),
            ),
            _buildToggleTile(
              icon: Icons.receipt_long_rounded,
              title: "Transaction Updates",
              subtitle: "Confirmations for added or edited transactions",
              value: notificationProvider.transactionUpdatesEnabled,
              onChanged: (v) => notificationProvider.setTransactionUpdatesEnabled(v),
            ),
            _buildToggleTile(
              icon: Icons.sync_problem_rounded,
              title: "Sync Errors",
              subtitle: "Alerts when data synchronization fails",
              value: notificationProvider.syncErrorsEnabled,
              onChanged: (v) => notificationProvider.setSyncErrorsEnabled(v),
            ),
            const SizedBox(height: 12),
            _buildSectionLabel("Schedule"),
            _buildReminderTile(
              context,
              icon: Icons.wb_sunny_outlined,
              title: "Morning Reminder",
              isEnabled: notificationProvider.morningEnabled && notificationProvider.remindersEnabled,
              time: notificationProvider.morningTime,
              onToggle: (v) => notificationProvider.setMorningEnabled(v),
              onTimeTap: () => _selectTime(context, notificationProvider, true),
            ),
            _buildReminderTile(
              context,
              icon: Icons.nightlight_outlined,
              title: "Evening Reminder",
              isEnabled: notificationProvider.eveningEnabled && notificationProvider.remindersEnabled,
              time: notificationProvider.eveningTime,
              onToggle: (v) => notificationProvider.setEveningEnabled(v),
              onTimeTap: () => _selectTime(context, notificationProvider, false),
            ),
          ],
          const SizedBox(height: 12),
          _buildSectionLabel("General"),
          _buildSettingsTile(
            icon: Icons.info_outline_rounded,
            title: "About MoneyMap",
            subtitle: "Version 1.0.0",
            onTap: () => _showAboutDialog(),
          ),
          const SizedBox(height: 40),
        ],
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

  Widget _buildGlobalNotificationTile(NotificationProvider provider) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            provider.notificationsEnabled ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        title: Text(
          "Global Notifications",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
            fontSize: 15,
          ),
        ),
        trailing: Switch(
          value: provider.notificationsEnabled,
          onChanged: (v) {
            HapticFeedback.selectionClick();
            provider.setNotificationsEnabled(v);
          },
          activeColor: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 11, color: colors.textSecondary),
        ),
        trailing: Switch(
          value: value,
          onChanged: (v) {
            HapticFeedback.selectionClick();
            onChanged(v);
          },
          activeColor: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
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

  Widget _buildReminderTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool isEnabled,
    required TimeOfDay time,
    required ValueChanged<bool> onToggle,
    required VoidCallback onTimeTap,
  }) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
            trailing: Switch(
              value: isEnabled,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                onToggle(v);
              },
              activeColor: AppColors.primary,
            ),
          ),
          if (isEnabled) ...[
            Padding(
              padding: const EdgeInsets.only(left: 48, right: 16, bottom: 12),
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTimeTap();
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.border.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Reminder Time",
                        style: TextStyle(fontSize: 13, color: colors.textSecondary, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        time.format(context),
                        style: const TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showThemeDialog(ThemeProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text("Choose Theme", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeMode.values.map((mode) => RadioListTile<ThemeMode>(
                title: Text(_themeModeLabel(mode), style: TextStyle(color: context.colors.textPrimary)),
                value: mode,
                groupValue: provider.themeMode,
                onChanged: (v) {
                  provider.setThemeMode(v!);
                  Navigator.pop(ctx);
                },
                activeColor: AppColors.primary,
              )).toList(),
        ),
      ),
    );
  }

  void _showCurrencyDialog(CurrencyProvider provider) {
    final currencies = {
      'INR': '₹ Indian Rupee',
      'USD': '\$ US Dollar',
      'EUR': '€ Euro',
      'GBP': '£ British Pound',
      'JPY': '¥ Japanese Yen',
      'CNY': '¥ Chinese Yuan',
      'CAD': 'C\$ Canadian Dollar',
      'AUD': 'A\$ Australian Dollar',
    };
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text("Select Currency", style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: currencies.entries
                .map((e) => ListTile(
                      title: Text(e.value, style: TextStyle(color: context.colors.textPrimary)),
                      trailing: provider.selectedCurrency == e.key
                          ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                          : null,
                      onTap: () {
                        provider.setCurrency(e.key);
                        Navigator.pop(ctx);
                      },
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: context.colors.surface,
        title: const Text('About MoneyMap', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.map_rounded, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text('MoneyMap', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
            const SizedBox(height: 8),
            Text('Your Personal Finance Guide', style: TextStyle(fontSize: 14, color: context.colors.textSecondary)),
            const SizedBox(height: 24),
            const Text('Version 1.0.0', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
