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
import '../../widgets/aves_logo_widget.dart';
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
    final pendingActivities = await _activityService
        .getPendingMaintenanceActivities();
    final rows = <_MaintenanceUserRow>[];

    for (final user in users.where((item) => item.isApproved)) {
      final licenses = await _userService.getUserLicenses(user.id);
      final privileges = await _userService.getUserPrivileges(user.id);
      if (licenses.isEmpty && privileges.isEmpty) {
        continue;
      }
      final status = await _currencyService.getMaintenanceCurrency(user.id);
      final lastActivity = await _activityService.getLastValidatedMaintenance(
        user.id,
      );
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

    final statCardData = <_StatCardData>[
      _StatCardData(
        title: 'Attività manutentive in attesa',
        value: '$_pendingActivities',
        icon: Icons.pending_actions,
      ),
      _StatCardData(
        title: 'Utenti manutenzione approvati',
        value: '$approvedUsersCount',
        icon: Icons.groups,
      ),
      _StatCardData(
        title: 'Currency scadute',
        value: '$expiredCount',
        icon: Icons.warning_amber_rounded,
      ),
      _StatCardData(
        title: 'PTA attive',
        value: '$_activePtaCount',
        icon: Icons.block,
        color: _activePtaCount > 0 ? const Color(0xFF8E44AD) : null,
      ),
      if (_pendingAcksCount > 0)
        _StatCardData(
          title: 'Prese visione da validare',
          value: '$_pendingAcksCount',
          icon: Icons.pending_actions,
          color: AppColors.currencyWarning,
        ),
    ];

    final quickActions = <_DashboardActionConfig>[
      _DashboardActionConfig(
        label: 'Inserisci Ord. Lavoro',
        icon: Icons.add_task_outlined,
        onTap: () => context.go('/admin/insert'),
        highlighted: true,
      ),
      _DashboardActionConfig(
        label: 'Valida Attività',
        icon: Icons.verified_outlined,
        onTap: () => context.go('/admin/validate'),
        highlighted: false,
      ),
      _DashboardActionConfig(
        label: 'Gestione Utenti',
        icon: Icons.manage_accounts_outlined,
        onTap: () => context.go('/admin/users'),
      ),
      _DashboardActionConfig(
        label: 'Gestione PTA',
        icon: Icons.block_outlined,
        onTap: () => context.go('/admin/pta'),
      ),
      _DashboardActionConfig(
        label: 'Impostazioni Currency',
        icon: Icons.settings_outlined,
        onTap: () => context.go('/admin/settings'),
      ),
      _DashboardActionConfig(
        label: 'Scarica Report PDF',
        icon: Icons.picture_as_pdf_outlined,
        onTap: _reportService.downloadMaintenanceReport,
      ),
    ];

    final orgUnitItems = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(value: null, child: Text('Tutte')),
      ...auth.orgUnits.map(
        (unit) =>
            DropdownMenuItem<int?>(value: unit.id, child: Text(unit.name)),
      ),
    ];
    final licenseTypeItems = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(value: null, child: Text('Tutte')),
      ...auth.licenseTypes.map(
        (item) => DropdownMenuItem<int?>(
          value: item.id,
          child: Text(item.name),
        ),
      ),
    ];
    final licenseTypeLabels = <String>[
      'Tutte',
      ...auth.licenseTypes.map((item) => item.name),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: AvesLogoWidget(size: 40),
        ),
        title: const Text('Admin Manutenzione'),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      if (isMobile) {
                        return Column(
                          children: [
                            for (final data in statCardData)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _StatCard(
                                  title: data.title,
                                  value: data.value,
                                  icon: data.icon,
                                  color: data.color,
                                  compact: true,
                                ),
                              ),
                          ],
                        );
                      }
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          for (final data in statCardData)
                            SizedBox(
                              width: 240,
                              child: _StatCard(
                                title: data.title,
                                value: data.value,
                                icon: data.icon,
                                color: data.color,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isMobile = constraints.maxWidth < 600;
                          if (isMobile) {
                            return GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.15,
                              children: [
                                for (final action in quickActions)
                                  _QuickActionTile(config: action),
                              ],
                            );
                          }
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (final action in quickActions)
                                SizedBox(
                                  width: 240,
                                  child: action.highlighted
                                      ? ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            minimumSize: const Size(0, 52),
                                          ),
                                          onPressed: action.onTap,
                                          icon: Icon(action.icon),
                                          label: Text(action.label),
                                        )
                                      : OutlinedButton.icon(
                                          onPressed: action.onTap,
                                          icon: Icon(action.icon),
                                          label: Text(action.label),
                                        ),
                                ),
                            ],
                          );
                        },
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
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isMobile = constraints.maxWidth < 600;
                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  SizedBox(
                                    width: isMobile ? double.infinity : 260,
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
                                    width: isMobile ? double.infinity : 220,
                                    child: DropdownButtonFormField<int?>(
                                      isExpanded: true,
                                      initialValue: _orgUnitId,
                                      menuMaxHeight: 300,
                                      decoration: const InputDecoration(
                                        labelText: 'Unità organizzativa',
                                      ),
                                      items: orgUnitItems,
                                      onChanged: (value) =>
                                          setState(() => _orgUnitId = value),
                                    ),
                                  ),
                                  SizedBox(
                                    width: isMobile ? double.infinity : 220,
                                    child: DropdownButtonFormField<int?>(
                                      isExpanded: true,
                                      initialValue: _licenseTypeId,
                                      menuMaxHeight: 300,
                                      selectedItemBuilder: (context) =>
                                          licenseTypeLabels
                                              .map(
                                                (label) => Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: Text(
                                                    label,
                                                    maxLines: 3,
                                                    overflow:
                                                        TextOverflow.visible,
                                                    softWrap: true,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                      decoration: const InputDecoration(
                                        labelText: 'Tipo licenza',
                                      ),
                                      items: licenseTypeItems,
                                      onChanged: (value) => setState(
                                        () => _licenseTypeId = value,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: isMobile ? double.infinity : 220,
                                    child: DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      initialValue: _statusFilter,
                                      menuMaxHeight: 300,
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
                                      onChanged: (value) => setState(
                                        () => _statusFilter = value ?? 'all',
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
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
                        child: Text(
                          'Nessun utente corrisponde ai filtri selezionati.',
                        ),
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
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final compact = constraints.maxWidth < 520;
                                  final identity = _UserIdentityHeader(
                                    user: row.user,
                                  );
                                  if (compact) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        identity,
                                        const SizedBox(height: 12),
                                        CurrencyBadgeWidget(status: row.status),
                                      ],
                                    );
                                  }
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: identity),
                                      const SizedBox(width: 16),
                                      CurrencyBadgeWidget(status: row.status),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: row.licenses.isEmpty
                                    ? const [
                                        Chip(label: Text('Nessuna licenza')),
                                      ]
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
                              const SizedBox(height: 12),
                              Text(
                                'Privilegi',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                row.privileges.isEmpty
                                    ? '-'
                                    : row.privileges
                                          .map(
                                            (item) =>
                                                '${item.helicopterCode} ${item.privilegeName}',
                                          )
                                          .join(', '),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Ultima attività: ${_formatDate(row.lastActivityDate)}',
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Scadenza: ${_formatDate(row.status.expiryDate)}',
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

class _StatCardData {
  const _StatCardData({
    required this.title,
    required this.value,
    required this.icon,
    this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color? color;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.compact = false,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.secondary;
    if (compact) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  softWrap: true,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              softWrap: true,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardActionConfig {
  const _DashboardActionConfig({
    required this.label,
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.config});

  final _DashboardActionConfig config;

  @override
  Widget build(BuildContext context) {
    final accent = config.highlighted ? AppColors.accent : AppColors.secondary;

    return InkWell(
      onTap: config.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(config.icon, color: accent),
              ),
              const Spacer(),
              Text(
                config.label,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserIdentityHeader extends StatelessWidget {
  const _UserIdentityHeader({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final initials = _dashboardInitials('${user.nome} ${user.cognome}');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.fullName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${user.numeroLicenza ?? 'Licenza non indicata'} · ${user.orgUnitName}',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _dashboardInitials(String value) {
  final parts = value
      .split(RegExp(r'\s+'))
      .where((part) => part.trim().isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return 'AV';
  }
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}
