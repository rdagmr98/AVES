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
    final service = ActivityService();
    final maintenance = await service.getUserMaintenanceActivities(userId);
    final flight = await service.getUserFlightActivities(userId);
    final tob = await service.getUserTobActivities(userId);
    final seminars = await service.getUserSeminarActivities(userId);
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
  });

  final String title;
  final String subtitle;
  final DateTime date;
  final bool isValidated;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, softWrap: true),
      subtitle: Text(
        '$subtitle\n${DateFormat('dd/MM/yyyy').format(date)}',
        softWrap: true,
      ),
      trailing: Chip(
        label: Text(isValidated ? 'Validata' : 'In attesa', softWrap: true),
      ),
    );
  }
}
