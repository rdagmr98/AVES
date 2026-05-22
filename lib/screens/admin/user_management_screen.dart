import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../models/reference_models.dart';
import '../../models/user_models.dart';
import '../../services/user_service.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  final _service = UserService();

  bool _loading = true;
  bool _saving = false;
  List<UserProfile> _users = [];
  UserProfile? _selectedUser;
  String _selectedRole = 'user';

  Set<String> _licenseKeys = <String>{};
  Set<String> _privilegeKeys = <String>{};
  Set<int> _tCrewHelicopters = <int>{};
  Set<int> _tobCrewHelicopters = <int>{};
  Set<String> _tobCapabilityKeys = <String>{};
  Map<int, String> _tobGrades = <int, String>{};

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    final users = await _service.getAllUsers();
    if (!mounted) {
      return;
    }
    setState(() {
      _users = users;
      _loading = false;
    });
    if (users.isNotEmpty) {
      final selectedId = _selectedUser?.id;
      final matched = users
          .where((item) => item.id == selectedId)
          .cast<UserProfile?>()
          .firstWhere((item) => item != null, orElse: () => users.first);
      await _selectUser(matched!);
    }
  }

  Future<void> _selectUser(UserProfile user) async {
    setState(() {
      _selectedUser = user;
      _selectedRole = user.role;
      _saving = false;
    });

    final licenses = await _service.getUserLicenses(user.id);
    final privileges = await _service.getUserPrivileges(user.id);
    final crews = await _service.getUserCrewAssignments(user.id);
    final tobCaps = await _service.getUserTobCapabilities(user.id);

    if (!mounted) {
      return;
    }
    setState(() {
      _licenseKeys = licenses
          .map((item) => '${item.helicopterTypeId}:${item.licenseTypeId}')
          .toSet();
      _privilegeKeys = privileges
          .map((item) => '${item.helicopterTypeId}:${item.privilegeTypeId}')
          .toSet();
      _tCrewHelicopters = crews
          .where((item) => item.crewType == 'T')
          .map((item) => item.helicopterTypeId)
          .toSet();
      _tobCrewHelicopters = crews
          .where((item) => item.crewType == 'TOB')
          .map((item) => item.helicopterTypeId)
          .toSet();
      _tobGrades = {
        for (final item in crews.where((element) => element.crewType == 'TOB'))
          item.helicopterTypeId: item.fascia ?? 'A',
      };
      _tobCapabilityKeys = tobCaps
          .map((item) => '${item.helicopterTypeId}:${item.tobCapabilityId}')
          .toSet();
    });
  }

  Future<void> _approveUser() async {
    if (_selectedUser == null) {
      return;
    }
    final adminId = ref.read(authProvider).userProfile?.id;
    if (adminId == null) {
      return;
    }
    try {
      await _service.approveUser(_selectedUser!.id, adminId);
      await _loadUsers();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Utente approvato.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _saveAssignments() async {
    final user = _selectedUser;
    if (user == null) {
      return;
    }
    setState(() => _saving = true);

    try {
      await _service.updateProfile(user.copyWith(role: _selectedRole));
      await _service.setUserLicenses(
        user.id,
        _licenseKeys.map((key) {
          final parts = key.split(':');
          return {
            'helicopter_type_id': int.parse(parts[0]),
            'license_type_id': int.parse(parts[1]),
          };
        }).toList(),
      );
      await _service.setUserPrivileges(
        user.id,
        _privilegeKeys.map((key) {
          final parts = key.split(':');
          return {
            'helicopter_type_id': int.parse(parts[0]),
            'privilege_type_id': int.parse(parts[1]),
          };
        }).toList(),
      );

      final assignments = <Map<String, dynamic>>[];
      for (final helicopterId in _tCrewHelicopters) {
        assignments.add({
          'helicopter_type_id': helicopterId,
          'crew_type': 'T',
          'tob_grade': null,
        });
      }
      for (final helicopterId in _tobCrewHelicopters) {
        assignments.add({
          'helicopter_type_id': helicopterId,
          'crew_type': 'TOB',
          'tob_grade': _tobGrades[helicopterId] ?? 'A',
        });
      }
      await _service.setUserCrewAssignments(user.id, assignments);
      await _service.setUserTobCapabilities(
        user.id,
        _tobCapabilityKeys.map((key) {
          final parts = key.split(':');
          return {
            'helicopter_type_id': int.parse(parts[0]),
            'tob_capability_id': int.parse(parts[1]),
          };
        }).toList(),
      );

      if (!mounted) {
        return;
      }

      await _loadUsers();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ruoli e assegnazioni salvati.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final helicopterTypes = auth.helicopterTypes;
    final licenseTypes = auth.licenseTypes;
    final privilegeTypes = auth.privilegeTypes;
    final tobCapabilities = auth.tobCapabilityTypes;

    return Scaffold(
      appBar: AppBar(title: const Text('Gestione Utenti')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final detail = _selectedUser == null
                    ? const Center(
                        child: Text(
                          'Seleziona un utente per vedere i dettagli.',
                        ),
                      )
                    : _UserDetailPanel(
                        user: _selectedUser!,
                        selectedRole: _selectedRole,
                        onRoleChanged: (value) =>
                            setState(() => _selectedRole = value ?? 'user'),
                        onApprove: _approveUser,
                        onSave: _saving ? null : _saveAssignments,
                        helicopterTypes: helicopterTypes,
                        licenseTypes: licenseTypes,
                        privilegeTypes: privilegeTypes,
                        tobCapabilities: tobCapabilities,
                        licenseKeys: _licenseKeys,
                        privilegeKeys: _privilegeKeys,
                        tCrewHelicopters: _tCrewHelicopters,
                        tobCrewHelicopters: _tobCrewHelicopters,
                        tobCapabilityKeys: _tobCapabilityKeys,
                        tobGrades: _tobGrades,
                        onToggleLicense: (key) =>
                            setState(() => _toggleKey(_licenseKeys, key)),
                        onTogglePrivilege: (key) =>
                            setState(() => _toggleKey(_privilegeKeys, key)),
                        onToggleTCrew: (helicopterId) => setState(
                          () => _toggleInt(_tCrewHelicopters, helicopterId),
                        ),
                        onToggleTobCrew: (helicopterId) => setState(() {
                          _toggleInt(_tobCrewHelicopters, helicopterId);
                          _tobGrades.putIfAbsent(helicopterId, () => 'A');
                        }),
                        onToggleTobCapability: (key) =>
                            setState(() => _toggleKey(_tobCapabilityKeys, key)),
                        onTobGradeChanged: (helicopterId, value) => setState(
                          () => _tobGrades[helicopterId] = value ?? 'A',
                        ),
                      );

                if (constraints.maxWidth < 1000) {
                  return Column(
                    children: [
                      Expanded(
                        child: _UserList(
                          users: _users,
                          selected: _selectedUser,
                          onSelected: _selectUser,
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(child: detail),
                    ],
                  );
                }

                return Row(
                  children: [
                    SizedBox(
                      width: 340,
                      child: _UserList(
                        users: _users,
                        selected: _selectedUser,
                        onSelected: _selectUser,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: detail),
                  ],
                );
              },
            ),
    );
  }

  void _toggleKey(Set<String> values, String key) {
    if (values.contains(key)) {
      values.remove(key);
    } else {
      values.add(key);
    }
  }

  void _toggleInt(Set<int> values, int key) {
    if (values.contains(key)) {
      values.remove(key);
    } else {
      values.add(key);
    }
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
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: users.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final user = users[index];
        final selectedUser = selected?.id == user.id;
        return Card(
          color: !user.isApproved
              ? Colors.amber.withValues(alpha: 0.12)
              : selectedUser
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.16)
              : null,
          child: ListTile(
            onTap: () => onSelected(user),
            title: Text(user.fullName),
            subtitle: Text('${user.qualifica} · ${user.orgUnitName}'.trim()),
            trailing: user.isApproved
                ? const Icon(Icons.verified, color: Colors.green)
                : const Icon(Icons.pending_actions, color: Colors.amber),
          ),
        );
      },
    );
  }
}

class _UserDetailPanel extends StatelessWidget {
  const _UserDetailPanel({
    required this.user,
    required this.selectedRole,
    required this.onRoleChanged,
    required this.onApprove,
    required this.onSave,
    required this.helicopterTypes,
    required this.licenseTypes,
    required this.privilegeTypes,
    required this.tobCapabilities,
    required this.licenseKeys,
    required this.privilegeKeys,
    required this.tCrewHelicopters,
    required this.tobCrewHelicopters,
    required this.tobCapabilityKeys,
    required this.tobGrades,
    required this.onToggleLicense,
    required this.onTogglePrivilege,
    required this.onToggleTCrew,
    required this.onToggleTobCrew,
    required this.onToggleTobCapability,
    required this.onTobGradeChanged,
  });

  final UserProfile user;
  final String selectedRole;
  final ValueChanged<String?> onRoleChanged;
  final Future<void> Function() onApprove;
  final Future<void> Function()? onSave;
  final List<HelicopterType> helicopterTypes;
  final List<LicenseType> licenseTypes;
  final List<PrivilegeType> privilegeTypes;
  final List<TobCapability> tobCapabilities;
  final Set<String> licenseKeys;
  final Set<String> privilegeKeys;
  final Set<int> tCrewHelicopters;
  final Set<int> tobCrewHelicopters;
  final Set<String> tobCapabilityKeys;
  final Map<int, String> tobGrades;
  final ValueChanged<String> onToggleLicense;
  final ValueChanged<String> onTogglePrivilege;
  final ValueChanged<int> onToggleTCrew;
  final ValueChanged<int> onToggleTobCrew;
  final ValueChanged<String> onToggleTobCapability;
  final void Function(int helicopterId, String? value) onTobGradeChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${user.qualifica} · ${user.orgUnitName}'.trim(),
                          ),
                          Text(
                            'Licenza: ${user.numeroLicenza ?? 'Non indicata'}',
                          ),
                        ],
                      ),
                    ),
                    if (!user.isApproved)
                      ElevatedButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.verified_user_outlined),
                        label: const Text('Approva utente'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(labelText: 'Ruolo'),
                  items: const [
                    DropdownMenuItem(value: 'user', child: Text('Utente')),
                    DropdownMenuItem(
                      value: 'admin_priv',
                      child: Text('Admin privilegi'),
                    ),
                    DropdownMenuItem(
                      value: 'admin_crew',
                      child: Text('Admin equipaggi'),
                    ),
                  ],
                  onChanged: onRoleChanged,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _AssignmentSection(
          title: 'Licenze',
          children: helicopterTypes
              .map(
                (helicopter) => _HelicopterCheckboxGroup(
                  title: '${helicopter.code} - ${helicopter.name}',
                  children: licenseTypes
                      .map(
                        (license) => FilterChip(
                          selected: licenseKeys.contains(
                            '${helicopter.id}:${license.id}',
                          ),
                          label: Text(license.name),
                          onSelected: (_) =>
                              onToggleLicense('${helicopter.id}:${license.id}'),
                        ),
                      )
                      .toList(),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        _AssignmentSection(
          title: 'Privilegi',
          children: helicopterTypes
              .map(
                (helicopter) => _HelicopterCheckboxGroup(
                  title: '${helicopter.code} - ${helicopter.name}',
                  children: privilegeTypes
                      .map(
                        (privilege) => FilterChip(
                          selected: privilegeKeys.contains(
                            '${helicopter.id}:${privilege.id}',
                          ),
                          label: Text(privilege.name),
                          onSelected: (_) => onTogglePrivilege(
                            '${helicopter.id}:${privilege.id}',
                          ),
                        ),
                      )
                      .toList(),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        _AssignmentSection(
          title: 'Assegnazioni equipaggi',
          children: helicopterTypes
              .map(
                (helicopter) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${helicopter.code} - ${helicopter.name}'),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Equipaggio T'),
                          value: tCrewHelicopters.contains(helicopter.id),
                          onChanged: (_) => onToggleTCrew(helicopter.id),
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Equipaggio TOB'),
                          value: tobCrewHelicopters.contains(helicopter.id),
                          onChanged: (_) => onToggleTobCrew(helicopter.id),
                        ),
                        if (tobCrewHelicopters.contains(helicopter.id))
                          DropdownButtonFormField<String>(
                            initialValue: tobGrades[helicopter.id] ?? 'A',
                            decoration: const InputDecoration(
                              labelText: 'Fascia TOB',
                            ),
                            items: const [
                              DropdownMenuItem(value: 'A', child: Text('A')),
                              DropdownMenuItem(value: 'B', child: Text('B')),
                              DropdownMenuItem(value: 'C', child: Text('C')),
                            ],
                            onChanged: (value) =>
                                onTobGradeChanged(helicopter.id, value),
                          ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        _AssignmentSection(
          title: 'Capacità TOB',
          children: helicopterTypes
              .map(
                (helicopter) => _HelicopterCheckboxGroup(
                  title: '${helicopter.code} - ${helicopter.name}',
                  children: tobCapabilities
                      .map(
                        (capability) => FilterChip(
                          selected: tobCapabilityKeys.contains(
                            '${helicopter.id}:${capability.id}',
                          ),
                          label: Text(capability.name),
                          onSelected: (_) => onToggleTobCapability(
                            '${helicopter.id}:${capability.id}',
                          ),
                        ),
                      )
                      .toList(),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Salva ruolo e assegnazioni'),
          ),
        ),
      ],
    );
  }
}

class _AssignmentSection extends StatelessWidget {
  const _AssignmentSection({required this.title, required this.children});

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
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _HelicopterCheckboxGroup extends StatelessWidget {
  const _HelicopterCheckboxGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}
