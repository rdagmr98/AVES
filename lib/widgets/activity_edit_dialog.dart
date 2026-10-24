import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/app_constants.dart';
import '../models/activity_models.dart';
import '../services/activity_service.dart';
import '../services/hours_format.dart';
import '../services/user_service.dart';
import 'app_dropdown.dart';
import 'date_range_dialog.dart';
import 'form_parts.dart';
import 'hours_field.dart';

/// Modifica admin di un'attività (manutenzione, volo, TOB, seminario): mostra
/// solo i campi passati e restituisce i campi JSON da salvare (null = annulla).
///
/// [details] sono le opzioni (privilegi, capacità TOB) dell'elicottero scelto;
/// la chiave null ("tutti") va inclusa solo per le righe legacy che la hanno.
/// [texts]: chiave JSON → (etichetta, valore iniziale).
Future<Map<String, dynamic>?> showActivityEditDialog(
  BuildContext context, {
  required String title,
  required DateTime date,
  String dateKey = 'activity_date',
  String? description,
  Map<int, String>? helicopters,
  int? helicopterId,
  String detailLabel = '',
  String? detailKey,
  Map<int?, String> Function(int heliId)? details,
  int? detailId,
  bool period = false,
  DateTime? from,
  DateTime? to,
  Map<String, (String, String?)> texts = const {},
  double? hours,
  bool poligono = false,
  Set<int> poligonoHelicopters = const {},
}) {
  final fmt = DateFormat('dd/MM/yyyy');
  final narrow = MediaQuery.sizeOf(context).width < 600;
  var heliId = helicopterId;
  var detail = detailId;
  // ponytail: controller non disposti, il dialog li usa ancora durante
  // l'animazione di chiusura; il GC li raccoglie.
  final desc = TextEditingController(text: description ?? '');
  final hoursText = hours == null ? '' : formatHours(hours);
  final hoursCtrl = TextEditingController(text: hoursText);
  final textCtrls = {
    for (final MapEntry(:key, value: (_, initial)) in texts.entries)
      key: TextEditingController(text: initial ?? ''),
  };
  String? error;

  // Affiancati da PC, uno sotto l'altro su mobile (niente LayoutBuilder:
  // AlertDialog misura il contenuto con IntrinsicWidth).
  Widget line(List<Widget> children) => narrow
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        )
      : Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, c) in children.indexed) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: c),
            ],
          ],
        );

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setD) {
        final detailOptions = heliId == null || details == null
            ? const <int?, String>{}
            : details(heliId!);
        if (!detailOptions.containsKey(detail)) detail = null;
        final showPoligono =
            hours != null && poligonoHelicopters.contains(heliId);
        if (!showPoligono) poligono = false;

        Widget dateField(
          String label,
          DateTime? value,
          void Function(DateTime? d) onChanged, {
          bool clearable = true,
        }) => LabeledField(
          label: label,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.event, size: 18),
                  label: Text(value == null ? '—' : fmt.format(value)),
                  onPressed: () async {
                    final d = await showDateDialog(
                      c,
                      label: label,
                      initialDate: value ?? date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setD(() => onChanged(d));
                  },
                ),
              ),
              if (clearable && value != null)
                IconButton(
                  tooltip: 'Azzera',
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => setD(() => onChanged(null)),
                ),
            ],
          ),
        );

        Widget dropdown<V>(
          String label,
          V value,
          Map<V, String> options,
          ValueChanged<V> onChanged,
        ) => LabeledField(
          label: label,
          child: AppDropdown<V>(
            key: ValueKey('$label$value${options.length}'),
            initialValue: value,
            hint: const Text('Seleziona'),
            items: [
              for (final MapEntry(:key, :value) in options.entries)
                DropdownMenuItem(
                  value: key,
                  child: Text(value, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setD(() => onChanged(v as V)),
          ),
        );

        void save() {
          final f = from;
          final t = to;
          if (f != null && t != null && f.isAfter(t)) {
            setD(() => error = 'La data "Dal" è successiva ad "Al".');
            return;
          }
          if (detailKey != null &&
              detail == null &&
              !detailOptions.containsKey(null)) {
            setD(() => error = 'Seleziona: $detailLabel.');
            return;
          }
          final parsedHours = parseHours(hoursCtrl.text);
          if (hours != null && (parsedHours == null || parsedHours <= 0)) {
            setD(() => error = 'Ore di volo non valide.');
            return;
          }
          String? text(TextEditingController ctrl) =>
              ctrl.text.trim().isEmpty ? null : ctrl.text.trim();
          String? iso(DateTime? d) => d?.toIso8601String().split('T').first;
          Navigator.of(c).pop({
            dateKey: iso(date),
            if (period) ...{'date_from': iso(from), 'date_to': iso(to)},
            if (helicopters != null) 'helicopter_type_id': heliId,
            ?detailKey: detail,
            // h:mm arrotonda al minuto: riscrive solo se l'admin ha cambiato
            if (hours != null && hoursCtrl.text != hoursText)
              'flight_hours': parsedHours,
            if (hours != null) 'is_poligono': poligono,
            'description': text(desc),
            for (final MapEntry(:key, :value) in textCtrls.entries)
              key: text(value),
          });
        }

        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  line([
                    dateField(
                      'Data attività',
                      date,
                      (d) => date = d ?? date,
                      clearable: false,
                    ),
                    if (period) ...[
                      dateField('Dal', from, (d) => from = d),
                      dateField('Al', to, (d) => to = d),
                    ],
                  ]),
                  if (helicopters != null)
                    line([
                      dropdown<int?>(
                        'Elicottero',
                        heliId,
                        helicopters,
                        (v) => heliId = v,
                      ),
                      if (detailKey != null)
                        dropdown<int?>(
                          detailLabel,
                          detail,
                          detailOptions,
                          (v) => detail = v,
                        ),
                    ]),
                  if (hours != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: HoursField(
                        controller: hoursCtrl,
                        label: 'Ore di volo',
                      ),
                    ),
                  if (showPoligono)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: poligono,
                      title: const Text('Attività a fuoco (Poligono)'),
                      onChanged: (v) => setD(() => poligono = v ?? false),
                    ),
                  LabeledField(
                    label: 'Descrizione',
                    child: TextField(controller: desc, maxLines: 3),
                  ),
                  if (textCtrls.isNotEmpty)
                    line([
                      for (final MapEntry(:key, :value) in textCtrls.entries)
                        LabeledField(
                          label: texts[key]!.$1,
                          child: TextField(controller: value),
                        ),
                    ]),
                  if (error != null)
                    Text(
                      error!,
                      style: const TextStyle(color: AppColors.currencyExpired),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(),
              child: const Text('Annulla'),
            ),
            FilledButton(onPressed: save, child: const Text('Salva')),
          ],
        );
      },
    ),
  );
}

// Modifica e salvataggio per tipo di attività (true = salvata). Le opzioni
// vengono dall'utente che l'ha inserita, più il valore attuale.

Future<bool> editMaintenanceActivity(
  BuildContext context,
  MaintenanceActivity a,
) async {
  final users = UserService();
  final privileges = await users.getUserPrivileges(a.userId);
  final licenses = await users.getUserLicenses(a.userId);
  if (!context.mounted) return false;
  final fields = await showActivityEditDialog(
    context,
    title: 'Modifica manutenzione',
    date: a.activityDate,
    description: a.description,
    helicopters: {
      for (final l in licenses) l.helicopterTypeId: l.helicopterCode,
      for (final p in privileges) p.helicopterTypeId: p.helicopterCode,
      a.helicopterTypeId: a.helicopterCode,
    },
    helicopterId: a.helicopterTypeId,
    detailLabel: 'Privilegio',
    detailKey: 'privilege_type_id',
    details: (heli) => {
      // "tutti" resta solo per le righe legacy che lo hanno già
      if (a.privilegeTypeId == null) null: 'Tutti i privilegi (legacy)',
      for (final p in privileges.where((p) => p.helicopterTypeId == heli))
        p.privilegeTypeId: p.privilegeName,
      if (heli == a.helicopterTypeId && a.privilegeTypeId != null)
        a.privilegeTypeId: a.privilegeName,
    },
    detailId: a.privilegeTypeId,
    period: true,
    from: a.dateFrom,
    to: a.dateTo,
    texts: {
      'ordine_lavoro': ('Ordine di lavoro', a.ordineLavoro),
      'matricola_militare': ('Matricola militare', a.matricolaMilitare),
      'numero_corrozzella': ('N. corrozzella', a.numeroCorrozzella),
    },
  );
  if (fields == null) return false;
  await ActivityService().updateMaintenanceActivity(a.id!, fields);
  return true;
}

Future<bool> editFlightActivity(BuildContext context, FlightActivity a) async {
  final crew = await UserService().getUserCrewAssignments(a.userId);
  if (!context.mounted) return false;
  final fields = await showActivityEditDialog(
    context,
    title: 'Modifica volo',
    date: a.activityDate,
    description: a.description,
    helicopters: {
      for (final c in crew)
        if (c.crewType != 'TOB') c.helicopterTypeId: c.helicopterCode,
      a.helicopterTypeId: a.helicopterCode,
    },
    helicopterId: a.helicopterTypeId,
    hours: a.flightHours,
    poligono: a.isPoligono,
    poligonoHelicopters: {
      for (final c in crew)
        if (c.crewType == 'MDB') c.helicopterTypeId,
      if (a.isPoligono) a.helicopterTypeId,
    },
  );
  if (fields == null) return false;
  await ActivityService().updateFlightActivity(a.id!, fields);
  return true;
}

Future<bool> editTobActivity(BuildContext context, TobActivity a) async {
  final users = UserService();
  final crew = await users.getUserCrewAssignments(a.userId);
  final caps = await users.getUserTobCapabilities(a.userId);
  if (!context.mounted) return false;
  final fields = await showActivityEditDialog(
    context,
    title: 'Modifica TOB',
    date: a.activityDate,
    description: a.description,
    helicopters: {
      for (final c in crew)
        if (c.crewType == 'TOB') c.helicopterTypeId: c.helicopterCode,
      a.helicopterTypeId: a.helicopterCode,
    },
    helicopterId: a.helicopterTypeId,
    detailLabel: 'Capacità',
    detailKey: 'tob_capability_id',
    details: (heli) => {
      for (final cap in caps.where((cap) => cap.helicopterTypeId == heli))
        cap.tobCapabilityId: cap.capabilityName,
      if (heli == a.helicopterTypeId) a.tobCapabilityId: a.capabilityName,
    },
    detailId: a.tobCapabilityId,
  );
  if (fields == null) return false;
  await ActivityService().updateTobActivity(a.id!, fields);
  return true;
}

Future<bool> editSeminarActivity(
  BuildContext context,
  SeminarActivity a,
) async {
  final fields = await showActivityEditDialog(
    context,
    title: 'Modifica seminario',
    date: a.seminarDate,
    dateKey: 'seminar_date',
    description: a.description,
  );
  if (fields == null) return false;
  await ActivityService().updateSeminarActivity(a.id!, fields);
  return true;
}
