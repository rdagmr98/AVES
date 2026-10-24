import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../constants/app_constants.dart';
import '../models/activity_models.dart';
import '../models/user_models.dart';
import '../services/activity_service.dart';
import '../services/hours_format.dart';
import '../services/user_service.dart';
import 'app_dropdown.dart';
import 'date_range_dialog.dart';
import 'hours_field.dart';

const _courseTypes = ['Corso iniziale', 'Corso di ripristino'];
const _qualT = -1;

/// Corso volo: abilita (o ripristina) una qualifica T o una capacità TOB.
/// Assegna la qualifica se manca e registra il corso come attività validata
/// con `activity_type` = tipo corso. Per la T i voli del corso, con le durate,
/// contano per le ore del semestre; per la capacità la currency riparte dalla
/// data del corso. [heliId] / [capId] / [t] bloccano elicottero e qualifica.
Future<bool> registerFlightCourse(
  BuildContext context,
  WidgetRef ref,
  UserProfile user, {
  int? heliId,
  int? capId,
  bool t = false,
  bool restore = false,
}) async {
  final auth = ref.read(authProvider);
  final adminId = auth.userProfile?.id;
  final helis = auth.visibleHelicopters(keep: heliId);
  final caps = auth.tobCapabilityTypes;
  final lockQual = t || capId != null;
  var type = _courseTypes[restore ? 1 : 0];
  var heli = heliId ?? helis.firstOrNull?.id;
  var qual = capId ?? _qualT;
  var date = DateTime.now();
  final dates = <DateTime?>[null];
  // ponytail: controller non disposti, come in _registerOjt.
  final hours = [TextEditingController()];
  final notes = TextEditingController();
  bool flightsOk() =>
      hours.isNotEmpty &&
      dates.every((d) => d != null) &&
      hours.every((c) => (parseHours(c.text) ?? 0) > 0);
  Widget label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4, top: 12),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
    ),
  );
  Widget dateButton(BuildContext c, DateTime? d, ValueChanged<DateTime> set) =>
      OutlinedButton.icon(
        icon: const Icon(Icons.event, size: 18),
        label: Text(d == null ? 'Data' : DateFormat('dd/MM/yyyy').format(d)),
        onPressed: () async {
          final v = await showDateDialog(
            c,
            initialDate: d ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime.now(),
          );
          if (v != null) set(v);
        },
      );
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setD) => AlertDialog(
        title: Text(
          'Corso volo  ·  ${user.fullName}',
          overflow: TextOverflow.ellipsis,
        ),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                label('Tipo'),
                AppDropdown<String>(
                  initialValue: type,
                  isDense: true,
                  items: [
                    for (final ct in _courseTypes)
                      DropdownMenuItem(value: ct, child: Text(ct)),
                  ],
                  onChanged: (v) => type = v ?? type,
                ),
                label('Elicottero'),
                AppDropdown<int>(
                  initialValue: heli,
                  isDense: true,
                  items: [
                    for (final h in helis)
                      DropdownMenuItem(
                        value: h.id,
                        child: Text(h.code, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: heliId != null ? null : (v) => heli = v,
                ),
                label('Qualifica'),
                AppDropdown<int>(
                  initialValue: qual,
                  isDense: true,
                  items: [
                    const DropdownMenuItem(value: _qualT, child: Text('T')),
                    for (final cap in caps)
                      DropdownMenuItem(
                        value: cap.id,
                        child: Text(
                          '${cap.code} · ${cap.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: lockQual
                      ? null
                      : (v) => setD(() => qual = v ?? qual),
                ),
                if (qual == _qualT) ...[
                  label('Voli del corso (contano per le ore del semestre)'),
                  for (var i = 0; i < hours.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 30),
                            child: dateButton(
                              c,
                              dates[i],
                              (v) => setD(() => dates[i] = v),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: HoursField(
                              controller: hours[i],
                              label: 'Durata volo ${i + 1}',
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 30),
                            child: IconButton(
                              tooltip: 'Elimina volo',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => setD(() {
                                dates.removeAt(i);
                                hours.removeAt(i);
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Aggiungi volo'),
                      onPressed: () => setD(() {
                        dates.add(null);
                        hours.add(TextEditingController());
                      }),
                    ),
                  ),
                ] else ...[
                  label('Data corso'),
                  dateButton(c, date, (v) => setD(() => date = v)),
                ],
                label('Note'),
                TextField(
                  controller: notes,
                  maxLines: 2,
                  decoration: const InputDecoration(isDense: true),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Annulla'),
          ),
          ListenableBuilder(
            listenable: Listenable.merge(hours),
            builder: (_, _) => FilledButton(
              onPressed: qual != _qualT || flightsOk()
                  ? () => Navigator.of(c).pop(true)
                  : null,
              child: const Text('Registra corso'),
            ),
          ),
        ],
      ),
    ),
  );
  final h = heli;
  if (ok != true || h == null || adminId == null) return false;
  final users = UserService();
  final acts = ActivityService();
  final note = notes.text.trim();
  final desc = note.isEmpty ? null : note;
  if (qual == _qualT) {
    final assigned = (await users.getUserCrewAssignments(
      user.id,
    )).any((a) => a.crewType == 'T' && a.helicopterTypeId == h);
    if (!assigned) {
      await users.setUserCrewAssignments(user.id, [
        {'helicopter_type_id': h, 'crew_type': 'T', 'tob_grade': null},
      ], append: true);
    }
    // ponytail: un'attività (e una notifica) per volo, come se il tecnico li
    // avesse inseriti uno a uno; batch se le notifiche diventano troppe.
    for (var i = 0; i < hours.length; i++) {
      await acts.addFlightActivityValidated(
        FlightActivity(
          userId: user.id,
          helicopterTypeId: h,
          activityDate: dates[i]!,
          flightHours: parseHours(hours[i].text)!,
          description: desc,
          activityType: type,
          submittedBy: adminId,
        ),
        adminId,
      );
    }
    return true;
  }
  final assigned = (await users.getUserTobCapabilities(
    user.id,
  )).any((x) => x.helicopterTypeId == h && x.tobCapabilityId == qual);
  if (!assigned) {
    await users.setUserTobCapabilities(user.id, [
      {'helicopter_type_id': h, 'tob_capability_id': qual},
    ], append: true);
  }
  await acts.addTobActivityValidated(
    TobActivity(
      userId: user.id,
      helicopterTypeId: h,
      tobCapabilityId: qual,
      activityDate: date,
      description: desc,
      activityType: type,
      submittedBy: adminId,
    ),
    adminId,
  );
  return true;
}
