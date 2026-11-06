import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app.dart';
import '../../constants/app_constants.dart';
import '../../models/activity_models.dart';
import '../../models/user_models.dart';
import '../../services/gh_db_service.dart';
import '../../services/activity_service.dart';
import '../../services/currency_history.dart';
import '../../services/currency_service.dart';
import '../../services/hours_format.dart';
import '../../services/report_service.dart';
import '../../services/user_service.dart';
import '../../widgets/activity_edit_dialog.dart';
import '../../widgets/admin_app_bar_leading.dart';
import '../../widgets/aves_logo_widget.dart';
import '../../widgets/currency_badge_widget.dart';
import '../../widgets/currency_event_tile.dart';
import '../../widgets/filter_panel.dart';
import '../../widgets/flight_course_dialog.dart';
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
  final List<int> _orgUnitChipIds = [];
  final List<int> _helicopterTypeIds = [];
  final List<String> _crewTypeIds = [];
  final List<int> _tobCapabilityChipIds = [];
  final List<String> _statusChipFilters = [];
  bool _andMode = false;
  bool _onlyTi = false;
  bool _onlyEtp = false;
  _CrewSortMode _sortMode = _CrewSortMode.status;

  @override
  void initState() {
    super.initState();
    GhDbService().changes.addListener(_loadData);
    _loadData();
  }

  @override
  void dispose() {
    GhDbService().changes.removeListener(_loadData);
    _searchCtrl.dispose();
    super.dispose();
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
      return true;
    }
    return _andMode ? selected.every(predicate) : selected.any(predicate);
  }

  String get _statusCrewFilter =>
      _crewTypeIds.length == 1 ? _crewTypeIds.first : 'all';

  int? get _statusCapabilityFilter =>
      _tobCapabilityChipIds.length == 1 ? _tobCapabilityChipIds.first : null;

  int get _activeFilterCount =>
      _orgUnitChipIds.length +
      _helicopterTypeIds.length +
      _crewTypeIds.length +
      _tobCapabilityChipIds.length +
      _statusChipFilters.length +
      (_onlyTi ? 1 : 0) +
      (_onlyEtp ? 1 : 0);

  void _clearFilters() {
    setState(() {
      _orgUnitChipIds.clear();
      _helicopterTypeIds.clear();
      _crewTypeIds.clear();
      _tobCapabilityChipIds.clear();
      _statusChipFilters.clear();
      _onlyTi = false;
      _onlyEtp = false;
      _search = '';
      _searchCtrl.clear();
    });
  }

  Future<void> _loadData() async {
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
      flightStatus = await _currencyService.getFlightCurrency(user.id);
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

      final rowStatuses = row.relevantStatuses(
        _statusCrewFilter,
        _statusCapabilityFilter,
      );
      final statusKeys = <String>{
        if (rowStatuses.any((item) => item.isValid)) 'valid',
        if (rowStatuses.any((item) => item.isWarning)) 'warning',
        if (rowStatuses.any((item) => item.isExpired)) 'expired',
      };

      // AND tra le voci; dentro una voce unità e stato sono "almeno uno",
      // le altre seguono _andMode.
      final matchesFilters =
          (_orgUnitChipIds.isEmpty ||
              _orgUnitChipIds.contains(row.user.orgUnitId)) &&
          (_statusChipFilters.isEmpty ||
              _statusChipFilters.any(statusKeys.contains)) &&
          _matchSelectedValues<int>(
            _tobCapabilityChipIds,
            capabilityIds.contains,
          ) &&
          _matchSelectedValues<int>(
            _helicopterTypeIds,
            assignmentHelicopters.contains,
          ) &&
          _matchSelectedValues<String>(_crewTypeIds, assignmentTypes.contains);

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
              '${row.user.fullName} — ${row.relevantStatuses(_statusCrewFilter, _statusCapabilityFilter).where((item) => item.isWarning || item.isExpired).map((item) => item.label).join(' | ')}',
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

  Future<(List<FlightActivity>, List<TobActivity>)> _validatedFlights(
    String userId,
  ) async => (
    (await _activityService.getUserFlightActivities(
      userId,
    )).where((a) => a.isValidated).toList(),
    (await _activityService.getUserTobActivities(
      userId,
    )).where((a) => a.isValidated).toList(),
  );

  Future<void> _showUserDetail(_CrewUserRow initial) async {
    var row = initial;
    var history = _currencyService.getFlightCurrencyHistory(row.user.id);
    var flights = _validatedFlights(row.user.id);
    final adminId = ref.read(authProvider).userProfile!.id;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setD) => _CrewRecordDialog(
          row: row,
          history: history,
          flights: flights,
          adminId: adminId,
          onEmail: () => _launchCrewEmail([row]),
          onCourse: () async {
            Navigator.of(dialogContext).pop();
            if (await registerFlightCourse(context, ref, row.user) && mounted) {
              _loadData();
            }
          },
          onChanged: () async {
            await _loadData();
            if (!dialogContext.mounted) return;
            setD(() {
              row =
                  _rows.where((r) => r.user.id == row.user.id).firstOrNull ??
                  row;
              history = _currencyService.getFlightCurrencyHistory(row.user.id);
              flights = _validatedFlights(row.user.id);
            });
          },
        ),
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
          _statusCapabilityFilter,
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
                    child: Center(child: UserAvatar.fill(user: row.user)),
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
    const statusChips = [
      ('valid', 'GO', AppColors.currencyValid),
      ('warning', 'In scadenza', AppColors.currencyWarning),
      ('expired', 'NO GO', AppColors.currencyExpired),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FiltersHeader(active: _activeFilterCount, onClear: _clearFilters),
            const SizedBox(height: 8),
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Cerca nome o licenza',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
            FilterSection(
              title: 'Stato currency',
              children: [
                for (final (key, label, color) in statusChips)
                  FilterPill(
                    label: label,
                    color: color,
                    selected: _statusChipFilters.contains(key),
                    onTap: () => _toggleStringFilter(_statusChipFilters, key),
                  ),
              ],
            ),
            FilterSection(
              title: 'Tipo equipaggio',
              children: [
                for (final crewType in const ['T', 'TOB', 'MTB'])
                  FilterPill(
                    label: crewType,
                    selected: _crewTypeIds.contains(crewType),
                    onTap: () => _toggleStringFilter(_crewTypeIds, crewType),
                  ),
              ],
            ),
            FilterSection(
              title: 'Unità',
              children: [
                for (final unit in auth.orgUnits)
                  FilterPill(
                    label: unit.code,
                    tooltip: unit.name,
                    selected: _orgUnitChipIds.contains(unit.id),
                    onTap: () => _toggleIntFilter(_orgUnitChipIds, unit.id),
                  ),
              ],
            ),
            FilterSection(
              title: 'Elicotteri',
              children: [
                for (final heli in auth.helicopterTypes)
                  FilterPill(
                    label: heli.code,
                    tooltip: heli.name,
                    selected: _helicopterTypeIds.contains(heli.id),
                    onTap: () => _toggleIntFilter(_helicopterTypeIds, heli.id),
                  ),
              ],
            ),
            FilterSection(
              title: 'Capacità TOB',
              children: [
                for (final cap in auth.tobCapabilityTypes)
                  FilterPill(
                    label: cap.name,
                    selected: _tobCapabilityChipIds.contains(cap.id),
                    onTap: () =>
                        _toggleIntFilter(_tobCapabilityChipIds, cap.id),
                  ),
              ],
            ),
            FilterSection(
              title: 'Qualifiche istruttori',
              children: [
                FilterPill(
                  label: 'Solo TI',
                  selected: _onlyTi,
                  onTap: () => setState(() => _onlyTi = !_onlyTi),
                ),
                FilterPill(
                  label: 'Solo ETP',
                  selected: _onlyEtp,
                  onTap: () => setState(() => _onlyEtp = !_onlyEtp),
                ),
              ],
            ),
            FilterMatchMode(
              all: _andMode,
              onChanged: (value) => setState(() => _andMode = value),
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

    return _buildUserGrid(filteredRows);
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
                  case 'refresh':
                    ref.read(authProvider).sync();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'email',
                  child: Text('Invia avvisi scadenza'),
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
              onPressed: ref.read(authProvider).sync,
              tooltip: 'Aggiorna dal server',
              icon: const Icon(Icons.refresh),
            ),
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
    if (flightStatus != null) statuses.add(flightStatus!);
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

  /// Stato peggiore tra le qualifiche: il badge unico della scheda.
  CurrencyStatus? get worstStatus {
    const rank = {
      CurrencyStatusEnum.expired: 0,
      CurrencyStatusEnum.suspended: 0,
      CurrencyStatusEnum.warning: 1,
      CurrencyStatusEnum.noData: 2,
      CurrencyStatusEnum.valid: 3,
    };
    final s = relevantStatuses('all', null);
    return s.isEmpty
        ? null
        : s.reduce((a, b) => rank[b.status]! < rank[a.status]! ? b : a);
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

/// Scheda equipaggio, sul modello della scheda manutentore (admincsl):
/// una card per elicottero con una riga per qualifica, storico a parte.
class _CrewRecordDialog extends StatelessWidget {
  const _CrewRecordDialog({
    required this.row,
    required this.history,
    required this.flights,
    required this.adminId,
    required this.onEmail,
    required this.onCourse,
    required this.onChanged,
  });

  final _CrewUserRow row;
  final Future<List<CurrencyEvent>> history;
  final Future<(List<FlightActivity>, List<TobActivity>)> flights;
  final String adminId;
  final VoidCallback onEmail;
  final VoidCallback onCourse;
  final Future<void> Function() onChanged;

  static final _df = DateFormat('dd/MM/yyyy');
  static String _fmt(DateTime? d) => d == null ? '-' : _df.format(d);

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w800,
        color: AppColors.secondary,
      ),
    ),
  );

  Widget _statusChip(CurrencyStatus s) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: s.color,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      s.statusText,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
    ),
  );

  Widget _info(IconData icon, String text, [Color? color]) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: color ?? AppColors.textSecondary),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          text,
          style: color == null ? null : TextStyle(color: color),
        ),
      ),
    ],
  );

  Widget _fitness(
    IconData icon,
    String label,
    DateTime? d, {
    bool optional = false,
  }) {
    if (d == null) {
      return _info(
        icon,
        '$label: non inserita',
        optional ? null : AppColors.currencyExpired,
      );
    }
    return _info(icon, '$label: ${_fmt(d)}', expiryBadge(d).$2);
  }

  Widget _qualRow(String title, CurrencyStatus? s) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                s == null
                    ? 'Nessun dato'
                    : '${s.label}  ·  Scadenza: ${_fmt(s.expiryDate)}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (s != null) _statusChip(s),
      ],
    ),
  );

  Widget _heliCard(int heliId) {
    final roles = row.assignments.where((a) => a.helicopterTypeId == heliId);
    final caps = row.tobCapabilities.where((c) => c.helicopterTypeId == heliId);
    final code = roles.firstOrNull?.helicopterCode ?? caps.first.helicopterCode;
    bool has(String t) => roles.any((a) => a.crewType == t);
    final fascia = roles
        .where((a) => a.crewType == 'TOB')
        .map((a) => a.fascia)
        .firstOrNull;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              code,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            if (roles.isNotEmpty)
              _qualRow(
                '${has('T')
                    ? 'T'
                    : has('TOB')
                    ? 'TOB'
                    : 'MTB'} · 3 h a semestre',
                row.flightStatus,
              ),
            if (has('TOB'))
              _qualRow('TOB fascia ${fascia ?? '-'}', row.tobBaseStatus),
            for (final c in caps)
              _qualRow(
                'Capacità: ${c.capabilityName}',
                row.tobStatuses['${c.helicopterTypeId}:${c.tobCapabilityId}'],
              ),
            if (has('MTB')) _qualRow('MTB · poligono', row.mdbStatus),
          ],
        ),
      ),
    );
  }

  Widget _buildQualifications() {
    final heliIds = <int>{
      for (final a in row.assignments) a.helicopterTypeId,
      for (final c in row.tobCapabilities) c.helicopterTypeId,
    }.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Equipaggi e currency'),
        for (final id in heliIds) _heliCard(id),
      ],
    );
  }

  Widget _flightTile(
    BuildContext context, {
    required DateTime date,
    required String title,
    String? description,
    required Future<bool> Function() edit,
    required String what,
    required Future<void> Function() delete,
  }) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              _fmt(date),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if ((description ?? '').isNotEmpty)
                  Text(
                    description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Modifica',
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () async {
              if (await edit()) await onChanged();
            },
          ),
          IconButton(
            tooltip: 'Elimina',
            icon: const Icon(
              Icons.delete_outline,
              size: 20,
              color: AppColors.currencyExpired,
            ),
            onPressed: () async {
              final ok = await confirmAction(
                context,
                'Elimina $what',
                'Eliminare $what del ${_fmt(date)}? La currency verrà ricalcolata.',
                'Elimina',
              );
              if (!ok) return;
              await delete();
              await onChanged();
            },
          ),
        ],
      ),
    ),
  );

  Widget _buildFlights(BuildContext context) {
    final acts = ActivityService();
    String hours(double h) => h > 0 ? '  ·  ${formatHours(h)} h' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle('Voli validati')),
            TextButton.icon(
              onPressed: () async {
                if (await insertFlight(context, row.user.id, adminId)) {
                  await onChanged();
                }
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Volo'),
            ),
          ],
        ),
        FutureBuilder(
          future: flights,
          builder: (_, snap) {
            final data = snap.data;
            if (data == null) return const LinearProgressIndicator();
            final (fl, tob) = data;
            final tiles = <(DateTime, Widget)>[
              for (final a in fl)
                (
                  a.activityDate,
                  _flightTile(
                    context,
                    date: a.activityDate,
                    title:
                        [
                          a.helicopterCode,
                          a.isPoligono ? 'Volo poligono' : 'Volo',
                          ?a.activityType,
                        ].join('  ·  ') +
                        hours(a.flightHours),
                    description: a.description,
                    edit: () => editFlightActivity(context, a),
                    what: 'il volo',
                    delete: () => acts.deleteFlightActivity(a.id!),
                  ),
                ),
              for (final a in tob)
                (
                  a.activityDate,
                  _flightTile(
                    context,
                    date: a.activityDate,
                    title:
                        [
                          a.helicopterCode,
                          'TOB ${a.tobCapabilityId == null ? 'volo base' : a.capabilityName}',
                          ?a.activityType,
                        ].join('  ·  ') +
                        hours(a.flightHours),
                    description: a.description,
                    edit: () => editTobActivity(context, a),
                    what: 'il TOB',
                    delete: () => acts.deleteTobActivity(a.id!),
                  ),
                ),
            ]..sort((a, b) => b.$1.compareTo(a.$1));
            if (tiles.isEmpty) {
              return const Text(
                'Nessun volo validato.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                ),
              );
            }
            return Column(children: [for (final t in tiles) t.$2]);
          },
        ),
      ],
    );
  }

  Widget _buildHistory() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionTitle('Storico currency volo'),
      FutureBuilder(
        future: history,
        builder: (_, snap) => switch (snap.data) {
          null => const LinearProgressIndicator(),
          [] => const Text(
            'Nessun evento.',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
            ),
          ),
          final events => Column(
            children: [
              for (final e in events)
                CurrencyEventTile(e, onDeleted: onChanged),
            ],
          ),
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 1100;
    final user = row.user;
    final email = user.email?.trim() ?? '';
    final worst = row.worstStatus;
    final subtitle = [
      'Lic. ${user.numeroLicenza ?? '-'}',
      user.orgUnitName.isEmpty ? 'Unità non indicata' : user.orgUnitName,
      if (user.isTi) 'TI',
      if (user.isEtp) 'ETP',
      if (user.isPreRegistered) 'non ancora registrato',
    ].join('  ·  ');
    final semester = row.flightStatus;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: wide ? 1280 : 760,
          maxHeight: (size.height - 48).clamp(420, 900),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
              child: Row(
                children: [
                  UserAvatar(user: user, radius: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (worst != null) CurrencyBadgeWidget(status: worst),
                  IconButton(
                    tooltip: 'Registra corso',
                    icon: const Icon(Icons.school_outlined),
                    onPressed: onCourse,
                  ),
                  if (email.isNotEmpty)
                    IconButton(
                      tooltip: 'Invia email',
                      icon: const Icon(Icons.email_outlined),
                      onPressed: onEmail,
                    ),
                  IconButton(
                    tooltip: 'Chiudi',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Container(
              color: AppColors.surfaceVariant.withValues(alpha: 0.35),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Wrap(
                spacing: 28,
                runSpacing: 6,
                children: [
                  _info(
                    Icons.history,
                    'Ultima attività: ${_fmt(row.lastActivityDate)}',
                  ),
                  if (semester?.flightHours != null)
                    _info(
                      Icons.schedule,
                      'Semestre: ${formatHours(semester!.flightHours!)} h'
                      ' / ${formatHours(semester.minFlightHours ?? 0)} h',
                    ),
                  _fitness(
                    Icons.medical_services_outlined,
                    'Idoneità volo',
                    user.flightFitnessExpiry,
                  ),
                  _fitness(Icons.military_tech_outlined, 'SMI', user.smiExpiry),
                  _fitness(
                    Icons.health_and_safety_outlined,
                    'Visita mansione',
                    user.jobFitnessExpiry,
                    optional: true,
                  ),
                ],
              ),
            ),
            if (wide)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 2,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildQualifications(),
                            const SizedBox(height: 16),
                            _buildHistory(),
                          ],
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 3,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: _buildFlights(context),
                      ),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildQualifications(),
                      const SizedBox(height: 20),
                      _buildFlights(context),
                      const SizedBox(height: 20),
                      _buildHistory(),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
