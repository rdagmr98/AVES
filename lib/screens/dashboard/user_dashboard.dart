import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../constants/app_constants.dart';
import '../../models/activity_models.dart';
import '../../services/pta_service.dart';
import '../../widgets/currency_badge_widget.dart';
import '../../widgets/notification_panel_widget.dart';
import '../../widgets/privilege_grid_widget.dart';

class UserDashboard extends ConsumerWidget {
  const UserDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.userProfile;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    Future<void> openNotifications() async {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => FractionallySizedBox(
          heightFactor: 0.88,
          child: NotificationPanelWidget(userId: user.id),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Operatore'),
        actions: [
          IconButton(
            tooltip: 'Notifiche',
            onPressed: openNotifications,
            icon: Badge.count(
              isLabelVisible: auth.unreadNotifications > 0,
              count: auth.unreadNotifications,
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          IconButton(
            tooltip: 'Esci',
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
      body: RefreshIndicator(
        onRefresh: () => ref.read(authProvider).refreshUserData(),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                      child: const Icon(Icons.person, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Benvenuto ${user.nome}',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.orgUnitName,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Badge.count(
                      isLabelVisible: auth.unreadNotifications > 0,
                      count: auth.unreadNotifications,
                      child: const Icon(Icons.mark_email_unread_outlined),
                    ),
                  ],
                ),
              ),
            ),
            if (!user.isApproved) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.currencyWarning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.currencyWarning),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.pending_actions,
                      color: AppColors.currencyWarning,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'In attesa di approvazione. Alcune funzionalità saranno abilitate dopo la verifica del profilo.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // PTA banner
            Builder(builder: (context) {
              final blockingPta =
                  PtaService().getBlockingPtaForUser(user.id);
              if (blockingPta.isEmpty) return const SizedBox.shrink();
              final ptaNumbers =
                  blockingPta.map((p) => p.number).join(', ');
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: InkWell(
                  onTap: () => context.go('/pta'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8E44AD).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF8E44AD)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.block, color: Color(0xFF8E44AD)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CURRENCY SOSPESA — PTA attiva',
                                style: TextStyle(
                                  color: Color(0xFF8E44AD),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'PTA: $ptaNumbers — Tocca per prendere visione',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: Color(0xFF8E44AD),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),
            Text(
              'Stato Currency',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _CurrencyCard(
                  title: 'Manutenzione',
                  status: auth.currency['maintenance'],
                ),
                if (auth.hasTCrew)
                  _CurrencyCard(
                    title: 'Volo T',
                    status: auth.currency['flight_t'],
                  ),
                if (auth.hasTobCrew)
                  ...auth.tobCapabilities.map(
                    (cap) => _CurrencyCard(
                      title: 'TOB · ${cap.capabilityName}',
                      status: auth.currency['tob_${cap.tobCapabilityId}'],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Azioni rapide',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: () => context.go('/activities/add'),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Inserisci Attività'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/activities/my'),
                  icon: const Icon(Icons.history),
                  label: const Text('Le Mie Attività'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/profile'),
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Profilo'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/pta'),
                  icon: const Icon(Icons.article_outlined),
                  label: const Text('PTA'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Privilegi assegnati',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            PrivilegeGridWidget(privileges: auth.privileges),
          ],
        ),
      ),
    );
  }
}

class _CurrencyCard extends StatelessWidget {
  const _CurrencyCard({required this.title, required this.status});

  final String title;
  final CurrencyStatus? status;

  @override
  Widget build(BuildContext context) {
    final currentStatus =
        status ??
        const CurrencyStatus(
          status: CurrencyStatusEnum.noData,
          label: 'Nessun dato',
        );

    return SizedBox(
      width: 300,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              CurrencyBadgeWidget(status: currentStatus),
              const SizedBox(height: 12),
              Text('Etichetta: ${currentStatus.label}'),
              if (currentStatus.lastActivityDate != null)
                Text(
                  'Ultima attività: ${DateFormat('dd/MM/yyyy').format(currentStatus.lastActivityDate!)}',
                ),
              if (currentStatus.expiryDate != null)
                Text(
                  'Scadenza: ${DateFormat('dd/MM/yyyy').format(currentStatus.expiryDate!)}',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
