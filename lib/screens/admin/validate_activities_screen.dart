import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../models/activity_models.dart';
import '../../services/activity_service.dart';

class ValidateActivitiesScreen extends ConsumerStatefulWidget {
  const ValidateActivitiesScreen({super.key});

  @override
  ConsumerState<ValidateActivitiesScreen> createState() =>
      _ValidateActivitiesScreenState();
}

enum _ValidationTabType { maintenance, flight, tob }

class _ValidateActivitiesScreenState
    extends ConsumerState<ValidateActivitiesScreen>
    with SingleTickerProviderStateMixin {
  final _service = ActivityService();

  late final TabController _tabController;
  late final List<_ValidationTabType> _tabs;
  bool _loading = true;
  List<MaintenanceActivity> _maintenance = [];
  List<FlightActivity> _flight = [];
  List<TobActivity> _tob = [];

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider);
    if (auth.isAdminPriv) {
      _tabs = const [_ValidationTabType.maintenance];
    } else if (auth.isAdminCrew) {
      _tabs = const [_ValidationTabType.flight, _ValidationTabType.tob];
    } else {
      _tabs = const [
        _ValidationTabType.maintenance,
        _ValidationTabType.flight,
        _ValidationTabType.tob,
      ];
    }
    _tabController = TabController(length: _tabs.length, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final maintenance = _tabs.contains(_ValidationTabType.maintenance)
        ? await _service.getPendingMaintenanceActivities()
        : <MaintenanceActivity>[];
    final flight = _tabs.contains(_ValidationTabType.flight)
        ? await _service.getPendingFlightActivities()
        : <FlightActivity>[];
    final tob = _tabs.contains(_ValidationTabType.tob)
        ? await _service.getPendingTobActivities()
        : <TobActivity>[];
    if (!mounted) {
      return;
    }
    setState(() {
      _maintenance = maintenance;
      _flight = flight;
      _tob = tob;
      _loading = false;
    });
  }

  Future<void> _validateMaintenance(int id) async {
    final adminId = ref.read(authProvider).userProfile?.id;
    if (adminId == null) {
      return;
    }
    try {
      await _service.validateMaintenanceActivity(id, adminId);
      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _validateFlight(int id) async {
    final adminId = ref.read(authProvider).userProfile?.id;
    if (adminId == null) {
      return;
    }
    try {
      await _service.validateFlightActivity(id, adminId);
      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _validateTob(int id) async {
    final adminId = ref.read(authProvider).userProfile?.id;
    if (adminId == null) {
      return;
    }
    try {
      await _service.validateTobActivity(id, adminId);
      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Valida Attività'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: MediaQuery.of(context).size.width < 420,
          tabs: _tabs
              .map(
                (tab) => Tab(
                  text: switch (tab) {
                    _ValidationTabType.maintenance => 'Manutenzione',
                    _ValidationTabType.flight => 'Volo',
                    _ValidationTabType.tob => 'TOB',
                  },
                ),
              )
              .toList(),
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: _tabs.map(_buildTabContent).toList(),
            ),
    );
  }

  Widget _buildTabContent(_ValidationTabType tab) {
    switch (tab) {
      case _ValidationTabType.maintenance:
        return _ValidationList<MaintenanceActivity>(
          items: _maintenance,
          titleBuilder: (item) =>
              '${item.userFullName} · ${item.helicopterCode}',
          subtitleBuilder: (item) =>
              '${item.privilegeName}\n${item.description ?? 'Nessuna descrizione'}',
          dateBuilder: (item) => item.activityDate,
          onValidate: (item) => _validateMaintenance(item.id!),
          onReject: (item) async {
            await _service.rejectMaintenanceActivity(item.id!);
            await _load();
          },
        );
      case _ValidationTabType.flight:
        return _ValidationList<FlightActivity>(
          items: _flight,
          titleBuilder: (item) =>
              '${item.userFullName} · ${item.helicopterCode}',
          subtitleBuilder: (item) =>
              '${item.flightHours.toStringAsFixed(1)}h\n${item.description ?? 'Nessuna descrizione'}',
          dateBuilder: (item) => item.activityDate,
          onValidate: (item) => _validateFlight(item.id!),
          onReject: (item) async {
            await _service.rejectFlightActivity(item.id!);
            await _load();
          },
        );
      case _ValidationTabType.tob:
        return _ValidationList<TobActivity>(
          items: _tob,
          titleBuilder: (item) =>
              '${item.userFullName} · ${item.helicopterCode}',
          subtitleBuilder: (item) =>
              '${item.capabilityName}\n${item.description ?? 'Nessuna descrizione'}',
          dateBuilder: (item) => item.activityDate,
          onValidate: (item) => _validateTob(item.id!),
          onReject: (item) async {
            await _service.rejectTobActivity(item.id!);
            await _load();
          },
        );
    }
  }
}

class _ValidationList<T> extends StatelessWidget {
  const _ValidationList({
    required this.items,
    required this.titleBuilder,
    required this.subtitleBuilder,
    required this.dateBuilder,
    required this.onValidate,
    required this.onReject,
  });

  final List<T> items;
  final String Function(T item) titleBuilder;
  final String Function(T item) subtitleBuilder;
  final DateTime Function(T item) dateBuilder;
  final Future<void> Function(T item) onValidate;
  final Future<void> Function(T item) onReject;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('Nessuna attività in attesa.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleBuilder(item),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(subtitleBuilder(item)),
                const SizedBox(height: 8),
                Text(
                  'Data: ${DateFormat('dd/MM/yyyy').format(dateBuilder(item))}',
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isStacked = constraints.maxWidth < 300;
                    final validateButton = ElevatedButton(
                      onPressed: () => onValidate(item),
                      child: const Text('Valida'),
                    );
                    final rejectButton = OutlinedButton(
                      onPressed: () => onReject(item),
                      child: const Text('Rifiuta'),
                    );

                    if (isStacked) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          validateButton,
                          const SizedBox(height: 8),
                          rejectButton,
                        ],
                      );
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(child: validateButton),
                        const SizedBox(width: 12),
                        Flexible(child: rejectButton),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
