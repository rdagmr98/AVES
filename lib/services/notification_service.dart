import '../models/activity_models.dart';
import 'gh_db_service.dart';

class NotificationService {
  final _db = GhDbService();

  Future<List<NotificationModel>> getNotifications(String userId) async {
    final items = _db.notifications
        .where((item) => item['user_id'] == userId)
        .toList()
      ..sort(
        (a, b) => DateTime.parse(b['created_at'] as String).compareTo(
          DateTime.parse(a['created_at'] as String),
        ),
      );
    return items.take(50).map(NotificationModel.fromJson).toList();
  }

  Future<List<NotificationModel>> getUnreadNotifications(String userId) async {
    final items = _db.notifications
        .where((item) => item['user_id'] == userId && item['is_read'] == false)
        .toList()
      ..sort(
        (a, b) => DateTime.parse(b['created_at'] as String).compareTo(
          DateTime.parse(a['created_at'] as String),
        ),
      );
    return items.map(NotificationModel.fromJson).toList();
  }

  Future<int> getUnreadCount(String userId) async {
    return _db.notifications
        .where((item) => item['user_id'] == userId && item['is_read'] == false)
        .length;
  }

  Future<void> markAsRead(int notificationId) async {
    final notifications = _db.notifications;
    final index = notifications.indexWhere((item) => item['id'] == notificationId);
    if (index == -1) {
      return;
    }
    notifications[index] = {...notifications[index], 'is_read': true};
    await _db.saveNotifications(notifications);
  }

  Future<void> markAllAsRead(String userId) async {
    final notifications = _db.notifications;
    var changed = false;
    for (var i = 0; i < notifications.length; i++) {
      if (notifications[i]['user_id'] == userId && notifications[i]['is_read'] != true) {
        notifications[i] = {...notifications[i], 'is_read': true};
        changed = true;
      }
    }
    if (changed) {
      await _db.saveNotifications(notifications);
    }
  }
}
