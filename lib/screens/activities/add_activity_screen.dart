import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../models/activity_models.dart';
import '../../models/user_models.dart';
import '../../services/activity_service.dart';

class AddActivityScreen extends ConsumerStatefulWidget {
  const AddActivityScreen({super.key});

  @override
  ConsumerState<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends ConsumerState<AddActivityScreen>
    with SingleTickerProviderStateMixin {
  final _service = ActivityService();
  final _maintenanceDescCtrl = TextEditingController();
  final _flightDescCtrl = TextEditingController();
  final _tobDescCtrl = TextEditingController();
  final _seminarDescCtrl = TextEditingController();
  final _flightHoursCtrl = TextEditingController();

  late final TabController _tabController;

  int? _maintenanceHelicopterId;
  int? _maintenancePrivilegeId;
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
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

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
    _tabController.dispose();
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
      await _service.addMaintenanceActivity(
        MaintenanceActivity(
          userId: user.id,
          helicopterTypeId: _maintenanceHelicopterId!,
          privilegeTypeId: _maintenancePrivilegeId,
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
      _finishSubmit();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
      }
      _showMessage(e.toString());
    }
  }

  Future<void> _submitFlight(UserProfile user) async {
    final hours = double.tryParse(_flightHoursCtrl.text.replaceAll(',', '.'));
    if (_flightHelicopterId == null || hours == null || hours <= 0) {
      _showMessage('Inserisci elicottero e ore di volo valide.');
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

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.userProfile;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isCompactTabs = screenWidth < 420;
    final maintenancePrivileges = auth.privileges;
    final maintenanceHelicopters = _uniqueHelicoptersFromPrivileges(
      maintenancePrivileges,
    );
    final filteredPrivileges = maintenancePrivileges
        .where((item) => item.helicopterTypeId == _maintenanceHelicopterId)
        .toList();

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
    final isMdbFlightHelicopter =
        _flightHelicopterId != null &&
        mdbHelicopterIds.contains(_flightHelicopterId);
    final filteredCapabilities = auth.tobCapabilities
        .where((item) => item.helicopterTypeId == _tobHelicopterId)
        .toList();

    final maintenanceHelicopterItems = maintenanceHelicopters
        .map(
          (item) =>
              DropdownMenuItem<int>(value: item.id, child: Text(item.name)),
        )
        .toList(growable: false);
    final maintenancePrivilegeItems = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(
        value: null,
        child: Text('Tutti i privilegi / legacy'),
      ),
      ...filteredPrivileges.map(
        (item) => DropdownMenuItem<int?>(
          value: item.privilegeTypeId,
          child: Text(item.privilegeName),
        ),
      ),
    ];
    final flightHelicopterItems = flightHelicopters
        .map(
          (item) =>
              DropdownMenuItem<int>(value: item.id, child: Text(item.name)),
        )
        .toList(growable: false);
    final tobHelicopterItems = tobHelicopters
        .map(
          (item) =>
              DropdownMenuItem<int>(value: item.id, child: Text(item.name)),
        )
        .toList(growable: false);
    final tobCapabilityItems = filteredCapabilities
        .map(
          (item) => DropdownMenuItem<int>(
            value: item.tobCapabilityId,
            child: Text(item.capabilityName),
          ),
        )
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inserisci Attività'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: isCompactTabs,
          tabs: const [
            Tab(text: 'Manutenzione'),
            Tab(text: 'Volo'),
            Tab(text: 'TOB'),
            Tab(text: 'Seminario NAM/MHF'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ActivityTab(
            enabled: maintenancePrivileges.isNotEmpty,
            disabledMessage: 'Nessun privilegio manutentivo assegnato.',
            child: _ActivityFormCard(
              children: [
                DropdownButtonFormField<int>(
                  initialValue:
                      maintenanceHelicopters.any(
                        (item) => item.id == _maintenanceHelicopterId,
                      )
                      ? _maintenanceHelicopterId
                      : null,
                  menuMaxHeight: 300,
                  decoration: const InputDecoration(labelText: 'Elicottero'),
                  items: maintenanceHelicopterItems,
                  onChanged: (value) {
                    setState(() {
                      _maintenanceHelicopterId = value;
                      if (!filteredPrivileges.any(
                        (item) =>
                            item.privilegeTypeId == _maintenancePrivilegeId,
                      )) {
                        _maintenancePrivilegeId = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int?>(
                  initialValue:
                      _maintenancePrivilegeId == null ||
                          filteredPrivileges.any(
                            (item) =>
                                item.privilegeTypeId == _maintenancePrivilegeId,
                          )
                      ? _maintenancePrivilegeId
                      : null,
                  menuMaxHeight: 300,
                  decoration: const InputDecoration(
                    labelText: 'Tipo attività (privilegio)',
                    helperText:
                        'Opzionale per compatibilità con attività legacy',
                  ),
                  items: maintenancePrivilegeItems,
                  onChanged: (value) =>
                      setState(() => _maintenancePrivilegeId = value),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Attività singola'),
                    const SizedBox(width: 8),
                    Switch(
                      value: _maintenanceIsWorkOrder,
                      onChanged: (value) => setState(() {
                        _maintenanceIsWorkOrder = value;
                        if (!value) {
                          _maintenanceDateFrom = null;
                          _maintenanceDateTo = null;
                          _maintenanceOrdLavCtrl.clear();
                        }
                      }),
                    ),
                    const SizedBox(width: 8),
                    const Text('Ordine di lavoro'),
                  ],
                ),
                const SizedBox(height: 8),
                if (!_maintenanceIsWorkOrder)
                  _DateSelector(
                    label: 'Data attività',
                    date: _maintenanceDate,
                    onPressed: () => _pickDate(
                      (value) => _maintenanceDate = value,
                      _maintenanceDate,
                    ),
                  )
                else ...[
                  _DateSelector(
                    label: 'Dal (inizio OL)',
                    date: _maintenanceDateFrom ?? DateTime.now(),
                    onPressed: () => _pickDate(
                      (value) => _maintenanceDateFrom = value,
                      _maintenanceDateFrom ?? DateTime.now(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _DateSelector(
                    label: 'Al (fine OL)',
                    date: _maintenanceDateTo ?? DateTime.now(),
                    onPressed: () => _pickDate(
                      (value) => _maintenanceDateTo = value,
                      _maintenanceDateTo ?? DateTime.now(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (_maintenanceIsWorkOrder) ...[
                  TextField(
                    controller: _maintenanceOrdLavCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Numero Ordine di Lavoro',
                      helperText: 'Obbligatorio per Ordine di lavoro',
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _maintenanceDescCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Descrizione'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _maintenanceMatricolaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Matricola militare (opzionale)',
                    hintText: 'es. MM1234',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _maintenanceNumCarrCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Num. carrozzella (opzionale)',
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : () => _submitMaintenance(user),
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Text('Invia attività manutentiva'),
                ),
              ],
            ),
          ),
          _ActivityTab(
            enabled: auth.hasTCrew || auth.hasMdbCrew,
            disabledMessage:
                'Nessuna abilitazione equipaggio T o MDB assegnata.',
            child: _ActivityFormCard(
              children: [
                DropdownButtonFormField<int>(
                  initialValue:
                      flightHelicopters.any(
                        (item) => item.id == _flightHelicopterId,
                      )
                      ? _flightHelicopterId
                      : null,
                  menuMaxHeight: 300,
                  decoration: const InputDecoration(labelText: 'Elicottero'),
                  items: flightHelicopterItems,
                  onChanged: (value) => setState(() {
                    _flightHelicopterId = value;
                    if (value == null || !mdbHelicopterIds.contains(value)) {
                      _flightIsPoligono = false;
                    }
                  }),
                ),
                const SizedBox(height: 16),
                _DateSelector(
                  label: 'Data volo',
                  date: _flightDate,
                  onPressed: () =>
                      _pickDate((value) => _flightDate = value, _flightDate),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _flightHoursCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Ore di volo'),
                ),
                if (isMdbFlightHelicopter) ...[
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Attività a fuoco (Poligono)'),
                    value: _flightIsPoligono,
                    onChanged: (value) =>
                        setState(() => _flightIsPoligono = value ?? false),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _flightDescCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Descrizione'),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : () => _submitFlight(user),
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Text('Invia attività di volo'),
                ),
              ],
            ),
          ),
          _ActivityTab(
            enabled: auth.hasTobCrew,
            disabledMessage: 'Nessuna abilitazione equipaggio TOB assegnata.',
            child: _ActivityFormCard(
              children: [
                DropdownButtonFormField<int>(
                  initialValue:
                      tobHelicopters.any((item) => item.id == _tobHelicopterId)
                      ? _tobHelicopterId
                      : null,
                  menuMaxHeight: 300,
                  decoration: const InputDecoration(labelText: 'Elicottero'),
                  items: tobHelicopterItems,
                  onChanged: (value) {
                    setState(() {
                      _tobHelicopterId = value;
                      if (!filteredCapabilities.any(
                        (item) => item.tobCapabilityId == _tobCapabilityId,
                      )) {
                        _tobCapabilityId = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue:
                      filteredCapabilities.any(
                        (item) => item.tobCapabilityId == _tobCapabilityId,
                      )
                      ? _tobCapabilityId
                      : null,
                  menuMaxHeight: 300,
                  decoration: const InputDecoration(labelText: 'Capacità TOB'),
                  items: tobCapabilityItems,
                  onChanged: (value) =>
                      setState(() => _tobCapabilityId = value),
                ),
                const SizedBox(height: 16),
                _DateSelector(
                  label: 'Data attività TOB',
                  date: _tobDate,
                  onPressed: () =>
                      _pickDate((value) => _tobDate = value, _tobDate),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _tobDescCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Descrizione'),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : () => _submitTob(user),
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Text('Invia attività TOB'),
                ),
              ],
            ),
          ),
          _ActivityTab(
            enabled: auth.privileges.isNotEmpty,
            disabledMessage: 'Nessun privilegio manutentivo assegnato.',
            child: _ActivityFormCard(
              children: [
                Text(
                  'Aggiornamento Seminario NAM e MHF',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Inserisci la partecipazione al seminario biennale di Normativa Aeronautica Militare (NAM) e Military Human Factor (MHF) come da AER P 2005.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                _DateSelector(
                  label: 'Data seminario',
                  date: _seminarDate,
                  onPressed: () =>
                      _pickDate((value) => _seminarDate = value, _seminarDate),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _seminarDescCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Note (opzionale)',
                    hintText:
                        'es. Sede: CAAE Viterbo - Nr. ordine giornale ...',
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : () => _submitSeminar(user),
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Text('Invia richiesta seminario NAM/MHF'),
                ),
              ],
            ),
          ),
        ],
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

class _ActivityTab extends StatelessWidget {
  const _ActivityTab({
    required this.enabled,
    required this.disabledMessage,
    required this.child,
  });

  final bool enabled;
  final String disabledMessage;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return Center(child: Text(disabledMessage));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: child,
    );
  }
}

class _ActivityFormCard extends StatelessWidget {
  const _ActivityFormCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardPadding = screenWidth < 600 ? 20.0 : 24.0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class _DateSelector extends StatelessWidget {
  const _DateSelector({
    required this.label,
    required this.date,
    required this.onPressed,
  });

  final String label;
  final DateTime date;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
      onPressed: onPressed,
      icon: const Icon(Icons.calendar_today_outlined),
      label: Text('$label: ${DateFormat('dd/MM/yyyy').format(date)}'),
    );
  }
}
