import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../constants/app_constants.dart';
import '../../models/activity_models.dart';
import '../../models/user_models.dart';
import '../../services/pta_service.dart';
import '../../widgets/aves_logo_widget.dart';
import '../../widgets/currency_badge_widget.dart';
import '../../widgets/notification_panel_widget.dart';
import '../../widgets/privilege_grid_widget.dart';
import '../../widgets/user_avatar.dart';

class UserDashboard extends ConsumerStatefulWidget {
  const UserDashboard({super.key});

  @override
  ConsumerState<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends ConsumerState<UserDashboard> {
  bool _emailDialogOpen = false;

  void _promptInstitutionalEmail(UserProfile user) {
    if (_emailDialogOpen || user.hasInstitutionalEmail) {
      return;
    }
    _emailDialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text(
            'Email istituzionale richiesta',
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'Per continuare ad utilizzare l\'app è necessario inserire il tuo indirizzo email istituzionale (@esercito.difesa.it). Vai al profilo per completare i dati.',
            textAlign: TextAlign.center,
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.go('/profile');
              },
              child: const Text('Vai al Profilo'),
            ),
          ],
        ),
      );
      _emailDialogOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.userProfile;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    _promptInstitutionalEmail(user);

    final hasMaintenanceAccess =
        auth.licenses.isNotEmpty || auth.privileges.isNotEmpty;
    final helicopterIds = <int>{
      ...auth.licenses.map((item) => item.helicopterTypeId),
      ...auth.privileges.map((item) => item.helicopterTypeId),
      ...auth.crewAssignments.map((item) => item.helicopterTypeId),
      ...auth.tobCapabilities.map((item) => item.helicopterTypeId),
    };
    final assignedHelicopters = auth.helicopterTypes
        .where((item) => helicopterIds.contains(item.id))
        .toList();

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

    final currencyCards = <Widget>[
      if (hasMaintenanceAccess)
        _CurrencyCard(
          title: 'Manutenzione',
          status: auth.currency['maintenance'],
        ),
      if (auth.hasTCrew)
        _CurrencyCard(title: 'Volo T', status: auth.currency['flight_t']),
      if (auth.hasTobCrew)
        _CurrencyCard(title: 'Base TOB', status: auth.currency['tob_base']),
      if (auth.hasTobCrew)
        ...auth.tobCapabilities.map(
          (cap) => _CurrencyCard(
            title: 'TOB · ${cap.capabilityName}',
            status: auth.currency['tob_${cap.tobCapabilityId}'],
          ),
        ),
    ];

    final quickActions = <_DashboardActionButtonData>[
      _DashboardActionButtonData(
        label: 'Inserisci Attività',
        icon: Icons.add_circle_outline,
        onPressed: () => context.go('/activities/add'),
        primary: true,
      ),
      _DashboardActionButtonData(
        label: 'Le Mie Attività',
        icon: Icons.history,
        onPressed: () => context.go('/activities/my'),
      ),
      _DashboardActionButtonData(
        label: 'Profilo',
        icon: Icons.person_outline,
        onPressed: () => context.go('/profile'),
      ),
      if (hasMaintenanceAccess)
        _DashboardActionButtonData(
          label: 'PTA',
          icon: Icons.article_outlined,
          onPressed: () => context.go('/pta'),
        ),
      if (assignedHelicopters.isNotEmpty)
        _DashboardActionButtonData(
          label: 'La Mia Flotta',
          icon: Icons.flight,
          onPressed: () => context.go('/helicopters/fleet'),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(6),
          child: AvesLogoWidget(size: 32),
        ),
        title: const Text('AVES Tecnici'),
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              shrinkWrap: false,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                _UserHeaderCard(
                  user: user,
                  unreadNotifications: auth.unreadNotifications,
                ),
                if (!user.isApproved) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.currencyWarning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.currencyWarning),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                Builder(
                  builder: (context) {
                    final blockingPta = PtaService().getBlockingPtaForUser(
                      user.id,
                    );
                    if (blockingPta.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final ptaNumbers = blockingPta
                        .map((p) => p.number)
                        .join(', ');
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: InkWell(
                        onTap: () => context.go('/pta'),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF8E44AD).withValues(alpha: 0.2),
                                AppColors.surface,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
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
                                        color: Color(0xFFCE93D8),
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
                                color: Color(0xFFCE93D8),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Stato Currency',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 500;
                    if (isMobile) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < currencyCards.length; i++)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: i == currencyCards.length - 1 ? 0 : 12,
                              ),
                              child: currencyCards[i],
                            ),
                        ],
                      );
                    }
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final card in currencyCards)
                          SizedBox(width: 300, child: card),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Azioni rapide',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 500;
                    if (isMobile) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < quickActions.length; i++)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: i == quickActions.length - 1 ? 0 : 8,
                              ),
                              child: _DashboardActionButton(
                                data: quickActions[i],
                              ),
                            ),
                        ],
                      );
                    }
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final action in quickActions)
                          SizedBox(
                            width: 220,
                            child: _DashboardActionButton(
                              data: action,
                              compact: true,
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Privilegi assegnati',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                PrivilegeGridWidget(privileges: auth.privileges),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserHeaderCard extends StatelessWidget {
  const _UserHeaderCard({
    required this.user,
    required this.unreadNotifications,
  });

  final UserProfile user;
  final int unreadNotifications;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.surfaceVariant, AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 420;
            final avatar = UserAvatar(user: user, radius: 31);

            final info = Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Benvenuto ${user.nome}',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  user.orgUnitName,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  user.numeroLicenza ?? 'Licenza non indicata',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (user.email != null && user.email!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    user.email!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            );

            final notificationPill = Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mark_email_unread_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    unreadNotifications > 0
                        ? '$unreadNotifications notifiche'
                        : 'Nessuna notifica',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );

            if (isMobile) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      avatar,
                      const Spacer(),
                      Badge.count(
                        isLabelVisible: unreadNotifications > 0,
                        count: unreadNotifications,
                        child: notificationPill,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  info,
                ],
              );
            }

            return Row(
              children: [
                avatar,
                const SizedBox(width: 16),
                Expanded(child: info),
                const SizedBox(width: 16),
                Badge.count(
                  isLabelVisible: unreadNotifications > 0,
                  count: unreadNotifications,
                  child: notificationPill,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DashboardActionButtonData {
  const _DashboardActionButtonData({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;
}

class _DashboardActionButton extends StatelessWidget {
  const _DashboardActionButton({required this.data, this.compact = false});

  final _DashboardActionButtonData data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (data.primary) {
      return ElevatedButton.icon(
        style: compact
            ? ElevatedButton.styleFrom(minimumSize: const Size(0, 52))
            : null,
        onPressed: data.onPressed,
        icon: Icon(data.icon),
        label: Text(data.label),
      );
    }

    return OutlinedButton.icon(
      style: compact
          ? OutlinedButton.styleFrom(minimumSize: const Size(0, 52))
          : null,
      onPressed: data.onPressed,
      icon: Icon(data.icon),
      label: Text(data.label),
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
    final highlight = Color.lerp(
      AppColors.surfaceVariant,
      currentStatus.color,
      0.2,
    )!;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [highlight, AppColors.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: currentStatus.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(currentStatus.icon, color: currentStatus.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    CurrencyBadgeWidget(status: currentStatus),
                    const SizedBox(height: 10),
                    Text(
                      currentStatus.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (currentStatus.lastActivityDate != null) ...[
                      const SizedBox(height: 10),
                      _CurrencyMetaLine(
                        icon: Icons.history_toggle_off,
                        text:
                            'Ultima attività: ${DateFormat('dd/MM/yyyy').format(currentStatus.lastActivityDate!)}',
                      ),
                    ],
                    if (currentStatus.expiryDate != null) ...[
                      const SizedBox(height: 6),
                      _CurrencyMetaLine(
                        icon: Icons.event_available,
                        text:
                            'Scadenza: ${DateFormat('dd/MM/yyyy').format(currentStatus.expiryDate!)}',
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrencyMetaLine extends StatelessWidget {
  const _CurrencyMetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
