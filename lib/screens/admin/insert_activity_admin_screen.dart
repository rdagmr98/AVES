import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../constants/app_constants.dart';
import '../../models/activity_models.dart';
import '../../models/reference_models.dart';
import '../../models/user_models.dart';
import '../../services/activity_service.dart';
import '../../services/gh_db_service.dart';
import '../../services/hours_format.dart';
import '../../services/user_service.dart';
import '../../widgets/admin_app_bar_leading.dart';
import '../../widgets/filter_panel.dart';
import '../../widgets/hours_field.dart';
import '../../widgets/user_avatar.dart';

class InsertActivityAdminScreen extends ConsumerStatefulWidget {
  const InsertActivityAdminScreen({super.key});

  @override
  ConsumerState<InsertActivityAdminScreen> createState() =>
      _InsertActivityAdminScreenState();
}

enum _AdminInsertTabType {
  workOrder,
  maintenance,
  seminar,
  flight,
  tob,
  crewFlight,
}

class _InsertActivityAdminScreenState
    extends ConsumerState<InsertActivityAdminScreen>
    with SingleTickerProviderStateMixin {
  final _activityService = ActivityService();
  final _userService = UserService();
  final _maintenanceDescCtrl = TextEditingController();
  final _maintenanceMatricolaCtrl = TextEditingController();
  final _maintenanceNumCarrCtrl = TextEditingController();
  final _maintenanceOrdLavCtrl = TextEditingController();
  final _flightDescCtrl = TextEditingController();
  final _tobDescCtrl = TextEditingController();
  final _seminarDescCtrl = TextEditingController();
  final _flightHoursCtrl = TextEditingController();
  final _crewFlightHoursCtrl = TextEditingController();
  final _crewFlightDescCtrl = TextEditingController();
  final _workOrderMatricolaCtrl = TextEditingController();
  final _workOrderNumCarrCtrl = TextEditingController();
  final _workOrderOrdLavCtrl = TextEditingController();
  final _workOrderDescCtrl = TextEditingController();

  late final TabController _tabController;
  late final List<_AdminInsertTabType> _tabs;
  bool _loading = true;
  bool _saving = false;
  List<UserProfile> _users = [];
  UserProfile? _selectedUser;
  List<UserCrewAssignment> _crews = [];
  List<UserTobCapability> _tobCapabilities = [];

  int? _maintenanceHelicopterId;
  // privilegio -> tecnici selezionati
  final Map<int, Set<String>> _maintenanceTeam = {};
  String _maintenanceUserSearch = '';
  DateTime _maintenanceDate = DateTime.now();

  int? _flightHelicopterId;
  DateTime _flightDate = DateTime.now();
  bool _flightIsPoligono = false;

  int? _tobHelicopterId;
  int? _tobCapabilityId;
  DateTime _tobDate = DateTime.now();
  DateTime _seminarDate = DateTime.now();
  String _seminarType = 'NAM';
  final Set<String> _seminarUserIds = {};
  String _seminarUserSearch = '';

  int? _workOrderHelicopterId;
  DateTime? _workOrderDateFrom;
  DateTime? _workOrderDateTo;
  String? _workOrderActivityType;
  final Map<int, Set<String>> _workOrderTeam = {};
  String _workOrderSearch = '';

  int? _crewFlightHelicopterId;
  DateTime _crewFlightDate = DateTime.now();
  bool _crewFlightIsPoligono = false;
  final List<_CrewEntry> _crewEntries = [];

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider);
    if (auth.isAdminPriv) {
      _tabs = const [
        _AdminInsertTabType.workOrder,
        _AdminInsertTabType.maintenance,
        _AdminInsertTabType.seminar,
      ];
    } else if (auth.isAdminCrew) {
      _tabs = const [
        _AdminInsertTabType.crewFlight,
        _AdminInsertTabType.flight,
        _AdminInsertTabType.tob,
      ];
    } else {
      _tabs = const [
        _AdminInsertTabType.maintenance,
        _AdminInsertTabType.seminar,
        _AdminInsertTabType.flight,
        _AdminInsertTabType.tob,
      ];
    }
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _maintenanceDescCtrl.dispose();
    _maintenanceMatricolaCtrl.dispose();
    _maintenanceNumCarrCtrl.dispose();
    _maintenanceOrdLavCtrl.dispose();
    _flightDescCtrl.dispose();
    _tobDescCtrl.dispose();
    _seminarDescCtrl.dispose();
    _flightHoursCtrl.dispose();
    _crewFlightHoursCtrl.dispose();
    _crewFlightDescCtrl.dispose();
    _workOrderMatricolaCtrl.dispose();
    _workOrderNumCarrCtrl.dispose();
    _workOrderOrdLavCtrl.dispose();
    _workOrderDescCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final users = await _userService.getAllUsers();
    final auth = ref.read(authProvider);
    if (!mounted) {
      return;
    }
    setState(() {
      _users = users.where((item) {
        if (auth.isAdminPriv) {
          return item.isApprovedMaint;
        }
        if (auth.isAdminCrew) {
          return item.isApprovedCrew;
        }
        return item.isApproved;
      }).toList();
      _loading = false;
    });
  }

  Future<void> _selectUser(UserProfile? user) async {
    setState(() {
      _selectedUser = user;
      _crews = [];
      _tobCapabilities = [];
    });
    if (user == null) {
      return;
    }
    final crews = await _userService.getUserCrewAssignments(user.id);
    final tobCapabilities = await _userService.getUserTobCapabilities(user.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _crews = crews;
      _tobCapabilities = tobCapabilities;
    });
  }

  Future<void> _pickDate(ValueSetter<DateTime> onSet, DateTime current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => onSet(picked));
    }
  }

  Future<void> _submitMaintenance() async {
    final adminId = ref.read(authProvider).userProfile?.id;
    if (adminId == null ||
        _maintenanceHelicopterId == null ||
        _teamRows(_maintenanceTeam) == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Seleziona elicottero e almeno un tecnico per privilegio.',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      for (final MapEntry(key: privilegeId, value: userIds)
          in _maintenanceTeam.entries) {
        for (final userId in userIds) {
          await _activityService.addMaintenanceActivityValidated(
            MaintenanceActivity(
              userId: userId,
              helicopterTypeId: _maintenanceHelicopterId!,
              privilegeTypeId: privilegeId,
              activityDate: _maintenanceDate,
              description: _maintenanceDescCtrl.text.trim().isEmpty
                  ? null
                  : _maintenanceDescCtrl.text.trim(),
              matricolaMilitare: _maintenanceMatricolaCtrl.text.trim().isEmpty
                  ? null
                  : _maintenanceMatricolaCtrl.text.trim(),
              numeroCorrozzella: _maintenanceNumCarrCtrl.text.trim().isEmpty
                  ? null
                  : _maintenanceNumCarrCtrl.text.trim(),
              ordineLavoro: _maintenanceOrdLavCtrl.text.trim().isEmpty
                  ? null
                  : _maintenanceOrdLavCtrl.text.trim(),
              submittedBy: adminId,
            ),
            adminId,
          );
        }
      }
      _finish();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _submitFlight() async {
    final user = _selectedUser;
    final adminId = ref.read(authProvider).userProfile?.id;
    final hours = parseHours(_flightHoursCtrl.text);
    if (user == null ||
        adminId == null ||
        _flightHelicopterId == null ||
        hours == null ||
        hours <= 0) {
      return;
    }
    setState(() => _saving = true);
    try {
      await _activityService.addFlightActivityValidated(
        FlightActivity(
          userId: user.id,
          helicopterTypeId: _flightHelicopterId!,
          activityDate: _flightDate,
          flightHours: hours,
          description: _flightDescCtrl.text.trim().isEmpty
              ? null
              : _flightDescCtrl.text.trim(),
          isPoligono: _flightIsPoligono,
          submittedBy: adminId,
        ),
        adminId,
      );
      _finish();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _submitTob() async {
    final user = _selectedUser;
    final adminId = ref.read(authProvider).userProfile?.id;
    if (user == null ||
        adminId == null ||
        _tobHelicopterId == null ||
        _tobCapabilityId == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      await _activityService.addTobActivityValidated(
        TobActivity(
          userId: user.id,
          helicopterTypeId: _tobHelicopterId!,
          tobCapabilityId: _tobCapabilityId!,
          activityDate: _tobDate,
          description: _tobDescCtrl.text.trim().isEmpty
              ? null
              : _tobDescCtrl.text.trim(),
          submittedBy: adminId,
        ),
        adminId,
      );
      _finish();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _submitSeminar() async {
    final adminId = ref.read(authProvider).userProfile?.id;
    if (adminId == null || _seminarUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona almeno un partecipante.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final db = GhDbService();
      final now = DateTime.now();
      final rows = db.seminars.toList();
      var nextId = rows
          .map((item) => item['id'])
          .whereType<int>()
          .fold<int>(0, (maxId, id) => id > maxId ? id : maxId);

      for (final userId in _seminarUserIds) {
        for (final type
            in _seminarType == 'NAM_MHF' ? ['NAM', 'MHF'] : [_seminarType]) {
          nextId++;
          rows.add({
            'id': nextId,
            'user_id': userId,
            'seminar_type': type,
            'seminar_date': _seminarDate.toIso8601String().split('T').first,
            'description': _seminarDescCtrl.text.trim().isEmpty
                ? null
                : _seminarDescCtrl.text.trim(),
            'is_validated': true,
            'submitted_by': adminId,
            'validated_by': adminId,
            'validated_at': now.toIso8601String(),
            'created_at': now.toIso8601String(),
          });
        }
      }
      await db.saveSeminars(rows);
      if (mounted) {
        final summary =
            '${_seminarUserIds.length} partecipanti '
            '(${_seminarType == 'NAM_MHF' ? 'NAM + MHF' : _seminarType})';
        setState(() {
          _saving = false;
          _seminarUserIds.clear();
          _seminarDescCtrl.clear();
          _seminarType = 'NAM';
          _seminarDate = DateTime.now();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Seminario inserito per $summary.')),
        );
        context.go('/admin/validate');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _addCrewEntry(List<TobCapability> tobCapabilities) async {
    final helicopterId = _crewFlightHelicopterId;
    if (helicopterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona prima un elicottero.')),
      );
      return;
    }
    final availableUsers = _users
        .where((u) => !_crewEntries.any((e) => e.user.id == u.id))
        .toList(growable: false);
    final roleItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'T', child: Text('T')),
      const DropdownMenuItem(value: 'TOB', child: Text('TOB')),
      const DropdownMenuItem(value: 'MTB', child: Text('MTB')),
    ];
    final capabilityItems = tobCapabilities
        .map(
          (item) =>
              DropdownMenuItem<int>(value: item.id, child: Text(item.name)),
        )
        .toList(growable: false);

    final result = await showDialog<_CrewEntry>(
      context: context,
      builder: (ctx) {
        String? userId;
        String role = 'T';
        int? capId;
        String? capName;
        return StatefulBuilder(
          builder: (context, setD) => AlertDialog(
            scrollable: true,
            title: const Text('Aggiungi membro equipaggio'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Membro'),
                  menuMaxHeight: 300,
                  items: availableUsers
                      .map(
                        (u) => DropdownMenuItem<String>(
                          value: u.id,
                          child: Text(
                            '${u.fullName} · ${u.numeroLicenza ?? ''}',
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (v) => setD(() => userId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Ruolo'),
                  items: roleItems,
                  onChanged: (v) => setD(() {
                    role = v ?? 'T';
                    capId = null;
                    capName = null;
                  }),
                ),
                if (role == 'TOB') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Capacità TOB',
                    ),
                    menuMaxHeight: 300,
                    items: capabilityItems,
                    onChanged: (v) {
                      setD(() {
                        capId = v;
                        capName = tobCapabilities
                            .firstWhere((c) => c.id == v)
                            .name;
                      });
                    },
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (userId == null) {
                    return;
                  }
                  final user = _users.firstWhere((u) => u.id == userId);
                  Navigator.pop(
                    ctx,
                    _CrewEntry(
                      user: user,
                      role: role,
                      tobCapabilityId: capId,
                      tobCapabilityName: capName,
                    ),
                  );
                },
                child: const Text('Aggiungi'),
              ),
            ],
          ),
        );
      },
    );
    if (result != null && mounted) {
      setState(() => _crewEntries.add(result));
    }
  }

  Future<void> _pickWorkOrderRange() async {
    final from = _workOrderDateFrom;
    final to = _workOrderDateTo;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: from != null && to != null
          ? DateTimeRange(start: from, end: to)
          : null,
      builder: (context, child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 640),
          child: child,
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _workOrderDateFrom = picked.start;
        _workOrderDateTo = picked.end;
      });
    }
  }

  /// Tecnici abilitati per privilegio sull'elicottero, ordinati per nome.
  Map<int, List<UserProfile>> _eligibleTechs(int helicopterId) {
    final byId = {for (final u in _users) u.id: u};
    final result = <int, List<UserProfile>>{};
    for (final p in GhDbService().privileges) {
      if (p['helicopter_type_id'] != helicopterId || p['active'] == false) {
        continue;
      }
      final user = byId[p['user_id']];
      if (user == null) continue;
      final list = result.putIfAbsent(p['privilege_type_id'] as int, () => []);
      if (!list.contains(user)) list.add(user);
    }
    for (final users in result.values) {
      users.sort((a, b) => a.fullName.compareTo(b.fullName));
    }
    return result;
  }

  int _teamRows(Map<int, Set<String>> team) =>
      team.values.fold(0, (n, ids) => n + ids.length);

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }

  Widget _paneHeader(
    String title,
    String search,
    String hint,
    ValueChanged<String> onSearch,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        SizedBox(
          width: 280,
          child: TextFormField(
            initialValue: search,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
            onChanged: onSearch,
          ),
        ),
      ],
    );
  }

  /// Colonna sinistra (elicottero, privilegi, dettagli) + a destra una
  /// sezione di tecnici abilitati per ogni privilegio scelto.
  Widget _teamTab({
    required int? helicopterId,
    required ValueSetter<int?> onHelicopter,
    required Map<int, Set<String>> team,
    required String search,
    required ValueChanged<String> onSearch,
    required List<Widget> details,
    required String submitLabel,
    required VoidCallback onSubmit,
  }) {
    final auth = ref.read(authProvider);
    final eligible = helicopterId == null
        ? const <int, List<UserProfile>>{}
        : _eligibleTechs(helicopterId);
    final privileges = auth.privilegeTypes
        .where((p) => eligible.containsKey(p.id))
        .toList();
    final usersById = {for (final u in _users) u.id: u};
    final codesByUser = <String, List<String>>{};
    for (final p in privileges) {
      for (final id in team[p.id] ?? const <String>{}) {
        codesByUser.putIfAbsent(id, () => []).add(p.code);
      }
    }
    final members = [for (final id in codesByUser.keys) usersById[id]!]
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    final rows = _teamRows(team);

    return _TwoPane(
      left: [
        DropdownButtonFormField<int>(
          initialValue: helicopterId,
          decoration: const InputDecoration(labelText: 'Elicottero'),
          items: [
            for (final h in auth.helicopterTypes)
              DropdownMenuItem(value: h.id, child: Text(h.name)),
          ],
          onChanged: (v) => setState(() {
            team.clear();
            onHelicopter(v);
          }),
        ),
        if (helicopterId != null && privileges.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: Text(
              'Nessun tecnico abilitato su questo elicottero.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else if (helicopterId != null)
          FilterSection(
            title: 'Privilegi',
            children: [
              for (final p in privileges)
                FilterPill(
                  label: '${p.code} (${eligible[p.id]!.length})',
                  tooltip: p.name,
                  selected: team.containsKey(p.id),
                  onTap: () => setState(() {
                    if (team.remove(p.id) == null) team[p.id] = {};
                  }),
                ),
            ],
          ),
        const SizedBox(height: 16),
        ...details,
        const SizedBox(height: 20),
        Text(
          '${members.length} ${members.length == 1 ? 'tecnico' : 'tecnici'}'
          ' · $rows ${rows == 1 ? 'riga' : 'righe'}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        for (final u in members)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${u.fullName}: ${codesByUser[u.id]!.join(', ')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _saving ? null : onSubmit,
          icon: const Icon(Icons.check),
          label: Text('$submitLabel ($rows)'),
        ),
      ],
      header: _paneHeader(
        'Squadra di lavoro',
        search,
        'Cerca tecnico',
        onSearch,
      ),
      sections: [
        if (team.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(
              child: Text(
                'Scegli elicottero e privilegi a sinistra.',
                style: TextStyle(color: AppColors.textHint),
              ),
            ),
          )
        else
          for (final p in privileges)
            if (team[p.id] case final selected?)
              _TeamSection(
                title: p.code,
                subtitle: p.name,
                users: eligible[p.id]!,
                query: search,
                selected: selected,
                onChanged: () => setState(() {}),
              ),
      ],
    );
  }

  Widget _buildWorkOrderTab() {
    final from = _workOrderDateFrom;
    final to = _workOrderDateTo;
    final fmt = DateFormat('dd/MM/yyyy');
    return _teamTab(
      helicopterId: _workOrderHelicopterId,
      onHelicopter: (v) => _workOrderHelicopterId = v,
      team: _workOrderTeam,
      search: _workOrderSearch,
      onSearch: (v) => setState(() => _workOrderSearch = v),
      submitLabel: 'Inserisci OL',
      onSubmit: _submitWorkOrder,
      details: [
        OutlinedButton.icon(
          onPressed: _pickWorkOrderRange,
          icon: const Icon(Icons.date_range_outlined),
          label: Text(
            from == null || to == null
                ? 'Periodo Dal – Al'
                : 'Periodo: ${fmt.format(from)} – ${fmt.format(to)} '
                      '(${(to.difference(from).inHours / 24).round() + 1} gg)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _workOrderActivityType,
          decoration: const InputDecoration(
            labelText: 'Tipo attività (opzionale)',
          ),
          isExpanded: true,
          // Voci gestite dagli admin in Opzioni (reference.json).
          items: [
            for (final t in {
              ..._userService.getActivityTypes(),
              ?_workOrderActivityType,
            })
              DropdownMenuItem(
                value: t,
                child: Text(t, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) => setState(() => _workOrderActivityType = value),
        ),
        _field(
          _workOrderMatricolaCtrl,
          'Matricola militare (opzionale)',
          hint: 'es. MM1234',
        ),
        _field(_workOrderNumCarrCtrl, 'Num. carrozzella (opzionale)'),
        _field(_workOrderOrdLavCtrl, 'Ordine di lavoro (opzionale)'),
        _field(_workOrderDescCtrl, 'Descrizione (opzionale)', maxLines: 2),
      ],
    );
  }

  Widget _buildMaintenanceTab() {
    return _teamTab(
      helicopterId: _maintenanceHelicopterId,
      onHelicopter: (v) => _maintenanceHelicopterId = v,
      team: _maintenanceTeam,
      search: _maintenanceUserSearch,
      onSearch: (v) => setState(() => _maintenanceUserSearch = v),
      submitLabel: 'Inserisci come validata',
      onSubmit: _submitMaintenance,
      details: [
        _AdminDateButton(
          label: 'Data attività',
          date: _maintenanceDate,
          onPressed: () =>
              _pickDate((value) => _maintenanceDate = value, _maintenanceDate),
        ),
        _field(_maintenanceDescCtrl, 'Descrizione', maxLines: 2),
        _field(
          _maintenanceMatricolaCtrl,
          'Matricola militare (opzionale)',
          hint: 'es. MM1234',
        ),
        _field(_maintenanceNumCarrCtrl, 'Num. carrozzella (opzionale)'),
        _field(_maintenanceOrdLavCtrl, 'Ordine di lavoro (opzionale)'),
      ],
    );
  }

  Widget _buildSeminarTab() {
    return _TwoPane(
      left: [
        DropdownButtonFormField<String>(
          initialValue: _seminarType,
          decoration: const InputDecoration(labelText: 'Tipo seminario'),
          items: const [
            DropdownMenuItem(value: 'NAM', child: Text('NAM')),
            DropdownMenuItem(value: 'MHF', child: Text('MHF')),
            DropdownMenuItem(value: 'NAM_MHF', child: Text('NAM + MHF')),
          ],
          onChanged: (v) => setState(() => _seminarType = v ?? 'NAM'),
        ),
        const SizedBox(height: 16),
        _AdminDateButton(
          label: 'Data seminario',
          date: _seminarDate,
          onPressed: () =>
              _pickDate((value) => _seminarDate = value, _seminarDate),
        ),
        _field(_seminarDescCtrl, 'Note (opzionale)', maxLines: 2),
        const SizedBox(height: 20),
        Text(
          '${_seminarUserIds.length} '
          '${_seminarUserIds.length == 1 ? 'partecipante' : 'partecipanti'}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _saving ? null : _submitSeminar,
          icon: const Icon(Icons.check),
          label: const Text('Inserisci seminario'),
        ),
      ],
      header: _paneHeader(
        'Partecipanti',
        _seminarUserSearch,
        'Cerca partecipante',
        (v) => setState(() => _seminarUserSearch = v),
      ),
      sections: [
        _TeamSection(
          title: 'Partecipanti',
          users: _users,
          query: _seminarUserSearch,
          selected: _seminarUserIds,
          onChanged: () => setState(() {}),
        ),
      ],
    );
  }

  Future<void> _submitWorkOrder() async {
    final adminId = ref.read(authProvider).userProfile?.id;
    final helicopterId = _workOrderHelicopterId;
    if (adminId == null ||
        helicopterId == null ||
        _teamRows(_workOrderTeam) == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Seleziona elicottero e almeno un tecnico per privilegio.',
          ),
        ),
      );
      return;
    }
    final dateTo = _workOrderDateTo;
    if (_workOrderDateFrom == null || dateTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scegli il periodo Dal – Al.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final desc = _workOrderDescCtrl.text.trim().isEmpty
          ? null
          : _workOrderDescCtrl.text.trim();
      final matricola = _workOrderMatricolaCtrl.text.trim().isEmpty
          ? null
          : _workOrderMatricolaCtrl.text.trim();
      final numCarr = _workOrderNumCarrCtrl.text.trim().isEmpty
          ? null
          : _workOrderNumCarrCtrl.text.trim();
      final ordLav = _workOrderOrdLavCtrl.text.trim().isEmpty
          ? null
          : _workOrderOrdLavCtrl.text.trim();
      for (final MapEntry(key: privilegeId, value: userIds)
          in _workOrderTeam.entries) {
        for (final userId in userIds) {
          await _activityService.addMaintenanceActivityValidated(
            MaintenanceActivity(
              userId: userId,
              helicopterTypeId: helicopterId,
              privilegeTypeId: privilegeId,
              activityDate: dateTo,
              dateFrom: _workOrderDateFrom,
              dateTo: _workOrderDateTo,
              description: desc,
              submittedBy: adminId,
              activityType: _workOrderActivityType,
              matricolaMilitare: matricola,
              numeroCorrozzella: numCarr,
              ordineLavoro: ordLav,
            ),
            adminId,
          );
        }
      }
      if (mounted) {
        setState(() {
          _saving = false;
          _workOrderTeam.clear();
          _workOrderHelicopterId = null;
          _workOrderMatricolaCtrl.clear();
          _workOrderNumCarrCtrl.clear();
          _workOrderOrdLavCtrl.clear();
          _workOrderDescCtrl.clear();
          _workOrderActivityType = null;
          _workOrderDateFrom = null;
          _workOrderDateTo = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ordine di lavoro inserito per tutti i tecnici.'),
          ),
        );
        context.go('/admin/validate');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _submitCrewFlight() async {
    final adminId = ref.read(authProvider).userProfile?.id;
    final helicopterId = _crewFlightHelicopterId;
    final hours = parseHours(_crewFlightHoursCtrl.text);
    if (adminId == null || helicopterId == null || _crewEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compila tutti i campi e aggiungi almeno un membro.'),
        ),
      );
      return;
    }
    if (_crewEntries.any((e) => e.role == 'T' || e.role == 'MTB') &&
        (hours == null || hours <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci le ore di volo per i membri T/MTB.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final desc = _crewFlightDescCtrl.text.trim().isEmpty
          ? null
          : _crewFlightDescCtrl.text.trim();
      for (final entry in _crewEntries) {
        if (entry.role == 'T' || entry.role == 'MTB') {
          await _activityService.addFlightActivityValidated(
            FlightActivity(
              userId: entry.user.id,
              helicopterTypeId: helicopterId,
              activityDate: _crewFlightDate,
              flightHours: hours ?? 0,
              description: desc,
              isPoligono: entry.role == 'MTB' ? _crewFlightIsPoligono : false,
              submittedBy: adminId,
            ),
            adminId,
          );
        } else if (entry.role == 'TOB') {
          if (entry.tobCapabilityId != null) {
            await _activityService.addTobActivityValidated(
              TobActivity(
                userId: entry.user.id,
                helicopterTypeId: helicopterId,
                tobCapabilityId: entry.tobCapabilityId!,
                activityDate: _crewFlightDate,
                description: desc,
                submittedBy: adminId,
              ),
              adminId,
            );
          } else if (hours != null && hours > 0) {
            // Base TOB (no capability): record as a flight activity
            await _activityService.addFlightActivityValidated(
              FlightActivity(
                userId: entry.user.id,
                helicopterTypeId: helicopterId,
                activityDate: _crewFlightDate,
                flightHours: hours,
                description: desc,
                isPoligono: false,
                submittedBy: adminId,
              ),
              adminId,
            );
          }
        }
      }
      if (mounted) {
        setState(() {
          _saving = false;
          _crewEntries.clear();
          _crewFlightHelicopterId = null;
          _crewFlightIsPoligono = false;
          _crewFlightHoursCtrl.clear();
          _crewFlightDescCtrl.clear();
          _crewFlightDate = DateTime.now();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Volo inserito per tutto l\'equipaggio.'),
          ),
        );
        context.go('/admin/validate');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _finish() {
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attività inserita come validata.')),
    );
    context.go('/admin/validate');
  }

  @override
  Widget build(BuildContext context) {
    final tAssignments = _crews.where((item) => item.crewType == 'T').toList();
    final mdbAssignments = _crews
        .where((item) => item.crewType == 'MTB')
        .toList();
    final tobAssignments = _crews
        .where((item) => item.crewType == 'TOB')
        .toList();
    final flightHelicopters = _uniqueCrewHelicopters([
      ...tAssignments,
      ...mdbAssignments,
    ]);
    final tobHelicopters = _uniqueCrewHelicopters(tobAssignments);
    final mdbHelicopterIds = mdbAssignments
        .map((item) => item.helicopterTypeId)
        .toSet();
    final isMdbFlightHelicopter =
        _flightHelicopterId != null &&
        mdbHelicopterIds.contains(_flightHelicopterId);
    final filteredCapabilities = _tobCapabilities
        .where((item) => item.helicopterTypeId == _tobHelicopterId)
        .toList();

    return Scaffold(
      appBar: AppBar(
        leading: const AdminAppBarLeading(),
        title: const Text('Attività'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs
              .map(
                (tab) => Tab(
                  text: switch (tab) {
                    _AdminInsertTabType.workOrder => 'Ordine di Lavoro',
                    _AdminInsertTabType.maintenance => 'Manutenzione',
                    _AdminInsertTabType.seminar => 'Seminario',
                    _AdminInsertTabType.flight => 'Volo',
                    _AdminInsertTabType.tob => 'TOB',
                    _AdminInsertTabType.crewFlight => 'Volo Equipaggio',
                  },
                ),
              )
              .toList(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, _) {
                    final currentTab = _tabs[_tabController.index];
                    final needsUserSelector =
                        currentTab == _AdminInsertTabType.flight ||
                        currentTab == _AdminInsertTabType.tob;
                    if (!needsUserSelector) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedUser?.id,
                        decoration: const InputDecoration(
                          labelText: 'Seleziona utente',
                        ),
                        items: _users
                            .map(
                              (user) => DropdownMenuItem<String>(
                                value: user.id,
                                child: Text(
                                  '${user.fullName} · ${user.numeroLicenza ?? 'N/A'}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          UserProfile? user;
                          for (final item in _users) {
                            if (item.id == value) {
                              user = item;
                              break;
                            }
                          }
                          _selectUser(user);
                        },
                      ),
                    );
                  },
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: _tabs.map((tab) {
                      switch (tab) {
                        case _AdminInsertTabType.workOrder:
                          return _buildWorkOrderTab();
                        case _AdminInsertTabType.crewFlight:
                          final auth = ref.read(authProvider);
                          final tobCaps = auth.tobCapabilityTypes;
                          final allHelicopters = auth.helicopterTypes;
                          final helicopterItems = allHelicopters
                              .map(
                                (h) => DropdownMenuItem<int>(
                                  value: h.id,
                                  child: Text(h.name),
                                ),
                              )
                              .toList(growable: false);
                          return _AdminActivityTab(
                            enabled: true,
                            child: _AdminActivityCard(
                              children: [
                                DropdownButtonFormField<int>(
                                  initialValue: _crewFlightHelicopterId,
                                  menuMaxHeight: 300,
                                  decoration: const InputDecoration(
                                    labelText: 'Elicottero',
                                  ),
                                  items: helicopterItems,
                                  onChanged: (v) => setState(() {
                                    _crewFlightHelicopterId = v;
                                    _crewEntries.clear();
                                    _crewFlightIsPoligono = false;
                                  }),
                                ),
                                const SizedBox(height: 16),
                                _AdminDateButton(
                                  label: 'Data volo',
                                  date: _crewFlightDate,
                                  onPressed: () => _pickDate(
                                    (v) => _crewFlightDate = v,
                                    _crewFlightDate,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                HoursField(
                                  controller: _crewFlightHoursCtrl,
                                  label: 'Ore di volo (per membri T/MTB)',
                                ),
                                if (_crewEntries.any(
                                  (entry) => entry.role == 'MTB',
                                )) ...[
                                  const SizedBox(height: 8),
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text(
                                      'Attività a fuoco (solo membri MTB)',
                                    ),
                                    value: _crewFlightIsPoligono,
                                    onChanged: (value) => setState(
                                      () => _crewFlightIsPoligono =
                                          value ?? false,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _crewFlightDescCtrl,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    labelText: 'Descrizione (opzionale)',
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Text(
                                      'Equipaggio (${_crewEntries.length})',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const Spacer(),
                                    TextButton.icon(
                                      onPressed: () => _addCrewEntry(tobCaps),
                                      icon: const Icon(
                                        Icons.person_add_outlined,
                                      ),
                                      label: const Text('Aggiungi'),
                                    ),
                                  ],
                                ),
                                if (_crewEntries.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      'Nessun membro aggiunto.',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  )
                                else
                                  ...List.generate(_crewEntries.length, (i) {
                                    final entry = _crewEntries[i];
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: CircleAvatar(
                                        child: Text(
                                          entry.role,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                      title: Text(entry.user.fullName),
                                      subtitle: Text(
                                        entry.role == 'TOB'
                                            ? entry.tobCapabilityName != null
                                                  ? 'TOB · ${entry.tobCapabilityName}'
                                                  : 'TOB (base)'
                                            : entry.role == 'MTB'
                                            ? 'MTB · Mitragliere di Bordo'
                                            : 'T · Pilota/Equipaggio',
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                          color: Colors.red,
                                        ),
                                        onPressed: () => setState(
                                          () => _crewEntries.removeAt(i),
                                        ),
                                      ),
                                    );
                                  }),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _saving ? null : _submitCrewFlight,
                                  icon: const Icon(Icons.save_outlined),
                                  label: const Text(
                                    'Inserisci per tutto l\'equipaggio',
                                  ),
                                ),
                              ],
                            ),
                          );
                        case _AdminInsertTabType.maintenance:
                          return _buildMaintenanceTab();
                        case _AdminInsertTabType.seminar:
                          return _buildSeminarTab();
                        case _AdminInsertTabType.flight:
                          return _AdminActivityTab(
                            enabled:
                                _selectedUser != null &&
                                flightHelicopters.isNotEmpty,
                            child: _AdminActivityCard(
                              children: [
                                DropdownButtonFormField<int>(
                                  initialValue:
                                      flightHelicopters.any(
                                        (item) =>
                                            item.id == _flightHelicopterId,
                                      )
                                      ? _flightHelicopterId
                                      : null,
                                  decoration: const InputDecoration(
                                    labelText: 'Elicottero',
                                  ),
                                  items: flightHelicopters
                                      .map(
                                        (item) => DropdownMenuItem<int>(
                                          value: item.id,
                                          child: Text(item.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) => setState(() {
                                    _flightHelicopterId = value;
                                    if (value == null ||
                                        !mdbHelicopterIds.contains(value)) {
                                      _flightIsPoligono = false;
                                    }
                                  }),
                                ),
                                const SizedBox(height: 16),
                                _AdminDateButton(
                                  label: 'Data volo',
                                  date: _flightDate,
                                  onPressed: () => _pickDate(
                                    (value) => _flightDate = value,
                                    _flightDate,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                HoursField(
                                  controller: _flightHoursCtrl,
                                  label: 'Ore di volo',
                                ),
                                if (isMdbFlightHelicopter) ...[
                                  const SizedBox(height: 8),
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text(
                                      'Attività a fuoco (Poligono)',
                                    ),
                                    value: _flightIsPoligono,
                                    onChanged: (value) => setState(
                                      () => _flightIsPoligono = value ?? false,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _flightDescCtrl,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: 'Descrizione',
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: _saving ? null : _submitFlight,
                                  child: const Text('Inserisci come validata'),
                                ),
                              ],
                            ),
                          );
                        case _AdminInsertTabType.tob:
                          return _AdminActivityTab(
                            enabled:
                                _selectedUser != null &&
                                tobHelicopters.isNotEmpty,
                            child: _AdminActivityCard(
                              children: [
                                DropdownButtonFormField<int>(
                                  initialValue:
                                      tobHelicopters.any(
                                        (item) => item.id == _tobHelicopterId,
                                      )
                                      ? _tobHelicopterId
                                      : null,
                                  decoration: const InputDecoration(
                                    labelText: 'Elicottero',
                                  ),
                                  items: tobHelicopters
                                      .map(
                                        (item) => DropdownMenuItem<int>(
                                          value: item.id,
                                          child: Text(item.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => _tobHelicopterId = value),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<int>(
                                  initialValue:
                                      filteredCapabilities.any(
                                        (item) =>
                                            item.tobCapabilityId ==
                                            _tobCapabilityId,
                                      )
                                      ? _tobCapabilityId
                                      : null,
                                  decoration: const InputDecoration(
                                    labelText: 'Capacità TOB',
                                  ),
                                  items: filteredCapabilities
                                      .map(
                                        (item) => DropdownMenuItem<int>(
                                          value: item.tobCapabilityId,
                                          child: Text(item.capabilityName),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => _tobCapabilityId = value),
                                ),
                                const SizedBox(height: 16),
                                _AdminDateButton(
                                  label: 'Data attività TOB',
                                  date: _tobDate,
                                  onPressed: () => _pickDate(
                                    (value) => _tobDate = value,
                                    _tobDate,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _tobDescCtrl,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: 'Descrizione',
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: _saving ? null : _submitTob,
                                  child: const Text('Inserisci come validata'),
                                ),
                              ],
                            ),
                          );
                      }
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }

  List<_ActivityHelicopterOption> _uniqueCrewHelicopters(
    List<UserCrewAssignment> assignments,
  ) {
    final map = <int, _ActivityHelicopterOption>{};
    for (final assignment in assignments) {
      map[assignment.helicopterTypeId] = _ActivityHelicopterOption(
        id: assignment.helicopterTypeId,
        code: assignment.helicopterCode,
        name: assignment.helicopterName,
      );
    }
    return map.values.toList();
  }
}

class _ActivityHelicopterOption {
  const _ActivityHelicopterOption({
    required this.id,
    required this.code,
    required this.name,
  });

  final int id;
  final String code;
  final String name;
}

class _CrewEntry {
  const _CrewEntry({
    required this.user,
    required this.role,
    this.tobCapabilityId,
    this.tobCapabilityName,
  });

  final UserProfile user;
  final String role;
  final int? tobCapabilityId;
  final String? tobCapabilityName;
}

class _AdminActivityTab extends StatelessWidget {
  const _AdminActivityTab({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return const Center(
        child: Text('Seleziona un utente con le abilitazioni richieste.'),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }
}

class _AdminActivityCard extends StatelessWidget {
  const _AdminActivityCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: children),
          ),
        ),
      ),
    );
  }
}

class _AdminDateButton extends StatelessWidget {
  const _AdminDateButton({
    required this.label,
    this.date,
    required this.onPressed,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.calendar_today_outlined),
      label: Text(
        date != null
            ? '$label: ${DateFormat('dd/MM/yyyy').format(date!)}'
            : label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Desktop: colonna fissa a sinistra + sezioni scorrevoli a destra.
/// Sotto i 900 px tutto in un'unica colonna.
class _TwoPane extends StatelessWidget {
  const _TwoPane({
    required this.left,
    required this.header,
    required this.sections,
  });

  final List<Widget> left;
  final Widget header;
  final List<Widget> sections;

  @override
  Widget build(BuildContext context) {
    final leftCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: left,
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              leftCard,
              const SizedBox(height: 16),
              header,
              const SizedBox(height: 12),
              ...sections,
            ],
          );
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 400,
                child: SingleChildScrollView(child: leftCard),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    header,
                    const SizedBox(height: 12),
                    Expanded(child: ListView(children: sections)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TeamSection extends StatelessWidget {
  const _TeamSection({
    required this.title,
    this.subtitle,
    required this.users,
    required this.query,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final List<UserProfile> users;
  final String query;
  // modificato in place, poi onChanged
  final Set<String> selected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final visible = q.isEmpty
        ? users
        : users.where((u) => u.fullName.toLowerCase().contains(q)).toList();
    final allVisible =
        visible.isNotEmpty && visible.every((u) => selected.contains(u.id));
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (subtitle != null)
                          TextSpan(
                            text: '   $subtitle',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${selected.length}/${users.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected.isEmpty
                        ? AppColors.textHint
                        : AppColors.accentGlow,
                  ),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: visible.isEmpty
                      ? null
                      : () {
                          final ids = visible.map((u) => u.id);
                          if (allVisible) {
                            selected.removeAll(ids);
                          } else {
                            selected.addAll(ids);
                          }
                          onChanged();
                        },
                  child: Text(allVisible ? 'Nessuno' : 'Tutti'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (visible.isEmpty)
              const Text(
                'Nessuno corrisponde alla ricerca.',
                style: TextStyle(color: AppColors.textHint),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final u in visible)
                    _TechTile(
                      user: u,
                      selected: selected.contains(u.id),
                      onTap: () {
                        if (!selected.remove(u.id)) selected.add(u.id);
                        onChanged();
                      },
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TechTile extends StatelessWidget {
  const _TechTile({
    required this.user,
    required this.selected,
    required this.onTap,
  });

  final UserProfile user;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: SizedBox(
        width: 210,
        child: Material(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.22)
              : AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: selected ? AppColors.accentGlow : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 44,
                    child: UserAvatar.fill(user: user),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          user.cognome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (user.orgUnitName.isNotEmpty)
                          Text(
                            user.orgUnitName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textHint,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    size: 20,
                    color: selected ? AppColors.accentGlow : AppColors.textHint,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
