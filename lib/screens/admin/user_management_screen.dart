import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../constants/app_constants.dart';
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
    final auth = ref.read(authProvider);
    return _users.where((user) {
      final search = _search.trim().toLowerCase();
      final matchesSearch =
          search.isEmpty ||
          user.fullName.toLowerCase().contains(search) ||
          (user.numeroLicenza ?? '').toLowerCase().contains(search);
      final matchesOrg = _orgUnitId == null || user.orgUnitId == _orgUnitId;
      final matchesApproval = switch (_approvalFilter) {
        'approved' => user.isApproved,
        'pending_maint' => auth.isAdminPriv && !user.isApprovedMaint,
        'pending_crew' => auth.isAdminCrew && !user.isApprovedCrew,
        'pending' => !user.isApproved,
        _ => true,
      };
      return matchesSearch && matchesOrg && matchesApproval;
    }).toList();
  }

  Future<void> _bulkApproveMaint() async {
    final adminId = ref.read(authProvider).userProfile?.id;
    if (adminId == null) return;

    final pendingUsers = _filteredUsers()
        .where((u) => !u.isApprovedMaint)
        .toList();

    if (pendingUsers.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approva manutenzione'),
        content: Text(
          'Approvare ${pendingUsers.length} utenti per la manutenzione?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Approva'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _service.bulkApproveMaint(
        pendingUsers.map((u) => u.id).toList(),
        adminId,
      );
      await _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${pendingUsers.length} utenti approvati per manutenzione.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _bulkApproveCrew() async {
    final adminId = ref.read(authProvider).userProfile?.id;
    if (adminId == null) return;

    final pendingUsers = _filteredUsers()
        .where((u) => !u.isApprovedCrew)
        .toList();

    if (pendingUsers.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approva equipaggio'),
        content: Text(
          'Approvare ${pendingUsers.length} utenti per l\'equipaggio?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Approva'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _service.bulkApproveCrew(
        pendingUsers.map((u) => u.id).toList(),
        adminId,
      );
      await _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${pendingUsers.length} utenti approvati per equipaggio.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
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
                                  items: [
                                    const DropdownMenuItem(
                                      value: 'all',
                                      child: Text('Tutti'),
                                    ),
                                    const DropdownMenuItem(
                                      value: 'approved',
                                      child: Text('Approvati'),
                                    ),
                                    const DropdownMenuItem(
                                      value: 'pending',
                                      child: Text('In attesa'),
                                    ),
                                    if (auth.isAdminPriv || !auth.isAdminCrew)
                                      const DropdownMenuItem(
                                        value: 'pending_maint',
                                        child: Text('In attesa - Manutenzione'),
                                      ),
                                    if (auth.isAdminCrew || !auth.isAdminPriv)
                                      const DropdownMenuItem(
                                        value: 'pending_crew',
                                        child: Text('In attesa - Equipaggio'),
                                      ),
                                  ],
                                  onChanged: (v) => setState(
                                    () => _approvalFilter = v ?? 'all',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (auth.isAdminPriv || !auth.isAdminCrew) ...[
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        filteredUsers.any(
                                          (u) => !u.isApprovedMaint,
                                        )
                                        ? _bulkApproveMaint
                                        : null,
                                    icon: const Icon(
                                      Icons.engineering_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('Approva Manutenzione'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (auth.isAdminCrew || !auth.isAdminPriv)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        filteredUsers.any(
                                          (u) => !u.isApprovedCrew,
                                        )
                                        ? _bulkApproveCrew
                                        : null,
                                    icon: const Icon(
                                      Icons.flight_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('Approva Equipaggio'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
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
                                isMaintenanceContext:
                                    auth.isAdminPriv || !auth.isAdminCrew,
                                isCrewContext:
                                    auth.isAdminCrew || !auth.isAdminPriv,
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
                          isMaintenanceContext:
                              auth.isAdminPriv || !auth.isAdminCrew,
                          isCrewContext: auth.isAdminCrew || !auth.isAdminPriv,
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
    required this.isMaintenanceContext,
    required this.isCrewContext,
  });

  final List<UserProfile> users;
  final UserProfile? selected;
  final ValueChanged<UserProfile> onSelected;
  final bool isMaintenanceContext;
  final bool isCrewContext;

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
        final isPending = isMaintenanceContext
            ? !user.isApprovedMaint
            : isCrewContext
            ? !user.isApprovedCrew
            : !user.isApproved;
        return Card(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.18)
              : isPending
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
                    backgroundColor: isPending
                        ? Colors.amber.shade700
                        : Theme.of(context).colorScheme.primary,
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
                  isPending
                      ? const Icon(
                          Icons.pending_rounded,
                          color: Colors.amber,
                          size: 22,
                        )
                      : const Icon(
                          Icons.verified_rounded,
                          color: Colors.green,
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
  Set<int> _mdbCrewHelicopters = <int>{};
  Set<String> _tobCapabilityKeys = <String>{};
  Map<int, String> _tobGrades = <int, String>{};
  Map<int, String> _mdbGrades = <int, String>{};

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
      _mdbCrewHelicopters = crews
          .where((i) => i.crewType == 'MDB')
          .map((i) => i.helicopterTypeId)
          .toSet();
      _tobGrades = {
        for (final i in crews.where((c) => c.crewType == 'TOB'))
          i.helicopterTypeId: i.fascia ?? 'A',
      };
      _mdbGrades = {
        for (final i in crews.where((c) => c.crewType == 'MDB'))
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

  Future<void> _selectTCrewHelicopters() async {
    final selected = await showDialog<Set<int>>(
      context: context,
      builder: (ctx) => _HelicopterMultiSelectDialog(
        title: 'Seleziona elicotteri Equipaggio T',
        helicopters: widget.helicopterTypes,
        initialSelection: _tCrewHelicopters,
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _tCrewHelicopters = selected;
      });
    }
  }

  Future<void> _selectTobCrewHelicopters() async {
    final selected = await showDialog<Set<int>>(
      context: context,
      builder: (ctx) => _HelicopterMultiSelectDialog(
        title: 'Seleziona elicotteri Equipaggio TOB',
        helicopters: widget.helicopterTypes,
        initialSelection: _tobCrewHelicopters,
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _tobCrewHelicopters = selected;
        _tobGrades.removeWhere((key, _) => !selected.contains(key));
        _tobCapabilityKeys.removeWhere((key) {
          final helicopterId = int.tryParse(key.split(':').first);
          return helicopterId == null || !selected.contains(helicopterId);
        });
        for (final id in selected) {
          _tobGrades.putIfAbsent(id, () => 'A');
        }
      });
    }
  }

  Future<void> _selectMdbCrewHelicopters() async {
    final selected = await showDialog<Set<int>>(
      context: context,
      builder: (ctx) => _HelicopterMultiSelectDialog(
        title: 'Seleziona elicotteri Mitragliere di Bordo',
        helicopters: widget.helicopterTypes,
        initialSelection: _mdbCrewHelicopters,
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _mdbCrewHelicopters = selected;
        _mdbGrades.removeWhere((key, _) => !selected.contains(key));
        for (final id in selected) {
          _mdbGrades.putIfAbsent(id, () => 'A');
        }
      });
    }
  }

  Future<void> _approveMaint() async {
    final adminId = ref.read(authProvider).userProfile?.id;
    if (adminId == null) return;
    try {
      await widget.service.approveMaint(_user.id, adminId);
      if (!mounted) return;
      final updated = _user.copyWith(isApprovedMaint: true, isApproved: true);
      setState(() => _user = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Utente approvato per manutenzione.')),
      );
      widget.onSaved?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _approveCrew() async {
    final adminId = ref.read(authProvider).userProfile?.id;
    if (adminId == null) return;
    try {
      await widget.service.approveCrew(_user.id, adminId);
      if (!mounted) return;
      final updated = _user.copyWith(isApprovedCrew: true, isApproved: true);
      setState(() => _user = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Utente approvato per equipaggio.')),
      );
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
      await widget.service.updateProfile(
        _user.copyWith(
          role: _selectedRole,
          isTi: _user.isTi,
          isEtp: _user.isEtp,
        ),
      );
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
        for (final id in _mdbCrewHelicopters)
          {
            'helicopter_type_id': id,
            'crew_type': 'MDB',
            'tob_grade': _mdbGrades[id] ?? 'A',
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
    final auth = ref.watch(authProvider);
    final canEditInstructorQualifications = auth.isAdminPriv;

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
                if ((widget.showMaintenanceSections &&
                        !_user.isApprovedMaint) ||
                    (widget.showCrewSections && !_user.isApprovedCrew))
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
                        Builder(
                          builder: (ctx) {
                            final showMaint =
                                widget.showMaintenanceSections &&
                                !_user.isApprovedMaint;
                            final showCrew =
                                widget.showCrewSections &&
                                !_user.isApprovedCrew;

                            return Column(
                              children: [
                                if (showMaint)
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: _approveMaint,
                                      icon: const Icon(
                                        Icons.engineering_outlined,
                                      ),
                                      label: const Text('APPROVA MANUTENZIONE'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.green.shade700,
                                      ),
                                    ),
                                  ),
                                if (showMaint && showCrew)
                                  const SizedBox(height: 8),
                                if (showCrew)
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: _approveCrew,
                                      icon: const Icon(Icons.flight_outlined),
                                      label: const Text('APPROVA EQUIPAGGIO'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.blue.shade700,
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
                        if (_user.isTi || _user.isEtp) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (_user.isTi)
                                Chip(
                                  label: const Text('TI'),
                                  backgroundColor: Colors.blue.shade700,
                                ),
                              if (_user.isEtp)
                                Chip(
                                  label: const Text('ETP'),
                                  backgroundColor: Colors.purple.shade700,
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),
                        // Il ruolo admin è fisso e non modificabile da qui.
                        // Esistono solo 2 admin (admin_priv / admin_crew).
                        if (_user.isAdminPriv || _user.isAdminCrew)
                          InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Ruolo',
                              isDense: true,
                            ),
                            child: Text(
                              _user.isAdminPriv
                                  ? 'Admin Privilegi (non modificabile)'
                                  : 'Admin Equipaggi (non modificabile)',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          )
                        else
                          InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Ruolo',
                              isDense: true,
                            ),
                            child: const Text('Utente'),
                          ),
                      ],
                    ),
                  ),
                ),
                // ── Maintenance sections ──────────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Qualifiche Istruttori',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (!canEditInstructorQualifications)
                          Text(
                            'Solo Admin privilegi può modificare TI/ETP.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Istruttore T.A. (TI)'),
                          value: _user.isTi,
                          onChanged: canEditInstructorQualifications
                              ? (value) => setState(
                                  () => _user = _user.copyWith(isTi: value),
                                )
                              : null,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Esaminatore T.P. (ETP)'),
                          value: _user.isEtp,
                          onChanged: canEditInstructorQualifications
                              ? (value) => setState(
                                  () => _user = _user.copyWith(isEtp: value),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.showMaintenanceSections) ...[
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Licenze',
                    children: widget.helicopterTypes.map((h) {
                      return SizedBox(
                        width: double.infinity,
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  h.name,
                                  style: Theme.of(context).textTheme.titleSmall,
                                  textAlign: TextAlign.center,
                                  softWrap: true,
                                ),
                                const SizedBox(height: 8),
                                ...widget.licenseTypes.map((l) {
                                  final key = '${h.id}:${l.id}';
                                  final selected = _licenseKeys.contains(key);
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? AppColors.accent.withValues(
                                              alpha: 0.12,
                                            )
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: selected
                                            ? AppColors.accent
                                            : AppColors.border,
                                      ),
                                    ),
                                    child: CheckboxListTile(
                                      value: selected,
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                      title: Text(l.name, softWrap: true),
                                      subtitle: Text(
                                        selected
                                            ? 'Licenza assegnata'
                                            : 'Tocca per assegnare',
                                        softWrap: true,
                                      ),
                                      onChanged: (_) => setState(
                                        () => _toggle(_licenseKeys, key),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
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
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Equipaggi di volo',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Equipaggio T',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleSmall,
                                        ),
                                      ),
                                      if (_tCrewHelicopters.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primaryContainer,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            '${_tCrewHelicopters.length}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (_tCrewHelicopters.isNotEmpty)
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: widget.helicopterTypes
                                          .where(
                                            (h) => _tCrewHelicopters.contains(
                                              h.id,
                                            ),
                                          )
                                          .map(
                                            (h) => Chip(
                                              label: Text(h.name),
                                              onDeleted: () => setState(
                                                () => _tCrewHelicopters.remove(
                                                  h.id,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    )
                                  else
                                    const Text(
                                      'Nessun elicottero selezionato',
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: _selectTCrewHelicopters,
                                    icon: const Icon(Icons.flight, size: 16),
                                    label: const Text('Scegli elicotteri'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Equipaggio TOB',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleSmall,
                                        ),
                                      ),
                                      if (_tobCrewHelicopters.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primaryContainer,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            '${_tobCrewHelicopters.length}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (_tobCrewHelicopters.isNotEmpty)
                                    ...widget.helicopterTypes
                                        .where(
                                          (h) => _tobCrewHelicopters.contains(
                                            h.id,
                                          ),
                                        )
                                        .map(
                                          (h) => Card(
                                            margin: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(8),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          h.name,
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.close,
                                                          size: 18,
                                                        ),
                                                        padding:
                                                            EdgeInsets.zero,
                                                        constraints:
                                                            const BoxConstraints(),
                                                        onPressed: () => setState(
                                                          () {
                                                            _tobCrewHelicopters
                                                                .remove(h.id);
                                                            _tobGrades.remove(
                                                              h.id,
                                                            );
                                                            _tobCapabilityKeys
                                                                .removeWhere(
                                                                  (
                                                                    k,
                                                                  ) => k.startsWith(
                                                                    '${h.id}:',
                                                                  ),
                                                                );
                                                          },
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  DropdownButtonFormField<
                                                    String
                                                  >(
                                                    key: ValueKey(
                                                      '${h.id}_${_tobGrades[h.id]}',
                                                    ),
                                                    initialValue:
                                                        _tobGrades[h.id] ?? 'A',
                                                    isExpanded: true,
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText:
                                                              'Fascia TOB',
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
                                                      () => _tobGrades[h.id] =
                                                          v ?? 'A',
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  const Text(
                                                    'Capacità TOB:',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Wrap(
                                                    spacing: 6,
                                                    runSpacing: 6,
                                                    children: widget
                                                        .tobCapabilities
                                                        .map(
                                                          (c) => FilterChip(
                                                            selected:
                                                                _tobCapabilityKeys
                                                                    .contains(
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
                                                ],
                                              ),
                                            ),
                                          ),
                                        )
                                  else
                                    const Text(
                                      'Nessun elicottero selezionato',
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: _selectTobCrewHelicopters,
                                    icon: const Icon(Icons.flight, size: 16),
                                    label: const Text('Scegli elicotteri'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Mitragliere di Bordo (MDB)',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleSmall,
                                        ),
                                      ),
                                      if (_mdbCrewHelicopters.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primaryContainer,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            '${_mdbCrewHelicopters.length}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (_mdbCrewHelicopters.isNotEmpty)
                                    ...widget.helicopterTypes
                                        .where(
                                          (h) => _mdbCrewHelicopters.contains(
                                            h.id,
                                          ),
                                        )
                                        .map(
                                          (h) => Card(
                                            margin: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(8),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          h.name,
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.close,
                                                          size: 18,
                                                        ),
                                                        padding:
                                                            EdgeInsets.zero,
                                                        constraints:
                                                            const BoxConstraints(),
                                                        onPressed: () =>
                                                            setState(() {
                                                              _mdbCrewHelicopters
                                                                  .remove(h.id);
                                                              _mdbGrades.remove(
                                                                h.id,
                                                              );
                                                            }),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  DropdownButtonFormField<
                                                    String
                                                  >(
                                                    key: ValueKey(
                                                      'mdb_${h.id}_${_mdbGrades[h.id]}',
                                                    ),
                                                    initialValue:
                                                        _mdbGrades[h.id] ?? 'A',
                                                    isExpanded: true,
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText:
                                                              'Fascia MDB',
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
                                                      () => _mdbGrades[h.id] =
                                                          v ?? 'A',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        )
                                  else
                                    const Text(
                                      'Nessun elicottero selezionato',
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: _selectMdbCrewHelicopters,
                                    icon: const Icon(
                                      Icons.shield_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('Scegli elicotteri'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _HelicopterMultiSelectDialog extends StatefulWidget {
  const _HelicopterMultiSelectDialog({
    required this.title,
    required this.helicopters,
    required this.initialSelection,
  });

  final String title;
  final List<HelicopterType> helicopters;
  final Set<int> initialSelection;

  @override
  State<_HelicopterMultiSelectDialog> createState() =>
      _HelicopterMultiSelectDialogState();
}

class _HelicopterMultiSelectDialogState
    extends State<_HelicopterMultiSelectDialog> {
  late Set<int> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<int>.from(widget.initialSelection);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: widget.helicopters.map((h) {
            final isSelected = _selected.contains(h.id);
            return CheckboxListTile(
              value: isSelected,
              title: Text(h.name),
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selected.add(h.id);
                  } else {
                    _selected.remove(h.id);
                  }
                });
              },
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('Conferma'),
        ),
      ],
    );
  }
}
