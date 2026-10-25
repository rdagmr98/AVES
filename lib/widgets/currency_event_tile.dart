import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/app_constants.dart';
import '../services/currency_history.dart';

/// Riga dello storico currency (manutenzione e volo). Con [onDeleted] le voci
/// eliminabili hanno il cestino: conferma, cancella la riga, poi [onDeleted].
class CurrencyEventTile extends StatelessWidget {
  const CurrencyEventTile(this.event, {super.key, this.onDeleted});

  final CurrencyEvent event;
  final VoidCallback? onDeleted;

  Future<void> _delete(BuildContext context) async {
    final paired =
        event.kind == CurrencyEventKind.assigned ||
        event.kind == CurrencyEventKind.revoked;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Elimina dallo storico'),
        content: SizedBox(
          width: 420,
          child: Text(
            '${event.title}\n\n'
            '${paired ? 'Assegnazione e revoca sono la stessa riga e spariscono insieme. ' : ''}'
            "L'eliminazione è definitiva e la currency viene ricalcolata.",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.currencyExpired,
            ),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await event.delete!();
    onDeleted!();
  }

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
      trailing: event.delete == null || onDeleted == null
          ? null
          : IconButton(
              tooltip: 'Elimina dallo storico',
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => _delete(context),
            ),
      subtitle: Text(
        [
          DateFormat('dd/MM/yyyy').format(event.date),
          if ((event.note ?? '').isNotEmpty) event.note!,
        ].join('  ·  '),
      ),
    );
  }
}
