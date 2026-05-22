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
    if (!mounted) {
      return;
    }
    setState(() {
      _notifications = notifications;
      _isLoading = false;
    });
  }

  Future<void> _markAsRead(NotificationModel notification, int index) async {
    if (notification.isRead) {
      return;
    }
    await _service.markAsRead(notification.id);
    if (!mounted) {
      return;
    }
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
  }

  Future<void> _markAllAsRead() async {
    final unreadCount = _notifications.where((item) => !item.isRead).length;
    if (unreadCount == 0) {
      return;
    }
    await _service.markAllAsRead(widget.userId);
    if (!mounted) {
      return;
    }
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(
                    'Notifiche',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _markAllAsRead,
                    child: const Text('Segna tutte lette'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _notifications.isEmpty
                  ? const Center(child: Text('Nessuna notifica disponibile.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final item = _notifications[index];
                        return Card(
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
                        );
                      },
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemCount: _notifications.length,
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
