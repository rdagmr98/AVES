import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../models/activity_models.dart';
import '../../models/reference_models.dart';
import '../../models/user_models.dart';
import '../../services/activity_service.dart';
import '../../services/user_service.dart';

class InsertActivityAdminScreen extends ConsumerStatefulWidget {
  const InsertActivityAdminScreen({super.key});

  @override
  ConsumerState<InsertActivityAdminScreen> createState() =>
      _InsertActivityAdminScreenState();
}

enum _AdminInsertTabType { workOrder, maintenance, flight, tob, crewFlight }

class _InsertActivityAdminScreenState
    extends ConsumerState<InsertActivityAdminScreen>
    with SingleTickerProviderStateMixin {
  final _activityService = ActivityService();
  final _userService = UserService();
  final _maintenanceDescCtrl = TextEditingController();
  final _maintenanceMatricolaCtrl = TextEditingController();
  final _maintenanceNumCarrCtrl = TextEditingController();
  final _maintenanceOrdLavCtrl = TextEditingController();
  final _flightDescCtrl = TextEditingController();
  final _tobDescCtrl = TextEditingController();
  final _flightHoursCtrl = TextEditingController();
  final _crewFlightHoursCtrl = TextEditingController();
  final _crewFlightDescCtrl = TextEditingController();
  final _workOrderMatricolaCtrl = TextEditingController();
  final _workOrderNumCarrCtrl = TextEditingController();
  final _workOrderOrdLavCtrl = TextEditingController();
  final _workOrderDescCtrl = TextEditingController();

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
  String? _maintenanceActivityType;

  int? _flightHelicopterId;
  DateTime _flightDate = DateTime.now();

  int? _tobHelicopterId;
  int? _tobCapabilityId;
  DateTime _tobDate = DateTime.now();

  int? _workOrderHelicopterId;
  DateTime _workOrderDate = DateTime.now();
  String? _workOrderActivityType;
  final List<_TechEntry> _techEntries = [];

  int? _crewFlightHelicopterId;
  DateTime _crewFlightDate = DateTime.now();
  final List<_CrewEntry> _crewEntries = [];

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider);
    if (auth.isAdminPriv) {
      _tabs = const [
        _AdminInsertTabType.workOrder,
        _AdminInsertTabType.maintenance,
      ];
    } else if (auth.isAdminCrew) {
      _tabs = const [
        _AdminInsertTabType.crewFlight,
        _AdminInsertTabType.flight,
        _AdminInsertTabType.tob,
      ];
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
    _maintenanceMatricolaCtrl.dispose();
    _maintenanceNumCarrCtrl.dispose();
    _maintenanceOrdLavCtrl.dispose();
    _flightDescCtrl.dispose();
    _tobDescCtrl.dispose();
    _flightHoursCtrl.dispose();
    _crewFlightHoursCtrl.dispose();
    _crewFlightDescCtrl.dispose();
    _workOrderMatricolaCtrl.dispose();
    _workOrderNumCarrCtrl.dispose();
    _workOrderOrdLavCtrl.dispose();
    _workOrderDescCtrl.dispose();
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
          activityType: _maintenanceActivityType,
          matricolaMilitare: _maintenanceMatricolaCtrl.text.trim().isEmpty
              ? null
              : _maintenanceMatricolaCtrl.text.trim(),
          numeroCorrozzella: _maintenanceNumCarrCtrl.text.trim().isEmpty
              ? null
              : _maintenanceNumCarrCtrl.text.trim(),
          ordineLavoro: _maintenanceOrdLavCtrl.text.trim().isEmpty
              ? null
              : _maintenanceOrdLavCtrl.text.trim(),
          submittedBy: adminId,
        ),
        adminId,
      );
      _finish();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _addCrewEntry(List<TobCapability> tobCapabilities) async {
    final helicopterId = _crewFlightHelicopterId;
    if (helicopterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona prima un elicottero.')),
      );
      return;
    }
    final availableUsers = _users
        .where((u) => !_crewEntries.any((e) => e.user.id == u.id))
        .toList(growable: false);
    final roleItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'T', child: Text('T')),
      const DropdownMenuItem(value: 'TOB', child: Text('TOB')),
    ];
    final capabilityItems = tobCapabilities
        .map(
          (item) =>
              DropdownMenuItem<int>(value: item.id, child: Text(item.name)),
        )
        .toList(growable: false);

    final result = await showDialog<_CrewEntry>(
      context: context,
      builder: (ctx) {
        String? userId;
        String role = 'T';
        int? capId;
        String? capName;
        return StatefulBuilder(
          builder: (context, setD) => AlertDialog(
            scrollable: true,
            title: const Text('Aggiungi membro equipaggio'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Membro'),
                  menuMaxHeight: 300,
                  items: availableUsers
                      .map(
                        (u) => DropdownMenuItem<String>(
                          value: u.id,
                          child: Text(
                            '${u.fullName} · ${u.numeroLicenza ?? ''}',
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (v) => setD(() => userId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Ruolo'),
                  items: roleItems,
                  onChanged: (v) => setD(() {
                    role = v ?? 'T';
                    capId = null;
                    capName = null;
                  }),
                ),
                if (role == 'TOB') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Capacità TOB',
                    ),
                    menuMaxHeight: 300,
                    items: capabilityItems,
                    onChanged: (v) {
                      setD(() {
                        capId = v;
                        capName = tobCapabilities
                            .firstWhere((c) => c.id == v)
                            .name;
                      });
                    },
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (userId == null) {
                    return;
                  }
                  if (role == 'TOB' && capId == null) {
                    return;
                  }
                  final user = _users.firstWhere((u) => u.id == userId);
                  Navigator.pop(
                    ctx,
                    _CrewEntry(
                      user: user,
                      role: role,
                      tobCapabilityId: capId,
                      tobCapabilityName: capName,
                    ),
                  );
                },
                child: const Text('Aggiungi'),
              ),
            ],
          ),
        );
      },
    );
    if (result != null && mounted) {
      setState(() => _crewEntries.add(result));
    }
  }

  Future<void> _addTechEntry() async {
    final helicopterId = _workOrderHelicopterId;
    if (helicopterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona prima un elicottero.')),
      );
      return;
    }
    final availableUsers = _users
        .where((u) => !_techEntries.any((e) => e.user.id == u.id))
        .toList(growable: false);
    if (availableUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nessun tecnico disponibile da aggiungere.'),
        ),
      );
      return;
    }

    String? selectedUserId;
    int? selectedPrivilegeId;
    String? selectedPrivilegeName;
    List<UserPrivilege> userPrivileges = [];

    final result = await showDialog<_TechEntry>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setD) => AlertDialog(
            scrollable: true,
            title: const Text('Aggiungi tecnico'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  menuMaxHeight: 300,
                  decoration: const InputDecoration(labelText: 'Tecnico'),
                  items: availableUsers
                      .map(
                        (u) => DropdownMenuItem<String>(
                          value: u.id,
                          child: Text(
                            '${u.fullName} · ${u.numeroLicenza ?? ''}',
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) async {
                    setD(() {
                      selectedUserId = value;
                      selectedPrivilegeId = null;
                      selectedPrivilegeName = null;
                      userPrivileges = [];
                    });
                    if (value != null) {
                      final privileges = await _userService.getUserPrivileges(
                        value,
                      );
                      final filtered = privileges
                          .where((p) => p.helicopterTypeId == helicopterId)
                          .toList(growable: false);
                      if (ctx.mounted) {
                        setD(() => userPrivileges = filtered);
                      }
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (userPrivileges.isNotEmpty)
                  DropdownButtonFormField<int>(
                    menuMaxHeight: 300,
                    decoration: const InputDecoration(
                      labelText: 'Privilegio esercitato',
                    ),
                    items: userPrivileges
                        .map(
                          (p) => DropdownMenuItem<int>(
                            value: p.privilegeTypeId,
                            child: Text(p.privilegeName),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      final privilege = userPrivileges.firstWhere(
                        (p) => p.privilegeTypeId == value,
                      );
                      setD(() {
                        selectedPrivilegeId = value;
                        selectedPrivilegeName = privilege.privilegeName;
                      });
                    },
                  )
                else if (selectedUserId != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Nessun privilegio su questo elicottero.',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (selectedUserId == null || selectedPrivilegeId == null) {
                    return;
                  }
                  final user = _users.firstWhere((u) => u.id == selectedUserId);
                  Navigator.pop(
                    ctx,
                    _TechEntry(
                      user: user,
                      privilegeTypeId: selectedPrivilegeId!,
                      privilegeName: selectedPrivilegeName ?? '',
                    ),
                  );
                },
                child: const Text('Aggiungi'),
              ),
            ],
          ),
        );
      },
    );
    if (result != null && mounted) {
      setState(() => _techEntries.add(result));
    }
  }

  Future<void> _submitWorkOrder() async {
    final adminId = ref.read(authProvider).userProfile?.id;
    final helicopterId = _workOrderHelicopterId;
    if (adminId == null || helicopterId == null || _techEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compila elicottero e aggiungi almeno un tecnico.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final desc = _workOrderDescCtrl.text.trim().isEmpty
          ? null
          : _workOrderDescCtrl.text.trim();
      final matricola = _workOrderMatricolaCtrl.text.trim().isEmpty
          ? null
          : _workOrderMatricolaCtrl.text.trim();
      final numCarr = _workOrderNumCarrCtrl.text.trim().isEmpty
          ? null
          : _workOrderNumCarrCtrl.text.trim();
      final ordLav = _workOrderOrdLavCtrl.text.trim().isEmpty
          ? null
          : _workOrderOrdLavCtrl.text.trim();
      for (final entry in _techEntries) {
        await _activityService.addMaintenanceActivityValidated(
          MaintenanceActivity(
            userId: entry.user.id,
            helicopterTypeId: helicopterId,
            privilegeTypeId: entry.privilegeTypeId,
            activityDate: _workOrderDate,
            description: desc,
            submittedBy: adminId,
            activityType: _workOrderActivityType,
            matricolaMilitare: matricola,
            numeroCorrozzella: numCarr,
            ordineLavoro: ordLav,
          ),
          adminId,
        );
      }
      if (mounted) {
        setState(() {
          _saving = false;
          _techEntries.clear();
          _workOrderHelicopterId = null;
          _workOrderMatricolaCtrl.clear();
          _workOrderNumCarrCtrl.clear();
          _workOrderOrdLavCtrl.clear();
          _workOrderDescCtrl.clear();
          _workOrderActivityType = null;
          _workOrderDate = DateTime.now();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ordine di lavoro inserito per tutti i tecnici.'),
          ),
        );
        context.go('/admin/validate');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _submitCrewFlight() async {
    final adminId = ref.read(authProvider).userProfile?.id;
    final helicopterId = _crewFlightHelicopterId;
    final hours = double.tryParse(
      _crewFlightHoursCtrl.text.replaceAll(',', '.'),
    );
    if (adminId == null || helicopterId == null || _crewEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compila tutti i campi e aggiungi almeno un membro.'),
        ),
      );
      return;
    }
    if (_crewEntries.any((e) => e.role == 'T') &&
        (hours == null || hours <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci le ore di volo per i membri T.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final desc = _crewFlightDescCtrl.text.trim().isEmpty
          ? null
          : _crewFlightDescCtrl.text.trim();
      for (final entry in _crewEntries) {
        if (entry.role == 'T') {
          await _activityService.addFlightActivityValidated(
            FlightActivity(
              userId: entry.user.id,
              helicopterTypeId: helicopterId,
              activityDate: _crewFlightDate,
              flightHours: hours ?? 0,
              description: desc,
              submittedBy: adminId,
            ),
            adminId,
          );
        } else if (entry.role == 'TOB' && entry.tobCapabilityId != null) {
          await _activityService.addTobActivityValidated(
            TobActivity(
              userId: entry.user.id,
              helicopterTypeId: helicopterId,
              tobCapabilityId: entry.tobCapabilityId!,
              activityDate: _crewFlightDate,
              description: desc,
              submittedBy: adminId,
            ),
            adminId,
          );
        }
      }
      if (mounted) {
        setState(() {
          _saving = false;
          _crewEntries.clear();
          _crewFlightHelicopterId = null;
          _crewFlightHoursCtrl.clear();
          _crewFlightDescCtrl.clear();
          _crewFlightDate = DateTime.now();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Volo inserito per tutto l\'equipaggio.'),
          ),
        );
        context.go('/admin/validate');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
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
    final maintenanceHelicopters = _uniqueHelicoptersFromPrivileges(
      _privileges,
    );
    final filteredPrivileges = _privileges
        .where((item) => item.helicopterTypeId == _maintenanceHelicopterId)
        .toList();
    final tAssignments = _crews.where((item) => item.crewType == 'T').toList();
    final tobAssignments = _crews
        .where((item) => item.crewType == 'TOB')
        .toList();
    final flightHelicopters = _uniqueCrewHelicopters(tAssignments);
    final tobHelicopters = _uniqueCrewHelicopters(tobAssignments);
    final filteredCapabilities = _tobCapabilities
        .where((item) => item.helicopterTypeId == _tobHelicopterId)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attività'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs
              .map(
                (tab) => Tab(
                  text: switch (tab) {
                    _AdminInsertTabType.workOrder => 'Ordine di Lavoro',
                    _AdminInsertTabType.maintenance => 'Manutenzione',
                    _AdminInsertTabType.flight => 'Volo',
                    _AdminInsertTabType.tob => 'TOB',
                    _AdminInsertTabType.crewFlight => 'Volo Equipaggio',
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
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, _) {
                    final currentTab = _tabs[_tabController.index];
                    final needsUserSelector =
                        currentTab == _AdminInsertTabType.maintenance ||
                        currentTab == _AdminInsertTabType.flight ||
                        currentTab == _AdminInsertTabType.tob;
                    if (!needsUserSelector) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _selectedUser?.id,
                          decoration: const InputDecoration(
                            labelText: 'Seleziona utente',
                          ),
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
                      ],
                    );
                  },
                ),
                SizedBox(
                  height: 800,
                  child: TabBarView(
                    controller: _tabController,
                    children: _tabs.map((tab) {
                      switch (tab) {
                        case _AdminInsertTabType.workOrder:
                          final auth = ref.read(authProvider);
                          final allHelicopters = auth.helicopterTypes;
                          final helicopterItems = allHelicopters
                              .map(
                                (h) => DropdownMenuItem<int>(
                                  value: h.id,
                                  child: Text(h.name),
                                ),
                              )
                              .toList(growable: false);
                          return _AdminActivityTab(
                            enabled: true,
                            child: _AdminActivityCard(
                              children: [
                                DropdownButtonFormField<int>(
                                  initialValue: _workOrderHelicopterId,
                                  menuMaxHeight: 300,
                                  decoration: const InputDecoration(
                                    labelText: 'Elicottero',
                                  ),
                                  items: helicopterItems,
                                  onChanged: (value) => setState(() {
                                    _workOrderHelicopterId = value;
                                    _techEntries.clear();
                                  }),
                                ),
                                const SizedBox(height: 16),
                                _AdminDateButton(
                                  label: 'Data attività',
                                  date: _workOrderDate,
                                  onPressed: () => _pickDate(
                                    (value) => _workOrderDate = value,
                                    _workOrderDate,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  initialValue: _workOrderActivityType,
                                  decoration: const InputDecoration(
                                    labelText: 'Tipo attività (opzionale)',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Linea',
                                      child: Text('Linea'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Motori',
                                      child: Text('Motori'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Altri',
                                      child: Text('Altri'),
                                    ),
                                  ],
                                  onChanged: (value) => setState(
                                    () => _workOrderActivityType = value,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _workOrderMatricolaCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Matricola militare (opzionale)',
                                    hintText: 'es. MM1234',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _workOrderNumCarrCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Num. carrozzella (opzionale)',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _workOrderOrdLavCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Ordine di lavoro (opzionale)',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _workOrderDescCtrl,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    labelText: 'Descrizione (opzionale)',
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Text(
                                      'Tecnici (${_techEntries.length})',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const Spacer(),
                                    TextButton.icon(
                                      onPressed: _addTechEntry,
                                      icon: const Icon(
                                        Icons.person_add_outlined,
                                      ),
                                      label: const Text('Aggiungi tecnico'),
                                    ),
                                  ],
                                ),
                                if (_techEntries.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      'Nessun tecnico aggiunto.',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  )
                                else
                                  ...List.generate(_techEntries.length, (i) {
                                    final entry = _techEntries[i];
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const CircleAvatar(
                                        child: Icon(
                                          Icons.engineering,
                                          size: 18,
                                        ),
                                      ),
                                      title: Text(entry.user.fullName),
                                      subtitle: Text(entry.privilegeName),
                                      trailing: IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                          color: Colors.red,
                                        ),
                                        onPressed: () => setState(
                                          () => _techEntries.removeAt(i),
                                        ),
                                      ),
                                    );
                                  }),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _saving ? null : _submitWorkOrder,
                                  icon: const Icon(
                                    Icons.assignment_turned_in_outlined,
                                  ),
                                  label: const Text(
                                    'Inserisci per tutti i tecnici',
                                  ),
                                ),
                              ],
                            ),
                          );
                        case _AdminInsertTabType.crewFlight:
                          final auth = ref.read(authProvider);
                          final tobCaps = auth.tobCapabilityTypes;
                          final allHelicopters = auth.helicopterTypes;
                          final helicopterItems = allHelicopters
                              .map(
                                (h) => DropdownMenuItem<int>(
                                  value: h.id,
                                  child: Text(h.name),
                                ),
                              )
                              .toList(growable: false);
                          return _AdminActivityTab(
                            enabled: true,
                            child: _AdminActivityCard(
                              children: [
                                DropdownButtonFormField<int>(
                                  initialValue: _crewFlightHelicopterId,
                                  menuMaxHeight: 300,
                                  decoration: const InputDecoration(
                                    labelText: 'Elicottero',
                                  ),
                                  items: helicopterItems,
                                  onChanged: (v) => setState(() {
                                    _crewFlightHelicopterId = v;
                                    _crewEntries.clear();
                                  }),
                                ),
                                const SizedBox(height: 16),
                                _AdminDateButton(
                                  label: 'Data volo',
                                  date: _crewFlightDate,
                                  onPressed: () => _pickDate(
                                    (v) => _crewFlightDate = v,
                                    _crewFlightDate,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _crewFlightHoursCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Ore di volo (per membri T)',
                                    hintText: 'es. 1.5',
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _crewFlightDescCtrl,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    labelText: 'Descrizione (opzionale)',
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Text(
                                      'Equipaggio (${_crewEntries.length})',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const Spacer(),
                                    TextButton.icon(
                                      onPressed: () => _addCrewEntry(tobCaps),
                                      icon: const Icon(
                                        Icons.person_add_outlined,
                                      ),
                                      label: const Text('Aggiungi'),
                                    ),
                                  ],
                                ),
                                if (_crewEntries.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      'Nessun membro aggiunto.',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  )
                                else
                                  ...List.generate(_crewEntries.length, (i) {
                                    final entry = _crewEntries[i];
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: CircleAvatar(
                                        child: Text(
                                          entry.role,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                      title: Text(entry.user.fullName),
                                      subtitle: Text(
                                        entry.role == 'TOB'
                                            ? 'TOB · ${entry.tobCapabilityName ?? ''}'
                                            : 'T · Pilota/Equipaggio',
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                          color: Colors.red,
                                        ),
                                        onPressed: () => setState(
                                          () => _crewEntries.removeAt(i),
                                        ),
                                      ),
                                    );
                                  }),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _saving ? null : _submitCrewFlight,
                                  icon: const Icon(Icons.save_outlined),
                                  label: const Text(
                                    'Inserisci per tutto l\'equipaggio',
                                  ),
                                ),
                              ],
                            ),
                          );
                        case _AdminInsertTabType.maintenance:
                          return _AdminActivityTab(
                            enabled:
                                _selectedUser != null &&
                                maintenanceHelicopters.isNotEmpty,
                            child: _AdminActivityCard(
                              children: [
                                DropdownButtonFormField<int>(
                                  initialValue:
                                      maintenanceHelicopters.any(
                                        (item) =>
                                            item.id == _maintenanceHelicopterId,
                                      )
                                      ? _maintenanceHelicopterId
                                      : null,
                                  decoration: const InputDecoration(
                                    labelText: 'Elicottero',
                                  ),
                                  items: maintenanceHelicopters
                                      .map(
                                        (item) => DropdownMenuItem<int>(
                                          value: item.id,
                                          child: Text(item.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) => setState(
                                    () => _maintenanceHelicopterId = value,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<int>(
                                  initialValue:
                                      filteredPrivileges.any(
                                        (item) =>
                                            item.privilegeTypeId ==
                                            _maintenancePrivilegeId,
                                      )
                                      ? _maintenancePrivilegeId
                                      : null,
                                  decoration: const InputDecoration(
                                    labelText: 'Privilegio',
                                  ),
                                  items: filteredPrivileges
                                      .map(
                                        (item) => DropdownMenuItem<int>(
                                          value: item.privilegeTypeId,
                                          child: Text(item.privilegeName),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) => setState(
                                    () => _maintenancePrivilegeId = value,
                                  ),
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
                                  decoration: const InputDecoration(
                                    labelText: 'Descrizione',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  initialValue: _maintenanceActivityType,
                                  decoration: const InputDecoration(
                                    labelText: 'Tipo attività (opzionale)',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Linea',
                                      child: Text('Linea'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Motori',
                                      child: Text('Motori'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Altri',
                                      child: Text('Altri'),
                                    ),
                                  ],
                                  onChanged: (value) => setState(
                                    () => _maintenanceActivityType = value,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _maintenanceMatricolaCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Matricola militare (opzionale)',
                                    hintText: 'es. MM1234',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _maintenanceNumCarrCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Num. carrozzella (opzionale)',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _maintenanceOrdLavCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Ordine di lavoro (opzionale)',
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: _saving
                                      ? null
                                      : _submitMaintenance,
                                  child: const Text('Inserisci come validata'),
                                ),
                              ],
                            ),
                          );
                        case _AdminInsertTabType.flight:
                          return _AdminActivityTab(
                            enabled:
                                _selectedUser != null &&
                                flightHelicopters.isNotEmpty,
                            child: _AdminActivityCard(
                              children: [
                                DropdownButtonFormField<int>(
                                  initialValue:
                                      flightHelicopters.any(
                                        (item) =>
                                            item.id == _flightHelicopterId,
                                      )
                                      ? _flightHelicopterId
                                      : null,
                                  decoration: const InputDecoration(
                                    labelText: 'Elicottero',
                                  ),
                                  items: flightHelicopters
                                      .map(
                                        (item) => DropdownMenuItem<int>(
                                          value: item.id,
                                          child: Text(item.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) => setState(
                                    () => _flightHelicopterId = value,
                                  ),
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
                                  decoration: const InputDecoration(
                                    labelText: 'Ore di volo',
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _flightDescCtrl,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: 'Descrizione',
                                  ),
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
                            enabled:
                                _selectedUser != null &&
                                tobHelicopters.isNotEmpty,
                            child: _AdminActivityCard(
                              children: [
                                DropdownButtonFormField<int>(
                                  initialValue:
                                      tobHelicopters.any(
                                        (item) => item.id == _tobHelicopterId,
                                      )
                                      ? _tobHelicopterId
                                      : null,
                                  decoration: const InputDecoration(
                                    labelText: 'Elicottero',
                                  ),
                                  items: tobHelicopters
                                      .map(
                                        (item) => DropdownMenuItem<int>(
                                          value: item.id,
                                          child: Text(item.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => _tobHelicopterId = value),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<int>(
                                  initialValue:
                                      filteredCapabilities.any(
                                        (item) =>
                                            item.tobCapabilityId ==
                                            _tobCapabilityId,
                                      )
                                      ? _tobCapabilityId
                                      : null,
                                  decoration: const InputDecoration(
                                    labelText: 'Capacità TOB',
                                  ),
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
                                  decoration: const InputDecoration(
                                    labelText: 'Descrizione',
                                  ),
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

class _TechEntry {
  const _TechEntry({
    required this.user,
    required this.privilegeTypeId,
    required this.privilegeName,
  });

  final UserProfile user;
  final int privilegeTypeId;
  final String privilegeName;
}

class _CrewEntry {
  const _CrewEntry({
    required this.user,
    required this.role,
    this.tobCapabilityId,
    this.tobCapabilityName,
  });

  final UserProfile user;
  final String role;
  final int? tobCapabilityId;
  final String? tobCapabilityName;
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
