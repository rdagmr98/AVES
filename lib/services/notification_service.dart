import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity_models.dart';
import 'gh_db_service.dart';
import 'web_notification_service.dart';

class NotificationService {
  final _db = GhDbService();
  static const _shownNotificationLimit = 250;
  static const _defaultTitle = 'AVES Tecnici';

  int _nextId(Iterable<Map<String, dynamic>> existing) {
    final ids = existing.map((item) => item['id']).whereType<int>().toSet();
    var candidate = DateTime.now().millisecondsSinceEpoch % 1000000000 + 1;
    while (ids.contains(candidate)) {
      candidate++;
    }
    return candidate;
  }

  List<String> _adminIds({
    bool maintenanceOnly = false,
    bool crewOnly = false,
  }) {
    return _db.users
        .where((item) {
          if (item['is_active'] == false) {
            return false;
          }
          final role = item['role'] as String? ?? '';
          if (maintenanceOnly) {
            return role == 'admin_priv';
          }
          if (crewOnly) {
            return role == 'admin_crew';
          }
          return role.startsWith('admin');
        })
        .map((item) => item['id'] as String)
        .toList(growable: false);
  }

  String _titleForType(String type) {
    if (type.startsWith('PTA_')) {
      return 'PTA manutenzione';
    }
    if (type.startsWith('PROFILE_')) {
      return 'Profilo utente';
    }
    if (type.startsWith('MAINTENANCE_')) {
      return 'Manutenzione';
    }
    if (type.startsWith('FLIGHT_') || type.startsWith('CREW_')) {
      return 'Volo';
    }
    if (type.startsWith('TOB_')) {
      return 'TOB';
    }
    return _defaultTitle;
  }

  Future<void> createNotification({
    required String userId,
    required String type,
    required String message,
    bool dedupeUnread = false,
    Map<String, dynamic>? metadata,
  }) async {
    final notifications = _db.notifications;
    final exists =
        dedupeUnread &&
        notifications.any(
          (item) =>
              item['user_id'] == userId &&
              item['type'] == type &&
              item['message'] == message &&
              item['is_read'] != true,
        );
    if (exists) {
      return;
    }

    notifications.add({
      'id': _nextId(notifications),
      'user_id': userId,
      'type': type,
      'message': message,
      'metadata': metadata,
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    });
    await _db.saveNotifications(notifications);
  }

  Future<void> createNotifications(
    Iterable<
      ({
        String userId,
        String type,
        String message,
        Map<String, dynamic>? metadata,
      })
    >
    entries, {
    bool dedupeUnread = false,
  }) async {
    final notifications = _db.notifications;
    var changed = false;
    for (final entry in entries) {
      final exists =
          dedupeUnread &&
          notifications.any(
            (item) =>
                item['user_id'] == entry.userId &&
                item['type'] == entry.type &&
                item['message'] == entry.message &&
                item['is_read'] != true,
          );
      if (exists) {
        continue;
      }
      notifications.add({
        'id': _nextId(notifications),
        'user_id': entry.userId,
        'type': entry.type,
        'message': entry.message,
        'metadata': entry.metadata,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
      changed = true;
    }
    if (changed) {
      await _db.saveNotifications(notifications);
    }
  }

  Future<void> notifyMaintenanceAdmins({
    required String type,
    required String message,
    bool dedupeUnread = false,
  }) async {
    await createNotifications(
      _adminIds(maintenanceOnly: true).map(
        (userId) =>
            (userId: userId, type: type, message: message, metadata: null),
      ),
      dedupeUnread: dedupeUnread,
    );
  }

  Future<void> notifyCrewAdmins({
    required String type,
    required String message,
    bool dedupeUnread = false,
  }) async {
    await createNotifications(
      _adminIds(crewOnly: true).map(
        (userId) =>
            (userId: userId, type: type, message: message, metadata: null),
      ),
      dedupeUnread: dedupeUnread,
    );
  }

  Future<void> notifyAllAdmins({
    required String type,
    required String message,
    bool dedupeUnread = false,
  }) async {
    await createNotifications(
      _adminIds().map(
        (userId) =>
            (userId: userId, type: type, message: message, metadata: null),
      ),
      dedupeUnread: dedupeUnread,
    );
  }

  Future<List<NotificationModel>> getNotifications(String userId) async {
    final items =
        _db.notifications.where((item) => item['user_id'] == userId).toList()
          ..sort(
            (a, b) => DateTime.parse(
              b['created_at'] as String,
            ).compareTo(DateTime.parse(a['created_at'] as String)),
          );
    return items.take(50).map(NotificationModel.fromJson).toList();
  }

  Future<List<NotificationModel>> getUnreadNotifications(String userId) async {
    final items =
        _db.notifications
            .where(
              (item) => item['user_id'] == userId && item['is_read'] == false,
            )
            .toList()
          ..sort(
            (a, b) => DateTime.parse(
              b['created_at'] as String,
            ).compareTo(DateTime.parse(a['created_at'] as String)),
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
    final index = notifications.indexWhere(
      (item) => item['id'] == notificationId,
    );
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
      if (notifications[i]['user_id'] == userId &&
          notifications[i]['is_read'] != true) {
        notifications[i] = {...notifications[i], 'is_read': true};
        changed = true;
      }
    }
    if (changed) {
      await _db.saveNotifications(notifications);
    }
  }

  Future<void> deleteNotification(int notificationId) async {
    final notifications = _db.notifications;
    final updated = notifications
        .where((n) => n['id'] != notificationId)
        .toList();
    if (updated.length != notifications.length) {
      await _db.saveNotifications(updated);
    }
  }

  Future<void> deleteAll(String userId) async {
    final notifications = _db.notifications;
    final updated = notifications.where((n) => n['user_id'] != userId).toList();
    await _db.saveNotifications(updated);
  }

  Future<void> syncUnreadSystemNotifications(String userId) async {
    final unread = await getUnreadNotifications(userId);
    if (unread.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final key = 'aves_system_notifications_seen_$userId';
    final seenIds = prefs.getStringList(key) ?? <String>[];
    final seenSet = seenIds.toSet();
    final updatedSeen = [...seenIds];

    for (final notification in unread.reversed) {
      final id = notification.id.toString();
      if (seenSet.contains(id)) {
        continue;
      }
      WebNotificationService.showNotification(
        _titleForType(notification.type),
        notification.message,
      );
      seenSet.add(id);
      updatedSeen.add(id);
    }

    if (updatedSeen.length > _shownNotificationLimit) {
      updatedSeen.removeRange(0, updatedSeen.length - _shownNotificationLimit);
    }
    await prefs.setStringList(key, updatedSeen);
  }
}
