// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

class WebNotificationService {
  static Future<bool> requestPermission() async {
    if (!_isSupported()) {
      return false;
    }
    final permission = await html.Notification.requestPermission();
    return permission == 'granted';
  }

  static void showNotification(String title, String body) {
    if (!_isSupported()) {
      return;
    }
    if (html.Notification.permission == 'granted') {
      try {
        html.Notification(title, body: body, icon: '/AVES/icons/Icon-192.png');
      } catch (_) {
        // Browser Notification constructor can fail on mobile or when
        // called outside a service-worker context — silently ignore.
      }
    }
  }

  static bool _isSupported() {
    try {
      return html.Notification.supported;
    } catch (_) {
      return false;
    }
  }
}
