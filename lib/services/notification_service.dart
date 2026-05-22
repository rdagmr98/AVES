import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/activity_models.dart';

class NotificationService {
  final _db = Supabase.instance.client;

  Future<List<NotificationModel>> getNotifications(String userId) async {
    final data = await _db
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
    return (data as List).map((e) => NotificationModel.fromJson(e)).toList();
  }

  Future<List<NotificationModel>> getUnreadNotifications(String userId) async {
    final data = await _db
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .eq('is_read', false)
        .order('created_at', ascending: false);
    return (data as List).map((e) => NotificationModel.fromJson(e)).toList();
  }

  Future<int> getUnreadCount(String userId) async {
    final data = await _db
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .eq('is_read', false);
    return (data as List).length;
  }

  Future<void> markAsRead(int notificationId) async {
    await _db
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  Future<void> markAllAsRead(String userId) async {
    await _db
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId);
  }
}
