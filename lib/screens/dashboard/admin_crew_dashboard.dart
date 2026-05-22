import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../services/activity_service.dart';
import '../../services/user_service.dart';
import '../../widgets/admin_write_pat_button.dart';

class AdminCrewDashboard extends ConsumerWidget {
  const AdminCrewDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Admin Equipaggi'),
        actions: [
          IconButton(
            onPressed: () async {
              await ref.read(authProvider).signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: FutureBuilder<_AdminCrewData>(
        future: _loadData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _CrewStatCard(
                    title: 'Attività da validare',
                    value: '${data.pendingActivities}',
                    icon: Icons.pending_actions,
                  ),
                  _CrewStatCard(
                    title: 'Equipaggi T',
                    value: '${data.tCrewUsers}',
                    icon: Icons.flight,
                  ),
                  _CrewStatCard(
                    title: 'Equipaggi TOB',
                    value: '${data.tobCrewUsers}',
                    icon: Icons.precision_manufacturing_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => context.go('/admin/validate'),
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('Valida Attività'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/admin/users'),
                    icon: const Icon(Icons.manage_accounts_outlined),
                    label: const Text('Gestione Utenti'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/admin/insert'),
                    icon: const Icon(Icons.add_task_outlined),
                    label: const Text('Inserisci Attività'),
                  ),
                  const AdminWritePatButton(),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<_AdminCrewData> _loadData() async {
    final userService = UserService();
    final activityService = ActivityService();
    final users = await userService.getAllUsers();
    final pendingActivities = await activityService.getPendingActivitiesCount();
    var tCrewUsers = 0;
    var tobCrewUsers = 0;

    for (final user in users.where((item) => item.isApproved)) {
      final assignments = await userService.getUserCrewAssignments(user.id);
      if (assignments.any((item) => item.crewType == 'T')) {
        tCrewUsers++;
      }
      if (assignments.any((item) => item.crewType == 'TOB')) {
        tobCrewUsers++;
      }
    }

    return _AdminCrewData(
      pendingActivities: pendingActivities,
      tCrewUsers: tCrewUsers,
      tobCrewUsers: tobCrewUsers,
    );
  }
}

class _AdminCrewData {
  const _AdminCrewData({
    required this.pendingActivities,
    required this.tCrewUsers,
    required this.tobCrewUsers,
  });

  final int pendingActivities;
  final int tCrewUsers;
  final int tobCrewUsers;
}

class _CrewStatCard extends StatelessWidget {
  const _CrewStatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 10),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
        ),
      ),
    );
  }
}
