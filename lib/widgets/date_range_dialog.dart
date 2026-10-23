import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Periodo "Dal / Al" con due calendari affiancati: gli admin lavorano da PC,
/// `showDateRangePicker` scorre i mesi in verticale. Su schermi stretti il
/// Wrap li impila.
Future<DateTimeRange?> showDateRangeDialog(
  BuildContext context, {
  required DateTime firstDate,
  required DateTime lastDate,
  DateTimeRange? initialDateRange,
}) {
  DateTime clamp(DateTime d) => d.isBefore(firstDate)
      ? firstDate
      : (d.isAfter(lastDate) ? lastDate : DateUtils.dateOnly(d));
  var start = clamp(initialDateRange?.start ?? DateTime.now());
  var end = clamp(initialDateRange?.end ?? start);
  final fmt = DateFormat('dd/MM/yyyy');

  return showDialog<DateTimeRange>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        Widget pane(
          String label,
          DateTime value,
          DateTime first,
          ValueChanged<DateTime> onChanged,
        ) => SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '$label  '),
                      TextSpan(
                        text: fmt.format(value),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              CalendarDatePicker(
                // non rilegge initialDate dopo il primo build: chiave = inizio,
                // così "Al" si riallinea quando "Dal" lo supera
                key: ValueKey(first),
                initialDate: value,
                firstDate: first,
                lastDate: lastDate,
                onDateChanged: (d) => setDialogState(() => onChanged(d)),
              ),
            ],
          ),
        );

        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Wrap(
                    spacing: 24,
                    runSpacing: 16,
                    children: [
                      pane('Dal', start, firstDate, (d) {
                        start = d;
                        if (end.isBefore(d)) end = d;
                      }),
                      pane('Al', end, start, (d) => end = d),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Annulla'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => Navigator.of(
                          ctx,
                        ).pop(DateTimeRange(start: start, end: end)),
                        child: const Text('Conferma'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
