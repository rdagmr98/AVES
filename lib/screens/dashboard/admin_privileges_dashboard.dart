import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app.dart';
import '../../constants/app_constants.dart';
import '../../models/activity_models.dart';
import '../../models/reference_models.dart';
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
import '../../widgets/date_range_dialog.dart';
import '../../widgets/filter_panel.dart';
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
  final List<int> _orgUnitChipIds = [];
  final List<int> _licenseTypeChipIds = [];
  final List<String> _statusChipFilters = [];
  final List<int> _helicopterTypeIds = [];
  final List<int> _privilegeTypeIds = [];
  bool _andMode = false;
  bool _gridView = true;
  bool _onlyTi = false;
  bool _onlyEtp = false;
  _MaintenanceSortMode _sortMode = _MaintenanceSortMode.status;
  // Elicotteri su cui si calcola GO / NO GO; null = tutti.
  Set<int>? _goHeliIds;

  @override
  void initState() {
    super.initState();
    _loadGoHeliIds().then((ids) {
      _goHeliIds = ids;
      if (mounted) _loadData();
    });
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
      return true;
    }
    return _andMode ? selected.every(predicate) : selected.any(predicate);
  }

  int get _activeFilterCount =>
      _orgUnitChipIds.length +
      _licenseTypeChipIds.length +
      _statusChipFilters.length +
      _helicopterTypeIds.length +
      _privilegeTypeIds.length +
      (_onlyTi ? 1 : 0) +
      (_onlyEtp ? 1 : 0);

  void _clearFilters() {
    setState(() {
      _orgUnitChipIds.clear();
      _licenseTypeChipIds.clear();
      _statusChipFilters.clear();
      _helicopterTypeIds.clear();
      _privilegeTypeIds.clear();
      _onlyTi = false;
      _onlyEtp = false;
      _search = '';
      _searchCtrl.clear();
    });
  }

  static const _matrixDefaultHeliPrefsKey =
      'privilege_matrix_default_helicopter_ids';

  Future<Set<int>> _loadDefaultHeliIds(
    List<HelicopterType> helicopterTypes,
  ) async {
    final allIds = helicopterTypes.map((h) => h.id).toSet();
    // Filtro elicottero attivo in dashboard: ha sempre priorità sul
    // predefinito salvato, altrimenti un elicottero escluso a schermo
    // rischia di rientrare nel PDF tramite un vecchio "predefinito".
    if (_helicopterTypeIds.isNotEmpty) {
      return _helicopterTypeIds.toSet();
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_matrixDefaultHeliPrefsKey);
    if (saved == null) {
      return _goHeliIds?.toSet() ?? allIds;
    }
    if (saved.length == 1 && saved.first == 'all') {
      return allIds;
    }
    final restored = saved.map(int.parse).where(allIds.contains).toSet();
    return restored.isEmpty ? allIds : restored;
  }

  Future<void> _saveDefaultHeliIds(Set<int> ids, int totalCount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _matrixDefaultHeliPrefsKey,
      ids.length == totalCount
          ? ['all']
          : ids.map((id) => id.toString()).toList(),
    );
  }

  // Preferenza nel profilo dell'admin (UserService.viewHelicopterIds): vale
  // su ogni dispositivo e filtra anche le sue notifiche privilegio scaduto.
  Future<Set<int>?> _loadGoHeliIds() async {
    final userId = ref.read(authProvider).userProfile?.id;
    return userId == null ? null : _userService.viewHelicopterIds(userId);
  }

  Future<void> _saveGoHeliIds(Set<int>? ids) async {
    final userId = ref.read(authProvider).userProfile?.id;
    if (userId != null) await _userService.setViewHelicopterIds(userId, ids);
  }

  String _goHeliSummary(List<HelicopterType> helicopterTypes) {
    final ids = _goHeliIds;
    if (ids == null) return 'Tutti';
    return helicopterTypes
        .where((h) => ids.contains(h.id))
        .map((h) => h.code)
        .join(', ');
  }

  /// [save]: da Opzioni, solo "Salva" (sempre nel profilo); dalla dashboard
  /// anche "Applica" per la sola sessione.
  Future<void> _chooseGoHelicopters({bool save = false}) async {
    final helicopterTypes = ref.read(authProvider).helicopterTypes;
    final selected = (_goHeliIds ?? helicopterTypes.map((h) => h.id)).toSet();
    var saveAsDefault = save;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Elicotteri da mostrare'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Privilegi e licenze degli altri elicotteri non incidono '
                  'sullo stato GO / NO GO. '
                  '${save ? 'La scelta' : 'Con "Imposta predefiniti" la scelta'} '
                  'resta nel tuo profilo e vale anche per le tendine '
                  'elicotteri e per le notifiche di privilegio scaduto.',
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setDialogState(
                      () => selected.length == helicopterTypes.length
                          ? selected.clear()
                          : selected.addAll(helicopterTypes.map((h) => h.id)),
                    ),
                    child: Text(
                      selected.length == helicopterTypes.length
                          ? 'Deseleziona tutti'
                          : 'Seleziona tutti',
                    ),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: helicopterTypes
                        .map(
                          (heli) => CheckboxListTile(
                            dense: true,
                            title: Text(
                              heli.code,
                              overflow: TextOverflow.ellipsis,
                            ),
                            value: selected.contains(heli.id),
                            onChanged: (checked) => setDialogState(() {
                              if (checked == true) {
                                selected.add(heli.id);
                              } else {
                                selected.remove(heli.id);
                              }
                            }),
                          ),
                        )
                        .toList(),
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
            if (!save)
              TextButton.icon(
                onPressed: selected.isEmpty
                    ? null
                    : () {
                        saveAsDefault = true;
                        Navigator.of(ctx).pop(true);
                      },
                icon: const Icon(Icons.bookmark_outline, size: 18),
                label: const Text('Imposta predefiniti'),
              ),
            ElevatedButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.of(ctx).pop(true),
              child: Text(save ? 'Salva' : 'Applica'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final ids = selected.length == helicopterTypes.length ? null : selected;
    if (saveAsDefault) {
      await _saveGoHeliIds(ids);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elicotteri da mostrare salvati')),
      );
    }
    setState(() => _goHeliIds = ids);
    await _loadData();
  }

  Future<void> _printPrivilegeMatrix() async {
    final helicopterTypes = ref.read(authProvider).helicopterTypes;
    final selectedHeliIds = await _loadDefaultHeliIds(helicopterTypes);
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Matrice Privilegi'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('Elicotteri'),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setDialogState(
                        () => selectedHeliIds.length == helicopterTypes.length
                            ? selectedHeliIds.clear()
                            : selectedHeliIds.addAll(
                                helicopterTypes.map((h) => h.id),
                              ),
                      ),
                      child: Text(
                        selectedHeliIds.length == helicopterTypes.length
                            ? 'Deseleziona tutti'
                            : 'Seleziona tutti',
                      ),
                    ),
                  ],
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: helicopterTypes
                        .map(
                          (heli) => CheckboxListTile(
                            dense: true,
                            title: Text(heli.code),
                            value: selectedHeliIds.contains(heli.id),
                            onChanged: (checked) => setDialogState(() {
                              if (checked == true) {
                                selectedHeliIds.add(heli.id);
                              } else {
                                selectedHeliIds.remove(heli.id);
                              }
                            }),
                          ),
                        )
                        .toList(),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: selectedHeliIds.isEmpty
                        ? null
                        : () async {
                            await _saveDefaultHeliIds(
                              selectedHeliIds,
                              helicopterTypes.length,
                            );
                            if (!ctx.mounted) return;
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Selezione salvata come predefinita',
                                ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.bookmark_outline, size: 18),
                    label: const Text('Imposta predefiniti'),
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
            ElevatedButton(
              onPressed: selectedHeliIds.isEmpty
                  ? null
                  : () => Navigator.of(ctx).pop(true),
              child: const Text('Stampa'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await _reportService.downloadPrivilegeMatrix(
      orgUnitId: _orgUnitChipIds.length == 1 ? _orgUnitChipIds.first : null,
      helicopterTypeIds: selectedHeliIds.length == helicopterTypes.length
          ? null
          : selectedHeliIds.toList(),
      licenseTypeId: _licenseTypeChipIds.length == 1
          ? _licenseTypeChipIds.first
          : null,
    );
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final users = await _userService.getAllUsers();
    final pendingActivities = await _activityService
        .getPendingMaintenanceActivities();
    final pendingSeminars = await _activityService
        .getPendingSeminarActivities();
    final rows = <_MaintenanceUserRow>[];
    final scope = _goHeliIds;

    for (final user in users.where((item) => item.isApprovedMaint)) {
      final licenses = (await _userService.getUserLicenses(user.id))
          .where((l) => scope == null || scope.contains(l.helicopterTypeId))
          .toList();
      final privileges = (await _userService.getUserPrivileges(user.id))
          .where((p) => scope == null || scope.contains(p.helicopterTypeId))
          .toList();
      if (licenses.isEmpty && privileges.isEmpty) {
        continue;
      }
      final status = await _currencyService.getMaintenanceCurrency(
        user.id,
        helicopterTypeIds: scope,
      );
      final lastActivity = await _activityService.getLastValidatedMaintenance(
        user.id,
      );

      final perPrivilegeCurrency = await _currencyService
          .getPerPrivilegeCurrency(user.id, helicopterTypeIds: scope);

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
      _pendingActivities = pendingActivities.length + pendingSeminars.length;
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

      final licenseTypes = row.licenses
          .map((item) => item.licenseTypeId)
          .toSet();
      // AND tra le voci; dentro una voce: unità e stato sono valori unici
      // (sempre "almeno uno"), le altre seguono _andMode.
      final matchesFilters =
          (_orgUnitChipIds.isEmpty ||
              _orgUnitChipIds.contains(row.user.orgUnitId)) &&
          (_statusChipFilters.isEmpty ||
              _statusChipFilters.contains(rowStatusKey)) &&
          _matchSelectedValues<int>(
            _licenseTypeChipIds,
            licenseTypes.contains,
          ) &&
          _matchSelectedValues<int>(
            _helicopterTypeIds,
            privilegeHelicopters.contains,
          ) &&
          _matchSelectedValues<int>(_privilegeTypeIds, privilegeTypes.contains);

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
      builder: (_) => _ServiceRecordDialog(
        initialRow: row,
        reload: () async {
          await _loadData();
          return _rows.where((r) => r.user.id == row.user.id).firstOrNull;
        },
        onEmail: (r) => _launchMaintenanceEmail([r]),
        privilegeTypes: ref.read(authProvider).privilegeTypes,
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
                          style: const TextStyle(fontSize: 13),
                        ),
                        Text(
                          row.user.cognome,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
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
              leading: const Icon(Icons.grid_on_outlined),
              title: const Text('Matrice Privilegi'),
              onTap: () {
                Navigator.of(context).pop();
                _printPrivilegeMatrix();
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
              leading: const Icon(Icons.tune),
              title: const Text('Opzioni'),
              onTap: () {
                Navigator.of(context).pop();
                _openOptions();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openOptions() async {
    final helicopterTypes = ref.read(authProvider).helicopterTypes;
    final action = await showDialog<VoidCallback>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Opzioni'),
        children: [
          ListTile(
            leading: const Icon(Icons.account_tree_outlined),
            title: const Text('Unità organizzative'),
            onTap: () => Navigator.of(ctx).pop(_manageOrgUnits),
          ),
          ListTile(
            leading: const Icon(Icons.build_outlined),
            title: const Text('Tipi di attività OL'),
            onTap: () => Navigator.of(ctx).pop(_manageActivityTypes),
          ),
          ListTile(
            leading: const Icon(Icons.flight_outlined),
            title: const Text('Elicotteri da mostrare'),
            subtitle: Text(
              _goHeliSummary(helicopterTypes),
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () =>
                Navigator.of(ctx).pop(() => _chooseGoHelicopters(save: true)),
          ),
        ],
      ),
    );
    action?.call();
  }

  Future<void> _manageActivityTypes() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final types = _userService.getActivityTypes();
          Future<void> edit(String? old) async {
            if (await _editActivityType(old)) setDialogState(() {});
          }

          return AlertDialog(
            title: const Text('Tipi di attività OL'),
            content: SizedBox(
              width: 480,
              height: 420,
              child: ListView(
                children: [
                  for (final t in types)
                    ListTile(
                      title: Text(t, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.edit_outlined, size: 18),
                      onTap: () => edit(t),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () => edit(null),
                icon: const Icon(Icons.add),
                label: const Text('Nuovo tipo'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Chiudi'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// true se la lista dei tipi attività è cambiata.
  Future<bool> _editActivityType(String? old) async {
    final ctrl = TextEditingController(text: old);
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          old == null ? 'Nuovo tipo attività' : 'Modifica tipo attività',
        ),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
        ),
        actions: [
          if (old != null)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () => Navigator.of(ctx).pop('delete'),
              child: const Text('Elimina'),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('save'),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
    final value = ctrl.text;
    ctrl.dispose();
    if (choice == null) return false;
    try {
      await _userService.saveActivityType(
        old: old,
        value: choice == 'delete' ? null : value,
      );
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
      return false;
    }
  }

  Future<void> _manageOrgUnits() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final units = ref.read(authProvider).orgUnits;
          Future<void> edit(OrgUnit? unit) async {
            if (await _editOrgUnit(unit)) setDialogState(() {});
          }

          return AlertDialog(
            title: const Text('Unità organizzative'),
            content: SizedBox(
              width: 480,
              height: 420,
              child: ListView(
                children: [
                  for (final u in units)
                    ListTile(
                      leading: SizedBox(
                        width: 64,
                        child: Text(
                          u.code,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      title: Text(u.name, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.edit_outlined, size: 18),
                      onTap: () => edit(u),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () => edit(null),
                icon: const Icon(Icons.add),
                label: const Text('Nuova unità'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Chiudi'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// true se l'unità è stata salvata.
  Future<bool> _editOrgUnit(OrgUnit? unit) async {
    final codeCtrl = TextEditingController(text: unit?.code);
    final nameCtrl = TextEditingController(text: unit?.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(unit == null ? 'Nuova unità' : 'Modifica unità'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Sigla'),
              ),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nome'),
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
            child: const Text('Salva'),
          ),
        ],
      ),
    );
    final code = codeCtrl.text;
    final name = nameCtrl.text;
    codeCtrl.dispose();
    nameCtrl.dispose();
    if (ok != true) return false;
    try {
      await UserService().saveOrgUnit(id: unit?.id, code: code, name: name);
      await ref.read(authProvider).reloadOrgUnits();
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
      return false;
    }
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
                              if (item.helicopterTypeId == id) {
                                return item.helicopterCode;
                              }
                            }
                            for (final item in row.privileges) {
                              if (item.helicopterTypeId == id) {
                                return item.helicopterCode;
                              }
                            }
                            for (final item in row.perPrivilegeCurrency) {
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
            const SizedBox(height: 4),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flight, size: 20),
              title: const Text(
                'Elicotteri da mostrare',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                _goHeliSummary(auth.helicopterTypes),
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.tune, size: 20),
              onTap: _chooseGoHelicopters,
            ),
            FilterSection(
              title: 'Stato currency',
              children: [
                for (final (key, label, color) in statusChips)
                  FilterPill(
                    label: label,
                    color: color,
                    selected: _statusChipFilters.contains(key),
                    onTap: () => _toggleFilterValue(_statusChipFilters, key),
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
                    onTap: () => _toggleFilterId(_orgUnitChipIds, unit.id),
                  ),
              ],
            ),
            FilterSection(
              title: 'Licenza',
              children: [
                for (final item in auth.licenseTypes)
                  FilterPill(
                    label: item.code,
                    tooltip: item.name,
                    selected: _licenseTypeChipIds.contains(item.id),
                    onTap: () => _toggleFilterId(_licenseTypeChipIds, item.id),
                  ),
              ],
            ),
            FilterSection(
              title: 'Elicotteri',
              children: [
                for (final heli in auth.helicopterTypes)
                  if (_goHeliIds?.contains(heli.id) ?? true)
                    FilterPill(
                      label: heli.code,
                      tooltip: heli.name,
                      selected: _helicopterTypeIds.contains(heli.id),
                      onTap: () => _toggleFilterId(_helicopterTypeIds, heli.id),
                    ),
              ],
            ),
            FilterSection(
              title: 'Privilegi',
              children: [
                for (final priv in auth.privilegeTypes)
                  FilterPill(
                    label: priv.code,
                    tooltip: priv.name,
                    selected: _privilegeTypeIds.contains(priv.id),
                    onTap: () => _toggleFilterId(_privilegeTypeIds, priv.id),
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
              label: 'Inserisci Attività',
              icon: Icons.add_task_outlined,
              onTap: () => context.go('/admin/insert'),
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
              label: 'Matrice Privilegi',
              icon: Icons.grid_on_outlined,
              onTap: _printPrivilegeMatrix,
            ),
            const SizedBox(height: 8),
            _NavButton(label: 'Opzioni', icon: Icons.tune, onTap: _openOptions),
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

/// Scheda "stato di servizio" dell'utente: privilegi con currency a sinistra,
/// attività manutentive validate (ricerca, filtri, modifica, eliminazione)
/// a destra. A tutto schermo su desktop, colonna unica su schermi stretti.
class _ServiceRecordDialog extends ConsumerStatefulWidget {
  const _ServiceRecordDialog({
    required this.initialRow,
    required this.reload,
    required this.onEmail,
    required this.privilegeTypes,
  });

  final _MaintenanceUserRow initialRow;
  final Future<_MaintenanceUserRow?> Function() reload;
  final void Function(_MaintenanceUserRow row) onEmail;
  final List<PrivilegeType> privilegeTypes;

  @override
  ConsumerState<_ServiceRecordDialog> createState() =>
      _ServiceRecordDialogState();
}

class _ServiceRecordDialogState extends ConsumerState<_ServiceRecordDialog> {
  static final _df = DateFormat('dd/MM/yyyy');
  final _activityService = ActivityService();
  final _userService = UserService();
  final _searchCtrl = TextEditingController();
  late _MaintenanceUserRow _row = widget.initialRow;
  List<MaintenanceActivity> _acts = [];
  List<SeminarActivity> _seminars = [];
  bool _loading = true;
  String _query = '';
  int? _heliId;
  int? _privId; // -1 = attività registrate su "Tutti i privilegi"
  DateTimeRange? _period;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadActivities() async {
    final userId = _row.user.id;
    final acts = await _activityService.getUserMaintenanceActivities(userId);
    final seminars = await _activityService.getUserSeminarActivities(userId);
    if (!mounted) return;
    setState(() {
      _acts = acts.where((a) => a.isValidated).toList();
      _seminars = seminars.where((s) => s.isValidated).toList();
      _loading = false;
    });
  }

  Future<void> _afterChange() async {
    final row = await widget.reload();
    if (!mounted) return;
    if (row != null) setState(() => _row = row);
    await _loadActivities();
  }

  String _fmt(DateTime? d) => d == null ? '-' : _df.format(d);

  List<MaintenanceActivity> get _filtered {
    final q = _query.trim().toLowerCase();
    return _acts.where((a) {
      if (_heliId != null && a.helicopterTypeId != _heliId) return false;
      if (_privId != null && (a.privilegeTypeId ?? -1) != _privId) {
        return false;
      }
      final period = _period;
      if (period != null &&
          (a.effectiveDate.isBefore(period.start) ||
              (a.dateFrom ?? a.activityDate).isAfter(period.end))) {
        return false;
      }
      if (q.isEmpty) return true;
      return [
        a.helicopterCode,
        a.privilegeName,
        a.description,
        a.ordineLavoro,
        a.matricolaMilitare,
        a.numeroCorrozzella,
        _fmt(a.activityDate),
        _fmt(a.dateFrom),
        _fmt(a.dateTo),
      ].any((v) => (v ?? '').toLowerCase().contains(q));
    }).toList();
  }

  Future<bool> _confirm(String title, String message, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _removePrivilege(PrivilegeCurrencyStatus ps) async {
    final ok = await _confirm(
      'Conferma rimozione',
      'Vuoi rimuovere il privilegio ${ps.privilegeName} su ${ps.helicopterCode} dall\'utente ${_row.user.fullName}? L\'utente tornerà GO se questo era l\'unico privilegio scaduto.',
      'Rimuovi',
    );
    if (!ok) return;
    await _userService.removePrivilege(
      _row.user.id,
      ps.helicopterTypeId,
      ps.privilegeTypeId,
    );
    await _afterChange();
  }

  /// Assegna/toglie privilegi su un elicottero (heliId null = da scegliere).
  Future<void> _editPrivileges([int? heliId]) async {
    final userId = _row.user.id;
    final current = await _userService.getUserPrivileges(userId);
    if (!mounted) return;
    Set<int> assigned(int? h) => {
      for (final p in current)
        if (p.helicopterTypeId == h) p.privilegeTypeId,
    };
    final helis = ref.read(authProvider).visibleHelicopters(keep: heliId);
    var heli = heliId ?? helis.firstOrNull?.id;
    var selected = assigned(heli);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: Text(
            heliId == null ? 'Aggiungi privilegi' : 'Modifica privilegi',
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Elicottero', style: TextStyle(fontSize: 12)),
                  DropdownButton<int>(
                    value: heli,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(14),
                    dropdownColor: AppColors.surfaceVariant,
                    items: [
                      for (final h in helis)
                        DropdownMenuItem(
                          value: h.id,
                          child: Text(h.code, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: heliId != null
                        ? null
                        : (v) => setD(() {
                            heli = v;
                            selected = assigned(v);
                          }),
                  ),
                  const SizedBox(height: 8),
                  for (final p in widget.privilegeTypes)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: selected.contains(p.id),
                      title: Text(p.name, overflow: TextOverflow.ellipsis),
                      onChanged: (v) => setD(
                        () => v == true
                            ? selected.add(p.id)
                            : selected.remove(p.id),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
    final h = heli;
    if (ok != true || h == null) return;
    final before = assigned(h);
    for (final id in before.difference(selected)) {
      await _userService.removePrivilege(userId, h, id);
    }
    final added = selected.difference(before);
    if (added.isNotEmpty) {
      await _userService.setUserPrivileges(userId, [
        for (final id in added)
          {'helicopter_type_id': h, 'privilege_type_id': id},
      ], append: true);
    }
    await _afterChange();
  }

  Future<void> _deleteActivity(MaintenanceActivity a) async {
    final ok = await _confirm(
      'Elimina attività',
      'Eliminare l\'attività del ${_fmt(a.effectiveDate)} su ${a.helicopterCode} (${a.privilegeName})? La currency verrà ricalcolata.',
      'Elimina',
    );
    if (!ok) return;
    await _activityService.deleteMaintenanceActivity(a.id!);
    await _afterChange();
  }

  Future<void> _deleteSeminar(SeminarActivity s) async {
    final ok = await _confirm(
      'Elimina seminario',
      'Eliminare il seminario ${s.seminarType.replaceAll('_', '/')} del ${_fmt(s.seminarDate)}? Senza seminario valido l\'utente risulta NO GO.',
      'Elimina',
    );
    if (!ok) return;
    await _activityService.deleteSeminarActivity(s.id!);
    await _afterChange();
  }

  Future<void> _editActivity(MaintenanceActivity a) async {
    final heliOptions = <int, String>{
      for (final l in _row.licenses) l.helicopterTypeId: l.helicopterCode,
      for (final p in _row.privileges) p.helicopterTypeId: p.helicopterCode,
      a.helicopterTypeId: a.helicopterCode,
    };
    var heliId = a.helicopterTypeId;
    var privId = a.privilegeTypeId;
    var date = a.activityDate;
    var from = a.dateFrom;
    var to = a.dateTo;
    // ponytail: controller non disposti, il dialog li usa ancora durante
    // l'animazione di chiusura; il GC li raccoglie.
    final desc = TextEditingController(text: a.description ?? '');
    final odl = TextEditingController(text: a.ordineLavoro ?? '');
    final mm = TextEditingController(text: a.matricolaMilitare ?? '');
    final corr = TextEditingController(text: a.numeroCorrozzella ?? '');
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) {
          final privOptions = <int?, String>{
            null: 'Tutti i privilegi',
            for (final p in _row.privileges.where(
              (p) => p.helicopterTypeId == heliId,
            ))
              p.privilegeTypeId: p.privilegeName,
            if (heliId == a.helicopterTypeId && a.privilegeTypeId != null)
              a.privilegeTypeId: a.privilegeName,
          };
          if (!privOptions.containsKey(privId)) privId = null;

          Widget label(String text) => Padding(
            padding: const EdgeInsets.only(bottom: 4, top: 12),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          );

          Widget dateField(
            String text,
            DateTime? value,
            void Function(DateTime? d) onChanged, {
            bool clearable = true,
          }) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label(text),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event, size: 18),
                      label: Text(_fmt(value)),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: c,
                          initialDate: value ?? date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (d != null) setD(() => onChanged(d));
                      },
                    ),
                  ),
                  if (clearable && value != null)
                    IconButton(
                      tooltip: 'Azzera',
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setD(() => onChanged(null)),
                    ),
                ],
              ),
            ],
          );

          Widget textField(String text, TextEditingController ctrl) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label(text),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(isDense: true),
              ),
            ],
          );

          return AlertDialog(
            title: const Text('Modifica attività'),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: dateField(
                            'Data attività',
                            date,
                            (d) => date = d ?? date,
                            clearable: false,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: dateField('Dal', from, (d) => from = d),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: dateField('Al', to, (d) => to = d)),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              label('Elicottero'),
                              DropdownButton<int>(
                                borderRadius: BorderRadius.circular(14),
                                dropdownColor: AppColors.surfaceVariant,
                                value: heliId,
                                isExpanded: true,
                                items: [
                                  for (final e in heliOptions.entries)
                                    DropdownMenuItem(
                                      value: e.key,
                                      child: Text(e.value),
                                    ),
                                ],
                                onChanged: (v) {
                                  if (v != null) setD(() => heliId = v);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              label('Privilegio'),
                              DropdownButton<int?>(
                                borderRadius: BorderRadius.circular(14),
                                dropdownColor: AppColors.surfaceVariant,
                                value: privId,
                                isExpanded: true,
                                items: [
                                  for (final e in privOptions.entries)
                                    DropdownMenuItem(
                                      value: e.key,
                                      child: Text(
                                        e.value,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (v) => setD(() => privId = v),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    label('Descrizione'),
                    TextField(
                      controller: desc,
                      maxLines: 3,
                      decoration: const InputDecoration(isDense: true),
                    ),
                    Row(
                      children: [
                        Expanded(child: textField('Ordine di lavoro', odl)),
                        const SizedBox(width: 12),
                        Expanded(child: textField('Matricola militare', mm)),
                        const SizedBox(width: 12),
                        Expanded(child: textField('N. corrozzella', corr)),
                      ],
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: const TextStyle(
                          color: AppColors.currencyExpired,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(c).pop(false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () {
                  final f = from;
                  final t = to;
                  if (f != null && t != null && f.isAfter(t)) {
                    setD(() => error = 'La data "Dal" è successiva ad "Al".');
                    return;
                  }
                  Navigator.of(c).pop(true);
                },
                child: const Text('Salva'),
              ),
            ],
          );
        },
      ),
    );
    if (saved != true) return;

    String? text(TextEditingController ctrl) =>
        ctrl.text.trim().isEmpty ? null : ctrl.text.trim();
    String? iso(DateTime? d) => d?.toIso8601String().split('T').first;
    await _activityService.updateMaintenanceActivity(a.id!, {
      'activity_date': iso(date),
      'date_from': iso(from),
      'date_to': iso(to),
      'helicopter_type_id': heliId,
      'privilege_type_id': privId,
      'description': text(desc),
      'ordine_lavoro': text(odl),
      'matricola_militare': text(mm),
      'numero_corrozzella': text(corr),
    });
    await _afterChange();
  }

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

  Widget _statusChip(CurrencyStatus status) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: status.isExpired
          ? const Color(0xFFC0392B)
          : status.isWarning
          ? const Color(0xFFE67E22)
          : const Color(0xFF27AE60),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      status.statusText,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
    ),
  );

  Widget _info(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: AppColors.textSecondary),
      const SizedBox(width: 6),
      Flexible(child: Text(text)),
    ],
  );

  Widget _heliCard(int heliId, List<PrivilegeCurrencyStatus> privileges) {
    final licenses = _row.licenses
        .where((l) => l.helicopterTypeId == heliId)
        .toList();
    final heliCode = privileges.isNotEmpty
        ? privileges.first.helicopterCode
        : licenses.first.helicopterCode;
    final cat = licenses.isNotEmpty
        ? '  ·  Cat. ${licenses.first.licenseCode}'
        : '';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$heliCode$cat',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Modifica privilegi',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () => _editPrivileges(heliId),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (privileges.isEmpty)
              const Text(
                'Nessun privilegio assegnato.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            for (final ps in privileges)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ps.privilegeName),
                          Text(
                            'Scadenza: ${_fmt(ps.status.expiryDate)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (ps.status.isExpired)
                      IconButton(
                        tooltip: 'Rimuovi privilegio scaduto',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.remove_circle_outline, size: 18),
                        onPressed: () => _removePrivilege(ps),
                      ),
                    const SizedBox(width: 6),
                    _statusChip(ps.status),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivileges() {
    final groups = <int, List<PrivilegeCurrencyStatus>>{};
    for (final ps in _row.perPrivilegeCurrency) {
      groups.putIfAbsent(ps.helicopterTypeId, () => []).add(ps);
    }
    for (final lic in _row.licenses) {
      groups.putIfAbsent(lic.helicopterTypeId, () => []);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle('Licenze e privilegi')),
            TextButton.icon(
              onPressed: _editPrivileges,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Aggiungi'),
            ),
          ],
        ),
        if (groups.isEmpty)
          const Text('Nessuna licenza o privilegio assegnato.'),
        for (final e in groups.entries) _heliCard(e.key, e.value),
        const SizedBox(height: 16),
        _sectionTitle('Seminari validati'),
        if (_seminars.isEmpty)
          const Text(
            'Nessun seminario validato.',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
            ),
          ),
        for (final s in _seminars)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.school_outlined),
            title: Text(
              '${s.seminarType.replaceAll('_', '/')}  ·  ${_fmt(s.seminarDate)}',
            ),
            subtitle: (s.description ?? '').isEmpty
                ? null
                : Text(s.description!),
            trailing: IconButton(
              tooltip: 'Elimina seminario',
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: AppColors.currencyExpired,
              ),
              onPressed: () => _deleteSeminar(s),
            ),
          ),
      ],
    );
  }

  Widget _activityTile(MaintenanceActivity a) {
    final hasRange = a.dateFrom != null || a.dateTo != null;
    final refs = [
      if ((a.ordineLavoro ?? '').isNotEmpty) 'OdL ${a.ordineLavoro}',
      if ((a.matricolaMilitare ?? '').isNotEmpty) 'MM ${a.matricolaMilitare}',
      if ((a.numeroCorrozzella ?? '').isNotEmpty)
        'Corr. ${a.numeroCorrozzella}',
    ].join('  ·  ');
    const small = TextStyle(fontSize: 12, color: AppColors.textSecondary);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: Text(
                _fmt(a.effectiveDate),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${a.helicopterCode}  ·  ${a.privilegeName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (hasRange)
                    Text(
                      'dal ${_fmt(a.dateFrom ?? a.activityDate)} al ${_fmt(a.effectiveDate)}',
                      style: small,
                    ),
                  if ((a.description ?? '').isNotEmpty)
                    Text(
                      a.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (refs.isNotEmpty)
                    Text(
                      refs,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: small,
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Modifica',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _editActivity(a),
            ),
            IconButton(
              tooltip: 'Elimina',
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: AppColors.currencyExpired,
              ),
              onPressed: () => _deleteActivity(a),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivities({required bool scrollable}) {
    final items = _filtered;
    final heliOptions = <int, String>{
      for (final a in _acts) a.helicopterTypeId: a.helicopterCode,
    };
    final privOptions = <int, String>{
      for (final a in _acts)
        if (_heliId == null || a.helicopterTypeId == _heliId)
          a.privilegeTypeId ?? -1: a.privilegeName,
    };
    final filtersActive =
        _query.isNotEmpty ||
        _heliId != null ||
        _privId != null ||
        _period != null;

    final filters = Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Cerca OdL, matricola, descrizione...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        DropdownButton<int?>(
          borderRadius: BorderRadius.circular(14),
          dropdownColor: AppColors.surfaceVariant,
          value: heliOptions.containsKey(_heliId) ? _heliId : null,
          items: [
            const DropdownMenuItem(value: null, child: Text('Ogni elicottero')),
            for (final e in heliOptions.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => setState(() {
            _heliId = v;
            _privId = null;
          }),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: DropdownButton<int?>(
            borderRadius: BorderRadius.circular(14),
            dropdownColor: AppColors.surfaceVariant,
            value: privOptions.containsKey(_privId) ? _privId : null,
            isExpanded: true,
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Ogni privilegio'),
              ),
              for (final e in privOptions.entries)
                DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _privId = v),
          ),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.date_range, size: 18),
          label: Text(
            _period == null
                ? 'Periodo'
                : '${_fmt(_period!.start)} – ${_fmt(_period!.end)}',
          ),
          onPressed: () async {
            final r = await showDateRangeDialog(
              context,
              firstDate: DateTime(2000),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              initialDateRange: _period,
            );
            if (r != null) setState(() => _period = r);
          },
        ),
        if (filtersActive)
          TextButton.icon(
            icon: const Icon(Icons.filter_alt_off, size: 18),
            label: const Text('Azzera filtri'),
            onPressed: () {
              _searchCtrl.clear();
              setState(() {
                _query = '';
                _heliId = null;
                _privId = null;
                _period = null;
              });
            },
          ),
      ],
    );

    final header = <Widget>[
      _sectionTitle('Attività manutentive validate'),
      filters,
      const SizedBox(height: 8),
      Text(
        '${items.length} di ${_acts.length} attività',
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 8),
    ];
    final empty = Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          _acts.isEmpty
              ? 'Nessuna attività validata.'
              : 'Nessuna attività corrisponde ai filtri.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...header,
        if (items.isEmpty)
          empty
        else if (scrollable)
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) => _activityTile(items[i]),
            ),
          )
        else
          ...items.map(_activityTile),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 1100;
    final user = _row.user;
    final email = user.email?.trim() ?? '';
    final subtitle = [
      'Lic. ${user.numeroLicenza ?? '-'}',
      user.orgUnitName.isEmpty ? 'Unità non indicata' : user.orgUnitName,
      if (user.isPreRegistered) 'non ancora registrato',
    ].join('  ·  ');

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: wide ? 1480 : 760,
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
                  CurrencyBadgeWidget(status: _row.status),
                  if (email.isNotEmpty)
                    IconButton(
                      tooltip: 'Invia email',
                      icon: const Icon(Icons.email_outlined),
                      onPressed: () => widget.onEmail(_row),
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
                  _info(Icons.info_outline, _row.status.label),
                  _info(
                    Icons.history,
                    'Ultima attività: ${_fmt(_row.lastActivityDate)}',
                  ),
                  _info(
                    Icons.event,
                    'Scadenza: ${_fmt(_row.status.expiryDate)}',
                  ),
                  _info(
                    Icons.build_outlined,
                    'Attività validate: ${_acts.length}',
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
                        child: _buildPrivileges(),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: _buildActivities(scrollable: true),
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
                      _buildPrivileges(),
                      const SizedBox(height: 20),
                      _buildActivities(scrollable: false),
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
