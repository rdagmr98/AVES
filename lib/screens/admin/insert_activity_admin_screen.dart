import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../widgets/app_dropdown.dart';
import '../../widgets/date_range_dialog.dart';
import '../../app.dart';
import '../../constants/app_constants.dart';
import '../../models/activity_models.dart';
import '../../models/user_models.dart';
import '../../services/activity_service.dart';
import '../../services/currency_history.dart';
import '../../services/currency_service.dart';
import '../../services/gh_db_service.dart';
import '../../services/hours_format.dart';
import '../../services/user_service.dart';
import '../../widgets/admin_app_bar_leading.dart';
import '../../widgets/currency_badge_widget.dart';
import '../../widgets/filter_panel.dart';
import '../../widgets/hours_field.dart';
import '../../widgets/user_avatar.dart';

class InsertActivityAdminScreen extends ConsumerStatefulWidget {
  const InsertActivityAdminScreen({super.key});

  @override
  ConsumerState<InsertActivityAdminScreen> createState() =>
      _InsertActivityAdminScreenState();
}

enum _AdminInsertTabType { workOrder, maintenance, seminar, crewFlight }

class _InsertActivityAdminScreenState
    extends ConsumerState<InsertActivityAdminScreen>
    with SingleTickerProviderStateMixin {
  final _activityService = ActivityService();
  final _userService = UserService();
  final _currencyService = CurrencyService();
  int _periodDays = 180;
  // squadra: false = scadenza più vicina in cima (predefinito), true = A-Z
  bool _sortByName = false;
  final _maintenanceDescCtrl = TextEditingController();
  final _maintenanceMatricolaCtrl = TextEditingController();
  final _maintenanceNumCarrCtrl = TextEditingController();
  final _maintenanceOrdLavCtrl = TextEditingController();
  final _seminarDescCtrl = TextEditingController();
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

  int? _maintenanceHelicopterId;
  // privilegio -> tecnici selezionati
  final Map<int, Set<String>> _maintenanceTeam = {};
  String _maintenanceUserSearch = '';
  DateTime _maintenanceDate = DateTime.now();

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
  // persona -> ruolo nel volo: 'T', 'MTB', 'TOB' (volo base) o 'TOB:<capacità>'
  final Map<String, String> _crewPick = {};
  String _crewSearch = '';

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
      _tabs = const [_AdminInsertTabType.crewFlight];
    } else {
      _tabs = const [
        _AdminInsertTabType.maintenance,
        _AdminInsertTabType.seminar,
        _AdminInsertTabType.crewFlight,
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
    _seminarDescCtrl.dispose();
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
    final criteria = await _currencyService.getMaintenanceCriteria();
    final auth = ref.read(authProvider);
    if (!mounted) {
      return;
    }
    setState(() {
      _periodDays = criteria?.periodDays ?? 180;
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

  Future<void> _pickDate(ValueSetter<DateTime> onSet, DateTime current) async {
    final picked = await showDateDialog(
      context,
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

  Future<void> _pickWorkOrderRange() async {
    final from = _workOrderDateFrom;
    final to = _workOrderDateTo;
    final picked = await showDateRangeDialog(
      context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: from != null && to != null
          ? DateTimeRange(start: from, end: to)
          : null,
    );
    if (picked != null) {
      setState(() {
        _workOrderDateFrom = picked.start;
        _workOrderDateTo = picked.end;
      });
    }
  }

  /// Tecnici abilitati per privilegio sull'elicottero, ordinati per scadenza
  /// del privilegio più vicina (mai svolto = scaduto, in cima) o per nome.
  /// Riempie [expiry] (privilegio -> tecnico -> scadenza) per i riquadri.
  Map<int, List<UserProfile>> _eligibleTechs(
    int helicopterId,
    Map<int, Map<String, DateTime?>> expiry,
  ) {
    final byId = {for (final u in _users) u.id: u};
    final result = <int, List<UserProfile>>{};
    for (final p in GhDbService().privileges) {
      if (p['helicopter_type_id'] != helicopterId || p['active'] == false) {
        continue;
      }
      final user = byId[p['user_id']];
      if (user == null) continue;
      final privId = p['privilege_type_id'] as int;
      final list = result.putIfAbsent(privId, () => []);
      if (!list.contains(user)) list.add(user);
      final last = _currencyService.lastMaintenanceDate(
        user.id,
        helicopterId,
        privId,
        licenseTypeId: p['license_type_id'] as int?,
      );
      final exp = last == null ? null : maintenanceExpiry(last, _periodDays);
      // Più categorie (B1.3, B2): conta quella che scade prima (null = mai).
      final m = expiry[privId] ??= {};
      final prev = m[user.id];
      if (!m.containsKey(user.id) ||
          (prev != null && (exp == null || exp.isBefore(prev)))) {
        m[user.id] = exp;
      }
    }
    for (final MapEntry(key: privId, value: users) in result.entries) {
      _sortUsers(users, expiry[privId]!);
    }
    return result;
  }

  void _sortUsers(List<UserProfile> users, Map<String, DateTime?> expiry) =>
      _sortByName
      ? users.sort((a, b) => a.fullName.compareTo(b.fullName))
      : sortByExpiry(users, expiry);

  Widget _sortToggle() => SegmentedButton<bool>(
    showSelectedIcon: false,
    style: const ButtonStyle(visualDensity: VisualDensity.compact),
    segments: const [
      ButtonSegment(
        value: false,
        icon: Icon(Icons.event_busy, size: 18),
        label: Text('Scadenza'),
        tooltip: 'Prima chi scade prima',
      ),
      ButtonSegment(
        value: true,
        icon: Icon(Icons.sort_by_alpha, size: 18),
        label: Text('A-Z'),
        tooltip: 'Ordine alfabetico',
      ),
    ],
    selected: {_sortByName},
    onSelectionChanged: (v) => setState(() => _sortByName = v.first),
  );

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
    ValueChanged<String> onSearch, {
    Widget? trailing,
  }) {
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
        if (trailing != null) ...[trailing, const SizedBox(width: 12)],
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
    final expiry = <int, Map<String, DateTime?>>{};
    final eligible = helicopterId == null
        ? const <int, List<UserProfile>>{}
        : _eligibleTechs(helicopterId, expiry);
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
        AppDropdown<int>(
          initialValue: helicopterId,
          decoration: const InputDecoration(labelText: 'Elicottero'),
          items: [
            for (final h in auth.visibleHelicopters(keep: helicopterId))
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
        trailing: _sortToggle(),
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
                expiry: expiry[p.id],
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
        AppDropdown<String>(
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
    final expiry = seminarExpiries(GhDbService().seminars);
    final users = [..._users];
    _sortUsers(users, expiry);
    return _TwoPane(
      left: [
        AppDropdown<String>(
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
        trailing: _sortToggle(),
      ),
      sections: [
        _TeamSection(
          title: 'Partecipanti',
          subtitle: 'scadenza seminario',
          users: users,
          expiry: expiry,
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
    if (adminId == null || helicopterId == null || _crewPick.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scegli elicottero ed equipaggio.')),
      );
      return;
    }
    // Le ore valgono per tutti: anche i TOB le sommano al semestre T.
    if (hours == null || hours <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci le ore di volo.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final desc = _crewFlightDescCtrl.text.trim().isEmpty
          ? null
          : _crewFlightDescCtrl.text.trim();
      for (final MapEntry(key: userId, value: role) in _crewPick.entries) {
        if (role.startsWith('TOB')) {
          await _activityService.addTobActivityValidated(
            TobActivity(
              userId: userId,
              helicopterTypeId: helicopterId,
              tobCapabilityId: role == 'TOB'
                  ? null
                  : int.parse(role.substring(4)),
              activityDate: _crewFlightDate,
              flightHours: hours,
              description: desc,
              submittedBy: adminId,
            ),
            adminId,
          );
        } else {
          // T e MTB.
          await _activityService.addFlightActivityValidated(
            FlightActivity(
              userId: userId,
              helicopterTypeId: helicopterId,
              activityDate: _crewFlightDate,
              flightHours: hours,
              description: desc,
              isPoligono: role == 'MTB' && _crewFlightIsPoligono,
              submittedBy: adminId,
            ),
            adminId,
          );
        }
      }
      if (mounted) {
        setState(() {
          _saving = false;
          _crewPick.clear();
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

  /// Equipaggio abilitato sull'elicottero, un gruppo per ruolo: T (anche
  /// dalla famiglia 169), MTB, TOB volo base e una per capacità TOB.
  /// Record: (chiave in [_crewPick], titolo, sottotitolo, persone).
  List<(String, String, String, List<UserProfile>)> _crewGroups(int heli) {
    final db = GhDbService();
    final byId = {for (final u in _users) u.id: u};
    final family = _userService.tFamilyOf(heli);
    final rows = db.crew.where((r) => r['active'] != false).toList();
    final onHeli = {
      for (final r in rows)
        if (r['helicopter_type_id'] == heli) r['user_id'],
    };
    List<UserProfile> people(bool Function(Map<String, dynamic>) test) => [
      for (final id in {
        for (final r in rows)
          if (test(r)) r['user_id'] as String,
      })
        ?byId[id],
    ]..sort((a, b) => a.cognome.compareTo(b.cognome));
    bool on(Map<String, dynamic> r, String type) =>
        r['crew_type'] == type && r['helicopter_type_id'] == heli;
    final caps = db.tobUserCaps.where(
      (c) => c['active'] != false && c['helicopter_type_id'] == heli,
    );
    return [
      (
        'T',
        'T',
        '',
        people(
          (r) =>
              on(r, 'T') ||
              // T sul gemello 169 senza righe su questo elicottero.
              (r['crew_type'] == 'T' &&
                  family.contains(r['helicopter_type_id']) &&
                  !onHeli.contains(r['user_id'])),
        ),
      ),
      ('MTB', 'MTB', 'Mitragliere di bordo', people((r) => on(r, 'MTB'))),
      ('TOB', 'TOB', 'volo base', people((r) => on(r, 'TOB'))),
      for (final cap in ref.read(authProvider).tobCapabilityTypes)
        (
          'TOB:${cap.id}',
          'TOB',
          cap.name,
          [
            for (final id in {
              for (final c in caps)
                if (c['tob_capability_id'] == cap.id) c['user_id'] as String,
            })
              ?byId[id],
          ]..sort((a, b) => a.cognome.compareTo(b.cognome)),
        ),
    ].where((g) => g.$4.isNotEmpty).toList();
  }

  Widget _buildCrewFlightTab() {
    final heli = _crewFlightHelicopterId;
    final groups = heli == null
        ? const <(String, String, String, List<UserProfile>)>[]
        : _crewGroups(heli);
    final labels = {
      for (final (key, title, sub, _) in groups)
        key: sub.isEmpty ? title : '$title · $sub',
    };
    final byId = {for (final u in _users) u.id: u};
    final members = [for (final id in _crewPick.keys) ?byId[id]]
      ..sort((a, b) => a.cognome.compareTo(b.cognome));
    final n = members.length;
    return _TwoPane(
      left: [
        AppDropdown<int>(
          initialValue: heli,
          decoration: const InputDecoration(labelText: 'Elicottero'),
          items: [
            for (final h
                in ref.read(authProvider).visibleHelicopters(keep: heli))
              DropdownMenuItem(value: h.id, child: Text(h.name)),
          ],
          onChanged: (v) => setState(() {
            _crewFlightHelicopterId = v;
            _crewPick.clear();
            _crewFlightIsPoligono = false;
          }),
        ),
        const SizedBox(height: 16),
        _AdminDateButton(
          label: 'Data volo',
          date: _crewFlightDate,
          onPressed: () =>
              _pickDate((v) => _crewFlightDate = v, _crewFlightDate),
        ),
        const SizedBox(height: 16),
        HoursField(controller: _crewFlightHoursCtrl, label: 'Ore di volo'),
        if (_crewPick.containsValue('MTB'))
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Attività a fuoco (solo MTB)'),
            value: _crewFlightIsPoligono,
            onChanged: (v) =>
                setState(() => _crewFlightIsPoligono = v ?? false),
          ),
        _field(_crewFlightDescCtrl, 'Descrizione (opzionale)', maxLines: 2),
        const SizedBox(height: 20),
        Text(
          '$n ${n == 1 ? 'membro' : 'membri'} di equipaggio',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        for (final u in members)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${u.fullName}: ${labels[_crewPick[u.id]] ?? ''}',
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
          onPressed: _saving ? null : _submitCrewFlight,
          icon: const Icon(Icons.check),
          label: Text('Inserisci volo ($n)'),
        ),
      ],
      header: _paneHeader(
        'Equipaggio',
        _crewSearch,
        'Cerca persona',
        (v) => setState(() => _crewSearch = v),
      ),
      sections: [
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Center(
              child: Text(
                heli == null
                    ? 'Scegli l\'elicottero a sinistra.'
                    : 'Nessun equipaggio abilitato su questo elicottero.',
                style: const TextStyle(color: AppColors.textHint),
              ),
            ),
          )
        else
          for (final (key, title, sub, users) in groups)
            _TeamSection(
              title: title,
              subtitle: sub.isEmpty ? null : sub,
              users: users,
              query: _crewSearch,
              selected: {
                for (final e in _crewPick.entries)
                  if (e.value == key) e.key,
              },
              onChanged: () => setState(() {}),
              // Un solo ruolo per persona: scegliendolo qui si sposta.
              onToggle: (id) => setState(() {
                if (_crewPick[id] == key) {
                  _crewPick.remove(id);
                } else {
                  _crewPick[id] = key;
                }
              }),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AdminAppBarLeading(),
        title: const Text('Attività'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            for (final tab in _tabs)
              Tab(
                text: switch (tab) {
                  _AdminInsertTabType.workOrder => 'Ordine di Lavoro',
                  _AdminInsertTabType.maintenance => 'Manutenzione',
                  _AdminInsertTabType.seminar => 'Seminario',
                  _AdminInsertTabType.crewFlight => 'Volo',
                },
              ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                for (final tab in _tabs)
                  switch (tab) {
                    _AdminInsertTabType.workOrder => _buildWorkOrderTab(),
                    _AdminInsertTabType.maintenance => _buildMaintenanceTab(),
                    _AdminInsertTabType.seminar => _buildSeminarTab(),
                    _AdminInsertTabType.crewFlight => _buildCrewFlightTab(),
                  },
              ],
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
    this.expiry,
    required this.query,
    required this.selected,
    required this.onChanged,
    this.onToggle,
  });

  final String title;
  final String? subtitle;
  final List<UserProfile> users;
  // tecnico -> scadenza del privilegio (null = mai svolto); assente = non mostrata
  final Map<String, DateTime?>? expiry;
  final String query;
  // modificato in place, poi onChanged
  final Set<String> selected;
  final VoidCallback onChanged;
  // se presente: tocco = onToggle(id), niente «Tutti» (equipaggio di volo)
  final ValueSetter<String>? onToggle;

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
                if (onToggle == null)
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
                      expiry: expiry == null
                          ? null
                          : expiryBadge(expiry![u.id]),
                      selected: selected.contains(u.id),
                      onTap: onToggle != null
                          ? () => onToggle!(u.id)
                          : () {
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
    this.expiry,
    required this.selected,
    required this.onTap,
  });

  final UserProfile user;
  final (String, Color)? expiry;
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
                        if (expiry case (final text, final color))
                          Text(
                            text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: color,
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
