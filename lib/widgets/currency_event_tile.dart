import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/app_constants.dart';
import '../services/currency_history.dart';

/// Riga dello storico currency (manutenzione e volo).
class CurrencyEventTile extends StatelessWidget {
  const CurrencyEventTile(this.event, {super.key});

  final CurrencyEvent event;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (event.kind) {
      CurrencyEventKind.assigned => (
        Icons.add_circle_outline,
        AppColors.primary,
      ),
      CurrencyEventKind.revoked => (
        Icons.remove_circle_outline,
        AppColors.textSecondary,
      ),
      CurrencyEventKind.restored => (
        Icons.how_to_reg_outlined,
        AppColors.currencyValid,
      ),
      CurrencyEventKind.lost => (
        Icons.event_busy_outlined,
        AppColors.currencyExpired,
      ),
    };
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color, size: 20),
      title: Text(event.title),
      subtitle: Text(
        [
          DateFormat('dd/MM/yyyy').format(event.date),
          if ((event.note ?? '').isNotEmpty) event.note!,
        ].join('  ·  '),
      ),
    );
  }
}
