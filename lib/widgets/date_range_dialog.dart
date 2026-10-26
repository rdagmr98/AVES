import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// CalendarDatePicker ha celle a misura fissa (~320 px): FittedBox lo ingrandisce
// senza toccarne il layout interno (scala anche i tap).
const double _calendarWidth = 320;
const double _paneWidth = 440;

final _fmt = DateFormat('dd/MM/yyyy');

Widget _pane(
  String label,
  DateTime value,
  DateTime first,
  DateTime last,
  ValueChanged<DateTime> onChanged,
) => SizedBox(
  width: _paneWidth,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 12, bottom: 4),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '$label  '),
              TextSpan(
                text: _fmt.format(value),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          style: const TextStyle(fontSize: 18),
        ),
      ),
      FittedBox(
        child: SizedBox(
          width: _calendarWidth,
          child: CalendarDatePicker(
            // non rilegge initialDate dopo il primo build: chiave = inizio,
            // così "Al" si riallinea quando "Dal" lo supera
            key: ValueKey(first),
            initialDate: value,
            firstDate: first,
            lastDate: last,
            onDateChanged: onChanged,
          ),
        ),
      ),
    ],
  ),
);

Widget _dialog(BuildContext ctx, List<Widget> panes, VoidCallback onConfirm) =>
    Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: panes.length * _paneWidth + (panes.length - 1) * 24 + 32,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Wrap(spacing: 24, runSpacing: 16, children: panes),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Annulla'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: onConfirm,
                    child: const Text('Conferma'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

DateTime _clamp(DateTime d, DateTime first, DateTime last) => d.isBefore(first)
    ? first
    : (d.isAfter(last) ? last : DateUtils.dateOnly(d));

/// Periodo "Dal / Al" con due calendari affiancati: gli admin lavorano da PC,
/// `showDateRangePicker` scorre i mesi in verticale. Su schermi stretti il
/// Wrap li impila.
Future<DateTimeRange?> showDateRangeDialog(
  BuildContext context, {
  required DateTime firstDate,
  required DateTime lastDate,
  DateTimeRange? initialDateRange,
}) {
  var start = _clamp(
    initialDateRange?.start ?? DateTime.now(),
    firstDate,
    lastDate,
  );
  var end = _clamp(initialDateRange?.end ?? start, firstDate, lastDate);

  return showDialog<DateTimeRange>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => _dialog(ctx, [
        _pane(
          'Dal',
          start,
          firstDate,
          lastDate,
          (d) => setDialogState(() {
            start = d;
            if (end.isBefore(d)) end = d;
          }),
        ),
        _pane('Al', end, start, lastDate, (d) => setDialogState(() => end = d)),
      ], () => Navigator.of(ctx).pop(DateTimeRange(start: start, end: end))),
    ),
  );
}

/// Data singola, stesso calendario grande del periodo (admin = PC):
/// sostituisce `showDatePicker` nelle schermate admin.
Future<DateTime?> showDateDialog(
  BuildContext context, {
  required DateTime firstDate,
  required DateTime lastDate,
  DateTime? initialDate,
  String label = 'Data',
}) {
  var value = _clamp(initialDate ?? DateTime.now(), firstDate, lastDate);
  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => _dialog(ctx, [
        _pane(
          label,
          value,
          firstDate,
          lastDate,
          (d) => setDialogState(() => value = d),
        ),
      ], () => Navigator.of(ctx).pop(value)),
    ),
  );
}
