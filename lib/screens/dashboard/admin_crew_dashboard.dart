import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../constants/app_constants.dart';
import '../../models/activity_models.dart';
import '../../models/user_models.dart';
import '../../services/activity_service.dart';
import '../../services/currency_service.dart';
import '../../services/report_service.dart';
import '../../services/user_service.dart';
import '../../widgets/currency_badge_widget.dart';

class AdminCrewDashboard extends ConsumerStatefulWidget {
  const AdminCrewDashboard({super.key});

  @override
  ConsumerState<AdminCrewDashboard> createState() => _AdminCrewDashboardState();
}

class _AdminCrewDashboardState extends ConsumerState<AdminCrewDashboard> {
  final _userService = UserService();
  final _activityService = ActivityService();
  final _currencyService = CurrencyService();
  final _reportService = ReportService();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  int _pendingActivities = 0;
  List<_CrewUserRow> _rows = [];
  String _search = '';
  int? _orgUnitId;
  String _crewTypeFilter = 'all';
  int? _tobCapabilityId;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final users = await _userService.getAllUsers();
    final pendingFlight = await _activityService.getPendingFlightActivities();
    final pendingTob = await _activityService.getPendingTobActivities();
    final rows = <_CrewUserRow>[];

    for (final user in users.where((item) => item.isApproved)) {
      final assignments = await _userService.getUserCrewAssignments(user.id);
      if (assignments.isEmpty) {
        continue;
      }
      final tobCapabilities = await _userService.getUserTobCapabilities(user.id);
      CurrencyStatus? flightStatus;
      if (assignments.any((item) => item.crewType == 'T')) {
        flightStatus = await _currencyService.getFlightCurrency(user.id);
      }
      final tobStatuses = <int, CurrencyStatus>{};
      for (final capability in tobCapabilities) {
        tobStatuses[capability.tobCapabilityId] =
            await _currencyService.getTobCapabilityCurrencyStatus(
              user.id,
              capability.tobCapabilityId,
              capability.capabilityName,
            );
      }
      rows.add(
        _CrewUserRow(
          user: user,
          assignments: assignments,
          tobCapabilities: tobCapabilities,
          flightStatus: flightStatus,
          tobStatuses: tobStatuses,
        ),
      );
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _pendingActivities = pendingFlight.length + pendingTob.length;
      _rows = rows;
      _loading = false;
    });
  }

  List<_CrewUserRow> _filteredRows() {
    return _rows.where((row) {
      final search = _search.trim().toLowerCase();
      final matchesSearch =
          search.isEmpty ||
          row.user.fullName.toLowerCase().contains(search) ||
          (row.user.numeroLicenza ?? '').toLowerCase().contains(search);
      final matchesOrg = _orgUnitId == null || row.user.orgUnitId == _orgUnitId;
      final matchesCrewType = switch (_crewTypeFilter) {
        'T' => row.hasTCrew,
        'TOB' => row.hasTobCrew,
        _ => true,
      };
      final matchesCapability =
          _tobCapabilityId == null ||
          row.tobCapabilities.any((item) => item.tobCapabilityId == _tobCapabilityId);
      final statuses = row.relevantStatuses(_crewTypeFilter, _tobCapabilityId);
      final matchesStatus = switch (_statusFilter) {
        'valid' => statuses.any((item) => item.isValid),
        'warning' => statuses.any((item) => item.isWarning),
        'expired' => statuses.any((item) => item.isExpired),
        _ => true,
      };
      return matchesSearch &&
          matchesOrg &&
          matchesCrewType &&
          matchesCapability &&
          matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final filteredRows = _filteredRows();
    final tCrewCount = _rows.where((row) => row.hasTCrew).length;
    final tobCrewCount = _rows.where((row) => row.hasTobCrew).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Admin Volo'),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: () async {
              await ref.read(authProvider).signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _CrewStatCard(
                        title: 'Attività volo/TOB in attesa',
                        value: '$_pendingActivities',
                        icon: Icons.pending_actions,
                      ),
                      _CrewStatCard(
                        title: 'Equipaggi T',
                        value: '$tCrewCount',
                        icon: Icons.flight,
                      ),
                      _CrewStatCard(
                        title: 'Equipaggi TOB',
                        value: '$tobCrewCount',
                        icon: Icons.precision_manufacturing_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => context.go('/admin/validate'),
                            icon: const Icon(Icons.verified_outlined),
                            label: const Text('Valida Attività Volo'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => context.go('/admin/users'),
                            icon: const Icon(Icons.manage_accounts_outlined),
                            label: const Text('Gestione Equipaggi'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _reportService.downloadCrewReport,
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: const Text('Scarica Report Volo PDF'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filtri',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: 260,
                                child: TextField(
                                  controller: _searchCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Cerca per nome o licenza',
                                    prefixIcon: Icon(Icons.search),
                                  ),
                                  onChanged: (value) =>
                                      setState(() => _search = value),
                                ),
                              ),
                              SizedBox(
                                width: 220,
                                child: DropdownButtonFormField<int?>(
                                  initialValue: _orgUnitId,
                                  decoration: const InputDecoration(
                                    labelText: 'Unità organizzativa',
                                  ),
                                  items: [
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text('Tutte'),
                                    ),
                                    ...auth.orgUnits.map(
                                      (unit) => DropdownMenuItem<int?>(
                                        value: unit.id,
                                        child: Text('${unit.code} - ${unit.name}'),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => _orgUnitId = value),
                                ),
                              ),
                              SizedBox(
                                width: 180,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _crewTypeFilter,
                                  decoration: const InputDecoration(
                                    labelText: 'Tipo equipaggio',
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'all', child: Text('Tutti')),
                                    DropdownMenuItem(value: 'T', child: Text('T')),
                                    DropdownMenuItem(value: 'TOB', child: Text('TOB')),
                                  ],
                                  onChanged: (value) => setState(
                                    () => _crewTypeFilter = value ?? 'all',
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 220,
                                child: DropdownButtonFormField<int?>(
                                  initialValue: _tobCapabilityId,
                                  decoration: const InputDecoration(
                                    labelText: 'Capacità TOB',
                                  ),
                                  items: [
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text('Tutte'),
                                    ),
                                    ...auth.tobCapabilityTypes.map(
                                      (item) => DropdownMenuItem<int?>(
                                        value: item.id,
                                        child: Text(item.name),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => _tobCapabilityId = value),
                                ),
                              ),
                              SizedBox(
                                width: 220,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _statusFilter,
                                  decoration: const InputDecoration(
                                    labelText: 'Stato currency',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'all',
                                      child: Text('Tutte'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'valid',
                                      child: Text('Valida'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'warning',
                                      child: Text('In Scadenza'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'expired',
                                      child: Text('Scaduta'),
                                    ),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => _statusFilter = value ?? 'all'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Utenti equipaggi/volo',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (filteredRows.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Nessun utente corrisponde ai filtri selezionati.'),
                      ),
                    )
                  else
                    ...filteredRows.map(
                      (row) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.user.fullName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${row.user.numeroLicenza ?? 'Licenza non indicata'} · ${row.user.orgUnitName}',
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ...row.assignments.map(
                                    (item) => Chip(
                                      label: Text(
                                        item.crewType == 'TOB'
                                            ? '${item.helicopterCode} · TOB ${item.fascia ?? '-'}'
                                            : '${item.helicopterCode} · T',
                                      ),
                                    ),
                                  ),
                                  ...row.tobCapabilities.map(
                                    (item) => Chip(
                                      label: Text(
                                        '${item.helicopterCode} · ${item.capabilityName}',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (row.flightStatus != null)
                                    CurrencyBadgeWidget(status: row.flightStatus!),
                                  ...row.tobCapabilities.map(
                                    (item) => CurrencyBadgeWidget(
                                      status: row.tobStatuses[item.tobCapabilityId] ??
                                          const CurrencyStatus(
                                            status: CurrencyStatusEnum.noData,
                                            label: 'Nessun dato',
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _CrewUserRow {
  const _CrewUserRow({
    required this.user,
    required this.assignments,
    required this.tobCapabilities,
    required this.flightStatus,
    required this.tobStatuses,
  });

  final UserProfile user;
  final List<UserCrewAssignment> assignments;
  final List<UserTobCapability> tobCapabilities;
  final CurrencyStatus? flightStatus;
  final Map<int, CurrencyStatus> tobStatuses;

  bool get hasTCrew => assignments.any((item) => item.crewType == 'T');
  bool get hasTobCrew => assignments.any((item) => item.crewType == 'TOB');

  List<CurrencyStatus> relevantStatuses(String crewTypeFilter, int? capabilityId) {
    final statuses = <CurrencyStatus>[];
    if ((crewTypeFilter == 'all' || crewTypeFilter == 'T') && flightStatus != null) {
      statuses.add(flightStatus!);
    }
    if (crewTypeFilter == 'all' || crewTypeFilter == 'TOB') {
      for (final entry in tobStatuses.entries) {
        if (capabilityId == null || capabilityId == entry.key) {
          statuses.add(entry.value);
        }
      }
    }
    return statuses;
  }
}

class _CrewStatCard extends StatelessWidget {
  const _CrewStatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.secondary),
              const SizedBox(height: 10),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
        ),
      ),
    );
  }
}
