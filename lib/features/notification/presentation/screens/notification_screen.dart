import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:moneymap/core/providers/notification_provider.dart';
import 'package:moneymap/core/models/notification_history_model.dart';
import 'package:moneymap/core/theme/app_colors_extension.dart';
import 'package:moneymap/core/constants/color_constants.dart';
import 'package:moneymap/config/routes/app_routes.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        toolbarHeight: 90,
        titleSpacing: 16,
        title: Row(
          children: [
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.border),
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: colors.textPrimary),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                  Text(
                    "Track your activity",
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              if (provider.history.isEmpty) return const SizedBox.shrink();
              return Row(
                children: [
                  if (provider.unreadCount > 0)
                    TextButton(
                      onPressed: () => provider.markAllAsRead(),
                      child: const Text(
                        'Mark all as read',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: colors.textPrimary),
                    onSelected: (value) {
                      if (value == 'mark_read') {
                        provider.markAllAsRead();
                      } else if (value == 'delete_all') {
                        _showDeleteAllDialog(context, provider);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'mark_read',
                        child: Text('Mark all as read'),
                      ),
                      const PopupMenuItem(
                        value: 'delete_all',
                        child: Text('Delete all', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: provider.history.isEmpty
                ? _buildEmptyState(context)
                : _buildNotificationList(context, provider.history),
          );
        },
      ),
    );
  }

  Widget _buildNotificationList(BuildContext context, List<NotificationHistoryModel> history) {
    final colors = context.colors;
    final groupedNotifications = _groupNotifications(history);

    return ListView.builder(
      key: const ValueKey('notification_list'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: groupedNotifications.length,
      itemBuilder: (context, index) {
        final group = groupedNotifications[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Text(
                group.title.toUpperCase(),
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            ...group.notifications.map((n) => _NotificationItem(notification: n)),
          ],
        );
      },
    );
  }

  void _showDeleteAllDialog(BuildContext context, NotificationProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all notifications?'),
        content: const Text('This will permanently remove your notification history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.clearHistory();
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = context.colors;
    return Center(
      key: const ValueKey('notification_empty'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_off_outlined, size: 64, color: colors.textDisabled),
          ),
          const SizedBox(height: 24),
          Text(
            "You're all caught up",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: colors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            "No new notifications right now.",
            style: TextStyle(color: colors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "We'll notify you about important money reminders and budget updates.",
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textDisabled, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  List<_NotificationGroup> _groupNotifications(List<NotificationHistoryModel> notifications) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final Map<String, List<NotificationHistoryModel>> groups = {
      'Today': [],
      'Yesterday': [],
      'Earlier': [],
    };

    for (var n in notifications) {
      final date = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
      if (date == today) {
        groups['Today']!.add(n);
      } else if (date == yesterday) {
        groups['Yesterday']!.add(n);
      } else {
        groups['Earlier']!.add(n);
      }
    }

    return groups.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => _NotificationGroup(e.key, e.value))
        .toList();
  }
}

class _NotificationGroup {
  final String title;
  final List<NotificationHistoryModel> notifications;
  _NotificationGroup(this.title, this.notifications);
}

class _NotificationItem extends StatelessWidget {
  final NotificationHistoryModel notification;

  const _NotificationItem({required this.notification});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final provider = context.read<NotificationProvider>();

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => provider.deleteNotification(notification.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: () {
          provider.markAsRead(notification.id);
          _handleNavigation(context, notification.type);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notification.isRead ? colors.surface.withValues(alpha: 0.6) : colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: notification.isRead ? Colors.transparent : AppColors.primary.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIcon(notification.type),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w800,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatTime(notification.createdAt),
                      style: TextStyle(
                        color: colors.textDisabled,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(String type) {
    IconData iconData;
    Color color;

    switch (type) {
      case 'budgetAlert':
      case 'budget_alert':
        iconData = Icons.warning_amber_rounded;
        color = Colors.orange;
        break;
      case 'budget_exceeded':
        iconData = Icons.error_outline_rounded;
        color = Colors.red;
        break;
      case 'reminder':
      case 'morning_reminder':
        iconData = Icons.wb_sunny_rounded;
        color = Colors.blue;
        break;
      case 'evening_reminder':
        iconData = Icons.nightlight_round;
        color = Colors.indigo;
        break;
      case 'transactionAdded':
        iconData = Icons.account_balance_wallet_rounded;
        color = Colors.green;
        break;
      case 'syncFailed':
        iconData = Icons.sync_problem_rounded;
        color = Colors.red;
        break;
      case 'weekly_summary':
        iconData = Icons.bar_chart_rounded;
        color = Colors.purple;
        break;
      default:
        iconData = Icons.notifications_none_rounded;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: color, size: 22),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('h:mm a').format(date);
    }
  }

  void _handleNavigation(BuildContext context, String type) {
    switch (type) {
      case 'transactionAdded':
      case 'morning_reminder':
      case 'evening_reminder':
      case 'reminder':
        context.push(AppRoutes.addTransaction);
        break;
      case 'budget_alert':
      case 'budget_exceeded':
      case 'budgetAlert':
        context.push(AppRoutes.budget);
        break;
      case 'weekly_summary':
        context.push(AppRoutes.statistics);
        break;
    }
  }
}
