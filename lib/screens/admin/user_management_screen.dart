import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../models/reference_models.dart';
import '../../models/user_models.dart';
import '../../services/user_service.dart';
import '../../widgets/admin_app_bar_leading.dart';
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
  late final TextEditingController _licenseNumberCtrl;
  bool _loading = true;
  bool _saving = false;

  Set<String> _licenseKeys = <String>{};
  Set<String> _privilegeKeys = <String>{};
  Set<int> _tCrewHelicopters = <int>{};
  Set<int> _tobCrewHelicopters = <int>{};
  Set<int> _mdbCrewHelicopters = <int>{};
  final Set<int> _addedHelicopters = <int>{};
  Set<String> _tobCapabilityKeys = <String>{};
  Map<int, String> _tobGrades = <int, String>{};

  @override
  void initState() {
    super.initState();
    _user = widget.initialUser;
    _selectedRole = _user.role;
    _licenseNumberCtrl = TextEditingController(text: _user.numeroLicenza ?? '');
    _loadData();
  }

  @override
  void dispose() {
    _licenseNumberCtrl.dispose();
    super.dispose();
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
          .where((i) => i.crewType == 'MTB')
          .map((i) => i.helicopterTypeId)
          .toSet();
      _tobGrades = {
        for (final i in crews.where((c) => c.crewType == 'TOB'))
          i.helicopterTypeId: i.fascia ?? 'A',
      };
      _tobCapabilityKeys = tobCaps
          .map((i) => '${i.helicopterTypeId}:${i.tobCapabilityId}')
          .toSet();
      _addedHelicopters.clear();
      _loading = false;
    });
  }

  Set<int> _selectedPrivilegeIdsFor(int helicopterTypeId) {
    return _privilegeKeys
        .where((key) => key.startsWith('$helicopterTypeId:'))
        .map((key) => int.parse(key.split(':')[1]))
        .toSet();
  }

  int? _selectedLicenseTypeIdFor(int helicopterTypeId) {
    final key = _licenseKeys.firstWhere(
      (item) => item.startsWith('$helicopterTypeId:'),
      orElse: () => '',
    );
    if (key.isEmpty) {
      return null;
    }
    return int.tryParse(key.split(':')[1]);
  }

  void _setLicenseForHelicopter(int helicopterTypeId, int? licenseTypeId) {
    setState(() {
      _licenseKeys.removeWhere((key) => key.startsWith('$helicopterTypeId:'));
      if (licenseTypeId != null) {
        _licenseKeys.add('$helicopterTypeId:$licenseTypeId');
      }
    });
  }

  String _crewTypeForHelicopter(int helicopterTypeId) {
    if (_tobCrewHelicopters.contains(helicopterTypeId)) {
      return 'TOB';
    }
    if (_tCrewHelicopters.contains(helicopterTypeId)) {
      return 'T';
    }
    if (_mdbCrewHelicopters.contains(helicopterTypeId)) {
      return 'MTB';
    }
    return 'NONE';
  }

  void _setCrewTypeForHelicopter(int helicopterTypeId, String crewType) {
    setState(() {
      _tCrewHelicopters.remove(helicopterTypeId);
      _tobCrewHelicopters.remove(helicopterTypeId);
      _mdbCrewHelicopters.remove(helicopterTypeId);
      if (crewType == 'T') {
        _tCrewHelicopters.add(helicopterTypeId);
      } else if (crewType == 'TOB') {
        _tobCrewHelicopters.add(helicopterTypeId);
        _tobGrades.putIfAbsent(helicopterTypeId, () => 'A');
      } else if (crewType == 'MTB') {
        _mdbCrewHelicopters.add(helicopterTypeId);
      } else {
        _tobGrades.remove(helicopterTypeId);
        _tobCapabilityKeys.removeWhere(
          (key) => key.startsWith('$helicopterTypeId:'),
        );
      }
      if (crewType != 'TOB') {
        _tobGrades.remove(helicopterTypeId);
        _tobCapabilityKeys.removeWhere(
          (key) => key.startsWith('$helicopterTypeId:'),
        );
      }
    });
  }

  Set<int> _selectedTobCapabilityIdsFor(int helicopterTypeId) {
    return _tobCapabilityKeys
        .where((key) => key.startsWith('$helicopterTypeId:'))
        .map((key) => int.parse(key.split(':')[1]))
        .toSet();
  }

  List<int> _assignedHelicopterIds() {
    final ids = <int>{};
    for (final key in _licenseKeys) {
      ids.add(int.parse(key.split(':').first));
    }
    for (final key in _privilegeKeys) {
      ids.add(int.parse(key.split(':').first));
    }
    ids.addAll(_tCrewHelicopters);
    ids.addAll(_tobCrewHelicopters);
    ids.addAll(_mdbCrewHelicopters);
    ids.addAll(_addedHelicopters);
    final sorted = ids.toList()..sort();
    return sorted;
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Non impostata';
    }
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Future<void> _pickFlightFitnessExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _user.flightFitnessExpiry ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 20),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _user = _user.copyWith(flightFitnessExpiry: picked);
    });
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
      final currentAdmin = ref.read(authProvider).userProfile;
      if (currentAdmin == null) {
        throw Exception('Admin non autenticato');
      }
      final canEditLicenseNumber = currentAdmin.isAdminPriv && _user.isUser;
      if (canEditLicenseNumber) {
        final requestedLicense = _licenseNumberCtrl.text.trim();
        if (requestedLicense.isEmpty) {
          throw Exception('Numero licenza obbligatorio');
        }
        final currentLicense = (_user.numeroLicenza ?? '').trim();
        if (requestedLicense.toUpperCase() != currentLicense.toUpperCase()) {
          final updatedUser = await widget.service.updateUserLicenseNumber(
            userId: _user.id,
            newLicenseNumber: requestedLicense,
            adminId: currentAdmin.id,
          );
          _user = updatedUser;
          _licenseNumberCtrl.text = updatedUser.numeroLicenza ?? '';
        }
      }

      await widget.service.updateProfile(
        _user.copyWith(
          role: _selectedRole,
          isTi: _user.isTi,
          isEtp: _user.isEtp,
          flightFitnessExpiry: _user.flightFitnessExpiry,
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
          {'helicopter_type_id': id, 'crew_type': 'MTB', 'tob_grade': null},
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
    final canEditLicenseNumber = auth.isAdminPriv && _user.isUser;
    final today = DateTime.now();
    final isFlightFitnessExpired =
        _user.flightFitnessExpiry != null &&
        _user.flightFitnessExpiry!.isBefore(
          DateTime(today.year, today.month, today.day),
        );

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
                        if (canEditLicenseNumber)
                          TextField(
                            controller: _licenseNumberCtrl,
                            textAlign: TextAlign.center,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Numero licenza (login)',
                              helperText:
                                  'Admin CSL può aggiornarlo: la password resta invariata',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          )
                        else
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
                        const SizedBox(height: 12),
                        if (isFlightFitnessExpired)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade700.withValues(
                                alpha: 0.18,
                              ),
                              border: Border.all(color: Colors.red.shade400),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.redAccent,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Idoneità al volo scaduta. Aggiorna la data di scadenza.',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Idoneità al volo - Scadenza'),
                          subtitle: Text(
                            _formatDate(_user.flightFitnessExpiry),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_user.flightFitnessExpiry != null)
                                IconButton(
                                  tooltip: 'Rimuovi data',
                                  onPressed: () => setState(
                                    () => _user = _user.copyWith(
                                      flightFitnessExpiry: null,
                                    ),
                                  ),
                                  icon: const Icon(Icons.close),
                                ),
                              OutlinedButton.icon(
                                onPressed: _pickFlightFitnessExpiry,
                                icon: const Icon(Icons.calendar_month_outlined),
                                label: const Text('Seleziona'),
                              ),
                            ],
                          ),
                        ),
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
                if (widget.showMaintenanceSections ||
                    widget.showCrewSections) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Builder(
                        builder: (context) {
                          final helicopterIds = _assignedHelicopterIds();
                          final helicopters = helicopterIds
                              .map(
                                (id) => widget.helicopterTypes.firstWhere(
                                  (item) => item.id == id,
                                  orElse: () => HelicopterType(
                                    id: id,
                                    code: '$id',
                                    name: 'Elicottero $id',
                                  ),
                                ),
                              )
                              .toList();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Assegnazioni per elicottero',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              if (helicopters.isEmpty)
                                const Text(
                                  'Nessuna assegnazione configurata per questo utente.',
                                )
                              else
                                ...helicopters.map((helicopter) {
                                  final selectedLicenseId =
                                      _selectedLicenseTypeIdFor(helicopter.id);
                                  final selectedPrivilegeIds =
                                      _selectedPrivilegeIdsFor(helicopter.id);
                                  final selectedPrivileges =
                                      widget.privilegeTypes
                                          .where(
                                            (item) => selectedPrivilegeIds
                                                .contains(item.id),
                                          )
                                          .toList()
                                        ..sort(
                                          (a, b) => a.sortOrder.compareTo(
                                            b.sortOrder,
                                          ),
                                        );
                                  final crewType = _crewTypeForHelicopter(
                                    helicopter.id,
                                  );
                                  final selectedCapabilityIds =
                                      _selectedTobCapabilityIdsFor(
                                        helicopter.id,
                                      );
                                  final selectedCapabilities = widget
                                      .tobCapabilities
                                      .where(
                                        (item) => selectedCapabilityIds
                                            .contains(item.id),
                                      )
                                      .toList();
                                  final licenseLabel = selectedLicenseId == null
                                      ? 'Nessuna'
                                      : widget.licenseTypes
                                            .firstWhere(
                                              (item) =>
                                                  item.id == selectedLicenseId,
                                              orElse: () => LicenseType(
                                                id: selectedLicenseId,
                                                code: '$selectedLicenseId',
                                                name: '$selectedLicenseId',
                                              ),
                                            )
                                            .name;
                                  final privilegeLabel =
                                      selectedPrivileges.isEmpty
                                      ? 'Nessuno'
                                      : selectedPrivileges
                                            .map((item) => item.code)
                                            .join(', ');
                                  final crewLabel = switch (crewType) {
                                    'T' => 'T',
                                    'MTB' => 'MTB',
                                    'TOB' =>
                                      selectedCapabilities.isEmpty
                                          ? 'TOB - Fascia ${_tobGrades[helicopter.id] ?? 'A'}'
                                          : 'TOB - Fascia ${_tobGrades[helicopter.id] ?? 'A'} [${selectedCapabilities.map((item) => item.code).join(', ')}]',
                                    _ => 'Nessuno',
                                  };

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ExpansionTile(
                                      initiallyExpanded: true,
                                      tilePadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 4,
                                      ),
                                      childrenPadding:
                                          const EdgeInsets.fromLTRB(
                                            16,
                                            4,
                                            16,
                                            16,
                                          ),
                                      title: Text(helicopter.name),
                                      subtitle: Text(
                                        'Licenza: $licenseLabel\nPrivilegi: $privilegeLabel\nCrew: $crewLabel',
                                      ),
                                      children: [
                                        if (widget.showMaintenanceSections) ...[
                                          const SizedBox(height: 8),
                                          DropdownButtonFormField<int?>(
                                            key: ValueKey(
                                              'license_${helicopter.id}_$selectedLicenseId',
                                            ),
                                            initialValue: selectedLicenseId,
                                            decoration: const InputDecoration(
                                              labelText: 'Tipo licenza',
                                              labelStyle: TextStyle(
                                                color: Colors.white70,
                                              ),
                                              floatingLabelStyle: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              contentPadding:
                                                  EdgeInsets.fromLTRB(
                                                    12,
                                                    20,
                                                    12,
                                                    8,
                                                  ),
                                            ),
                                            items: [
                                              const DropdownMenuItem<int?>(
                                                value: null,
                                                child: Text('Nessuna'),
                                              ),
                                              ...widget.licenseTypes.map(
                                                (item) =>
                                                    DropdownMenuItem<int?>(
                                                      value: item.id,
                                                      child: Text(item.name),
                                                    ),
                                              ),
                                            ],
                                            onChanged: (value) =>
                                                _setLicenseForHelicopter(
                                                  helicopter.id,
                                                  value,
                                                ),
                                          ),
                                          const SizedBox(height: 12),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              'Privilegi manutentivi',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleSmall,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: widget.privilegeTypes
                                                .map(
                                                  (item) => Tooltip(
                                                    message: item.name,
                                                    child: FilterChip(
                                                      selected:
                                                          selectedPrivilegeIds
                                                              .contains(
                                                                item.id,
                                                              ),
                                                      label: Text(item.code),
                                                      onSelected: (selected) =>
                                                          setState(() {
                                                            final key =
                                                                '${helicopter.id}:${item.id}';
                                                            if (selected) {
                                                              _privilegeKeys
                                                                  .add(key);
                                                            } else {
                                                              _privilegeKeys
                                                                  .remove(key);
                                                            }
                                                          }),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                        ],
                                        if (widget.showMaintenanceSections &&
                                            widget.showCrewSections)
                                          const Divider(height: 24),
                                        if (widget.showCrewSections) ...[
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              'Tipo equipaggio',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleSmall,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children:
                                                [
                                                      ('NONE', 'Nessuno'),
                                                      ('T', 'T'),
                                                      ('TOB', 'TOB'),
                                                      ('MTB', 'MTB'),
                                                    ]
                                                    .map(
                                                      (item) => ChoiceChip(
                                                        label: Text(item.$2),
                                                        selected:
                                                            crewType == item.$1,
                                                        onSelected: (_) =>
                                                            _setCrewTypeForHelicopter(
                                                              helicopter.id,
                                                              item.$1,
                                                            ),
                                                      ),
                                                    )
                                                    .toList(),
                                          ),
                                          if (crewType == 'TOB') ...[
                                            const SizedBox(height: 12),
                                            DropdownButtonFormField<String>(
                                              key: ValueKey(
                                                'tob_grade_${helicopter.id}_${_tobGrades[helicopter.id] ?? 'A'}',
                                              ),
                                              initialValue:
                                                  _tobGrades[helicopter.id] ??
                                                  'A',
                                              decoration: const InputDecoration(
                                                labelText: 'Fascia TOB',
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
                                              onChanged: (value) => setState(
                                                () =>
                                                    _tobGrades[helicopter.id] =
                                                        value ?? 'A',
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                'Capacità TOB',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.titleSmall,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: widget.tobCapabilities
                                                  .map(
                                                    (item) => FilterChip(
                                                      selected:
                                                          selectedCapabilityIds
                                                              .contains(
                                                                item.id,
                                                              ),
                                                      label: Text(item.code),
                                                      onSelected: (selected) =>
                                                          setState(() {
                                                            final key =
                                                                '${helicopter.id}:${item.id}';
                                                            if (selected) {
                                                              _tobCapabilityKeys
                                                                  .add(key);
                                                            } else {
                                                              _tobCapabilityKeys
                                                                  .remove(key);
                                                            }
                                                          }),
                                                    ),
                                                  )
                                                  .toList(),
                                            ),
                                          ],
                                        ],
                                      ],
                                    ),
                                  );
                                }),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final assignedIds = _assignedHelicopterIds()
                                      .toSet();
                                  final available = widget.helicopterTypes
                                      .where((h) => !assignedIds.contains(h.id))
                                      .toList();
                                  if (available.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Tutti gli elicotteri già assegnati.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  int? selectedId;
                                  await showDialog<void>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Aggiungi Elicottero'),
                                      content: StatefulBuilder(
                                        builder: (ctx, setD) =>
                                            DropdownButtonFormField<int>(
                                              decoration: const InputDecoration(
                                                labelText: 'Elicottero',
                                              ),
                                              items: available
                                                  .map(
                                                    (h) =>
                                                        DropdownMenuItem<int>(
                                                          value: h.id,
                                                          child: Text(h.name),
                                                        ),
                                                  )
                                                  .toList(),
                                              onChanged: (v) =>
                                                  setD(() => selectedId = v),
                                            ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('Annulla'),
                                        ),
                                        FilledButton(
                                          onPressed: () {
                                            if (selectedId != null) {
                                              setState(
                                                () => _addedHelicopters.add(
                                                  selectedId!,
                                                ),
                                              );
                                            }
                                            Navigator.pop(ctx);
                                          },
                                          child: const Text('Aggiungi'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Aggiungi Elicottero'),
                              ),
                            ],
                          );
                        },
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
