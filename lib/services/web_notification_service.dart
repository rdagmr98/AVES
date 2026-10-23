// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

@JS('avesShowNotification')
external void _jsShowNotification(String title, String body);

/// Notifiche di sistema del browser: permesso, sottoscrizione Web Push e
/// notifiche locali. Il service worker dedicato (`web/push/sw.js`, scope
/// `push/`) riceve i push anche ad app chiusa; quello di Flutter non cambia.
class WebNotificationService {
  /// Questo browser è sottoscritto al push: le notifiche arrivano da lì,
  /// quelle locali si saltano per non mostrarle due volte.
  static final pushActive = ValueNotifier<bool>(false);

  /// Motivo dell'ultima sottoscrizione fallita, da mostrare all'utente.
  static String? lastError;

  /// iPhone/iPad da Safari: il push esiste solo con l'app nella schermata Home.
  static bool get needsHomeScreen =>
      permission == 'unsupported' &&
      RegExp('iPhone|iPad').hasMatch(html.window.navigator.userAgent);

  /// 'granted' | 'denied' | 'default' | 'unsupported'.
  static String get permission => _isSupported()
      ? (html.Notification.permission ?? 'default')
      : 'unsupported';

  static Future<bool> requestPermission() async {
    if (!_isSupported()) return false;
    if (permission == 'granted') return true;
    if (permission == 'denied') return false;
    final permissionResult = await html.Notification.requestPermission();
    return permissionResult == 'granted';
  }

  static String _b64u(ByteBuffer? b) =>
      b == null ? '' : base64Url.encode(Uint8List.view(b)).replaceAll('=', '');

  /// Sottoscrive il browser al push e restituisce `{endpoint, keys:{p256dh,auth}}`
  /// (null se non supportato, permesso negato o errore).
  static Future<Map<String, dynamic>?> subscribe(String vapidPublicKey) async {
    try {
      lastError = null;
      if (permission != 'granted') return null;
      final container = html.window.navigator.serviceWorker;
      if (container == null) {
        lastError = 'service worker non disponibile';
        return null;
      }
      final reg = await container.register('push/sw.js', {'scope': 'push/'});
      // ponytail: polling breve, `ready` risolverebbe il SW di Flutter (scope padre).
      for (var i = 0; i < 50 && reg.active == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      final pm = reg.active == null ? null : reg.pushManager;
      if (pm == null) {
        lastError = 'service worker push non attivo';
        return null;
      }
      // subscribe() restituisce la sottoscrizione esistente se c'è già (da spec).
      final sub = await pm.subscribe({
        'userVisibleOnly': true,
        'applicationServerKey': base64Url.decode(
          base64.normalize(vapidPublicKey),
        ),
      });
      final endpoint = sub.endpoint;
      final p256dh = _b64u(sub.getKey('p256dh'));
      final auth = _b64u(sub.getKey('auth'));
      if (endpoint == null || p256dh.isEmpty || auth.isEmpty) {
        lastError = 'sottoscrizione incompleta';
        return null;
      }
      pushActive.value = true;
      return {
        'endpoint': endpoint,
        'keys': {'p256dh': p256dh, 'auth': auth},
      };
    } catch (e) {
      lastError = '$e';
      return null;
    }
  }

  static void showNotification(String title, String body) {
    if (pushActive.value || permission != 'granted') return;
    try {
      _jsShowNotification(title, body);
    } catch (_) {}
  }

  static bool _isSupported() {
    try {
      return html.Notification.supported;
    } catch (_) {
      return false;
    }
  }
}
