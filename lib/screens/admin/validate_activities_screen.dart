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

class _ValidateActivitiesScreenState
    extends ConsumerState<ValidateActivitiesScreen>
    with SingleTickerProviderStateMixin {
  final _service = ActivityService();

  late final TabController _tabController;
  bool _loading = true;
  List<MaintenanceActivity> _maintenance = [];
  List<FlightActivity> _flight = [];
  List<TobActivity> _tob = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final maintenance = await _service.getPendingMaintenanceActivities();
    final flight = await _service.getPendingFlightActivities();
    final tob = await _service.getPendingTobActivities();
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
    await _service.validateMaintenanceActivity(id, adminId);
    await _load();
  }

  Future<void> _validateFlight(int id) async {
    final adminId = ref.read(authProvider).userProfile?.id;
    if (adminId == null) {
      return;
    }
    await _service.validateFlightActivity(id, adminId);
    await _load();
  }

  Future<void> _validateTob(int id) async {
    final adminId = ref.read(authProvider).userProfile?.id;
    if (adminId == null) {
      return;
    }
    await _service.validateTobActivity(id, adminId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Valida Attività'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Manutenzione'),
            Tab(text: 'Volo'),
            Tab(text: 'TOB'),
          ],
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _ValidationList<MaintenanceActivity>(
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
                ),
                _ValidationList<FlightActivity>(
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
                ),
                _ValidationList<TobActivity>(
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
                ),
              ],
            ),
    );
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
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () => onValidate(item),
                      child: const Text('Valida'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () => onReject(item),
                      child: const Text('Rifiuta'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
