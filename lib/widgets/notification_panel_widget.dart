import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../constants/app_constants.dart';
import '../models/activity_models.dart';
import '../services/notification_service.dart';

class NotificationPanelWidget extends ConsumerStatefulWidget {
  const NotificationPanelWidget({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<NotificationPanelWidget> createState() =>
      _NotificationPanelWidgetState();
}

class _NotificationPanelWidgetState
    extends ConsumerState<NotificationPanelWidget> {
  final _service = NotificationService();

  bool _isLoading = true;
  List<NotificationModel> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final notifications = await _service.getNotifications(widget.userId);
    if (!mounted) return;
    setState(() {
      _notifications = notifications;
      _isLoading = false;
    });
  }

  Future<void> _markAsRead(NotificationModel notification, int index) async {
    if (notification.isRead) return;
    try {
      await _service.markAsRead(notification.id);
      if (!mounted) return;
      setState(() {
        _notifications[index] = NotificationModel(
          id: notification.id,
          userId: notification.userId,
          type: notification.type,
          message: notification.message,
          isRead: true,
          createdAt: notification.createdAt,
        );
      });
      ref.read(authProvider).decrementUnread();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    final unreadCount = _notifications.where((item) => !item.isRead).length;
    if (unreadCount == 0) return;
    try {
      await _service.markAllAsRead(widget.userId);
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map(
              (item) => NotificationModel(
                id: item.id,
                userId: item.userId,
                type: item.type,
                message: item.message,
                isRead: true,
                createdAt: item.createdAt,
              ),
            )
            .toList();
      });
      final auth = ref.read(authProvider);
      for (var i = 0; i < unreadCount; i++) {
        auth.decrementUnread();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _deleteNotification(NotificationModel notification) async {
    try {
      await _service.deleteNotification(notification.id);
      if (!mounted) return;
      setState(() {
        _notifications.removeWhere((n) => n.id == notification.id);
      });
      if (!notification.isRead) {
        ref.read(authProvider).decrementUnread();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _deleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina tutte le notifiche'),
        content: const Text(
          'Vuoi eliminare definitivamente tutte le notifiche?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.currencyExpired,
            ),
            child: const Text('Elimina tutte'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteAll(widget.userId);
      if (!mounted) return;
      final unreadCount = _notifications.where((n) => !n.isRead).length;
      setState(() => _notifications = []);
      final auth = ref.read(authProvider);
      for (var i = 0; i < unreadCount; i++) {
        auth.decrementUnread();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 8, 8),
              child: Row(
                children: [
                  Text(
                    'Notifiche',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _markAllAsRead,
                    child: const Text('Segna lette'),
                  ),
                  IconButton(
                    onPressed: _notifications.isEmpty ? null : _deleteAll,
                    icon: const Icon(Icons.delete_sweep_outlined),
                    tooltip: 'Elimina tutte',
                    color: AppColors.currencyExpired,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _notifications.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 48,
                            color: AppColors.textHint,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Nessuna notifica',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _notifications.length,
                      separatorBuilder: (context, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final item = _notifications[index];
                        return Dismissible(
                          key: ValueKey(item.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: AppColors.currencyExpired,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                            ),
                          ),
                          onDismissed: (_) => _deleteNotification(item),
                          child: Card(
                            color: item.isRead
                                ? AppColors.cardBg
                                : AppColors.primary.withValues(alpha: 0.20),
                            child: ListTile(
                              onTap: () => _markAsRead(item, index),
                              leading: Icon(
                                item.icon,
                                color: item.isRead
                                    ? AppColors.textSecondary
                                    : AppColors.secondary,
                              ),
                              title: Text(
                                item.message,
                                style: TextStyle(
                                  fontWeight: item.isRead
                                      ? FontWeight.w400
                                      : FontWeight.w700,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  DateFormat(
                                    'dd/MM/yyyy HH:mm',
                                  ).format(item.createdAt),
                                ),
                              ),
                              trailing: item.isRead
                                  ? const Icon(Icons.done_all, size: 18)
                                  : const Icon(Icons.fiber_new, size: 18),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationPanel extends StatelessWidget {
  const NotificationPanel({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return NotificationPanelWidget(userId: userId);
  }
}
