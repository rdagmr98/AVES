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
import '../../widgets/notification_panel_widget.dart';
import '../../widgets/privilege_grid_widget.dart';
import '../../widgets/user_avatar.dart';

class UserDashboard extends ConsumerStatefulWidget {
  const UserDashboard({super.key});

  @override
  ConsumerState<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends ConsumerState<UserDashboard> {
  final _ptaService = PtaService();
  bool _emailDialogOpen = false;

  void _promptInstitutionalEmail(UserProfile user) {
    if (_emailDialogOpen || user.isAdmin || user.hasInstitutionalEmail) {
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

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '-';
    }
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _maintenanceDetail(CurrencyStatus? status) {
    final currentStatus =
        status ??
        const CurrencyStatus(
          status: CurrencyStatusEnum.noData,
          label: 'Nessun dato',
        );
    if (!currentStatus.hasData) {
      return currentStatus.label;
    }

    final expiries = <({DateTime date, String prefix})>[];
    if (currentStatus.expiryDate != null) {
      expiries.add((date: currentStatus.expiryDate!, prefix: 'Scad.'));
    }
    if (currentStatus.secondaryExpiryDate != null) {
      expiries.add((
        date: currentStatus.secondaryExpiryDate!,
        prefix: currentStatus.secondaryExpiryLabel ?? 'Scad.',
      ));
    }
    if (expiries.isEmpty) {
      return currentStatus.label;
    }

    expiries.sort((a, b) => a.date.compareTo(b.date));
    final nearest = expiries.first;
    return '${nearest.prefix} ${_formatDate(nearest.date)}';
  }

  String _flightDetail(CurrencyStatus? status) {
    final currentStatus =
        status ??
        const CurrencyStatus(
          status: CurrencyStatusEnum.noData,
          label: 'Nessun dato',
        );
    if (currentStatus.flightHours != null &&
        currentStatus.minFlightHours != null) {
      final summary =
          '${currentStatus.flightHours!.toStringAsFixed(1)}h / ${currentStatus.minFlightHours!.toStringAsFixed(1)}h';
      if (currentStatus.expiryDate != null) {
        return '$summary — Scad. ${_formatDate(currentStatus.expiryDate)}';
      }
      return summary;
    }
    if (currentStatus.expiryDate != null) {
      return 'Scad. ${_formatDate(currentStatus.expiryDate)}';
    }
    return currentStatus.label;
  }

  String _genericExpiryDetail(CurrencyStatus? status) {
    final currentStatus =
        status ??
        const CurrencyStatus(
          status: CurrencyStatusEnum.noData,
          label: 'Nessun dato',
        );
    if (currentStatus.expiryDate != null) {
      return 'Scad. ${_formatDate(currentStatus.expiryDate)}';
    }
    return currentStatus.label;
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
    final blockingPtas = _ptaService.getBlockingPtaForUser(user.id);
    final unreadPtas = _ptaService.getUserUnreadPtas(user.id);

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
          detailText: _maintenanceDetail(auth.currency['maintenance']),
          activityType: 'maintenance',
        ),
      if (auth.hasTCrew)
        _CurrencyCard(
          title: 'Volo T',
          status: auth.currency['flight_t'],
          detailText: _flightDetail(auth.currency['flight_t']),
          activityType: 'flight',
        ),
      if (auth.hasTobCrew)
        _CurrencyCard(
          title: 'Base TOB',
          status: auth.currency['tob_base'],
          detailText: _genericExpiryDetail(auth.currency['tob_base']),
          activityType: 'tob',
        ),
      if (auth.hasTobCrew)
        ...auth.tobCapabilities.map(
          (cap) => _CurrencyCard(
            title: 'TOB · ${cap.helicopterCode} · ${cap.capabilityName}',
            status: auth
                .currency['tob_${cap.helicopterTypeId}_${cap.tobCapabilityId}'],
            detailText: _genericExpiryDetail(
              auth.currency['tob_${cap.helicopterTypeId}_${cap.tobCapabilityId}'],
            ),
            activityType: 'tob',
          ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/activities/add'),
        tooltip: 'Inserisci Attività',
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: RefreshIndicator(
        onRefresh: () => ref.read(authProvider).refreshUserData(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              shrinkWrap: false,
              padding: const EdgeInsets.only(
                left: 16,
                top: 16,
                right: 16,
                bottom: 96,
              ),
              children: [
                _UserHeaderCard(
                  user: user,
                  showFleetShortcut: assignedHelicopters.isNotEmpty,
                  onProfileTap: () => context.go('/profile'),
                  onFleetTap: assignedHelicopters.isNotEmpty
                      ? () => context.go('/helicopters/fleet')
                      : null,
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
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (blockingPtas.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  InkWell(
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
                          const Icon(Icons.block, color: Color(0xFFCE93D8)),
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
                                  softWrap: true,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  unreadPtas.isNotEmpty
                                      ? 'PTA: ${unreadPtas.map((p) => p.number).join(', ')} — Tocca per prendere visione'
                                      : 'PTA: ${blockingPtas.map((p) => p.number).join(', ')} — Presa visione registrata, in attesa di chiusura',
                                  style: const TextStyle(fontSize: 13),
                                  softWrap: true,
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
                ],
                const SizedBox(height: 24),
                Text(
                  'Stato Currency',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                if (currencyCards.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Nessuna currency operativa assegnata al tuo profilo.',
                        textAlign: TextAlign.center,
                        softWrap: true,
                      ),
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = constraints.maxWidth >= 960
                          ? 320.0
                          : constraints.maxWidth >= 640
                          ? 300.0
                          : constraints.maxWidth;
                      return Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final card in currencyCards)
                            SizedBox(width: cardWidth, child: card),
                        ],
                      );
                    },
                  ),
                if (auth.privileges.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Privilegi assegnati',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  PrivilegeGridWidget(privileges: auth.privileges),
                ],
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
    required this.showFleetShortcut,
    required this.onProfileTap,
    this.onFleetTap,
  });

  final UserProfile user;
  final bool showFleetShortcut;
  final VoidCallback onProfileTap;
  final VoidCallback? onFleetTap;

  @override
  Widget build(BuildContext context) {
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Benvenuto ${user.nome}',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
          softWrap: true,
        ),
        const SizedBox(height: 6),
        Text(
          user.orgUnitName,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
          softWrap: true,
        ),
        if (!user.isAdmin &&
            user.numeroLicenza != null &&
            user.numeroLicenza!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            user.numeroLicenza!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.center,
            softWrap: true,
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Tocca per vedere il profilo',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          softWrap: true,
        ),
      ],
    );

    final fleetButton = showFleetShortcut
        ? IconButton(
            icon: const Icon(Icons.flight, size: 28),
            tooltip: 'La Mia Flotta',
            onPressed: onFleetTap,
          )
        : const SizedBox.shrink();

    return Tooltip(
      message: 'Tocca per vedere il profilo',
      child: GestureDetector(
        onTap: onProfileTap,
        child: Container(
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
                final isCompact = constraints.maxWidth < 520;
                final avatar = GestureDetector(
                  onTap: onProfileTap,
                  child: UserAvatar(user: user, radius: 31),
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(children: [avatar, const Spacer(), fleetButton]),
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
                    if (showFleetShortcut) ...[
                      const SizedBox(width: 16),
                      fleetButton,
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrencyCard extends StatelessWidget {
  const _CurrencyCard({
    required this.title,
    required this.status,
    required this.detailText,
    required this.activityType,
  });

  final String title;
  final CurrencyStatus? status;
  final String detailText;
  final String activityType;

  @override
  Widget build(BuildContext context) {
    final currentStatus =
        status ??
        const CurrencyStatus(
          status: CurrencyStatusEnum.noData,
          label: 'Nessun dato',
        );
    final statusText = currentStatus.hasData
        ? (currentStatus.isExpired || currentStatus.isSuspended
              ? 'NO GO'
              : 'GO')
        : 'N/D';

    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => context.go('/activities/my?type=$activityType'),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: currentStatus.color, width: 4),
            ),
            gradient: LinearGradient(
              colors: [
                currentStatus.color.withValues(alpha: 0.08),
                AppColors.surface,
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 80,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      currentStatus.icon,
                      size: 28,
                      color: currentStatus.color,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      statusText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: currentStatus.color,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                      softWrap: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      softWrap: true,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      detailText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      softWrap: true,
                    ),
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
