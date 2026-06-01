import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../models/activity_models.dart';
import '../../services/activity_service.dart';

class MyActivitiesScreen extends ConsumerStatefulWidget {
  const MyActivitiesScreen({super.key, this.initialType});

  final String? initialType;

  @override
  ConsumerState<MyActivitiesScreen> createState() => _MyActivitiesScreenState();
}

class _MyActivitiesScreenState extends ConsumerState<MyActivitiesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<_MyActivitiesData> _future;
  final _service = ActivityService();

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).userProfile;
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: _initialTabIndex(widget.initialType),
    );
    _future = user == null
        ? Future.value(const _MyActivitiesData.empty())
        : _load(user.id);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _initialTabIndex(String? type) {
    switch (type) {
      case 'flight':
        return 1;
      case 'tob':
        return 2;
      case 'seminar':
        return 3;
      case 'maintenance':
      default:
        return 0;
    }
  }

  void _reload(String userId) {
    setState(() => _future = _load(userId));
  }

  Future<bool> _confirmDelete(String title) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: Text('Eliminare l\'attività "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteActivity({
    required String title,
    required Future<void> Function() delete,
    required String userId,
  }) async {
    final confirmed = await _confirmDelete(title);
    if (!confirmed) {
      return;
    }
    await delete();
    if (!mounted) {
      return;
    }
    _reload(userId);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Attività eliminata.')));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).userProfile;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isCompactTabs = MediaQuery.of(context).size.width < 520;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Le Mie Attività'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: isCompactTabs,
          tabs: const [
            Tab(text: 'Manutenzione'),
            Tab(text: 'Volo'),
            Tab(text: 'TOB'),
            Tab(text: 'Seminari'),
          ],
        ),
      ),
      body: FutureBuilder<_MyActivitiesData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return TabBarView(
            controller: _tabController,
            children: [
              _ActivitySection(
                title: 'Manutenzione',
                children: data.maintenance
                    .map(
                      (item) => _ActivityListTile(
                        title: '${item.helicopterCode} · ${item.privilegeName}',
                        subtitle: item.description ?? 'Nessuna descrizione',
                        date: item.activityDate,
                        isValidated: item.isValidated,
                        onDelete: item.id != null && !item.isValidated
                            ? () {
                                _deleteActivity(
                                  title:
                                      '${item.helicopterCode} · ${item.privilegeName}',
                                  delete: () => _service
                                      .deleteMaintenanceActivity(item.id!),
                                  userId: user.id,
                                );
                              }
                            : null,
                      ),
                    )
                    .toList(),
              ),
              _ActivitySection(
                title: 'Volo',
                children: data.flight
                    .map(
                      (item) => _ActivityListTile(
                        title:
                            '${item.helicopterCode} · ${item.flightHours.toStringAsFixed(1)}h',
                        subtitle: item.description ?? 'Nessuna descrizione',
                        date: item.activityDate,
                        isValidated: item.isValidated,
                        onDelete: item.id != null && !item.isValidated
                            ? () {
                                _deleteActivity(
                                  title:
                                      '${item.helicopterCode} · ${item.flightHours.toStringAsFixed(1)}h',
                                  delete: () =>
                                      _service.deleteFlightActivity(item.id!),
                                  userId: user.id,
                                );
                              }
                            : null,
                      ),
                    )
                    .toList(),
              ),
              _ActivitySection(
                title: 'TOB',
                children: data.tob
                    .map(
                      (item) => _ActivityListTile(
                        title:
                            '${item.helicopterCode} · ${item.capabilityName}',
                        subtitle: item.description ?? 'Nessuna descrizione',
                        date: item.activityDate,
                        isValidated: item.isValidated,
                        onDelete: item.id != null && !item.isValidated
                            ? () {
                                _deleteActivity(
                                  title:
                                      '${item.helicopterCode} · ${item.capabilityName}',
                                  delete: () =>
                                      _service.deleteTobActivity(item.id!),
                                  userId: user.id,
                                );
                              }
                            : null,
                      ),
                    )
                    .toList(),
              ),
              _ActivitySection(
                title: 'Seminari NAM/MHF',
                children: data.seminars
                    .map(
                      (item) => _ActivityListTile(
                        title: 'Seminario NAM/MHF',
                        subtitle:
                            item.description ??
                            'Aggiornamento biennale NAM e MHF',
                        date: item.seminarDate,
                        isValidated: item.isValidated,
                        onDelete: item.id != null && !item.isValidated
                            ? () {
                                _deleteActivity(
                                  title: 'Seminario NAM/MHF',
                                  delete: () =>
                                      _service.deleteSeminarActivity(item.id!),
                                  userId: user.id,
                                );
                              }
                            : null,
                      ),
                    )
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<_MyActivitiesData> _load(String userId) async {
    final maintenance = await _service.getUserMaintenanceActivities(userId);
    final flight = await _service.getUserFlightActivities(userId);
    final tob = await _service.getUserTobActivities(userId);
    final seminars = await _service.getUserSeminarActivities(userId);
    return _MyActivitiesData(
      maintenance: maintenance,
      flight: flight,
      tob: tob,
      seminars: seminars,
    );
  }
}

class _MyActivitiesData {
  const _MyActivitiesData({
    required this.maintenance,
    required this.flight,
    required this.tob,
    required this.seminars,
  });

  const _MyActivitiesData.empty()
    : maintenance = const [],
      flight = const [],
      tob = const [],
      seminars = const [];

  final List<MaintenanceActivity> maintenance;
  final List<FlightActivity> flight;
  final List<TobActivity> tob;
  final List<SeminarActivity> seminars;
}

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                if (children.isEmpty)
                  const Text('Nessuna attività registrata.')
                else
                  ...children,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityListTile extends StatelessWidget {
  const _ActivityListTile({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.isValidated,
    this.onDelete,
  });

  final String title;
  final String subtitle;
  final DateTime date;
  final bool isValidated;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, softWrap: true),
      subtitle: Text(
        '$subtitle\n${DateFormat('dd/MM/yyyy').format(date)}',
        softWrap: true,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            label: Text(isValidated ? 'Validata' : 'In attesa', softWrap: true),
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Elimina attività',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            ),
          ],
        ],
      ),
    );
  }
}
