import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../constants/app_constants.dart';
import '../../app.dart';
import '../../models/activity_models.dart';
import '../../services/activity_service.dart';
import '../../services/hours_format.dart';
import '../../widgets/admin_app_bar_leading.dart';
import '../../widgets/activity_edit_dialog.dart';
import '../../widgets/app_dropdown.dart';

class ValidateActivitiesScreen extends ConsumerStatefulWidget {
  const ValidateActivitiesScreen({super.key});

  @override
  ConsumerState<ValidateActivitiesScreen> createState() =>
      _ValidateActivitiesScreenState();
}

enum _ValidationTabType { maintenance, seminar, flight, tob }

class _ValidateActivitiesScreenState
    extends ConsumerState<ValidateActivitiesScreen>
    with SingleTickerProviderStateMixin {
  final _service = ActivityService();

  late final TabController _tabController;
  late final List<_ValidationTabType> _tabs;
  bool _loading = true;
  List<MaintenanceActivity> _maintenance = [];
  List<SeminarActivity> _seminars = [];
  List<FlightActivity> _flight = [];
  List<TobActivity> _tob = [];

  String get _adminId => ref.read(authProvider).userProfile!.id;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider);
    if (auth.isAdminPriv) {
      _tabs = const [
        _ValidationTabType.maintenance,
        _ValidationTabType.seminar,
      ];
    } else if (auth.isAdminCrew) {
      _tabs = const [_ValidationTabType.flight, _ValidationTabType.tob];
    } else {
      _tabs = const [
        _ValidationTabType.maintenance,
        _ValidationTabType.seminar,
        _ValidationTabType.flight,
        _ValidationTabType.tob,
      ];
    }
    _tabController = TabController(length: _tabs.length, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final maintenance = _tabs.contains(_ValidationTabType.maintenance)
        ? await _service.getPendingMaintenanceActivities()
        : <MaintenanceActivity>[];
    final seminars = _tabs.contains(_ValidationTabType.seminar)
        ? await _service.getPendingSeminarActivities()
        : <SeminarActivity>[];
    final flight = _tabs.contains(_ValidationTabType.flight)
        ? await _service.getPendingFlightActivities()
        : <FlightActivity>[];
    final tob = _tabs.contains(_ValidationTabType.tob)
        ? await _service.getPendingTobActivities()
        : <TobActivity>[];
    if (!mounted) {
      return;
    }
    setState(() {
      _maintenance = maintenance;
      _seminars = seminars;
      _flight = flight;
      _tob = tob;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AdminAppBarLeading(),
        title: const Text('Valida Attività'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: MediaQuery.of(context).size.width < 420,
          tabAlignment: MediaQuery.of(context).size.width < 420
              ? TabAlignment.start
              : null,
          tabs: _tabs
              .map(
                (tab) => Tab(
                  text: switch (tab) {
                    _ValidationTabType.maintenance =>
                      'Manutenzione (${_maintenance.length})',
                    _ValidationTabType.seminar =>
                      'Seminari (${_seminars.length})',
                    _ValidationTabType.flight => 'Volo (${_flight.length})',
                    _ValidationTabType.tob => 'TOB (${_tob.length})',
                  },
                ),
              )
              .toList(),
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: _tabs.map(_buildTabContent).toList(),
            ),
    );
  }

  Widget _buildTabContent(_ValidationTabType tab) {
    switch (tab) {
      case _ValidationTabType.maintenance:
        return _ValidationTable<MaintenanceActivity>(
          items: _maintenance,
          detailLabel: 'Privilegio',
          row: (i) => (
            i.userFullName,
            i.helicopterCode,
            i.privilegeName,
            i.description,
            i.activityDate,
          ),
          validate: (i) =>
              _service.validateMaintenanceActivity(i.id!, _adminId),
          reject: (i, r) =>
              _service.rejectMaintenanceActivity(i.id!, reason: r),
          edit: editMaintenanceActivity,
          onDone: _load,
        );
      case _ValidationTabType.seminar:
        return _ValidationTable<SeminarActivity>(
          items: _seminars,
          detailLabel: 'Seminario',
          row: (i) =>
              (i.userFullName, '', i.seminarType, i.description, i.seminarDate),
          validate: (i) => _service.validateSeminarActivity(i.id!, _adminId),
          reject: (i, r) => _service.rejectSeminarActivity(i.id!, reason: r),
          edit: editSeminarActivity,
          onDone: _load,
        );
      case _ValidationTabType.flight:
        return _ValidationTable<FlightActivity>(
          items: _flight,
          detailLabel: 'Ore',
          row: (i) => (
            i.userFullName,
            i.helicopterCode,
            '${formatHours(i.flightHours)} h',
            i.description,
            i.activityDate,
          ),
          validate: (i) => _service.validateFlightActivity(i.id!, _adminId),
          reject: (i, r) => _service.rejectFlightActivity(i.id!, reason: r),
          edit: editFlightActivity,
          onDone: _load,
        );
      case _ValidationTabType.tob:
        return _ValidationTable<TobActivity>(
          items: _tob,
          detailLabel: 'Capacità',
          row: (i) => (
            i.userFullName,
            i.helicopterCode,
            i.capabilityName,
            i.description,
            i.activityDate,
          ),
          validate: (i) => _service.validateTobActivity(i.id!, _adminId),
          reject: (i, r) => _service.rejectTobActivity(i.id!, reason: r),
          edit: editTobActivity,
          onDone: _load,
        );
    }
  }
}

/// Utente, elicottero ('' = nessuno), dettaglio, note, data.
typedef _Row = (String, String, String, String?, DateTime);

/// Tabella densa da PC: selezione multipla, filtri utente/elicottero,
/// azioni per riga e sulle selezionate.
class _ValidationTable<T> extends StatefulWidget {
  const _ValidationTable({
    required this.items,
    required this.detailLabel,
    required this.row,
    required this.validate,
    required this.reject,
    required this.edit,
    required this.onDone,
  });

  final List<T> items;
  final String detailLabel;
  final _Row Function(T item) row;
  final Future<void> Function(T item) validate;
  final Future<void> Function(T item, String? reason) reject;
  final Future<bool> Function(BuildContext context, T item) edit;
  final Future<void> Function() onDone;

  @override
  State<_ValidationTable<T>> createState() => _ValidationTableState<T>();
}

class _ValidationTableState<T> extends State<_ValidationTable<T>> {
  static final _fmt = DateFormat('dd/MM/yyyy');
  final Set<T> _selected = {};
  String? _user;
  String? _heli;
  bool _busy = false;

  @override
  void didUpdateWidget(covariant _ValidationTable<T> old) {
    super.didUpdateWidget(old);
    // dopo il ricaricamento gli oggetti sono nuovi
    if (old.items != widget.items) _selected.clear();
  }

  List<T> get _visible => widget.items.where((i) {
    final r = widget.row(i);
    return (_user == null || r.$1 == _user) && (_heli == null || r.$2 == _heli);
  }).toList();

  Future<void> _run(
    List<T> items,
    Future<void> Function(T) action,
    String done,
  ) async {
    setState(() => _busy = true);
    try {
      for (final item in items) {
        await action(item);
      }
      await widget.onDone();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${items.length} $done.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(T item) async {
    try {
      if (await widget.edit(context, item)) await widget.onDone();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  // Rifiutare cancella l'attività: conferma + motivo opzionale nella notifica
  Future<void> _confirmReject(List<T> items) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          items.length == 1
              ? "Rifiutare l'attività?"
              : 'Rifiutare ${items.length} attività?',
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (items.length == 1) ...[
                Text(widget.row(items.first).$1),
                const SizedBox(height: 4),
              ],
              const Text(
                'Le attività vengono eliminate e il tecnico riceve una notifica.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                autofocus: true,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Motivo (facoltativo)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.currencyExpired,
            ),
            child: const Text('Rifiuta'),
          ),
        ],
      ),
    );
    final reason = reasonCtrl.text;
    reasonCtrl.dispose();
    if (ok == true) {
      await _run(items, (i) => widget.reject(i, reason), 'attività rifiutate');
    }
  }

  Widget _filter(
    String label,
    String? value,
    Set<String> options,
    ValueChanged<String?> onChanged,
  ) => SizedBox(
    width: 260,
    child: AppDropdown<String?>(
      key: ValueKey('$label$value${options.length}'),
      initialValue: value,
      isDense: true,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: [
        const DropdownMenuItem(value: null, child: Text('Tutti')),
        for (final o in options.toList()..sort())
          DropdownMenuItem(
            value: o,
            child: Text(o, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const Center(child: Text('Nessuna attività in attesa.'));
    }
    final visible = _visible;
    final selected = visible.where(_selected.contains).toList();
    final rows = widget.items.map(widget.row);
    final helis = rows.map((r) => r.$2).where((h) => h.isNotEmpty).toSet();
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _filter(
                'Utente',
                _user,
                rows.map((r) => r.$1).toSet(),
                (v) => setState(() => _user = v),
              ),
              if (helis.isNotEmpty)
                _filter(
                  'Elicottero',
                  _heli,
                  helis,
                  (v) => setState(() => _heli = v),
                ),
              FilledButton.icon(
                onPressed: _busy || selected.isEmpty
                    ? null
                    : () =>
                          _run(selected, widget.validate, 'attività validate'),
                icon: const Icon(Icons.done_all),
                label: Text('Valida selezionate (${selected.length})'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _busy || selected.isEmpty
                    ? null
                    : () => _confirmReject(selected),
                icon: const Icon(Icons.close),
                label: Text('Rifiuta selezionate (${selected.length})'),
              ),
            ],
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowHeight: 40,
                    dataRowMinHeight: 36,
                    dataRowMaxHeight: double.infinity,
                    columnSpacing: 20,
                    horizontalMargin: 16,
                    onSelectAll: (v) => setState(
                      () => v == true
                          ? _selected.addAll(visible)
                          : _selected.removeAll(visible),
                    ),
                    columns: [
                      const DataColumn(label: Text('Data')),
                      const DataColumn(label: Text('Utente')),
                      if (helis.isNotEmpty)
                        const DataColumn(label: Text('Elicottero')),
                      DataColumn(label: Text(widget.detailLabel)),
                      const DataColumn(label: Text('Note')),
                      const DataColumn(label: Text('')),
                    ],
                    rows: [
                      for (final item in visible)
                        _dataRow(
                          item,
                          widget.row(item),
                          helis.isNotEmpty,
                          muted,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  DataRow _dataRow(T item, _Row r, bool showHeli, Color muted) => DataRow(
    selected: _selected.contains(item),
    onSelectChanged: (v) => setState(
      () => v == true ? _selected.add(item) : _selected.remove(item),
    ),
    cells: [
      DataCell(Text(_fmt.format(r.$5))),
      DataCell(Text(r.$1, overflow: TextOverflow.ellipsis)),
      if (showHeli) DataCell(Text(r.$2)),
      DataCell(
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Text(r.$3),
        ),
      ),
      DataCell(
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: (r.$4 ?? '').trim().isEmpty
                ? Text('—', style: TextStyle(color: muted))
                : Text(r.$4!.trim()),
          ),
        ),
      ),
      DataCell(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Valida',
              color: Colors.green.shade600,
              icon: const Icon(Icons.check_circle_outline),
              onPressed: _busy
                  ? null
                  : () => _run([item], widget.validate, 'attività validate'),
            ),
            IconButton(
              tooltip: 'Modifica',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _busy ? null : () => _edit(item),
            ),
            IconButton(
              tooltip: 'Rifiuta',
              color: AppColors.currencyExpired,
              icon: const Icon(Icons.cancel_outlined),
              onPressed: _busy ? null : () => _confirmReject([item]),
            ),
          ],
        ),
      ),
    ],
  );
}
