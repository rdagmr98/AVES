import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../models/reference_models.dart';
import '../../models/user_models.dart';
import '../../services/user_service.dart';
import '../../widgets/admin_app_bar_leading.dart';
import '../../widgets/privilege_selection_dialog.dart';
import '../../widgets/user_avatar.dart';

// ─────────────────────────────────────────────────────────────
// Main screen: filters + list only
// ─────────────────────────────────────────────────────────────

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  final _service = UserService();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  List<UserProfile> _users = [];
  List<AccountDeletionRequest> _deletionRequests = [];
  String _search = '';
  int? _orgUnitId;
  String _approvalFilter = 'all';

  // kept only for desktop side-by-side selection
  UserProfile? _selectedUser;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    final users = await _service.getAllUsers();
    final deletionRequests = await _service.getDeletionRequests(
      onlyPending: true,
    );
    if (!mounted) return;
    setState(() {
      _users = users;
      _deletionRequests = deletionRequests;
      _loading = false;
    });
    // On desktop keep the previously selected user in sync
    if (_selectedUser != null && users.isNotEmpty) {
      final matched = users.firstWhere(
        (u) => u.id == _selectedUser!.id,
        orElse: () => users.first,
      );
      await _selectUser(matched);
    }
  }

  Future<void> _rejectDeletionRequest(AccountDeletionRequest request) async {
    final adminId = ref.read(authProvider).userProfile?.id;
    if (adminId == null) {
      return;
    }
    try {
      await _service.rejectDeletionRequest(request.id!, adminId);
      await _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Richiesta eliminazione rifiutata.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _approveDeletionRequest(AccountDeletionRequest request) async {
    final adminId = ref.read(authProvider).userProfile?.id;
    if (adminId == null) {
      return;
    }
    try {
      await _service.approveDeletionRequest(request.id!, adminId);
      await _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Utente eliminato.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _selectUser(UserProfile user) async {
    setState(() => _selectedUser = user);
  }

  List<UserProfile> _filteredUsers() {
    return _users.where((user) {
      final search = _search.trim().toLowerCase();
      final matchesSearch =
          search.isEmpty ||
          user.fullName.toLowerCase().contains(search) ||
          (user.numeroLicenza ?? '').toLowerCase().contains(search);
      final matchesOrg = _orgUnitId == null || user.orgUnitId == _orgUnitId;
      final matchesApproval = switch (_approvalFilter) {
        'approved' => user.isApproved,
        'pending' => !user.isApproved,
        _ => true,
      };
      return matchesSearch && matchesOrg && matchesApproval;
    }).toList();
  }

  /// Navigate to detail: push page on mobile, select in side-panel on desktop.
  Future<void> _openUserDetail(BuildContext context, UserProfile user) async {
    final isWide = MediaQuery.sizeOf(context).width >= 700;
    if (isWide) {
      await _selectUser(user);
    } else {
      final auth = ref.read(authProvider);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _UserDetailPage(
            initialUser: user,
            service: _service,
            showMaintenanceSections: auth.isAdminPriv || !auth.isAdminCrew,
            showCrewSections: auth.isAdminCrew || !auth.isAdminPriv,
            helicopterTypes: auth.helicopterTypes,
            licenseTypes: auth.licenseTypes,
            privilegeTypes: auth.privilegeTypes,
            tobCapabilities: auth.tobCapabilityTypes,
          ),
        ),
      );
      // Reload list after returning so any changes are reflected.
      if (mounted) _loadUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final filteredUsers = _filteredUsers();
    final isWide = MediaQuery.sizeOf(context).width >= 700;

    return Scaffold(
      appBar: AppBar(
        leading: const AdminAppBarLeading(),
        title: const Text('Gestione Utenti'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Filter bar ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _searchCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Cerca per nome o numero licenza…',
                              prefixIcon: Icon(Icons.search),
                              isDense: true,
                            ),
                            onChanged: (v) => setState(() => _search = v),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int?>(
                                  key: ValueKey(_orgUnitId),
                                  initialValue: _orgUnitId,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Unità',
                                    isDense: true,
                                  ),
                                  items: [
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text('Tutte'),
                                    ),
                                    ...auth.orgUnits.map(
                                      (u) => DropdownMenuItem<int?>(
                                        value: u.id,
                                        child: Text(
                                          u.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _orgUnitId = v),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey(_approvalFilter),
                                  initialValue: _approvalFilter,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Stato',
                                    isDense: true,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'all',
                                      child: Text('Tutti'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'approved',
                                      child: Text('Approvati'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'pending',
                                      child: Text('In attesa'),
                                    ),
                                  ],
                                  onChanged: (v) => setState(
                                    () => _approvalFilter = v ?? 'all',
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
                // ── Deletion requests ─────────────────────────────────────
                if (_deletionRequests.isNotEmpty)
                  _DeletionRequestsBanner(
                    requests: _deletionRequests,
                    onApprove: _approveDeletionRequest,
                    onReject: _rejectDeletionRequest,
                  ),
                const SizedBox(height: 4),
                // ── User list / side-by-side ───────────────────────────────
                Expanded(
                  child: isWide
                      ? Row(
                          children: [
                            SizedBox(
                              width: 320,
                              child: _UserList(
                                users: filteredUsers,
                                selected: _selectedUser,
                                onSelected: (u) => _openUserDetail(context, u),
                              ),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(
                              child: _selectedUser == null
                                  ? const Center(
                                      child: Text(
                                        'Seleziona un utente per vedere i dettagli.',
                                      ),
                                    )
                                  : _UserDetailPage(
                                      key: ValueKey(_selectedUser!.id),
                                      initialUser: _selectedUser!,
                                      service: _service,
                                      showMaintenanceSections:
                                          auth.isAdminPriv || !auth.isAdminCrew,
                                      showCrewSections:
                                          auth.isAdminCrew || !auth.isAdminPriv,
                                      helicopterTypes: auth.helicopterTypes,
                                      licenseTypes: auth.licenseTypes,
                                      privilegeTypes: auth.privilegeTypes,
                                      tobCapabilities: auth.tobCapabilityTypes,
                                      onSaved: _loadUsers,
                                    ),
                            ),
                          ],
                        )
                      : _UserList(
                          users: filteredUsers,
                          selected: null,
                          onSelected: (u) => _openUserDetail(context, u),
                        ),
                ),
              ],
            ),
    );
  }
}

class _UserList extends StatelessWidget {
  const _UserList({
    required this.users,
    required this.selected,
    required this.onSelected,
  });

  final List<UserProfile> users;
  final UserProfile? selected;
  final ValueChanged<UserProfile> onSelected;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const Center(child: Text('Nessun utente trovato.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: users.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final user = users[index];
        final isSelected = selected?.id == user.id;
        return Card(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.18)
              : !user.isApproved
              ? Theme.of(
                  context,
                ).colorScheme.errorContainer.withValues(alpha: 0.25)
              : null,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSelected(user),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  UserAvatar(
                    user: user,
                    radius: 22,
                    backgroundColor: user.isApproved
                        ? Theme.of(context).colorScheme.primary
                        : Colors.amber.shade700,
                    textStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Name + licence (Expanded so it never overflows)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.numeroLicenza ?? 'Licenza non indicata',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.65),
                              ),
                        ),
                        Text(
                          user.orgUnitName,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.55),
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  const SizedBox(width: 8),
                  user.isApproved
                      ? const Icon(
                          Icons.verified_rounded,
                          color: Colors.green,
                          size: 22,
                        )
                      : const Icon(
                          Icons.pending_rounded,
                          color: Colors.amber,
                          size: 22,
                        ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Deletion requests banner
// ─────────────────────────────────────────────────────────────

class _DeletionRequestsBanner extends StatelessWidget {
  const _DeletionRequestsBanner({
    required this.requests,
    required this.onApprove,
    required this.onReject,
  });

  final List<AccountDeletionRequest> requests;
  final Future<void> Function(AccountDeletionRequest) onApprove;
  final Future<void> Function(AccountDeletionRequest) onReject;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Card(
        color: Theme.of(
          context,
        ).colorScheme.errorContainer.withValues(alpha: 0.35),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Richieste eliminazione (${requests.length})',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...requests.map(
                (r) => _DeletionRequestRow(
                  request: r,
                  onApprove: () => onApprove(r),
                  onReject: () => onReject(r),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeletionRequestRow extends StatelessWidget {
  const _DeletionRequestRow({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });
  final AccountDeletionRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${request.userFullName} · ${request.userLicenza}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            DateFormat('dd/MM/yyyy HH:mm').format(request.requestedAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (request.reason != null && request.reason!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Motivo: ${request.reason}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilledButton.icon(
                onPressed: onApprove,
                icon: const Icon(Icons.delete_forever, size: 16),
                label: const Text('Elimina utente'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onReject,
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Rifiuta'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// User detail page (self-contained, can be pushed or embedded)
// ─────────────────────────────────────────────────────────────

class _UserDetailPage extends ConsumerStatefulWidget {
  const _UserDetailPage({
    super.key,
    required this.initialUser,
    required this.service,
    required this.showMaintenanceSections,
    required this.showCrewSections,
    required this.helicopterTypes,
    required this.licenseTypes,
    required this.privilegeTypes,
    required this.tobCapabilities,
    this.onSaved,
  });

  final UserProfile initialUser;
  final UserService service;
  final bool showMaintenanceSections;
  final bool showCrewSections;
  final List<HelicopterType> helicopterTypes;
  final List<LicenseType> licenseTypes;
  final List<PrivilegeType> privilegeTypes;
  final List<TobCapability> tobCapabilities;
  final VoidCallback? onSaved;

  @override
  ConsumerState<_UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends ConsumerState<_UserDetailPage> {
  late UserProfile _user;
  late String _selectedRole;
  bool _loading = true;
  bool _saving = false;

  Set<String> _licenseKeys = <String>{};
  Set<String> _privilegeKeys = <String>{};
  Set<int> _tCrewHelicopters = <int>{};
  Set<int> _tobCrewHelicopters = <int>{};
  Set<String> _tobCapabilityKeys = <String>{};
  Map<int, String> _tobGrades = <int, String>{};

  @override
  void initState() {
    super.initState();
    _user = widget.initialUser;
    _selectedRole = _user.role;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final s = widget.service;
    final licenses = await s.getUserLicenses(_user.id);
    final privileges = await s.getUserPrivileges(_user.id);
    final crews = await s.getUserCrewAssignments(_user.id);
    final tobCaps = await s.getUserTobCapabilities(_user.id);
    if (!mounted) return;
    setState(() {
      _licenseKeys = licenses
          .map((i) => '${i.helicopterTypeId}:${i.licenseTypeId}')
          .toSet();
      _privilegeKeys = privileges
          .map((i) => '${i.helicopterTypeId}:${i.privilegeTypeId}')
          .toSet();
      _tCrewHelicopters = crews
          .where((i) => i.crewType == 'T')
          .map((i) => i.helicopterTypeId)
          .toSet();
      _tobCrewHelicopters = crews
          .where((i) => i.crewType == 'TOB')
          .map((i) => i.helicopterTypeId)
          .toSet();
      _tobGrades = {
        for (final i in crews.where((c) => c.crewType == 'TOB'))
          i.helicopterTypeId: i.fascia ?? 'A',
      };
      _tobCapabilityKeys = tobCaps
          .map((i) => '${i.helicopterTypeId}:${i.tobCapabilityId}')
          .toSet();
      _loading = false;
    });
  }

  void _toggle(Set<String> set, String k) =>
      set.contains(k) ? set.remove(k) : set.add(k);
  void _toggleI(Set<int> set, int k) =>
      set.contains(k) ? set.remove(k) : set.add(k);

  Set<int> _selectedPrivilegeIdsFor(int helicopterTypeId) {
    return _privilegeKeys
        .where((key) => key.startsWith('$helicopterTypeId:'))
        .map((key) => int.parse(key.split(':')[1]))
        .toSet();
  }

  Future<void> _editPrivilegesForHelicopter(HelicopterType helicopter) async {
    final selectionsByHelicopter = <int, Set<int>>{
      for (final item in widget.helicopterTypes)
        item.id: _selectedPrivilegeIdsFor(item.id),
    };
    final result = await showPrivilegeSelectionDialog(
      context: context,
      helicopterTypes: widget.helicopterTypes,
      privilegeTypes: widget.privilegeTypes,
      selectionsByHelicopter: selectionsByHelicopter,
      initialHelicopterTypeId: helicopter.id,
      title: 'Seleziona privilegi manutentivi',
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      _privilegeKeys.removeWhere(
        (key) => key.startsWith('${result.helicopterTypeId}:'),
      );
      for (final privilegeTypeId in result.selectedPrivilegeTypeIds) {
        _privilegeKeys.add('${result.helicopterTypeId}:$privilegeTypeId');
      }
    });
  }

  Future<void> _approve() async {
    final adminId = ref.read(authProvider).userProfile?.id;
    if (adminId == null) return;
    try {
      await widget.service.approveUser(_user.id, adminId);
      if (!mounted) return;
      final updated = _user.copyWith(isApproved: true);
      setState(() => _user = updated);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Utente approvato.')));
      widget.onSaved?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.service.updateProfile(_user.copyWith(role: _selectedRole));
      await widget.service.setUserLicenses(
        _user.id,
        _licenseKeys.map((k) {
          final p = k.split(':');
          return {
            'helicopter_type_id': int.parse(p[0]),
            'license_type_id': int.parse(p[1]),
          };
        }).toList(),
      );
      await widget.service.setUserPrivileges(
        _user.id,
        _privilegeKeys.map((k) {
          final p = k.split(':');
          return {
            'helicopter_type_id': int.parse(p[0]),
            'privilege_type_id': int.parse(p[1]),
          };
        }).toList(),
      );
      final assignments = <Map<String, dynamic>>[
        for (final id in _tCrewHelicopters)
          {'helicopter_type_id': id, 'crew_type': 'T', 'tob_grade': null},
        for (final id in _tobCrewHelicopters)
          {
            'helicopter_type_id': id,
            'crew_type': 'TOB',
            'tob_grade': _tobGrades[id] ?? 'A',
          },
      ];
      await widget.service.setUserCrewAssignments(_user.id, assignments);
      await widget.service.setUserTobCapabilities(
        _user.id,
        _tobCapabilityKeys.map((k) {
          final p = k.split(':');
          return {
            'helicopter_type_id': int.parse(p[0]),
            'tob_capability_id': int.parse(p[1]),
          };
        }).toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ruoli e assegnazioni salvati.')),
      );
      widget.onSaved?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteUser() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina utente'),
        content: Text(
          'Eliminare definitivamente ${_user.fullName}? Questa azione non è reversibile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.service.deleteUser(_user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Utente eliminato.')));
      widget.onSaved?.call();
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AdminAppBarLeading(),
        title: Text(_user.fullName, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: Colors.redAccent,
            tooltip: 'Elimina utente',
            onPressed: _deleteUser,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Pending approval banner ───────────────────────────────
                if (!_user.isApproved)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700.withValues(alpha: 0.18),
                      border: Border.all(color: Colors.amber.shade700),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.pending_rounded,
                              color: Colors.amber,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Profilo in attesa di approvazione',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _approve,
                            icon: const Icon(Icons.verified_user_outlined),
                            label: const Text('APPROVA PROFILO'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // ── User info card ────────────────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        UserAvatar(user: _user, radius: 34),
                        const SizedBox(height: 12),
                        Text(
                          _user.fullName,
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _user.numeroLicenza ?? 'Licenza non indicata',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          _user.orgUnitName,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.65),
                              ),
                        ),
                        if (_user.email != null &&
                            _user.email!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _user.email!,
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (_user.username != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Username: ${_user.username}',
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          key: ValueKey(_selectedRole),
                          initialValue: _selectedRole,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Ruolo',
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'user',
                              child: Text('Utente'),
                            ),
                            DropdownMenuItem(
                              value: 'admin_priv',
                              child: Text('Admin privilegi'),
                            ),
                            DropdownMenuItem(
                              value: 'admin_crew',
                              child: Text('Admin equipaggi'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedRole = v ?? 'user'),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── Maintenance sections ──────────────────────────────────
                if (widget.showMaintenanceSections) ...[
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Licenze',
                    children: widget.helicopterTypes
                        .map(
                          (h) => _ChipGroup(
                            title: h.name,
                            chips: widget.licenseTypes
                                .map(
                                  (l) => FilterChip(
                                    selected: _licenseKeys.contains(
                                      '${h.id}:${l.id}',
                                    ),
                                    label: Text(l.name),
                                    onSelected: (_) => setState(
                                      () => _toggle(
                                        _licenseKeys,
                                        '${h.id}:${l.id}',
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Privilegi manutentivi',
                    children: widget.helicopterTypes.map((h) {
                      final selectedPrivileges = widget.privilegeTypes
                          .where(
                            (p) => _privilegeKeys.contains('${h.id}:${p.id}'),
                          )
                          .toList();
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                h.name,
                                style: Theme.of(context).textTheme.titleSmall,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              if (selectedPrivileges.isEmpty)
                                const Text(
                                  'Nessun privilegio selezionato.',
                                  textAlign: TextAlign.center,
                                )
                              else
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: selectedPrivileges
                                      .map(
                                        (item) => Chip(
                                          label: Text(
                                            '${item.code} · ${item.name}',
                                            softWrap: true,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _editPrivilegesForHelicopter(h),
                                icon: const Icon(Icons.checklist_outlined),
                                label: const Text('Modifica privilegi'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                // ── Crew sections ─────────────────────────────────────────
                if (widget.showCrewSections) ...[
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Equipaggi di volo',
                    children: widget.helicopterTypes.map((h) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                h.name,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: const Text('Equipaggio T'),
                                value: _tCrewHelicopters.contains(h.id),
                                onChanged: (_) => setState(
                                  () => _toggleI(_tCrewHelicopters, h.id),
                                ),
                              ),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: const Text('Equipaggio TOB'),
                                value: _tobCrewHelicopters.contains(h.id),
                                onChanged: (_) => setState(() {
                                  _toggleI(_tobCrewHelicopters, h.id);
                                  _tobGrades.putIfAbsent(h.id, () => 'A');
                                }),
                              ),
                              if (_tobCrewHelicopters.contains(h.id))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: DropdownButtonFormField<String>(
                                    key: ValueKey(
                                      '${h.id}_${_tobGrades[h.id]}',
                                    ),
                                    initialValue: _tobGrades[h.id] ?? 'A',
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Fascia TOB',
                                      isDense: true,
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'A',
                                        child: Text('A'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'B',
                                        child: Text('B'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'C',
                                        child: Text('C'),
                                      ),
                                    ],
                                    onChanged: (v) => setState(
                                      () => _tobGrades[h.id] = v ?? 'A',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Capacità TOB',
                    children: widget.helicopterTypes
                        .map(
                          (h) => _ChipGroup(
                            title: h.name,
                            chips: widget.tobCapabilities
                                .map(
                                  (c) => FilterChip(
                                    selected: _tobCapabilityKeys.contains(
                                      '${h.id}:${c.id}',
                                    ),
                                    label: Text(c.name),
                                    onSelected: (_) => setState(
                                      () => _toggle(
                                        _tobCapabilityKeys,
                                        '${h.id}:${c.id}',
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Salva ruolo e assegnazioni'),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ChipGroup extends StatelessWidget {
  const _ChipGroup({required this.title, required this.chips});
  final String title;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 6, children: chips),
        ],
      ),
    );
  }
}
