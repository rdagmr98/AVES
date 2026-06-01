import 'package:intl/intl.dart';

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

enum _CrewSortMode { status, alphabetical, lastModified, lastActivity }

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
  final List<int> _orgUnitChipIds = [];
  final List<int> _helicopterTypeIds = [];
  final List<String> _crewTypeIds = [];
  int? _tobCapabilityId;
  final List<int> _tobCapabilityChipIds = [];
  String _statusFilter = 'all';
  final List<String> _statusChipFilters = [];
  bool _andMode = false;
  bool _gridView = true;
  bool _filterModeDropdown = true;
  bool _onlyTi = false;
  bool _onlyEtp = false;
  _CrewSortMode _sortMode = _CrewSortMode.status;

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

  void _toggleHelicopterFilter(int id) {
    setState(() {
      if (_helicopterTypeIds.contains(id)) {
        _helicopterTypeIds.remove(id);
      } else {
        _helicopterTypeIds.add(id);
      }
    });
  }

  void _toggleCrewTypeFilter(String value) {
    setState(() {
      if (_crewTypeIds.contains(value)) {
        _crewTypeIds.remove(value);
      } else {
        _crewTypeIds.add(value);
      }
    });
  }

  void _toggleIntFilter(List<int> values, int value) {
    setState(() {
      if (values.contains(value)) {
        values.remove(value);
      } else {
        values.add(value);
      }
    });
  }

  void _toggleStringFilter(List<String> values, String value) {
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

  String get _statusCrewFilter =>
      _crewTypeIds.length == 1 ? _crewTypeIds.first : 'all';

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final users = await _userService.getAllUsers();
    final pendingFlight = await _activityService.getPendingFlightActivities();
    final pendingTob = await _activityService.getPendingTobActivities();
    final rows = <_CrewUserRow>[];

    for (final user in users.where((item) => item.isApprovedCrew)) {
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
      CurrencyStatus? mdbStatus;
      if (assignments.any((item) => item.crewType == 'T')) {
        flightStatus = await _currencyService.getFlightCurrency(user.id);
      }
      if (assignments.any((item) => item.crewType == 'TOB')) {
        tobBaseStatus = await _currencyService.getTobBaseCurrency(
          user.id,
          fascia,
        );
      }
      if (assignments.any((item) => item.crewType == 'MTB')) {
        mdbStatus = await _currencyService.getMtbCurrency(
          user.id,
          assignments,
          user.isTi,
        );
      }
      final tobStatuses = <String, CurrencyStatus>{};
      for (final capability in tobCapabilities) {
        tobStatuses['${capability.helicopterTypeId}:${capability.tobCapabilityId}'] =
            await _currencyService.getTobCapabilityCurrencyStatus(
              user.id,
              capability.helicopterTypeId,
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
          mdbStatus: mdbStatus,
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

  List<_CrewUserRow> _sortedRows(List<_CrewUserRow> rows) {
    final sorted = List<_CrewUserRow>.from(rows);
    switch (_sortMode) {
      case _CrewSortMode.status:
        sorted.sort((a, b) {
          final aPriority = _statusPriority(a.overallStatus(_statusCrewFilter));
          final bPriority = _statusPriority(b.overallStatus(_statusCrewFilter));
          if (aPriority != bPriority) {
            return aPriority.compareTo(bPriority);
          }
          return a.user.fullName.compareTo(b.user.fullName);
        });
        break;
      case _CrewSortMode.alphabetical:
        sorted.sort((a, b) => a.user.fullName.compareTo(b.user.fullName));
        break;
      case _CrewSortMode.lastModified:
        sorted.sort((a, b) => (b.user.updatedAt).compareTo(a.user.updatedAt));
        break;
      case _CrewSortMode.lastActivity:
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

  List<_CrewUserRow> _filteredRows() {
    return _rows.where((row) {
      final search = _search.trim().toLowerCase();
      final matchesSearch =
          search.isEmpty ||
          row.user.fullName.toLowerCase().contains(search) ||
          (row.user.numeroLicenza ?? '').toLowerCase().contains(search);
      final assignmentHelicopters = row.assignments
          .map((item) => item.helicopterTypeId)
          .toSet();
      final assignmentTypes = row.assignments
          .map((item) => item.crewType)
          .toSet();
      final capabilityIds = row.tobCapabilities
          .map((item) => item.tobCapabilityId)
          .toSet();

      final statusCrewFilter = _crewTypeIds.length == 1
          ? _crewTypeIds.first
          : 'all';
      final statusCapabilityFilter = _filterModeDropdown
          ? _tobCapabilityId
          : _tobCapabilityChipIds.length == 1
          ? _tobCapabilityChipIds.first
          : null;
      final rowStatuses = row.relevantStatuses(
        statusCrewFilter,
        statusCapabilityFilter,
      );
      final statusKeys = <String>{
        if (rowStatuses.any((item) => item.isValid)) 'valid',
        if (rowStatuses.any((item) => item.isWarning)) 'warning',
        if (rowStatuses.any((item) => item.isExpired)) 'expired',
      };

      final activeMatches = <bool>[];
      if (_filterModeDropdown) {
        if (_orgUnitId != null) {
          activeMatches.add(row.user.orgUnitId == _orgUnitId);
        }
        if (_tobCapabilityId != null) {
          activeMatches.add(capabilityIds.contains(_tobCapabilityId));
        }
        if (_statusFilter != 'all') {
          activeMatches.add(statusKeys.contains(_statusFilter));
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
        if (_tobCapabilityChipIds.isNotEmpty) {
          activeMatches.add(
            _matchSelectedValues<int>(
              _tobCapabilityChipIds,
              capabilityIds.contains,
            ),
          );
        }
        if (_statusChipFilters.isNotEmpty) {
          activeMatches.add(
            _matchSelectedValues<String>(
              _statusChipFilters,
              statusKeys.contains,
            ),
          );
        }
      }

      if (_helicopterTypeIds.isNotEmpty) {
        activeMatches.add(
          _matchSelectedValues<int>(
            _helicopterTypeIds,
            assignmentHelicopters.contains,
          ),
        );
      }
      if (_crewTypeIds.isNotEmpty) {
        activeMatches.add(
          _matchSelectedValues<String>(_crewTypeIds, assignmentTypes.contains),
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
              '${row.user.fullName} — ${row.relevantStatuses(_statusCrewFilter, _tobCapabilityId).where((item) => item.isWarning || item.isExpired).map((item) => item.label).join(' | ')}',
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
                              : item.crewType == 'MTB'
                              ? '${item.helicopterCode} · MTB ${item.fascia ?? '-'}'
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
        final statuses = row.relevantStatuses(
          _statusCrewFilter,
          _tobCapabilityId,
        );
        final hasExpired = statuses.any((item) => item.isExpired);
        final hasWarning = statuses.any((item) => item.isWarning);
        final backgroundColor = hasExpired
            ? const Color(0xFF3A0A0A)
            : hasWarning
            ? const Color(0xFF3A2A0A)
            : statuses.isNotEmpty
            ? const Color(0xFF1A3A1A)
            : AppColors.surface;
        final borderColor = hasExpired
            ? const Color(0xFFC0392B)
            : hasWarning
            ? const Color(0xFFE67E22)
            : statuses.isNotEmpty
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
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Expanded(
                    child: Center(
                      child: UserAvatar(user: row.user, radius: 14),
                    ),
                  ),
                  FittedBox(
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
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        );
      },
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
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.go('/admin/users'),
              icon: const Icon(Icons.people_outlined),
              label: const Text('Gestione Utenti', softWrap: true),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.go('/admin/validate'),
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Valida Attività', softWrap: true),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.go('/admin/pta'),
              icon: const Icon(Icons.block_outlined),
              label: const Text('Gestione PTA', softWrap: true),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.go('/admin/insert'),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Inserisci Attività', softWrap: true),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.go('/admin/settings'),
              icon: const Icon(Icons.tune_outlined),
              label: const Text('Impostazioni Currency', softWrap: true),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _reportService.downloadCrewReport,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Report PDF', softWrap: true),
            ),
          ],
        ),
      ),
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
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.people_outlined),
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
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Inserisci Attività'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/admin/insert');
              },
            ),
            ListTile(
              leading: const Icon(Icons.tune_outlined),
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
                _reportService.downloadCrewReport();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersSection() {
    final auth = ref.watch(authProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filtri', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Dropdown'),
                  selected: _filterModeDropdown,
                  onSelected: (_) => setState(() => _filterModeDropdown = true),
                ),
                ChoiceChip(
                  label: const Text('Chip'),
                  selected: !_filterModeDropdown,
                  onSelected: (_) =>
                      setState(() => _filterModeDropdown = false),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                labelText: 'Cerca per nome o licenza',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
            const SizedBox(height: 16),
            if (_filterModeDropdown) ...[
              DropdownButtonFormField<int?>(
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
                      child: Text(unit.name),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _orgUnitId = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                initialValue: _tobCapabilityId,
                menuMaxHeight: 300,
                decoration: const InputDecoration(labelText: 'Capacità TOB'),
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
                onChanged: (value) => setState(() => _tobCapabilityId = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
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
              Text('Elicotteri', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                menuMaxHeight: 300,
                decoration: const InputDecoration(labelText: 'Elicottero'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Tutti'),
                  ),
                  ...auth.helicopterTypes.map(
                    (h) => DropdownMenuItem<int?>(
                      value: h.id,
                      child: Text(h.code),
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
                'Tipi equipaggio',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                menuMaxHeight: 300,
                decoration: const InputDecoration(labelText: 'Tipo equipaggio'),
                items: const [
                  DropdownMenuItem<String?>(value: null, child: Text('Tutti')),
                  DropdownMenuItem<String?>(value: 'T', child: Text('T')),
                  DropdownMenuItem<String?>(value: 'TOB', child: Text('TOB')),
                  DropdownMenuItem<String?>(value: 'MTB', child: Text('MTB')),
                ],
                onChanged: (value) {
                  setState(() {
                    _crewTypeIds.clear();
                    if (value != null) _crewTypeIds.add(value);
                  });
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Qualifiche istruttori',
                style: Theme.of(context).textTheme.titleSmall,
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
            ] else ...[
              Text(
                'Unità organizzativa',
                style: Theme.of(context).textTheme.titleSmall,
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
                          _toggleIntFilter(_orgUnitChipIds, unit.id),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Capacità TOB',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final cap in auth.tobCapabilityTypes)
                    FilterChip(
                      label: Text(cap.name, softWrap: true),
                      selected: _tobCapabilityChipIds.contains(cap.id),
                      onSelected: (_) =>
                          _toggleIntFilter(_tobCapabilityChipIds, cap.id),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Stato currency',
                style: Theme.of(context).textTheme.titleSmall,
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
                        _toggleStringFilter(_statusChipFilters, 'valid'),
                  ),
                  FilterChip(
                    label: const Text('In Scadenza'),
                    selected: _statusChipFilters.contains('warning'),
                    onSelected: (_) =>
                        _toggleStringFilter(_statusChipFilters, 'warning'),
                  ),
                  FilterChip(
                    label: const Text('NO GO'),
                    selected: _statusChipFilters.contains('expired'),
                    onSelected: (_) =>
                        _toggleStringFilter(_statusChipFilters, 'expired'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Elicotteri', style: Theme.of(context).textTheme.titleSmall),
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
                      onSelected: (_) => _toggleHelicopterFilter(helicopter.id),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Tipi equipaggio',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final crewType in const ['T', 'TOB', 'MTB'])
                    FilterChip(
                      label: Text(crewType),
                      selected: _crewTypeIds.contains(crewType),
                      onSelected: (_) => _toggleCrewTypeFilter(crewType),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Qualifiche istruttori',
                style: Theme.of(context).textTheme.titleSmall,
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
            ],
            const SizedBox(height: 16),
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

  Widget _buildStatCards(bool isMobileLayout) {
    final tCrewCount = _rows.where((row) => row.hasTCrew).length;
    final tobCrewCount = _rows.where((row) => row.hasTobCrew).length;
    final mdbCrewCount = _rows.where((row) => row.hasMdbCrew).length;

    final statCardData = <_CrewStatCardData>[
      _CrewStatCardData(
        title: 'Attività volo/TOB in attesa',
        value: '$_pendingActivities',
        icon: Icons.pending_actions,
        onTap: () => context.go('/admin/validate'),
      ),
      _CrewStatCardData(
        title: 'Equipaggi T',
        value: '$tCrewCount',
        icon: Icons.flight,
        onTap: () => setState(
          () => _crewTypeIds
            ..clear()
            ..add('T'),
        ),
      ),
      _CrewStatCardData(
        title: 'Equipaggi TOB',
        value: '$tobCrewCount',
        icon: Icons.precision_manufacturing_outlined,
        onTap: () => setState(
          () => _crewTypeIds
            ..clear()
            ..add('TOB'),
        ),
      ),
      _CrewStatCardData(
        title: 'Equipaggi MTB',
        value: '$mdbCrewCount',
        icon: Icons.shield_outlined,
        onTap: () => setState(
          () => _crewTypeIds
            ..clear()
            ..add('MTB'),
        ),
      ),
    ];

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
          return _CrewStatCard(
            title: data.title,
            value: data.value,
            icon: data.icon,
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
              child: _CrewStatCard(
                title: data.title,
                value: data.value,
                icon: data.icon,
                compact: true,
                onTap: data.onTap,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  CurrencyStatus _combineCrewStatuses(
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

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _joinCrewLabels(Iterable<String> values) {
    final items =
        values
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    return items.isEmpty ? '-' : items.join(', ');
  }

  Widget _buildUserContent(List<_CrewUserRow> filteredRows) {
    if (filteredRows.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Nessun utente corrisponde ai filtri selezionati.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_gridView) {
      return _buildUserGrid(filteredRows);
    }

    return Column(
      children: filteredRows
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
                            ...row.assignments.map(
                              (item) => item.helicopterTypeId,
                            ),
                            ...row.tobCapabilities.map(
                              (item) => item.helicopterTypeId,
                            ),
                          }.toList(growable: false)..sort((a, b) {
                            String codeFor(int id) {
                              for (final item in row.assignments) {
                                if (item.helicopterTypeId == id) {
                                  return item.helicopterCode;
                                  }
                                }
                                for (final item in row.tobCapabilities) {
                                  if (item.helicopterTypeId == id) {
                                    return item.helicopterCode;
                                  }
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
                        final assignments = row.assignments
                            .where(
                              (item) =>
                                  item.helicopterTypeId == helicopterTypeId,
                            )
                            .toList(growable: false);
                        final capabilities = row.tobCapabilities
                            .where(
                              (item) =>
                                  item.helicopterTypeId == helicopterTypeId,
                            )
                            .toList(growable: false);
                        String helicopterCode = '-';
                        if (assignments.isNotEmpty) {
                          helicopterCode = assignments.first.helicopterCode;
                        } else if (capabilities.isNotEmpty) {
                          helicopterCode = capabilities.first.helicopterCode;
                        }

                        final statusItems = <CurrencyStatus>[];
                        if (assignments.any((item) => item.crewType == 'T') &&
                            row.flightStatus != null) {
                          statusItems.add(row.flightStatus!);
                        }
                        if (assignments.any((item) => item.crewType == 'TOB') &&
                            row.tobBaseStatus != null) {
                          statusItems.add(row.tobBaseStatus!);
                        }
                        for (final capability in capabilities) {
                          final capabilityStatus = row
                              .tobStatuses['${capability.helicopterTypeId}:${capability.tobCapabilityId}'];
                          if (capabilityStatus != null) {
                            statusItems.add(capabilityStatus);
                          }
                        }
                        if (assignments.any((item) => item.crewType == 'MTB') &&
                            row.mdbStatus != null) {
                          statusItems.add(row.mdbStatus!);
                        }
                        final status = _combineCrewStatuses(
                          statusItems,
                          label: 'Stato $helicopterCode',
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
                                _joinCrewLabels(
                                  assignments.map(
                                    (item) => item.crewType == 'TOB'
                                        ? 'TOB ${item.fascia ?? '-'}'
                                        : item.crewType,
                                  ),
                                ),
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                                softWrap: true,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                capabilities.isEmpty
                                    ? 'Capacità: -'
                                    : 'Capacità: ${_joinCrewLabels(capabilities.map((item) => item.capabilityName))}',
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
                          color: AppColors.surfaceVariant.withValues(
                            alpha: 0.42,
                          ),
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
                                'Nessuna assegnazione equipaggio disponibile.',
                                textAlign: TextAlign.center,
                              ),
                            )
                          : compact
                          ? Column(
                              children: [
                                for (final helicopterTypeId
                                    in helicopterIds) ...[
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
                      final overallStatus = _combineCrewStatuses(
                        row.relevantStatuses('all', null),
                        label: 'Stato equipaggio',
                      );

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
                                Icons.flight_takeoff_outlined,
                                'Ultima attività: ${_formatDate(row.lastActivityDate)}',
                              ),
                              CurrencyBadgeWidget(status: overallStatus),
                              if (emailAvailable)
                                OutlinedButton.icon(
                                  onPressed: () => _launchCrewEmail([row]),
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
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredRows = _sortedRows(_filteredRows());
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobileLayout = screenWidth < 650;

    final content = [
      _buildStatCards(isMobileLayout),
      const SizedBox(height: 16),
      Text(
        'Utenti equipaggi/volo',
        style: Theme.of(context).textTheme.titleLarge,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      _buildUserContent(filteredRows),
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
            : const AdminAppBarLeading(fallbackRoute: '/admin/crew'),
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AvesLogoWidget(size: 32),
            const SizedBox(width: 8),
            Text(isMobileLayout ? 'Volo' : 'Volo e TOB'),
          ],
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<_CrewSortMode>(
            icon: const Icon(Icons.sort),
            onSelected: (value) => setState(() => _sortMode = value),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _CrewSortMode.status,
                child: Text('Predefinito (Stato)'),
              ),
              PopupMenuItem(
                value: _CrewSortMode.alphabetical,
                child: Text('Alfabetico A-Z'),
              ),
              PopupMenuItem(
                value: _CrewSortMode.lastModified,
                child: Text('Ultima modifica'),
              ),
              PopupMenuItem(
                value: _CrewSortMode.lastActivity,
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
                              _buildFiltersSection(),
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
                      _buildFiltersSection(),
                      const SizedBox(height: 16),
                      ...content,
                    ],
                  );
                },
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
    this.mdbStatus,
    required this.tobStatuses,
  });

  final UserProfile user;
  final List<UserCrewAssignment> assignments;
  final List<UserTobCapability> tobCapabilities;
  final CurrencyStatus? flightStatus;
  final CurrencyStatus? tobBaseStatus;
  final CurrencyStatus? mdbStatus;
  final Map<String, CurrencyStatus> tobStatuses;

  bool get hasTCrew => assignments.any((item) => item.crewType == 'T');
  bool get hasTobCrew => assignments.any((item) => item.crewType == 'TOB');
  bool get hasMdbCrew => assignments.any((item) => item.crewType == 'MTB');
  DateTime? get lastActivityDate {
    final dates = relevantStatuses('all', null)
        .map((status) => status.lastActivityDate)
        .whereType<DateTime>()
        .toList(growable: false);
    if (dates.isEmpty) {
      return null;
    }
    dates.sort();
    return dates.last;
  }

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
      for (final capability in tobCapabilities) {
        if (capabilityId != null &&
            capability.tobCapabilityId != capabilityId) {
          continue;
        }
        final status =
            tobStatuses['${capability.helicopterTypeId}:${capability.tobCapabilityId}'];
        if (status != null) {
          statuses.add(status);
        }
      }
    }
    if ((crewTypeFilter == 'all' || crewTypeFilter == 'MTB') &&
        mdbStatus != null) {
      statuses.add(mdbStatus!);
    }
    return statuses;
  }

  CurrencyStatusEnum? overallStatus(String crewTypeFilter) {
    final statuses = relevantStatuses(crewTypeFilter, null);
    if (statuses.isEmpty) {
      return CurrencyStatusEnum.noData;
    }
    if (statuses.any((item) => item.status == CurrencyStatusEnum.expired)) {
      return CurrencyStatusEnum.expired;
    }
    if (statuses.any((item) => item.status == CurrencyStatusEnum.suspended)) {
      return CurrencyStatusEnum.suspended;
    }
    if (statuses.any((item) => item.status == CurrencyStatusEnum.warning)) {
      return CurrencyStatusEnum.warning;
    }
    if (statuses.any((item) => item.status == CurrencyStatusEnum.noData)) {
      return CurrencyStatusEnum.noData;
    }
    return CurrencyStatusEnum.valid;
  }
}

class _CrewStatCardData {
  const _CrewStatCardData({
    required this.title,
    required this.value,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
}

class _CrewStatCard extends StatelessWidget {
  const _CrewStatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.compact = false,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = compact
        ? Padding(
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
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    softWrap: true,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
          )
        : Padding(
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
          );

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      ),
    );
  }
}
