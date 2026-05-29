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

enum _MaintenanceSortMode { status, alphabetical, lastModified, lastActivity }

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
  bool _onlyTi = false;
  bool _onlyEtp = false;
  _MaintenanceSortMode _sortMode = _MaintenanceSortMode.status;

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

    for (final user in users.where((item) => item.isApprovedMaint)) {
      final licenses = await _userService.getUserLicenses(user.id);
      final privileges = await _userService.getUserPrivileges(user.id);
      if (licenses.isEmpty && privileges.isEmpty) {
        continue;
      }
      final status = await _currencyService.getMaintenanceCurrency(user.id);
      final lastActivity = await _activityService.getLastValidatedMaintenance(
        user.id,
      );

      final perPrivilegeCurrency = await _currencyService
          .getPerPrivilegeCurrency(user.id);

      rows.add(
        _MaintenanceUserRow(
          user: user,
          licenses: licenses,
          privileges: privileges,
          status: status,
          lastActivityDate: lastActivity?.effectiveDate,
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

  List<_MaintenanceUserRow> _sortedRows(List<_MaintenanceUserRow> rows) {
    final sorted = List<_MaintenanceUserRow>.from(rows);
    switch (_sortMode) {
      case _MaintenanceSortMode.status:
        sorted.sort((a, b) {
          final priority = _statusPriority(
            a.status.status,
          ).compareTo(_statusPriority(b.status.status));
          if (priority != 0) {
            return priority;
          }
          return a.user.fullName.compareTo(b.user.fullName);
        });
        break;
      case _MaintenanceSortMode.alphabetical:
        sorted.sort((a, b) => a.user.fullName.compareTo(b.user.fullName));
        break;
      case _MaintenanceSortMode.lastModified:
        sorted.sort((a, b) => (b.user.updatedAt).compareTo(a.user.updatedAt));
        break;
      case _MaintenanceSortMode.lastActivity:
        sorted.sort((a, b) {
          final aDate = a.lastActivityDate ?? DateTime(1970);
          final bDate = b.lastActivityDate ?? DateTime(1970);
          return bDate.compareTo(aDate);
        });
        break;
    }
    return sorted;
  }

  int _statusPriority(CurrencyStatusEnum? status) {
    if (status == CurrencyStatusEnum.expired ||
        status == CurrencyStatusEnum.suspended) {
      return 0;
    }
    if (status == CurrencyStatusEnum.warning) {
      return 1;
    }
    if (status == CurrencyStatusEnum.noData) {
      return 2;
    }
    return 3;
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

      final matchesQualifications =
          (!_onlyTi || row.user.isTi) && (!_onlyEtp || row.user.isEtp);

      return matchesSearch && matchesFilters && matchesQualifications;
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
                  'Licenze e privilegi per elicottero',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ...() {
                  // Group privileges by helicopter
                  final heliGroups = <int, List<PrivilegeCurrencyStatus>>{};
                  for (final ps in row.perPrivilegeCurrency) {
                    heliGroups
                        .putIfAbsent(ps.helicopterTypeId, () => [])
                        .add(ps);
                  }
                  // Also include helicopters that only have licenses (no privileges)
                  for (final lic in row.licenses) {
                    heliGroups.putIfAbsent(lic.helicopterTypeId, () => []);
                  }
                  return heliGroups.entries.map((heliEntry) {
                    final heliId = heliEntry.key;
                    final privileges = heliEntry.value;
                    final heliCode = privileges.isNotEmpty
                        ? privileges.first.helicopterCode
                        : row.licenses
                              .where((l) => l.helicopterTypeId == heliId)
                              .first
                              .helicopterCode;
                    final heliLicenses = row.licenses
                        .where((l) => l.helicopterTypeId == heliId)
                        .toList();
                    final licenseLabel = heliLicenses.isNotEmpty
                        ? '  ·  Cat. ${heliLicenses.first.licenseCode}'
                        : '';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Helicopter + license header
                            Text(
                              '$heliCode$licenseLabel',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              softWrap: true,
                            ),
                            if (privileges.isEmpty) ...[
                              const SizedBox(height: 6),
                              const Text(
                                'Nessun privilegio assegnato.',
                                style: TextStyle(fontStyle: FontStyle.italic),
                              ),
                            ] else ...[
                              const SizedBox(height: 8),
                              ...privileges.map((privStatus) {
                                final isExpired = privStatus.status.isExpired;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              privStatus.privilegeName,
                                              softWrap: true,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: privStatus.status.isExpired
                                                  ? const Color(0xFFC0392B)
                                                  : privStatus.status.isWarning
                                                  ? const Color(0xFFE67E22)
                                                  : const Color(0xFF27AE60),
                                              borderRadius:
                                                  BorderRadius.circular(10),
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
                                        const SizedBox(height: 4),
                                        TextButton(
                                          onPressed: () async {
                                            final confirmed = await showDialog<bool>(
                                              context: dialogContext,
                                              builder: (confirmContext) =>
                                                  AlertDialog(
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
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              confirmContext,
                                                            ).pop(false),
                                                        child: const Text(
                                                          'Annulla',
                                                        ),
                                                      ),
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              confirmContext,
                                                            ).pop(true),
                                                        child: const Text(
                                                          'Rimuovi',
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                            );
                                            if (confirmed == true &&
                                                context.mounted) {
                                              await _userService
                                                  .removePrivilege(
                                                    row.user.id,
                                                    privStatus.helicopterTypeId,
                                                    privStatus.privilegeTypeId,
                                                  );
                                              if (dialogContext.mounted) {
                                                Navigator.of(
                                                  dialogContext,
                                                ).pop();
                                              }
                                              await _loadData();
                                            }
                                          },
                                          child: const Text(
                                            'Rimuovi privilegio scaduto',
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList();
                }(),
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
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredRows.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 110,
        childAspectRatio: 1.0,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
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
          borderRadius: BorderRadius.circular(12),
          child: Card(
            color: backgroundColor,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: borderColor, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  UserAvatar(user: row.user, radius: 14),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              row.user.nome,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16),
                            ),
                            Text(
                              row.user.cognome,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
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
  }

  Widget _buildNavigationDrawer() {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Navigazione',
              style: Theme.of(context).textTheme.titleLarge,
              softWrap: true,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text('Gestione Utenti'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/admin/users');
              },
            ),
            ListTile(
              leading: const Icon(Icons.verified_outlined),
              title: const Text('Valida Attività'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/admin/validate');
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_outlined),
              title: const Text('Gestione PTA'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/admin/pta');
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_task_outlined),
              title: const Text('Inserisci Attività'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/admin/insert');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Impostazioni Currency'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/admin/settings');
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Report PDF'),
              onTap: () {
                Navigator.of(context).pop();
                _reportService.downloadMaintenanceReport();
              },
            ),
            ListTile(
              leading: const Icon(Icons.grid_on_outlined),
              title: const Text('Matrice Privilegi'),
              onTap: () {
                Navigator.of(context).pop();
                _reportService.downloadPrivilegeMatrix(
                  orgUnitId:
                      _orgUnitId ??
                      (_orgUnitChipIds.isNotEmpty
                          ? _orgUnitChipIds.first
                          : null),
                  helicopterTypeId: _helicopterTypeIds.isNotEmpty
                      ? _helicopterTypeIds.first
                      : null,
                  licenseTypeId:
                      _licenseTypeId ??
                      (_licenseTypeChipIds.isNotEmpty
                          ? _licenseTypeChipIds.first
                          : null),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('Sezione P-66'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/admin/p66');
              },
            ),
            ListTile(
              leading: const Icon(Icons.school_outlined),
              title: const Text('Inserisci Seminario'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/admin/seminars/add');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCardsSection(
    List<_StatCardData> statCardData,
    bool isMobileLayout,
  ) {
    if (isMobileLayout) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: statCardData.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
        ),
        itemBuilder: (context, index) {
          final data = statCardData[index];
          return _StatCard(
            title: data.title,
            value: data.value,
            icon: data.icon,
            color: data.color,
            onTap: data.onTap,
          );
        },
      );
    }
    return SizedBox(
      height: 76,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: statCardData.asMap().entries.map((entry) {
          final idx = entry.key;
          final data = entry.value;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: idx == 0 ? 0 : 12),
              child: _StatCard(
                title: data.title,
                value: data.value,
                icon: data.icon,
                color: data.color,
                onTap: data.onTap,
                compact: true,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final filteredRows = _sortedRows(_filteredRows());
    final approvedUsersCount = _rows.length;
    final expiredCount = _rows.where((row) => row.status.isExpired).length;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobileLayout = screenWidth < 650;

    final statCardData = <_StatCardData>[
      _StatCardData(
        title: 'Attività manutentive in attesa',
        value: '$_pendingActivities',
        icon: Icons.pending_actions,
        onTap: () => context.go('/admin/validate'),
      ),
      _StatCardData(
        title: 'Utenti manutenzione approvati',
        value: '$approvedUsersCount',
        icon: Icons.groups,
        onTap: () => context.go('/admin/users'),
      ),
      _StatCardData(
        title: 'Currency scadute',
        value: '$expiredCount',
        icon: Icons.warning_amber_rounded,
        onTap: () => setState(() => _sortMode = _MaintenanceSortMode.status),
      ),
      _StatCardData(
        title: 'PTA attive',
        value: '$_activePtaCount',
        icon: Icons.block,
        color: _activePtaCount > 0 ? const Color(0xFF8E44AD) : null,
        onTap: () => context.go('/admin/pta'),
      ),
      if (_pendingAcksCount > 0)
        _StatCardData(
          title: 'Prese visione da validare',
          value: '$_pendingAcksCount',
          icon: Icons.pending_actions,
          color: AppColors.currencyWarning,
        ),
    ];

    final content = [
      _buildStatCardsSection(statCardData, isMobileLayout),
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
    ];

    return Scaffold(
      drawer: isMobileLayout ? _buildNavigationDrawer() : null,
      appBar: AppBar(
        leading: isMobileLayout
            ? Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              )
            : const AdminAppBarLeading(fallbackRoute: '/admin/priv'),
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AvesLogoWidget(size: 32),
            const SizedBox(width: 8),
            Text(isMobileLayout ? 'CSL' : 'Manutenzione Currency'),
          ],
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<_MaintenanceSortMode>(
            icon: const Icon(Icons.sort),
            onSelected: (value) => setState(() => _sortMode = value),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _MaintenanceSortMode.status,
                child: Text('Predefinito (Stato)'),
              ),
              PopupMenuItem(
                value: _MaintenanceSortMode.alphabetical,
                child: Text('Alfabetico A-Z'),
              ),
              PopupMenuItem(
                value: _MaintenanceSortMode.lastModified,
                child: Text('Ultima modifica'),
              ),
              PopupMenuItem(
                value: _MaintenanceSortMode.lastActivity,
                child: Text('Ultima attività'),
              ),
            ],
          ),
          if (isMobileLayout)
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
          : RefreshIndicator(
              onRefresh: _loadData,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final showDrawerLayout = constraints.maxWidth < 650;
                  if (!showDrawerLayout) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: content,
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildFiltersCard(auth),
                      const SizedBox(height: 16),
                      ...content,
                    ],
                  );
                },
              ),
            ),
    );
  }

  CurrencyStatus _combineCurrencyStatuses(
    Iterable<CurrencyStatus> statuses, {
    String label = 'Nessun dato',
  }) {
    final items = statuses.toList(growable: false);
    if (items.isEmpty) {
      return CurrencyStatus(status: CurrencyStatusEnum.noData, label: label);
    }

    final activityDates =
        items
            .map((item) => item.lastActivityDate)
            .whereType<DateTime>()
            .toList(growable: false)
          ..sort();
    final expiryDates =
        items
            .map((item) => item.expiryDate)
            .whereType<DateTime>()
            .toList(growable: false)
          ..sort();
    final aggregatedStatus =
        items.any((item) => item.status == CurrencyStatusEnum.expired)
        ? CurrencyStatusEnum.expired
        : items.any((item) => item.status == CurrencyStatusEnum.suspended)
        ? CurrencyStatusEnum.suspended
        : items.any((item) => item.status == CurrencyStatusEnum.warning)
        ? CurrencyStatusEnum.warning
        : items.any((item) => item.status == CurrencyStatusEnum.noData)
        ? CurrencyStatusEnum.noData
        : CurrencyStatusEnum.valid;

    return CurrencyStatus(
      status: aggregatedStatus,
      label: label,
      lastActivityDate: activityDates.isEmpty ? null : activityDates.last,
      expiryDate: expiryDates.isEmpty ? null : expiryDates.first,
    );
  }

  String _joinDistinctLabels(Iterable<String> values) {
    final items =
        values
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    return items.isEmpty ? '-' : items.join(', ');
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 780;
                    final helicopterIds =
                        {
                          ...row.licenses.map((item) => item.helicopterTypeId),
                          ...row.privileges.map(
                            (item) => item.helicopterTypeId,
                          ),
                          ...row.perPrivilegeCurrency.map(
                            (item) => item.helicopterTypeId,
                          ),
                        }.toList(growable: false)..sort((a, b) {
                          String codeFor(int id) {
                            for (final item in row.licenses) {
                              if (item.helicopterTypeId == id)
                                return item.helicopterCode;
                            }
                            for (final item in row.privileges) {
                              if (item.helicopterTypeId == id)
                                return item.helicopterCode;
                            }
                            for (final item in row.perPrivilegeCurrency) {
                              if (item.helicopterTypeId == id)
                                return item.helicopterCode;
                            }
                            return '$id';
                          }

                          return codeFor(a).compareTo(codeFor(b));
                        });

                    Widget buildInfoPill(IconData icon, String label) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant.withValues(
                            alpha: 0.72,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Flexible(child: Text(label, softWrap: true)),
                          ],
                        ),
                      );
                    }

                    Widget buildHelicopterBlock(int helicopterTypeId) {
                      String helicopterCode = '-';
                      final licenses = row.licenses
                          .where(
                            (item) => item.helicopterTypeId == helicopterTypeId,
                          )
                          .toList(growable: false);
                      final privileges = row.privileges
                          .where(
                            (item) => item.helicopterTypeId == helicopterTypeId,
                          )
                          .toList(growable: false);
                      final statuses = row.perPrivilegeCurrency
                          .where(
                            (item) => item.helicopterTypeId == helicopterTypeId,
                          )
                          .map((item) => item.status);
                      if (licenses.isNotEmpty) {
                        helicopterCode = licenses.first.helicopterCode;
                      } else if (privileges.isNotEmpty) {
                        helicopterCode = privileges.first.helicopterCode;
                      } else {
                        final fallback = row.perPrivilegeCurrency.firstWhere(
                          (item) => item.helicopterTypeId == helicopterTypeId,
                        );
                        helicopterCode = fallback.helicopterCode;
                      }
                      final status = _combineCurrencyStatuses(
                        statuses,
                        label: 'Currency $helicopterCode',
                      );

                      return Container(
                        width: compact ? double.infinity : 250,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withValues(
                                      alpha: 0.14,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: AppColors.secondary.withValues(
                                        alpha: 0.45,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    helicopterCode,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  status.icon,
                                  color: status.color,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: status.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _joinDistinctLabels(
                                licenses.map((item) => item.licenseName),
                              ),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              softWrap: true,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _joinDistinctLabels(
                                privileges.map((item) => item.privilegeName),
                              ),
                              style: Theme.of(context).textTheme.bodyMedium,
                              softWrap: true,
                            ),
                          ],
                        ),
                      );
                    }

                    final leftPanel = Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant.withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: compact
                            ? CrossAxisAlignment.center
                            : CrossAxisAlignment.start,
                        children: [
                          UserAvatar(user: row.user, radius: 30),
                          const SizedBox(height: 14),
                          Text(
                            row.user.fullName,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                            textAlign: compact
                                ? TextAlign.center
                                : TextAlign.left,
                            softWrap: true,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            row.user.numeroLicenza ?? 'Licenza non indicata',
                            style: Theme.of(context).textTheme.bodyLarge,
                            textAlign: compact
                                ? TextAlign.center
                                : TextAlign.left,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            row.user.orgUnitName.isEmpty
                                ? 'Unità non indicata'
                                : row.user.orgUnitName,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                            textAlign: compact
                                ? TextAlign.center
                                : TextAlign.left,
                            softWrap: true,
                          ),
                        ],
                      ),
                    );

                    final rightPanel = helicopterIds.isEmpty
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant.withValues(
                                alpha: 0.4,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Text(
                              'Nessuna licenza o privilegio assegnato.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : compact
                        ? Column(
                            children: [
                              for (final helicopterTypeId in helicopterIds) ...[
                                buildHelicopterBlock(helicopterTypeId),
                                const SizedBox(height: 12),
                              ],
                            ],
                          )
                        : Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: helicopterIds
                                .map(buildHelicopterBlock)
                                .toList(growable: false),
                          );

                    final emailAvailable =
                        row.user.email != null &&
                        row.user.email!.trim().isNotEmpty;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (compact) ...[
                          leftPanel,
                          const SizedBox(height: 16),
                          rightPanel,
                        ] else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: constraints.maxWidth * 0.35,
                                child: leftPanel,
                              ),
                              const SizedBox(width: 16),
                              Expanded(child: rightPanel),
                            ],
                          ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            buildInfoPill(
                              Icons.event_available_outlined,
                              'Ultima attività: ${_formatDate(row.lastActivityDate)}',
                            ),
                            buildInfoPill(
                              Icons.schedule_outlined,
                              'Scadenza: ${_formatDate(row.status.expiryDate)}',
                            ),
                            CurrencyBadgeWidget(status: row.status),
                            if (emailAvailable)
                              OutlinedButton.icon(
                                onPressed: () => _launchMaintenanceEmail([row]),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 42),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.email_outlined,
                                  size: 18,
                                ),
                                label: const Text('Email'),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
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
            Text(
              'Qualifiche istruttori',
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
                  label: const Text('Mostra solo TI'),
                  selected: _onlyTi,
                  onSelected: (value) => setState(() => _onlyTi = value),
                ),
                FilterChip(
                  label: const Text('Mostra solo ETP'),
                  selected: _onlyEtp,
                  onSelected: (value) => setState(() => _onlyEtp = value),
                ),
              ],
            ),
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
              label: 'Inserisci Seminario',
              icon: Icons.school_outlined,
              onTap: () => context.go('/admin/seminars/add'),
            ),
            const SizedBox(height: 8),
            _NavButton(
              label: 'Sezione P-66',
              icon: Icons.article_outlined,
              onTap: () => context.go('/admin/p66'),
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
            const SizedBox(height: 8),
            _NavButton(
              label: 'Matrice Privilegi',
              icon: Icons.grid_on_outlined,
              onTap: () => _reportService.downloadPrivilegeMatrix(
                orgUnitId:
                    _orgUnitId ??
                    (_orgUnitChipIds.isNotEmpty ? _orgUnitChipIds.first : null),
                helicopterTypeId: _helicopterTypeIds.isNotEmpty
                    ? _helicopterTypeIds.first
                    : null,
                licenseTypeId:
                    _licenseTypeId ??
                    (_licenseTypeChipIds.isNotEmpty
                        ? _licenseTypeChipIds.first
                        : null),
              ),
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
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.compact = false,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.secondary;
    if (compact) {
      final card = Card(
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
      return onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: card,
            )
          : card;
    }

    final card = Card(
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
    return onTap != null
        ? InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: card,
          )
        : card;
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
