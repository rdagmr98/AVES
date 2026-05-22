import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../models/activity_models.dart';
import '../../models/user_models.dart';
import '../../services/activity_service.dart';
import '../../services/user_service.dart';

class InsertActivityAdminScreen extends ConsumerStatefulWidget {
  const InsertActivityAdminScreen({super.key});

  @override
  ConsumerState<InsertActivityAdminScreen> createState() =>
      _InsertActivityAdminScreenState();
}

enum _AdminInsertTabType { maintenance, flight, tob }

class _InsertActivityAdminScreenState
    extends ConsumerState<InsertActivityAdminScreen>
    with SingleTickerProviderStateMixin {
  final _activityService = ActivityService();
  final _userService = UserService();
  final _maintenanceDescCtrl = TextEditingController();
  final _flightDescCtrl = TextEditingController();
  final _tobDescCtrl = TextEditingController();
  final _flightHoursCtrl = TextEditingController();

  late final TabController _tabController;
  late final List<_AdminInsertTabType> _tabs;
  bool _loading = true;
  bool _saving = false;
  List<UserProfile> _users = [];
  UserProfile? _selectedUser;
  List<UserPrivilege> _privileges = [];
  List<UserCrewAssignment> _crews = [];
  List<UserTobCapability> _tobCapabilities = [];

  int? _maintenanceHelicopterId;
  int? _maintenancePrivilegeId;
  DateTime _maintenanceDate = DateTime.now();

  int? _flightHelicopterId;
  DateTime _flightDate = DateTime.now();

  int? _tobHelicopterId;
  int? _tobCapabilityId;
  DateTime _tobDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider);
    if (auth.isAdminPriv) {
      _tabs = const [_AdminInsertTabType.maintenance];
    } else if (auth.isAdminCrew) {
      _tabs = const [_AdminInsertTabType.flight, _AdminInsertTabType.tob];
    } else {
      _tabs = const [
        _AdminInsertTabType.maintenance,
        _AdminInsertTabType.flight,
        _AdminInsertTabType.tob,
      ];
    }
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _maintenanceDescCtrl.dispose();
    _flightDescCtrl.dispose();
    _tobDescCtrl.dispose();
    _flightHoursCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final users = await _userService.getAllUsers();
    if (!mounted) {
      return;
    }
    setState(() {
      _users = users.where((item) => item.isApproved).toList();
      _loading = false;
    });
  }

  Future<void> _selectUser(UserProfile? user) async {
    setState(() {
      _selectedUser = user;
      _privileges = [];
      _crews = [];
      _tobCapabilities = [];
    });
    if (user == null) {
      return;
    }
    final privileges = await _userService.getUserPrivileges(user.id);
    final crews = await _userService.getUserCrewAssignments(user.id);
    final tobCapabilities = await _userService.getUserTobCapabilities(user.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _privileges = privileges;
      _crews = crews;
      _tobCapabilities = tobCapabilities;
    });
  }

  Future<void> _pickDate(ValueSetter<DateTime> onSet, DateTime current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => onSet(picked));
    }
  }

  Future<void> _submitMaintenance() async {
    final user = _selectedUser;
    final adminId = ref.read(authProvider).userProfile?.id;
    if (user == null ||
        adminId == null ||
        _maintenanceHelicopterId == null ||
        _maintenancePrivilegeId == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      await _activityService.addMaintenanceActivityValidated(
        MaintenanceActivity(
          userId: user.id,
          helicopterTypeId: _maintenanceHelicopterId!,
          privilegeTypeId: _maintenancePrivilegeId!,
          activityDate: _maintenanceDate,
          description: _maintenanceDescCtrl.text.trim().isEmpty
              ? null
              : _maintenanceDescCtrl.text.trim(),
          submittedBy: adminId,
        ),
        adminId,
      );
      _finish();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _submitFlight() async {
    final user = _selectedUser;
    final adminId = ref.read(authProvider).userProfile?.id;
    final hours = double.tryParse(_flightHoursCtrl.text.replaceAll(',', '.'));
    if (user == null ||
        adminId == null ||
        _flightHelicopterId == null ||
        hours == null ||
        hours <= 0) {
      return;
    }
    setState(() => _saving = true);
    try {
      await _activityService.addFlightActivityValidated(
        FlightActivity(
          userId: user.id,
          helicopterTypeId: _flightHelicopterId!,
          activityDate: _flightDate,
          flightHours: hours,
          description: _flightDescCtrl.text.trim().isEmpty
              ? null
              : _flightDescCtrl.text.trim(),
          submittedBy: adminId,
        ),
        adminId,
      );
      _finish();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _submitTob() async {
    final user = _selectedUser;
    final adminId = ref.read(authProvider).userProfile?.id;
    if (user == null ||
        adminId == null ||
        _tobHelicopterId == null ||
        _tobCapabilityId == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      await _activityService.addTobActivityValidated(
        TobActivity(
          userId: user.id,
          helicopterTypeId: _tobHelicopterId!,
          tobCapabilityId: _tobCapabilityId!,
          activityDate: _tobDate,
          description: _tobDescCtrl.text.trim().isEmpty
              ? null
              : _tobDescCtrl.text.trim(),
          submittedBy: adminId,
        ),
        adminId,
      );
      _finish();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  void _finish() {
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attività inserita come validata.')),
    );
    context.go('/admin/validate');
  }

  @override
  Widget build(BuildContext context) {
    final maintenanceHelicopters = _uniqueHelicoptersFromPrivileges(_privileges);
    final filteredPrivileges = _privileges
        .where((item) => item.helicopterTypeId == _maintenanceHelicopterId)
        .toList();
    final tAssignments = _crews.where((item) => item.crewType == 'T').toList();
    final tobAssignments = _crews.where((item) => item.crewType == 'TOB').toList();
    final flightHelicopters = _uniqueCrewHelicopters(tAssignments);
    final tobHelicopters = _uniqueCrewHelicopters(tobAssignments);
    final filteredCapabilities = _tobCapabilities
        .where((item) => item.helicopterTypeId == _tobHelicopterId)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inserimento attività amministrativo'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs
              .map(
                (tab) => Tab(
                  text: switch (tab) {
                    _AdminInsertTabType.maintenance => 'Manutenzione',
                    _AdminInsertTabType.flight => 'Volo',
                    _AdminInsertTabType.tob => 'TOB',
                  },
                ),
              )
              .toList(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedUser?.id,
                  decoration: const InputDecoration(labelText: 'Seleziona utente'),
                  items: _users
                      .map(
                        (user) => DropdownMenuItem<String>(
                          value: user.id,
                          child: Text(
                            '${user.fullName} · ${user.numeroLicenza ?? 'N/A'}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    UserProfile? user;
                    for (final item in _users) {
                      if (item.id == value) {
                        user = item;
                        break;
                      }
                    }
                    _selectUser(user);
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 640,
                  child: TabBarView(
                    controller: _tabController,
                    children: _tabs.map((tab) {
                      switch (tab) {
                        case _AdminInsertTabType.maintenance:
                          return _AdminActivityTab(
                            enabled: _selectedUser != null && maintenanceHelicopters.isNotEmpty,
                            child: _AdminActivityCard(
                              children: [
                                DropdownButtonFormField<int>(
                                  initialValue: maintenanceHelicopters.any(
                                    (item) => item.id == _maintenanceHelicopterId,
                                  )
                                      ? _maintenanceHelicopterId
                                      : null,
                                  decoration: const InputDecoration(labelText: 'Elicottero'),
                                  items: maintenanceHelicopters
                                      .map(
                                        (item) => DropdownMenuItem<int>(
                                          value: item.id,
                                          child: Text('${item.code} - ${item.name}'),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => _maintenanceHelicopterId = value),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<int>(
                                  initialValue: filteredPrivileges.any(
                                    (item) => item.privilegeTypeId == _maintenancePrivilegeId,
                                  )
                                      ? _maintenancePrivilegeId
                                      : null,
                                  decoration: const InputDecoration(labelText: 'Privilegio'),
                                  items: filteredPrivileges
                                      .map(
                                        (item) => DropdownMenuItem<int>(
                                          value: item.privilegeTypeId,
                                          child: Text(item.privilegeName),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => _maintenancePrivilegeId = value),
                                ),
                                const SizedBox(height: 16),
                                _AdminDateButton(
                                  label: 'Data attività',
                                  date: _maintenanceDate,
                                  onPressed: () => _pickDate(
                                    (value) => _maintenanceDate = value,
                                    _maintenanceDate,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _maintenanceDescCtrl,
                                  maxLines: 3,
                                  decoration: const InputDecoration(labelText: 'Descrizione'),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: _saving ? null : _submitMaintenance,
                                  child: const Text('Inserisci come validata'),
                                ),
                              ],
                            ),
                          );
                        case _AdminInsertTabType.flight:
                          return _AdminActivityTab(
                            enabled: _selectedUser != null && flightHelicopters.isNotEmpty,
                            child: _AdminActivityCard(
                              children: [
                                DropdownButtonFormField<int>(
                                  initialValue: flightHelicopters.any(
                                    (item) => item.id == _flightHelicopterId,
                                  )
                                      ? _flightHelicopterId
                                      : null,
                                  decoration: const InputDecoration(labelText: 'Elicottero'),
                                  items: flightHelicopters
                                      .map(
                                        (item) => DropdownMenuItem<int>(
                                          value: item.id,
                                          child: Text('${item.code} - ${item.name}'),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => _flightHelicopterId = value),
                                ),
                                const SizedBox(height: 16),
                                _AdminDateButton(
                                  label: 'Data volo',
                                  date: _flightDate,
                                  onPressed: () => _pickDate(
                                    (value) => _flightDate = value,
                                    _flightDate,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _flightHoursCtrl,
                                  decoration: const InputDecoration(labelText: 'Ore di volo'),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(decimal: true),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _flightDescCtrl,
                                  maxLines: 3,
                                  decoration: const InputDecoration(labelText: 'Descrizione'),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: _saving ? null : _submitFlight,
                                  child: const Text('Inserisci come validata'),
                                ),
                              ],
                            ),
                          );
                        case _AdminInsertTabType.tob:
                          return _AdminActivityTab(
                            enabled: _selectedUser != null && tobHelicopters.isNotEmpty,
                            child: _AdminActivityCard(
                              children: [
                                DropdownButtonFormField<int>(
                                  initialValue: tobHelicopters.any(
                                    (item) => item.id == _tobHelicopterId,
                                  )
                                      ? _tobHelicopterId
                                      : null,
                                  decoration: const InputDecoration(labelText: 'Elicottero'),
                                  items: tobHelicopters
                                      .map(
                                        (item) => DropdownMenuItem<int>(
                                          value: item.id,
                                          child: Text('${item.code} - ${item.name}'),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => _tobHelicopterId = value),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<int>(
                                  initialValue: filteredCapabilities.any(
                                    (item) => item.tobCapabilityId == _tobCapabilityId,
                                  )
                                      ? _tobCapabilityId
                                      : null,
                                  decoration: const InputDecoration(labelText: 'Capacità TOB'),
                                  items: filteredCapabilities
                                      .map(
                                        (item) => DropdownMenuItem<int>(
                                          value: item.tobCapabilityId,
                                          child: Text(item.capabilityName),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => _tobCapabilityId = value),
                                ),
                                const SizedBox(height: 16),
                                _AdminDateButton(
                                  label: 'Data attività TOB',
                                  date: _tobDate,
                                  onPressed: () => _pickDate(
                                    (value) => _tobDate = value,
                                    _tobDate,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _tobDescCtrl,
                                  maxLines: 3,
                                  decoration: const InputDecoration(labelText: 'Descrizione'),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: _saving ? null : _submitTob,
                                  child: const Text('Inserisci come validata'),
                                ),
                              ],
                            ),
                          );
                      }
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }

  List<_ActivityHelicopterOption> _uniqueHelicoptersFromPrivileges(
    List<UserPrivilege> privileges,
  ) {
    final map = <int, _ActivityHelicopterOption>{};
    for (final privilege in privileges) {
      map[privilege.helicopterTypeId] = _ActivityHelicopterOption(
        id: privilege.helicopterTypeId,
        code: privilege.helicopterCode,
        name: privilege.helicopterName,
      );
    }
    return map.values.toList();
  }

  List<_ActivityHelicopterOption> _uniqueCrewHelicopters(
    List<UserCrewAssignment> assignments,
  ) {
    final map = <int, _ActivityHelicopterOption>{};
    for (final assignment in assignments) {
      map[assignment.helicopterTypeId] = _ActivityHelicopterOption(
        id: assignment.helicopterTypeId,
        code: assignment.helicopterCode,
        name: assignment.helicopterName,
      );
    }
    return map.values.toList();
  }
}

class _ActivityHelicopterOption {
  const _ActivityHelicopterOption({
    required this.id,
    required this.code,
    required this.name,
  });

  final int id;
  final String code;
  final String name;
}

class _AdminActivityTab extends StatelessWidget {
  const _AdminActivityTab({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return const Center(
        child: Text('Seleziona un utente con le abilitazioni richieste.'),
      );
    }
    return SingleChildScrollView(child: child);
  }
}

class _AdminActivityCard extends StatelessWidget {
  const _AdminActivityCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: children),
          ),
        ),
      ),
    );
  }
}

class _AdminDateButton extends StatelessWidget {
  const _AdminDateButton({
    required this.label,
    required this.date,
    required this.onPressed,
  });

  final String label;
  final DateTime date;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.calendar_today_outlined),
      label: Text('$label: ${DateFormat('dd/MM/yyyy').format(date)}'),
    );
  }
}
