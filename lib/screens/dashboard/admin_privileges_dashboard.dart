import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app.dart';
import '../../constants/app_constants.dart';
import '../../models/activity_models.dart';
import '../../models/user_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/activity_service.dart';
import '../../services/currency_service.dart';
import '../../services/pta_service.dart';
import '../../services/report_service.dart';
import '../../services/user_service.dart';
import '../../widgets/admin_app_bar_leading.dart';
import '../../widgets/aves_logo_widget.dart';
import '../../widgets/currency_badge_widget.dart';
import '../../widgets/user_avatar.dart';

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
  final List<int> _orgUnitChipIds = [];
  final List<int> _licenseTypeChipIds = [];
  final List<String> _statusChipFilters = [];
  final List<int> _helicopterTypeIds = [];
  final List<int> _privilegeTypeIds = [];
  bool _andMode = false;
  bool _gridView = true;
  bool _useDropdownFilters = true;

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

  void _toggleFilterId(List<int> values, int id) {
    setState(() {
      if (values.contains(id)) {
        values.remove(id);
      } else {
        values.add(id);
      }
    });
  }

  void _toggleFilterValue(List<String> values, String value) {
    setState(() {
      if (values.contains(value)) {
        values.remove(value);
      } else {
        values.add(value);
      }
    });
  }

  bool _matchSelectedValues<T>(
    List<T> selected,
    bool Function(T value) predicate,
  ) {
    if (selected.isEmpty) {
      return false;
    }
    return _andMode ? selected.every(predicate) : selected.any(predicate);
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

      // Fetch per-privilege currency
      final perPrivilegeCurrency = await _currencyService
          .getPerPrivilegeCurrency(user.id);

      rows.add(
        _MaintenanceUserRow(
          user: user,
          licenses: licenses,
          privileges: privileges,
          status: status,
          lastActivityDate: lastActivity?.activityDate,
          perPrivilegeCurrency: perPrivilegeCurrency,
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

      final privilegeHelicopters = row.privileges
          .map((item) => item.helicopterTypeId)
          .toSet();
      final privilegeTypes = row.privileges
          .map((item) => item.privilegeTypeId)
          .toSet();
      final rowStatusKey = row.status.isExpired
          ? 'expired'
          : row.status.isWarning
          ? 'warning'
          : row.status.isValid
          ? 'valid'
          : 'all';

      final activeMatches = <bool>[];
      if (_useDropdownFilters) {
        if (_orgUnitId != null) {
          activeMatches.add(row.user.orgUnitId == _orgUnitId);
        }
        if (_licenseTypeId != null) {
          activeMatches.add(
            row.licenses.any((item) => item.licenseTypeId == _licenseTypeId),
          );
        }
        if (_statusFilter != 'all') {
          activeMatches.add(rowStatusKey == _statusFilter);
        }
      } else {
        if (_orgUnitChipIds.isNotEmpty) {
          activeMatches.add(
            _matchSelectedValues<int>(
              _orgUnitChipIds,
              (value) => row.user.orgUnitId == value,
            ),
          );
        }
        if (_licenseTypeChipIds.isNotEmpty) {
          activeMatches.add(
            _matchSelectedValues<int>(
              _licenseTypeChipIds,
              (value) =>
                  row.licenses.any((item) => item.licenseTypeId == value),
            ),
          );
        }
        if (_statusChipFilters.isNotEmpty) {
          activeMatches.add(
            _matchSelectedValues<String>(
              _statusChipFilters,
              (value) => rowStatusKey == value,
            ),
          );
        }
      }

      if (_helicopterTypeIds.isNotEmpty) {
        activeMatches.add(
          _matchSelectedValues<int>(
            _helicopterTypeIds,
            privilegeHelicopters.contains,
          ),
        );
      }
      if (_privilegeTypeIds.isNotEmpty) {
        activeMatches.add(
          _matchSelectedValues<int>(_privilegeTypeIds, privilegeTypes.contains),
        );
      }

      final matchesFilters = activeMatches.isEmpty
          ? true
          : _andMode
          ? activeMatches.every((match) => match)
          : activeMatches.any((match) => match);

      return matchesSearch && matchesFilters;
    }).toList();
  }

  Future<void> _launchMaintenanceEmail(List<_MaintenanceUserRow> rows) async {
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

    final uri = Uri(
      scheme: 'mailto',
      path: recipients.map((row) => row.user.email!.trim()).join(','),
      queryParameters: {
        'subject': 'AVES - Avviso Scadenza Currency Manutentiva',
        'body': recipients
            .map(
              (row) =>
                  '${row.user.fullName} — ${row.status.statusText} — ${row.status.label}${row.status.expiryDate != null ? ' (Scadenza: ${_formatDate(row.status.expiryDate)})' : ''}',
            )
            .join('\n'),
      },
    );
    await launchUrl(uri);
  }

  Future<void> _emailExpiringUsers() async {
    final rowsToNotify = _rows
        .where((row) => row.status.isWarning || row.status.isExpired)
        .toList();
    await _launchMaintenanceEmail(rowsToNotify);
  }

  Future<void> _showUserDetail(_MaintenanceUserRow row) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          row.user.fullName,
          textAlign: TextAlign.center,
          softWrap: true,
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                UserAvatar(user: row.user, radius: 30),
                const SizedBox(height: 12),
                CurrencyBadgeWidget(status: row.status),
                const SizedBox(height: 12),
                Text(
                  row.status.label,
                  textAlign: TextAlign.center,
                  softWrap: true,
                ),
                const SizedBox(height: 12),
                Text(
                  'Ultima attività: ${_formatDate(row.lastActivityDate)}\nScadenza: ${_formatDate(row.status.expiryDate)}',
                  textAlign: TextAlign.center,
                  softWrap: true,
                ),
                const SizedBox(height: 16),
                Text(
                  'Privilegi per elicottero',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ...row.perPrivilegeCurrency.map((privStatus) {
                  final isExpired = privStatus.status.isExpired;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  '${privStatus.helicopterCode} · ${privStatus.privilegeName}',
                                  textAlign: TextAlign.center,
                                  softWrap: true,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: privStatus.status.isExpired
                                      ? const Color(0xFFC0392B)
                                      : privStatus.status.isWarning
                                      ? const Color(0xFFE67E22)
                                      : const Color(0xFF27AE60),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  privStatus.status.statusText,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isExpired) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: dialogContext,
                                  builder: (confirmContext) => AlertDialog(
                                    title: const Text(
                                      'Conferma rimozione',
                                      softWrap: true,
                                    ),
                                    content: Text(
                                      'Vuoi rimuovere il privilegio ${privStatus.privilegeName} su ${privStatus.helicopterCode} dall\'utente ${row.user.fullName}? L\'utente tornerà GO se questo era l\'unico privilegio scaduto.',
                                      softWrap: true,
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(
                                          confirmContext,
                                        ).pop(false),
                                        child: const Text('Annulla'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(
                                          confirmContext,
                                        ).pop(true),
                                        child: const Text('Rimuovi'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirmed == true && context.mounted) {
                                  await _userService.removePrivilege(
                                    row.user.id,
                                    privStatus.helicopterTypeId,
                                    privStatus.privilegeTypeId,
                                  );
                                  if (dialogContext.mounted) {
                                    Navigator.of(dialogContext).pop();
                                  }
                                  await _loadData();
                                }
                              },
                              child: const Text('Rimuovi privilegio scaduto'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          if (row.user.email != null && row.user.email!.trim().isNotEmpty)
            TextButton.icon(
              onPressed: () => _launchMaintenanceEmail([row]),
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

  Widget _buildUserGrid(List<_MaintenanceUserRow> filteredRows) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1200
            ? 6
            : constraints.maxWidth >= 900
            ? 5
            : constraints.maxWidth >= 600
            ? 4
            : constraints.maxWidth >= 400
            ? 3
            : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredRows.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: 1.0,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            final row = filteredRows[index];
            final backgroundColor = row.status.isExpired
                ? const Color(0xFF3A0A0A)
                : row.status.isWarning
                ? const Color(0xFF3A2A0A)
                : row.status.isValid
                ? const Color(0xFF1A3A1A)
                : AppColors.surface;
            final borderColor = row.status.isExpired
                ? const Color(0xFFC0392B)
                : row.status.isWarning
                ? const Color(0xFFE67E22)
                : row.status.isValid
                ? const Color(0xFF27AE60)
                : AppColors.border;
            return InkWell(
              onTap: () => _showUserDetail(row),
              borderRadius: BorderRadius.circular(16),
              child: Card(
                color: backgroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: borderColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      UserAvatar(user: row.user, radius: 16),
                      const SizedBox(height: 6),
                      Text(
                        row.user.nome,
                        textAlign: TextAlign.center,
                        softWrap: true,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
                      Text(
                        row.user.cognome,
                        textAlign: TextAlign.center,
                        softWrap: true,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
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

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        leading: const AdminAppBarLeading(fallbackRoute: '/admin/priv'),
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AvesLogoWidget(size: 32),
            const SizedBox(width: 8),
            Text(isMobile ? 'CSL' : 'Manutenzione Currency'),
          ],
        ),
        centerTitle: true,
        actions: [
          if (isMobile)
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'email':
                    _emailExpiringUsers();
                    break;
                  case 'view':
                    setState(() => _gridView = !_gridView);
                    break;
                  case 'refresh':
                    _loadData();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'email',
                  child: Text('Invia avvisi scadenza'),
                ),
                PopupMenuItem(
                  value: 'view',
                  child: Text(_gridView ? 'Vista estesa' : 'Vista compatta'),
                ),
                const PopupMenuItem(
                  value: 'refresh',
                  child: Text('Aggiorna dashboard'),
                ),
              ],
            )
          else ...[
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
          ],
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
          : LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 1200;

                if (isDesktop) {
                  // Desktop layout: sidebar + content
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left sidebar (300px fixed)
                      SizedBox(
                        width: 300,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _buildNavigationSidebar(),
                            const SizedBox(height: 16),
                            _buildFiltersCard(auth),
                          ],
                        ),
                      ),
                      // Right content (expanded)
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _loadData,
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              // Stat cards - equal width with Row + Expanded
                              Row(
                                children: [
                                  for (
                                    int i = 0;
                                    i < statCardData.length;
                                    i++
                                  ) ...[
                                    Expanded(
                                      child: _StatCard(
                                        title: statCardData[i].title,
                                        value: statCardData[i].value,
                                        icon: statCardData[i].icon,
                                        color: statCardData[i].color,
                                      ),
                                    ),
                                    if (i < statCardData.length - 1)
                                      const SizedBox(width: 16),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 24),
                              // Action buttons - evenly sized with Row + Expanded
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      for (
                                        int i = 0;
                                        i < quickActions.length;
                                        i++
                                      ) ...[
                                        Expanded(
                                          child: quickActions[i].highlighted
                                              ? ElevatedButton.icon(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        minimumSize: const Size(
                                                          0,
                                                          52,
                                                        ),
                                                      ),
                                                  onPressed:
                                                      quickActions[i].onTap,
                                                  icon: Icon(
                                                    quickActions[i].icon,
                                                    size: 20,
                                                  ),
                                                  label: Text(
                                                    quickActions[i].label,
                                                    softWrap: true,
                                                    textAlign: TextAlign.center,
                                                  ),
                                                )
                                              : OutlinedButton.icon(
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                        minimumSize: const Size(
                                                          0,
                                                          52,
                                                        ),
                                                      ),
                                                  onPressed:
                                                      quickActions[i].onTap,
                                                  icon: Icon(
                                                    quickActions[i].icon,
                                                    size: 20,
                                                  ),
                                                  label: Text(
                                                    quickActions[i].label,
                                                    softWrap: true,
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                        ),
                                        if (i < quickActions.length - 1)
                                          const SizedBox(width: 12),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Utenti con currency manutentiva',
                                style: Theme.of(context).textTheme.titleLarge,
                                textAlign: TextAlign.center,
                                softWrap: true,
                              ),
                              const SizedBox(height: 12),
                              if (filteredRows.isEmpty)
                                const Card(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(
                                      'Nessun utente corrisponde ai filtri selezionati.',
                                      textAlign: TextAlign.center,
                                      softWrap: true,
                                    ),
                                  ),
                                )
                              else if (_gridView)
                                _buildUserGrid(filteredRows)
                              else
                                ..._buildListView(filteredRows),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  // Mobile/Tablet layout: single column with scrolling
                  return RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Stat cards
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
                              alignment: WrapAlignment.center,
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
                        // Action buttons - centered with Wrap
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
                                    physics:
                                        const NeverScrollableScrollPhysics(),
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
                                  alignment: WrapAlignment.center,
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    for (final action in quickActions)
                                      SizedBox(
                                        width: 240,
                                        child: action.highlighted
                                            ? ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  minimumSize: const Size(
                                                    0,
                                                    52,
                                                  ),
                                                ),
                                                onPressed: action.onTap,
                                                icon: Icon(action.icon),
                                                label: Text(
                                                  action.label,
                                                  softWrap: true,
                                                ),
                                              )
                                            : OutlinedButton.icon(
                                                onPressed: action.onTap,
                                                icon: Icon(action.icon),
                                                label: Text(
                                                  action.label,
                                                  softWrap: true,
                                                ),
                                              ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFiltersCard(auth),
                        const SizedBox(height: 16),
                        Text(
                          'Utenti con currency manutentiva',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                          softWrap: true,
                        ),
                        const SizedBox(height: 12),
                        if (filteredRows.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Nessun utente corrisponde ai filtri selezionati.',
                                textAlign: TextAlign.center,
                                softWrap: true,
                              ),
                            ),
                          )
                        else if (_gridView)
                          _buildUserGrid(filteredRows)
                        else
                          ..._buildListView(filteredRows),
                      ],
                    ),
                  );
                }
              },
            ),
    );
  }

  List<Widget> _buildListView(List<_MaintenanceUserRow> filteredRows) {
    return filteredRows
        .map(
          (row) => Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _showUserDetail(row),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 520;
                        final identity = _UserIdentityHeader(user: row.user);
                        final emailButton =
                            row.user.email == null ||
                                row.user.email!.trim().isEmpty
                            ? const SizedBox.shrink()
                            : IconButton(
                                onPressed: () => _launchMaintenanceEmail([row]),
                                icon: const Icon(Icons.email_outlined),
                                tooltip: 'Invia Email',
                              );
                        if (compact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              identity,
                              const SizedBox(height: 12),
                              CurrencyBadgeWidget(status: row.status),
                              emailButton,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: identity),
                            emailButton,
                            const SizedBox(width: 16),
                            CurrencyBadgeWidget(status: row.status),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: row.licenses.isEmpty
                          ? const [Chip(label: Text('Nessuna licenza'))]
                          : row.licenses
                                .map(
                                  (item) => Chip(
                                    label: Text(
                                      '${item.helicopterCode} · ${item.licenseName}',
                                      softWrap: true,
                                    ),
                                  ),
                                )
                                .toList(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Privilegi',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                      softWrap: true,
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
                      textAlign: TextAlign.center,
                      softWrap: true,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ultima attività: ${_formatDate(row.lastActivityDate)}',
                      textAlign: TextAlign.center,
                      softWrap: true,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Scadenza: ${_formatDate(row.status.expiryDate)}',
                      textAlign: TextAlign.center,
                      softWrap: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .toList();
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '-';
    }
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Widget _buildFiltersCard(AuthProvider auth) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filtri',
              style: Theme.of(context).textTheme.titleLarge,
              softWrap: true,
            ),
            const SizedBox(height: 16),
            // Filter mode toggle
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Dropdown'),
                  selected: _useDropdownFilters,
                  onSelected: (_) => setState(() => _useDropdownFilters = true),
                ),
                ChoiceChip(
                  label: const Text('Chip'),
                  selected: !_useDropdownFilters,
                  onSelected: (_) =>
                      setState(() => _useDropdownFilters = false),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Search bar
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                labelText: 'Cerca per nome o licenza',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
            const SizedBox(height: 16),
            if (_useDropdownFilters) ...[
              // Dropdown mode
              DropdownButtonFormField<int?>(
                isExpanded: true,
                initialValue: _orgUnitId,
                menuMaxHeight: 300,
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
                      child: Text(unit.name, softWrap: true),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _orgUnitId = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                isExpanded: true,
                initialValue: _licenseTypeId,
                menuMaxHeight: 300,
                decoration: const InputDecoration(labelText: 'Tipo licenza'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Tutte'),
                  ),
                  ...auth.licenseTypes.map(
                    (item) => DropdownMenuItem<int?>(
                      value: item.id,
                      child: Text(item.name, softWrap: true),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _licenseTypeId = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _statusFilter,
                menuMaxHeight: 300,
                decoration: const InputDecoration(labelText: 'Stato currency'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Tutte')),
                  DropdownMenuItem(value: 'valid', child: Text('GO')),
                  DropdownMenuItem(
                    value: 'warning',
                    child: Text('In Scadenza'),
                  ),
                  DropdownMenuItem(value: 'expired', child: Text('NO GO')),
                ],
                onChanged: (value) =>
                    setState(() => _statusFilter = value ?? 'all'),
              ),
              const SizedBox(height: 16),
              Text(
                'Elicotteri',
                style: Theme.of(context).textTheme.titleSmall,
                softWrap: true,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                isExpanded: true,
                initialValue: _helicopterTypeIds.isEmpty
                    ? null
                    : _helicopterTypeIds.first,
                menuMaxHeight: 300,
                decoration: const InputDecoration(labelText: 'Elicottero'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Tutti'),
                  ),
                  ...auth.helicopterTypes.map(
                    (heli) => DropdownMenuItem<int?>(
                      value: heli.id,
                      child: Text(heli.code, softWrap: true),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _helicopterTypeIds.clear();
                    if (value != null) _helicopterTypeIds.add(value);
                  });
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Privilegi',
                style: Theme.of(context).textTheme.titleSmall,
                softWrap: true,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                isExpanded: true,
                initialValue: _privilegeTypeIds.isEmpty
                    ? null
                    : _privilegeTypeIds.first,
                menuMaxHeight: 300,
                decoration: const InputDecoration(labelText: 'Privilegio'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Tutti'),
                  ),
                  ...auth.privilegeTypes.map(
                    (priv) => DropdownMenuItem<int?>(
                      value: priv.id,
                      child: Text(priv.name, softWrap: true),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _privilegeTypeIds.clear();
                    if (value != null) _privilegeTypeIds.add(value);
                  });
                },
              ),
            ] else ...[
              // Chip mode
              Text(
                'Unità organizzativa',
                style: Theme.of(context).textTheme.titleSmall,
                softWrap: true,
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final unit in auth.orgUnits)
                    FilterChip(
                      label: Text(unit.name, softWrap: true),
                      selected: _orgUnitChipIds.contains(unit.id),
                      onSelected: (_) =>
                          _toggleFilterId(_orgUnitChipIds, unit.id),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Tipo licenza',
                style: Theme.of(context).textTheme.titleSmall,
                softWrap: true,
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final licenseType in auth.licenseTypes)
                    FilterChip(
                      label: Text(licenseType.name, softWrap: true),
                      selected: _licenseTypeChipIds.contains(licenseType.id),
                      onSelected: (_) =>
                          _toggleFilterId(_licenseTypeChipIds, licenseType.id),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Stato currency',
                style: Theme.of(context).textTheme.titleSmall,
                softWrap: true,
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('GO'),
                    selected: _statusChipFilters.contains('valid'),
                    onSelected: (_) =>
                        _toggleFilterValue(_statusChipFilters, 'valid'),
                  ),
                  FilterChip(
                    label: const Text('In Scadenza'),
                    selected: _statusChipFilters.contains('warning'),
                    onSelected: (_) =>
                        _toggleFilterValue(_statusChipFilters, 'warning'),
                  ),
                  FilterChip(
                    label: const Text('NO GO'),
                    selected: _statusChipFilters.contains('expired'),
                    onSelected: (_) =>
                        _toggleFilterValue(_statusChipFilters, 'expired'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Elicotteri',
                style: Theme.of(context).textTheme.titleSmall,
                softWrap: true,
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final helicopter in auth.helicopterTypes)
                    FilterChip(
                      label: Text(helicopter.code, softWrap: true),
                      selected: _helicopterTypeIds.contains(helicopter.id),
                      onSelected: (_) =>
                          _toggleFilterId(_helicopterTypeIds, helicopter.id),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Privilegi',
                style: Theme.of(context).textTheme.titleSmall,
                softWrap: true,
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final privilege in auth.privilegeTypes)
                    FilterChip(
                      label: Text(privilege.name, softWrap: true),
                      selected: _privilegeTypeIds.contains(privilege.id),
                      onSelected: (_) =>
                          _toggleFilterId(_privilegeTypeIds, privilege.id),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            // AND/OR toggle
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('OR'),
                  selected: !_andMode,
                  onSelected: (_) => setState(() => _andMode = false),
                ),
                ChoiceChip(
                  label: const Text('AND'),
                  selected: _andMode,
                  onSelected: (_) => setState(() => _andMode = true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationSidebar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Navigazione',
              style: Theme.of(context).textTheme.titleLarge,
              softWrap: true,
            ),
            const SizedBox(height: 16),
            _NavButton(
              label: 'Gestione Utenti',
              icon: Icons.manage_accounts_outlined,
              onTap: () => context.go('/admin/users'),
            ),
            const SizedBox(height: 8),
            _NavButton(
              label: 'Valida Attività',
              icon: Icons.verified_outlined,
              onTap: () => context.go('/admin/validate'),
            ),
            const SizedBox(height: 8),
            _NavButton(
              label: 'Gestione PTA',
              icon: Icons.block_outlined,
              onTap: () => context.go('/admin/pta'),
            ),
            const SizedBox(height: 8),
            _NavButton(
              label: 'Inserisci Attività',
              icon: Icons.add_task_outlined,
              onTap: () => context.go('/admin/insert'),
            ),
            const SizedBox(height: 8),
            _NavButton(
              label: 'Impostazioni Currency',
              icon: Icons.settings_outlined,
              onTap: () => context.go('/admin/settings'),
            ),
            const SizedBox(height: 8),
            _NavButton(
              label: 'Report PDF',
              icon: Icons.picture_as_pdf_outlined,
              onTap: _reportService.downloadMaintenanceReport,
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceUserRow {
  const _MaintenanceUserRow({
    required this.user,
    required this.licenses,
    required this.privileges,
    required this.status,
    required this.lastActivityDate,
    this.perPrivilegeCurrency = const [],
  });

  final UserProfile user;
  final List<UserLicense> licenses;
  final List<UserPrivilege> privileges;
  final CurrencyStatus status;
  final DateTime? lastActivityDate;
  final List<PrivilegeCurrencyStatus> perPrivilegeCurrency;
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
                softWrap: true,
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

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label, softWrap: true),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
