import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../widgets/admin_app_bar_leading.dart';
import '../../widgets/app_dropdown.dart';
import '../../app.dart';
import '../../constants/app_constants.dart';
import '../../models/activity_models.dart';
import '../../models/user_models.dart';
import '../../services/activity_service.dart';
import '../../services/hours_format.dart';
import '../../widgets/hours_field.dart';
import '../../widgets/form_parts.dart';

/// Tipi di attività, nello stesso ordine di `initialTab`.
const _types = [
  (
    icon: Icons.build_outlined,
    label: 'Manutenzione',
    title: 'Attività manutentiva',
    hint: 'Lavoro eseguito su un elicottero per cui hai il privilegio.',
    submit: 'Invia attività manutentiva',
    disabled: 'Nessun privilegio manutentivo assegnato.',
  ),
  (
    icon: Icons.flight,
    label: 'Volo',
    title: 'Attività di volo',
    hint: 'Ore di volo come equipaggio T o MDB.',
    submit: 'Invia attività di volo',
    disabled: 'Nessuna abilitazione equipaggio T o MDB assegnata.',
  ),
  (
    icon: Icons.groups_outlined,
    label: 'TOB',
    title: 'Attività TOB',
    hint: 'Attività svolta con una capacità TOB.',
    submit: 'Invia attività TOB',
    disabled: 'Nessuna abilitazione equipaggio TOB assegnata.',
  ),
  (
    icon: Icons.school_outlined,
    label: 'Seminario',
    title: 'Aggiornamento Seminario NAM e MHF',
    hint:
        'Inserisci la partecipazione al seminario biennale di Normativa Aeronautica Militare (NAM) e Military Human Factor (MHF) come da AER P 2005.',
    submit: 'Invia richiesta seminario NAM/MHF',
    disabled: 'Nessun privilegio manutentivo assegnato.',
  ),
];

class AddActivityScreen extends ConsumerStatefulWidget {
  const AddActivityScreen({super.key, this.initialTab = 0});

  /// 0 manutenzione, 1 volo, 2 TOB, 3 seminario.
  final int initialTab;

  @override
  ConsumerState<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends ConsumerState<AddActivityScreen> {
  final _service = ActivityService();
  final _maintenanceDescCtrl = TextEditingController();
  final _flightDescCtrl = TextEditingController();
  final _tobDescCtrl = TextEditingController();
  final _seminarDescCtrl = TextEditingController();
  final _flightHoursCtrl = TextEditingController();

  late int _type = widget.initialTab.clamp(0, 3);

  int? _maintenanceHelicopterId;
  Set<int> _maintenancePrivilegeIds = {};
  DateTime _maintenanceDate = DateTime.now();
  bool _maintenanceIsWorkOrder = false;
  DateTime? _maintenanceDateFrom;
  DateTime? _maintenanceDateTo;
  final _maintenanceMatricolaCtrl = TextEditingController();
  final _maintenanceNumCarrCtrl = TextEditingController();
  final _maintenanceOrdLavCtrl = TextEditingController();

  int? _flightHelicopterId;
  DateTime _flightDate = DateTime.now();
  bool _flightIsPoligono = false;

  int? _tobHelicopterId;
  int? _tobCapabilityId;
  DateTime _tobDate = DateTime.now();
  DateTime _seminarDate = DateTime.now();

  bool _saving = false;

  @override
  void dispose() {
    _maintenanceDescCtrl.dispose();
    _maintenanceMatricolaCtrl.dispose();
    _maintenanceNumCarrCtrl.dispose();
    _maintenanceOrdLavCtrl.dispose();
    _flightDescCtrl.dispose();
    _tobDescCtrl.dispose();
    _seminarDescCtrl.dispose();
    _flightHoursCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(
    ValueSetter<DateTime> onSelected,
    DateTime initial,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => onSelected(picked));
    }
  }

  Future<void> _submitMaintenance(UserProfile user) async {
    if (_maintenanceHelicopterId == null) {
      _showMessage('Seleziona l\'elicottero.');
      return;
    }
    if (_maintenancePrivilegeIds.isEmpty) {
      _showMessage('Seleziona almeno un privilegio esercitato.');
      return;
    }
    if (_maintenanceIsWorkOrder) {
      if (_maintenanceDateFrom == null || _maintenanceDateTo == null) {
        _showMessage(
          'Inserisci entrambe le date (Dal / Al) per l\'ordine di lavoro.',
        );
        return;
      }
      if (_maintenanceDateTo!.isBefore(_maintenanceDateFrom!)) {
        _showMessage('La data "Al" deve essere successiva alla data "Dal".');
        return;
      }
      if (_maintenanceOrdLavCtrl.text.trim().isEmpty) {
        _showMessage('Inserisci il numero ordine di lavoro.');
        return;
      }
    }
    setState(() => _saving = true);
    try {
      // Un'attività per privilegio: la currency è calcolata per privilegio.
      for (final privilegeId in _maintenancePrivilegeIds) {
        await _service.addMaintenanceActivity(
          MaintenanceActivity(
            userId: user.id,
            helicopterTypeId: _maintenanceHelicopterId!,
            privilegeTypeId: privilegeId,
            activityDate: _maintenanceIsWorkOrder
                ? (_maintenanceDateTo ?? _maintenanceDate)
                : _maintenanceDate,
            dateFrom: _maintenanceIsWorkOrder ? _maintenanceDateFrom : null,
            dateTo: _maintenanceIsWorkOrder ? _maintenanceDateTo : null,
            description: _maintenanceDescCtrl.text.trim().isEmpty
                ? null
                : _maintenanceDescCtrl.text.trim(),
            activityType: null,
            matricolaMilitare: _maintenanceMatricolaCtrl.text.trim().isEmpty
                ? null
                : _maintenanceMatricolaCtrl.text.trim(),
            numeroCorrozzella: _maintenanceNumCarrCtrl.text.trim().isEmpty
                ? null
                : _maintenanceNumCarrCtrl.text.trim(),
            ordineLavoro: _maintenanceOrdLavCtrl.text.trim().isEmpty
                ? null
                : _maintenanceOrdLavCtrl.text.trim(),
            submittedBy: user.id,
          ),
        );
      }
      _finishSubmit();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
      }
      _showMessage(e.toString());
    }
  }

  Future<void> _submitFlight(UserProfile user) async {
    final hours = parseHours(_flightHoursCtrl.text);
    if (_flightHelicopterId == null || hours == null || hours <= 0) {
      _showMessage(
        'Inserisci elicottero e ore di volo valide (h:mm o minuti).',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.addFlightActivity(
        FlightActivity(
          userId: user.id,
          helicopterTypeId: _flightHelicopterId!,
          activityDate: _flightDate,
          flightHours: hours,
          description: _flightDescCtrl.text.trim().isEmpty
              ? null
              : _flightDescCtrl.text.trim(),
          isPoligono: _flightIsPoligono,
          submittedBy: user.id,
        ),
      );
      _finishSubmit();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
      }
      _showMessage(e.toString());
    }
  }

  Future<void> _submitTob(UserProfile user) async {
    if (_tobHelicopterId == null || _tobCapabilityId == null) {
      _showMessage('Seleziona elicottero e capacità TOB.');
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.addTobActivity(
        TobActivity(
          userId: user.id,
          helicopterTypeId: _tobHelicopterId!,
          tobCapabilityId: _tobCapabilityId!,
          activityDate: _tobDate,
          description: _tobDescCtrl.text.trim().isEmpty
              ? null
              : _tobDescCtrl.text.trim(),
          submittedBy: user.id,
        ),
      );
      _finishSubmit();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
      }
      _showMessage(e.toString());
    }
  }

  Future<void> _submitSeminar(UserProfile user) async {
    setState(() => _saving = true);
    try {
      await _service.addSeminarActivity(
        SeminarActivity(
          userId: user.id,
          seminarType: 'NAM_MHF',
          seminarDate: _seminarDate,
          description: _seminarDescCtrl.text.trim().isEmpty
              ? null
              : _seminarDescCtrl.text.trim(),
          submittedBy: user.id,
        ),
      );
      if (mounted) {
        setState(() => _saving = false);
        _seminarDescCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seminario inviato per la validazione.'),
          ),
        );
        context.go('/activities/my');
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      _showMessage(e.toString());
    }
  }

  void _finishSubmit() {
    setState(() {
      _saving = false;
      _maintenanceIsWorkOrder = false;
      _maintenanceDateFrom = null;
      _maintenanceDateTo = null;
      _flightIsPoligono = false;
    });
    _maintenanceDescCtrl.clear();
    _maintenanceMatricolaCtrl.clear();
    _maintenanceNumCarrCtrl.clear();
    _maintenanceOrdLavCtrl.clear();
    _flightDescCtrl.clear();
    _tobDescCtrl.clear();
    _flightHoursCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Attività inserita e inviata per la validazione.'),
      ),
    );
    context.go('/activities/my');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Selezione ancora valida, altrimenti l'unica opzione disponibile o null.
  static int? _keepOrOnly(int? current, Iterable<int> ids) =>
      ids.contains(current) ? current : (ids.length == 1 ? ids.first : null);

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.userProfile;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final enabled = [
      auth.privileges.isNotEmpty,
      auth.hasTCrew || auth.hasMdbCrew,
      auth.hasTobCrew,
      auth.privileges.isNotEmpty,
    ];
    // Tipo richiesto non abilitato: si apre il primo abilitato (-1 = nessuno).
    final type = enabled[_type] ? _type : enabled.indexOf(true);

    final maintenancePrivileges = auth.privileges;
    final maintenanceHelicopters = _uniqueHelicoptersFromPrivileges(
      maintenancePrivileges,
    );
    final tCrewAssignments = auth.crewAssignments
        .where((item) => item.crewType == 'T')
        .toList();
    final mdbCrewAssignments = auth.crewAssignments
        .where((item) => item.crewType == 'MDB')
        .toList();
    final tobCrewAssignments = auth.crewAssignments
        .where((item) => item.crewType == 'TOB')
        .toList();
    final flightHelicopters = _uniqueCrewHelicopters([
      ...tCrewAssignments,
      ...mdbCrewAssignments,
    ]);
    final tobHelicopters = _uniqueCrewHelicopters(tobCrewAssignments);
    final mdbHelicopterIds = mdbCrewAssignments
        .map((item) => item.helicopterTypeId)
        .toSet();

    // ponytail: stato normalizzato qui, idempotente e senza setState. Un solo
    // elicottero/capacità = selezionato in automatico; una selezione che non
    // vale più per l'elicottero scelto viene azzerata (prima restava appesa e
    // finiva nell'invio pur non essendo mostrata).
    _maintenanceHelicopterId = _keepOrOnly(
      _maintenanceHelicopterId,
      maintenanceHelicopters.map((item) => item.id),
    );
    final filteredPrivileges = maintenancePrivileges
        .where((item) => item.helicopterTypeId == _maintenanceHelicopterId)
        .toList();
    _maintenancePrivilegeIds.retainWhere(
      (id) => filteredPrivileges.any((item) => item.privilegeTypeId == id),
    );
    if (filteredPrivileges.length == 1) {
      _maintenancePrivilegeIds = {filteredPrivileges.single.privilegeTypeId};
    }
    _flightHelicopterId = _keepOrOnly(
      _flightHelicopterId,
      flightHelicopters.map((item) => item.id),
    );
    final isMdbFlightHelicopter = mdbHelicopterIds.contains(
      _flightHelicopterId,
    );
    if (!isMdbFlightHelicopter) _flightIsPoligono = false;
    _tobHelicopterId = _keepOrOnly(
      _tobHelicopterId,
      tobHelicopters.map((item) => item.id),
    );
    final filteredCapabilities = auth.tobCapabilities
        .where((item) => item.helicopterTypeId == _tobHelicopterId)
        .toList();
    _tobCapabilityId = _keepOrOnly(
      _tobCapabilityId,
      filteredCapabilities.map((item) => item.tobCapabilityId),
    );

    final fields = switch (type) {
      0 => <Widget>[
        LabeledField(
          label: 'Elicottero',
          child: _HelicopterChips(
            options: maintenanceHelicopters,
            selected: _maintenanceHelicopterId,
            onSelected: (id) => setState(() => _maintenanceHelicopterId = id),
          ),
        ),
        LabeledField(
          label: 'Privilegi esercitati',
          child: filteredPrivileges.isEmpty
              ? Text(
                  _maintenanceHelicopterId == null
                      ? 'Scegli prima l\'elicottero.'
                      : 'Nessun privilegio assegnato su questo elicottero.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              : MultiCheckList<int>(
                  options: {
                    for (final item in filteredPrivileges)
                      item.privilegeTypeId: item.privilegeName,
                  },
                  selected: _maintenancePrivilegeIds,
                  onChanged: (ids) =>
                      setState(() => _maintenancePrivilegeIds = ids),
                ),
        ),
        LabeledField(
          label: 'Modalità',
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppColors.accent,
              selectedForegroundColor: Colors.white,
            ),
            segments: const [
              ButtonSegment(value: false, label: Text('Attività singola')),
              ButtonSegment(value: true, label: Text('Ordine di lavoro')),
            ],
            selected: {_maintenanceIsWorkOrder},
            onSelectionChanged: (selection) => setState(() {
              _maintenanceIsWorkOrder = selection.first;
              if (!_maintenanceIsWorkOrder) {
                _maintenanceDateFrom = null;
                _maintenanceDateTo = null;
                _maintenanceOrdLavCtrl.clear();
              }
            }),
          ),
        ),
        if (!_maintenanceIsWorkOrder)
          LabeledField(
            label: 'Data attività',
            child: _DateTile(
              date: _maintenanceDate,
              onTap: () => _pickDate(
                (value) => _maintenanceDate = value,
                _maintenanceDate,
              ),
            ),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: LabeledField(
                  label: 'Dal (inizio OL)',
                  child: _DateTile(
                    date: _maintenanceDateFrom,
                    compact: true,
                    onTap: () => _pickDate(
                      (value) => _maintenanceDateFrom = value,
                      _maintenanceDateFrom ?? DateTime.now(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LabeledField(
                  label: 'Al (fine OL)',
                  child: _DateTile(
                    date: _maintenanceDateTo,
                    compact: true,
                    onTap: () => _pickDate(
                      (value) => _maintenanceDateTo = value,
                      _maintenanceDateTo ??
                          _maintenanceDateFrom ??
                          DateTime.now(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          LabeledField(
            label: 'Numero ordine di lavoro',
            child: TextField(
              controller: _maintenanceOrdLavCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.tag_rounded),
              ),
            ),
          ),
        ],
        LabeledField(
          label: 'Descrizione',
          optional: true,
          child: TextField(
            controller: _maintenanceDescCtrl,
            minLines: 2,
            maxLines: 4,
          ),
        ),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            shape: const Border(),
            collapsedShape: const Border(),
            title: Text(
              'Dati aggiuntivi',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            subtitle: Text(
              'Matricola militare, num. carrozzella',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            children: [
              LabeledField(
                label: 'Matricola militare',
                optional: true,
                child: TextField(
                  controller: _maintenanceMatricolaCtrl,
                  decoration: const InputDecoration(hintText: 'es. MM1234'),
                ),
              ),
              LabeledField(
                label: 'Num. carrozzella',
                optional: true,
                child: TextField(controller: _maintenanceNumCarrCtrl),
              ),
            ],
          ),
        ),
      ],
      1 => [
        LabeledField(
          label: 'Elicottero',
          child: _HelicopterChips(
            options: flightHelicopters,
            selected: _flightHelicopterId,
            onSelected: (id) => setState(() => _flightHelicopterId = id),
          ),
        ),
        LabeledField(
          label: 'Data volo',
          child: _DateTile(
            date: _flightDate,
            onTap: () => _pickDate((value) => _flightDate = value, _flightDate),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: HoursField(controller: _flightHoursCtrl, label: 'Ore di volo'),
        ),
        if (isMdbFlightHelicopter)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.gps_fixed_rounded),
              title: const Text('Attività a fuoco (Poligono)'),
              value: _flightIsPoligono,
              onChanged: (value) => setState(() => _flightIsPoligono = value),
            ),
          ),
        LabeledField(
          label: 'Descrizione',
          optional: true,
          child: TextField(
            controller: _flightDescCtrl,
            minLines: 2,
            maxLines: 4,
          ),
        ),
      ],
      2 => [
        LabeledField(
          label: 'Elicottero',
          child: _HelicopterChips(
            options: tobHelicopters,
            selected: _tobHelicopterId,
            onSelected: (id) => setState(() => _tobHelicopterId = id),
          ),
        ),
        LabeledField(
          label: 'Capacità TOB',
          child: AppDropdown<int>(
            initialValue: _tobCapabilityId,
            menuMaxHeight: 300,
            hint: Text(
              _tobHelicopterId == null
                  ? 'Scegli prima l\'elicottero'
                  : 'Seleziona la capacità',
            ),
            items: filteredCapabilities
                .map(
                  (item) => DropdownMenuItem<int>(
                    value: item.tobCapabilityId,
                    child: Text(item.capabilityName),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) => setState(() => _tobCapabilityId = value),
          ),
        ),
        LabeledField(
          label: 'Data attività TOB',
          child: _DateTile(
            date: _tobDate,
            onTap: () => _pickDate((value) => _tobDate = value, _tobDate),
          ),
        ),
        LabeledField(
          label: 'Descrizione',
          optional: true,
          child: TextField(controller: _tobDescCtrl, minLines: 2, maxLines: 4),
        ),
      ],
      3 => [
        LabeledField(
          label: 'Data seminario',
          child: _DateTile(
            date: _seminarDate,
            onTap: () =>
                _pickDate((value) => _seminarDate = value, _seminarDate),
          ),
        ),
        LabeledField(
          label: 'Note',
          optional: true,
          child: TextField(
            controller: _seminarDescCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'es. Sede: CAAE Viterbo - Nr. ordine giornale ...',
            ),
          ),
        ),
      ],
      _ => const <Widget>[],
    };

    final submit = switch (type) {
      0 => _submitMaintenance,
      1 => _submitFlight,
      2 => _submitTob,
      _ => _submitSeminar,
    };

    return Scaffold(
      appBar: AppBar(
        leading: const AdminAppBarLeading(fallbackRoute: '/dashboard'),
        title: const Text('Nuova attività'),
      ),
      body: type < 0
          ? const _NoTypesState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            for (var i = 0; i < _types.length; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Expanded(
                                child: _TypeTile(
                                  icon: _types[i].icon,
                                  label: _types[i].label,
                                  selected: i == type,
                                  enabled: enabled[i],
                                  onTap: () => enabled[i]
                                      ? setState(() => _type = i)
                                      : _showMessage(_types[i].disabled),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                FormHeader(
                                  icon: _types[type].icon,
                                  title: _types[type].title,
                                  hint: _types[type].hint,
                                ),
                                const SizedBox(height: 20),
                                ...fields,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: type < 0
          ? null
          : SaveBar(
              label: _types[type].submit,
              icon: Icons.send_rounded,
              saving: _saving,
              onPressed: () => submit(user),
            ),
    );
  }

  List<_HelicopterOption> _uniqueHelicoptersFromPrivileges(
    List<UserPrivilege> privileges,
  ) {
    final map = <int, _HelicopterOption>{};
    for (final privilege in privileges) {
      map[privilege.helicopterTypeId] = _HelicopterOption(
        id: privilege.helicopterTypeId,
        code: privilege.helicopterCode,
        name: privilege.helicopterName,
      );
    }
    return map.values.toList()..sort((a, b) => a.code.compareTo(b.code));
  }

  List<_HelicopterOption> _uniqueCrewHelicopters(
    List<UserCrewAssignment> assignments,
  ) {
    final map = <int, _HelicopterOption>{};
    for (final assignment in assignments) {
      map[assignment.helicopterTypeId] = _HelicopterOption(
        id: assignment.helicopterTypeId,
        code: assignment.helicopterCode,
        name: assignment.helicopterName,
      );
    }
    return map.values.toList()..sort((a, b) => a.code.compareTo(b.code));
  }
}

class _HelicopterOption {
  const _HelicopterOption({
    required this.id,
    required this.code,
    required this.name,
  });

  final int id;
  final String code;
  final String name;
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.textPrimary : AppColors.textSecondary;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: selected ? AppColors.accent : AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? AppColors.accentGlow : AppColors.border,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HelicopterChips extends StatelessWidget {
  const _HelicopterChips({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<_HelicopterOption> options;
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in options)
          ChoiceChip(
            label: Text(item.name),
            selected: item.id == selected,
            showCheckmark: false,
            onSelected: (_) => onSelected(item.id),
          ),
      ],
    );
  }
}

/// Data con l'aspetto di un campo; `compact` per le colonne affiancate.
class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.date,
    required this.onTap,
    this.compact = false,
  });

  final DateTime? date;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final date = this.date;
    final textTheme = Theme.of(context).textTheme;
    String? relative;
    if (date != null && !compact) {
      final now = DateTime.now();
      final days = DateTime(
        now.year,
        now.month,
        now.day,
      ).difference(DateTime(date.year, date.month, date.day)).inDays;
      relative = switch (days) {
        0 => 'oggi',
        1 => 'ieri',
        _ => '$days giorni fa',
      };
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.event_outlined),
          suffixText: relative,
        ),
        child: Text(
          date == null
              ? 'Seleziona'
              : DateFormat(
                  compact ? 'dd/MM/yyyy' : 'EEE d MMM yyyy',
                  'it',
                ).format(date),
          style: date == null
              ? textTheme.bodyLarge?.copyWith(color: AppColors.textHint)
              : textTheme.bodyLarge,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _NoTypesState extends StatelessWidget {
  const _NoTypesState();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.assignment_late_outlined,
              size: 48,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 12),
            Text(
              'Nessuna abilitazione assegnata',
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Aggiungi privilegi manutentivi o equipaggi di volo nel profilo per inserire attività.',
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.go('/profile'),
              icon: const Icon(Icons.person_outline),
              label: const Text('Vai al profilo'),
            ),
          ],
        ),
      ),
    );
  }
}
