import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../models/activity_models.dart';
import '../../services/activity_service.dart';

class MyActivitiesScreen extends ConsumerWidget {
  const MyActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).userProfile;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Le Mie Attività')),
      body: FutureBuilder<_MyActivitiesData>(
        future: _load(user.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(24),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Card(
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
      title: Text(title),
      subtitle: Text('$subtitle\n${DateFormat('dd/MM/yyyy').format(date)}'),
      trailing: Chip(label: Text(isValidated ? 'Validata' : 'In attesa')),
    );
  }
}
