import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app.dart';
import '../../constants/app_constants.dart';
import '../../models/activity_models.dart';
import '../../models/user_models.dart';
import '../../services/activity_service.dart';
import '../../services/currency_service.dart';
import '../../services/report_service.dart';
import '../../services/user_service.dart';
import '../../widgets/admin_app_bar_leading.dart';
import '../../widgets/aves_logo_widget.dart';
import '../../widgets/currency_badge_widget.dart';
import '../../widgets/user_avatar.dart';

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
  bool _gridView = true;

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
      final tobCapabilities = await _userService.getUserTobCapabilities(
        user.id,
      );
      final fascia = assignments
          .where((a) => a.crewType == 'TOB')
          .map((a) => a.fascia)
          .firstWhere((f) => f != null, orElse: () => null);

      CurrencyStatus? flightStatus;
      CurrencyStatus? tobBaseStatus;
      if (assignments.any((item) => item.crewType == 'T')) {
        flightStatus = await _currencyService.getFlightCurrency(user.id);
      }
      if (assignments.any((item) => item.crewType == 'TOB')) {
        tobBaseStatus = await _currencyService.getTobBaseCurrency(
          user.id,
          fascia,
        );
      }
      final tobStatuses = <int, CurrencyStatus>{};
      for (final capability in tobCapabilities) {
        tobStatuses[capability.tobCapabilityId] = await _currencyService
            .getTobCapabilityCurrencyStatus(
              user.id,
              capability.tobCapabilityId,
              capability.capabilityName,
              fascia: fascia,
            );
      }
      rows.add(
        _CrewUserRow(
          user: user,
          assignments: assignments,
          tobCapabilities: tobCapabilities,
          flightStatus: flightStatus,
          tobBaseStatus: tobBaseStatus,
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
          row.tobCapabilities.any(
            (item) => item.tobCapabilityId == _tobCapabilityId,
          );
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

  Future<void> _launchCrewEmail(List<_CrewUserRow> rows) async {
    final recipients = rows
        .where(
          (row) => row.user.email != null && row.user.email!.trim().isNotEmpty,
        )
        .toList();
    if (recipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessun indirizzo email disponibile.')),
      );
      return;
    }
    final body = recipients
        .map(
          (row) =>
              '${row.user.fullName} — ${row.relevantStatuses(_crewTypeFilter, _tobCapabilityId).where((item) => item.isWarning || item.isExpired).map((item) => item.label).join(' | ')}',
        )
        .join('\n');
    final uri = Uri(
      scheme: 'mailto',
      path: recipients.map((row) => row.user.email!.trim()).join(','),
      queryParameters: {
        'subject': 'AVES - Avviso Scadenza Currency Volo',
        'body': body,
      },
    );
    await launchUrl(uri);
  }

  Future<void> _emailExpiringUsers() async {
    final rowsToNotify = _rows
        .where(
          (row) => row
              .relevantStatuses('all', null)
              .any((item) => item.isWarning || item.isExpired),
        )
        .toList();
    await _launchCrewEmail(rowsToNotify);
  }

  Future<void> _showUserDetail(_CrewUserRow row) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(row.user.fullName, textAlign: TextAlign.center),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                UserAvatar(user: row.user, radius: 30),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: row
                      .relevantStatuses('all', null)
                      .map((status) => CurrencyBadgeWidget(status: status))
                      .toList(),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
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
              ],
            ),
          ),
        ),
        actions: [
          if (row.user.email != null && row.user.email!.trim().isNotEmpty)
            TextButton.icon(
              onPressed: () => _launchCrewEmail([row]),
              icon: const Icon(Icons.email_outlined),
              label: const Text('Invia Email'),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  Widget _buildUserGrid(List<_CrewUserRow> filteredRows) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980
            ? 3
            : constraints.maxWidth >= 640
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredRows.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 168,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemBuilder: (context, index) {
            final row = filteredRows[index];
            final statuses = row.relevantStatuses('all', null);
            final hasExpired = statuses.any((item) => item.isExpired);
            final hasWarning = statuses.any((item) => item.isWarning);
            final statusColor = hasExpired
                ? const Color(0xFFC0392B)
                : hasWarning
                ? const Color(0xFFE67E22)
                : const Color(0xFF27AE60);
            final statusText = hasExpired
                ? 'NO GO'
                : hasWarning
                ? 'WARNING'
                : 'GO';
            return InkWell(
              onTap: () => _showUserDetail(row),
              borderRadius: BorderRadius.circular(18),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      UserAvatar(user: row.user, radius: 24),
                      const SizedBox(height: 10),
                      Text(
                        '${row.user.nome} ${row.user.cognome}',
                        textAlign: TextAlign.center,
                        softWrap: true,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final filteredRows = _filteredRows();
    final tCrewCount = _rows.where((row) => row.hasTCrew).length;
    final tobCrewCount = _rows.where((row) => row.hasTobCrew).length;

    final statCardData = <_CrewStatCardData>[
      _CrewStatCardData(
        title: 'Attività volo/TOB in attesa',
        value: '$_pendingActivities',
        icon: Icons.pending_actions,
      ),
      _CrewStatCardData(
        title: 'Equipaggi T',
        value: '$tCrewCount',
        icon: Icons.flight,
      ),
      _CrewStatCardData(
        title: 'Equipaggi TOB',
        value: '$tobCrewCount',
        icon: Icons.precision_manufacturing_outlined,
      ),
    ];

    final quickActions = <_CrewActionConfig>[
      _CrewActionConfig(
        label: 'Inserisci Volo',
        icon: Icons.add_circle_outline,
        onTap: () => context.go('/admin/insert'),
        highlighted: true,
      ),
      _CrewActionConfig(
        label: 'Valida Attività Volo',
        icon: Icons.verified_outlined,
        onTap: () => context.go('/admin/validate'),
        highlighted: false,
      ),
      _CrewActionConfig(
        label: 'Gestione Equipaggi',
        icon: Icons.manage_accounts_outlined,
        onTap: () => context.go('/admin/users'),
      ),
      _CrewActionConfig(
        label: 'Impostazioni Currency TOB',
        icon: Icons.tune_outlined,
        onTap: () => context.go('/admin/settings'),
      ),
      _CrewActionConfig(
        label: 'Scarica Report Volo PDF',
        icon: Icons.picture_as_pdf_outlined,
        onTap: _reportService.downloadCrewReport,
      ),
    ];

    final orgUnitItems = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(value: null, child: Text('Tutte')),
      ...auth.orgUnits.map(
        (unit) =>
            DropdownMenuItem<int?>(value: unit.id, child: Text(unit.name)),
      ),
    ];
    final tobCapabilityItems = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(value: null, child: Text('Tutte')),
      ...auth.tobCapabilityTypes.map(
        (item) =>
            DropdownMenuItem<int?>(value: item.id, child: Text(item.name)),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: const AdminAppBarLeading(),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            AvesLogoWidget(size: 32),
            SizedBox(width: 8),
            Text('Equipaggi'),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _emailExpiringUsers,
            icon: const Icon(Icons.email_outlined),
            tooltip: '📧 Invia Avvisi Scadenza',
          ),
          IconButton(
            onPressed: () => setState(() => _gridView = !_gridView),
            icon: Icon(_gridView ? Icons.view_list : Icons.grid_view),
            tooltip: _gridView ? 'Vista estesa' : 'Vista compatta',
          ),
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
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: ListView(
                    shrinkWrap: false,
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
                                    child: _CrewStatCard(
                                      title: data.title,
                                      value: data.value,
                                      icon: data.icon,
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
                                  child: _CrewStatCard(
                                    title: data.title,
                                    value: data.value,
                                    icon: data.icon,
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
                                      _CrewQuickActionTile(config: action),
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
                                            labelText:
                                                'Cerca per nome o licenza',
                                            prefixIcon: Icon(Icons.search),
                                          ),
                                          onChanged: (value) =>
                                              setState(() => _search = value),
                                        ),
                                      ),
                                      SizedBox(
                                        width: isMobile ? double.infinity : 220,
                                        child: DropdownButtonFormField<int?>(
                                          initialValue: _orgUnitId,
                                          menuMaxHeight: 300,
                                          decoration: const InputDecoration(
                                            labelText: 'Unità organizzativa',
                                          ),
                                          items: orgUnitItems,
                                          onChanged: (value) => setState(
                                            () => _orgUnitId = value,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: isMobile ? double.infinity : 180,
                                        child: DropdownButtonFormField<String>(
                                          initialValue: _crewTypeFilter,
                                          menuMaxHeight: 300,
                                          decoration: const InputDecoration(
                                            labelText: 'Tipo equipaggio',
                                          ),
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'all',
                                              child: Text('Tutti'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'T',
                                              child: Text('T'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'TOB',
                                              child: Text('TOB'),
                                            ),
                                          ],
                                          onChanged: (value) => setState(
                                            () => _crewTypeFilter =
                                                value ?? 'all',
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: isMobile ? double.infinity : 220,
                                        child: DropdownButtonFormField<int?>(
                                          initialValue: _tobCapabilityId,
                                          menuMaxHeight: 300,
                                          decoration: const InputDecoration(
                                            labelText: 'Capacità TOB',
                                          ),
                                          items: tobCapabilityItems,
                                          onChanged: (value) => setState(
                                            () => _tobCapabilityId = value,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: isMobile ? double.infinity : 220,
                                        child: DropdownButtonFormField<String>(
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
                                              child: Text('GO'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'warning',
                                              child: Text('In Scadenza'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'expired',
                                              child: Text('NO GO'),
                                            ),
                                          ],
                                          onChanged: (value) => setState(
                                            () =>
                                                _statusFilter = value ?? 'all',
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
                        'Utenti equipaggi/volo',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      if (filteredRows.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Nessun utente corrisponde ai filtri selezionati.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else if (_gridView)
                        _buildUserGrid(filteredRows)
                      else
                        ...filteredRows.map(
                          (row) => Card(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _showUserDetail(row),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: _CrewIdentityHeader(
                                            user: row.user,
                                          ),
                                        ),
                                        if (row.user.email != null &&
                                            row.user.email!.trim().isNotEmpty)
                                          IconButton(
                                            onPressed: () =>
                                                _launchCrewEmail([row]),
                                            icon: const Icon(
                                              Icons.email_outlined,
                                            ),
                                            tooltip: 'Invia Email',
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Wrap(
                                      alignment: WrapAlignment.center,
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
                                    const SizedBox(height: 16),
                                    Text(
                                      'Currency assegnate',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        if (row.flightStatus != null)
                                          CurrencyBadgeWidget(
                                            status: row.flightStatus!,
                                          ),
                                        if (row.tobBaseStatus != null)
                                          CurrencyBadgeWidget(
                                            status: row.tobBaseStatus!,
                                          ),
                                        ...row.tobCapabilities.map(
                                          (item) => CurrencyBadgeWidget(
                                            status:
                                                row.tobStatuses[item
                                                    .tobCapabilityId] ??
                                                const CurrencyStatus(
                                                  status:
                                                      CurrencyStatusEnum.noData,
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
                        ),
                    ],
                  ),
                ),
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
    this.tobBaseStatus,
    required this.tobStatuses,
  });

  final UserProfile user;
  final List<UserCrewAssignment> assignments;
  final List<UserTobCapability> tobCapabilities;
  final CurrencyStatus? flightStatus;
  final CurrencyStatus? tobBaseStatus;
  final Map<int, CurrencyStatus> tobStatuses;

  bool get hasTCrew => assignments.any((item) => item.crewType == 'T');
  bool get hasTobCrew => assignments.any((item) => item.crewType == 'TOB');

  List<CurrencyStatus> relevantStatuses(
    String crewTypeFilter,
    int? capabilityId,
  ) {
    final statuses = <CurrencyStatus>[];
    if ((crewTypeFilter == 'all' || crewTypeFilter == 'T') &&
        flightStatus != null) {
      statuses.add(flightStatus!);
    }
    if (crewTypeFilter == 'all' || crewTypeFilter == 'TOB') {
      if (tobBaseStatus != null) {
        statuses.add(tobBaseStatus!);
      }
      for (final entry in tobStatuses.entries) {
        if (capabilityId == null || capabilityId == entry.key) {
          statuses.add(entry.value);
        }
      }
    }
    return statuses;
  }
}

class _CrewStatCardData {
  const _CrewStatCardData({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;
}

class _CrewStatCard extends StatelessWidget {
  const _CrewStatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.compact = false,
  });

  final String title;
  final String value;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
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
                  color: AppColors.secondary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.secondary, size: 22),
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
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
                color: AppColors.secondary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.secondary),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              softWrap: true,
            ),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}

class _CrewActionConfig {
  const _CrewActionConfig({
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

class _CrewQuickActionTile extends StatelessWidget {
  const _CrewQuickActionTile({required this.config});

  final _CrewActionConfig config;

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
                  color: accent.withValues(alpha: 0.14),
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

class _CrewIdentityHeader extends StatelessWidget {
  const _CrewIdentityHeader({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        UserAvatar(user: user, radius: 23),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                user.fullName,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '${user.numeroLicenza ?? 'Licenza non indicata'} · ${user.orgUnitName}',
                textAlign: TextAlign.center,
                softWrap: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
