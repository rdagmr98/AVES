import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../constants/app_constants.dart';
import '../../models/activity_models.dart';
import '../../models/user_models.dart';
import '../../services/activity_service.dart';
import '../../services/currency_service.dart';
import '../../services/pta_service.dart';
import '../../services/report_service.dart';
import '../../services/user_service.dart';
import '../../widgets/currency_badge_widget.dart';

class AdminPrivilegesDashboard extends ConsumerStatefulWidget {
  const AdminPrivilegesDashboard({super.key});

  @override
  ConsumerState<AdminPrivilegesDashboard> createState() =>
      _AdminPrivilegesDashboardState();
}

class _AdminPrivilegesDashboardState
    extends ConsumerState<AdminPrivilegesDashboard> {
  final _userService = UserService();
  final _activityService = ActivityService();
  final _currencyService = CurrencyService();
  final _reportService = ReportService();
  final _ptaService = PtaService();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  int _pendingActivities = 0;
  int _activePtaCount = 0;
  int _pendingAcksCount = 0;
  List<_MaintenanceUserRow> _rows = [];
  String _search = '';
  int? _orgUnitId;
  int? _licenseTypeId;
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
    final pendingActivities = await _activityService.getPendingMaintenanceActivities();
    final rows = <_MaintenanceUserRow>[];

    for (final user in users.where((item) => item.isApproved)) {
      final licenses = await _userService.getUserLicenses(user.id);
      final privileges = await _userService.getUserPrivileges(user.id);
      if (licenses.isEmpty && privileges.isEmpty) {
        continue;
      }
      final status = await _currencyService.getMaintenanceCurrency(user.id);
      final lastActivity = await _activityService.getLastValidatedMaintenance(user.id);
      rows.add(
        _MaintenanceUserRow(
          user: user,
          licenses: licenses,
          privileges: privileges,
          status: status,
          lastActivityDate: lastActivity?.activityDate,
        ),
      );
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _pendingActivities = pendingActivities.length;
      _activePtaCount = _ptaService.getActivePta().length;
      _pendingAcksCount = _ptaService.getPendingAcknowledgments().length;
      _rows = rows;
      _loading = false;
    });
  }

  List<_MaintenanceUserRow> _filteredRows() {
    return _rows.where((row) {
      final search = _search.trim().toLowerCase();
      final matchesSearch =
          search.isEmpty ||
          row.user.fullName.toLowerCase().contains(search) ||
          (row.user.numeroLicenza ?? '').toLowerCase().contains(search);
      final matchesOrg = _orgUnitId == null || row.user.orgUnitId == _orgUnitId;
      final matchesLicenseType =
          _licenseTypeId == null ||
          row.licenses.any((item) => item.licenseTypeId == _licenseTypeId);
      final matchesStatus = switch (_statusFilter) {
        'valid' => row.status.isValid,
        'warning' => row.status.isWarning,
        'expired' => row.status.isExpired,
        _ => true,
      };
      return matchesSearch && matchesOrg && matchesLicenseType && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final filteredRows = _filteredRows();
    final approvedUsersCount = _rows.length;
    final expiredCount = _rows.where((row) => row.status.isExpired).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Admin CSL'),
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
                      _StatCard(
                        title: 'Attività manutentive in attesa',
                        value: '$_pendingActivities',
                        icon: Icons.pending_actions,
                      ),
                      _StatCard(
                        title: 'Utenti manutenzione approvati',
                        value: '$approvedUsersCount',
                        icon: Icons.groups,
                      ),
                      _StatCard(
                        title: 'Currency scadute',
                        value: '$expiredCount',
                        icon: Icons.warning_amber_rounded,
                      ),
                      _StatCard(
                        title: 'PTA attive',
                        value: '$_activePtaCount',
                        icon: Icons.block,
                        color: _activePtaCount > 0
                            ? const Color(0xFF8E44AD)
                            : null,
                      ),
                      if (_pendingAcksCount > 0)
                        _StatCard(
                          title: 'Prese visione da validare',
                          value: '$_pendingAcksCount',
                          icon: Icons.pending_actions,
                          color: AppColors.currencyWarning,
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
                            label: const Text('Valida Attività Manutenzione'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => context.go('/admin/users'),
                            icon: const Icon(Icons.manage_accounts_outlined),
                            label: const Text('Gestione Utenti'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => context.go('/admin/pta'),
                            icon: const Icon(Icons.block_outlined),
                            label: const Text('Gestione PTA'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => context.go('/admin/settings'),
                            icon: const Icon(Icons.settings_outlined),
                            label: const Text('Impostazioni Currency'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _reportService.downloadMaintenanceReport,
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: const Text('Scarica Report PDF'),
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
                                width: 220,
                                child: DropdownButtonFormField<int?>(
                                  initialValue: _licenseTypeId,
                                  decoration: const InputDecoration(
                                    labelText: 'Tipo licenza',
                                  ),
                                  items: [
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text('Tutte'),
                                    ),
                                    ...auth.licenseTypes.map(
                                      (item) => DropdownMenuItem<int?>(
                                        value: item.id,
                                        child: Text(item.name),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => _licenseTypeId = value),
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
                    'Utenti con currency manutentiva',
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
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          row.user.fullName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${row.user.numeroLicenza ?? 'Licenza non indicata'} · ${row.user.orgUnitName}',
                                        ),
                                      ],
                                    ),
                                  ),
                                  CurrencyBadgeWidget(status: row.status),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: row.licenses.isEmpty
                                    ? const [Chip(label: Text('Nessuna licenza'))]
                                    : row.licenses
                                          .map(
                                            (item) => Chip(
                                              label: Text(
                                                '${item.helicopterCode} · ${item.licenseName}',
                                              ),
                                            ),
                                          )
                                          .toList(),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Privilegi: ${row.privileges.isEmpty ? '-' : row.privileges.map((item) => '${item.helicopterCode} ${item.privilegeName}').join(', ')}',
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ultima attività: ${_formatDate(row.lastActivityDate)} · Scadenza: ${_formatDate(row.status.expiryDate)}',
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

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '-';
    }
    return DateFormat('dd/MM/yyyy').format(date);
  }
}

class _MaintenanceUserRow {
  const _MaintenanceUserRow({
    required this.user,
    required this.licenses,
    required this.privileges,
    required this.status,
    required this.lastActivityDate,
  });

  final UserProfile user;
  final List<UserLicense> licenses;
  final List<UserPrivilege> privileges;
  final CurrencyStatus status;
  final DateTime? lastActivityDate;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color ?? AppColors.secondary),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
