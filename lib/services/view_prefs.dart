import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _compactKey = 'compact_dashboard';

/// Dashboard utente in visualizzazione compatta (default) o classica.
/// Preferenza del dispositivo, non del profilo.
final compactDashboard = ValueNotifier<bool>(true);

Future<void> loadViewPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  compactDashboard.value = prefs.getBool(_compactKey) ?? true;
}

Future<void> setCompactDashboard(bool value) async {
  compactDashboard.value = value;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_compactKey, value);
}
