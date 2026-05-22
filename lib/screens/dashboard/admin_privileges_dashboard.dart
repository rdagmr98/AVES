import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../constants/app_constants.dart';
import '../../models/user_models.dart';
import '../../services/activity_service.dart';
import '../../services/currency_service.dart';
import '../../services/user_service.dart';
import '../../widgets/admin_write_pat_button.dart';

class AdminPrivilegesDashboard extends ConsumerWidget {
  const AdminPrivilegesDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Admin Privilegi'),
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
      body: FutureBuilder<_AdminPrivData>(
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
                  _StatCard(
                    title: 'Attività da validare',
                    value: '${data.pendingActivities}',
                    icon: Icons.pending_actions,
                  ),
                  _StatCard(
                    title: 'Utenti gestiti',
                    value: '${data.userCount}',
                    icon: Icons.groups,
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
                    onPressed: () => context.go('/admin/settings'),
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Impostazioni Currency'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/admin/insert'),
                    icon: const Icon(Icons.add_task_outlined),
                    label: const Text('Inserisci Attività'),
                  ),
                  const AdminWritePatButton(),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Utenti con currency manutentiva scaduta',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (data.expiredMaintenanceUsers.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Nessun utente con scadenza manutentiva rilevata.',
                    ),
                  ),
                )
              else
                ...data.expiredMaintenanceUsers.map(
                  (user) => Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.currencyExpired,
                      ),
                      title: Text(user.fullName),
                      subtitle: Text(
                        '${user.qualifica} · ${user.numeroLicenza ?? 'Licenza non indicata'}',
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<_AdminPrivData> _loadData() async {
    final userService = UserService();
    final activityService = ActivityService();
    final currencyService = CurrencyService();

    final users = await userService.getAllUsers();
    final pendingActivities = await activityService.getPendingActivitiesCount();
    final expiredUsers = <UserProfile>[];

    for (final user in users.where((item) => item.isApproved)) {
      final status = await currencyService.getMaintenanceCurrency(user.id);
      if (status.isExpired) {
        expiredUsers.add(user);
      }
    }

    return _AdminPrivData(
      pendingActivities: pendingActivities,
      userCount: users.length,
      expiredMaintenanceUsers: expiredUsers,
    );
  }
}

class _AdminPrivData {
  const _AdminPrivData({
    required this.pendingActivities,
    required this.userCount,
    required this.expiredMaintenanceUsers,
  });

  final int pendingActivities;
  final int userCount;
  final List<UserProfile> expiredMaintenanceUsers;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
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
      width: 240,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.secondary),
              const SizedBox(height: 12),
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
