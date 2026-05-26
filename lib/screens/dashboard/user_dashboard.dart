import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../constants/app_constants.dart';
import '../../models/activity_models.dart';
import '../../models/user_models.dart';
import '../../services/currency_service.dart';
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
  final _ptaService = PtaService();
  final _currencyService = CurrencyService();
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

  String _formatLongDate(DateTime? date) {
    if (date == null) {
      return 'Nessuna data registrata';
    }
    return 'Scadenza: ${DateFormat('d MMMM yyyy', 'it').format(date)}';
  }

  String _maintenanceSubtitle(CurrencyStatus? status) {
    final currentStatus =
        status ??
        const CurrencyStatus(
          status: CurrencyStatusEnum.noData,
          label: 'Nessun dato',
        );
    if (!currentStatus.hasData) {
      return currentStatus.label;
    }
    final seminarLabel = currentStatus.label.toLowerCase().contains(
      'seminario',
    );
    if (currentStatus.isExpired) {
      return seminarLabel ? 'Seminario NAM/MHF scaduto' : 'Attività scaduta';
    }
    if (currentStatus.isWarning) {
      return seminarLabel
          ? 'Seminario NAM/MHF in scadenza'
          : 'Attività in scadenza';
    }
    return 'Attività regolare';
  }

  DateTime? _maintenanceExpiryDate(CurrencyStatus? status) {
    final currentStatus =
        status ??
        const CurrencyStatus(
          status: CurrencyStatusEnum.noData,
          label: 'Nessun dato',
        );
    if (currentStatus.label.toLowerCase().contains('seminario') &&
        currentStatus.secondaryExpiryDate != null) {
      return currentStatus.secondaryExpiryDate;
    }
    return currentStatus.expiryDate;
  }

  String _flightSubtitle(CurrencyStatus? status) {
    final currentStatus =
        status ??
        const CurrencyStatus(
          status: CurrencyStatusEnum.noData,
          label: 'Nessun dato',
        );
    final hours = currentStatus.flightHours;
    final minHours = currentStatus.minFlightHours;
    if (hours != null && minHours != null) {
      return '${hours.toStringAsFixed(1)} h  /  ${minHours.toStringAsFixed(1)} h';
    }
    return 'Nessun dato ore di volo';
  }

  Future<void> _showMaintenanceBreakdown(UserProfile user) async {
    final items = await _currencyService.getPerPrivilegeCurrency(user.id);
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Dettaglio privilegi manutentivi',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
                softWrap: true,
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Nessun privilegio manutentivo attivo.',
                    textAlign: TextAlign.center,
                    softWrap: true,
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item.helicopterCode} · ${item.privilegeName}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                      softWrap: true,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatLongDate(item.status.expiryDate),
                                      softWrap: true,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              CurrencyBadgeWidget(status: item.status),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
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

    final tobFascia = auth.crewAssignments
        .where((item) => item.crewType == 'TOB')
        .map((item) => item.fascia)
        .firstWhere((item) => item != null, orElse: () => null);

    final currencyCards = <Widget>[
      if (hasMaintenanceAccess)
        _CurrencyCard(
          title: 'Manutenzione',
          status: auth.currency['maintenance'],
          subtitle: _maintenanceSubtitle(auth.currency['maintenance']),
          expiryText: _formatLongDate(
            _maintenanceExpiryDate(auth.currency['maintenance']),
          ),
          onTap: () => _showMaintenanceBreakdown(user),
        ),
      if (auth.hasTCrew)
        _CurrencyCard(
          title: 'Volo T',
          status: auth.currency['flight_t'],
          subtitle: _flightSubtitle(auth.currency['flight_t']),
          expiryText: _formatLongDate(auth.currency['flight_t']?.expiryDate),
          onTap: () => context.go('/activities/my?type=flight'),
        ),
      if (auth.hasTobCrew)
        _CurrencyCard(
          title: 'Base TOB',
          status: auth.currency['tob_base'],
          subtitle: 'Fascia ${tobFascia ?? '-'}',
          expiryText: _formatLongDate(auth.currency['tob_base']?.expiryDate),
          onTap: () => context.go('/activities/my?type=tob'),
        ),
      if (auth.hasTobCrew)
        ...auth.tobCapabilities.map(
          (cap) => _CurrencyCard(
            title: cap.capabilityName,
            status: auth
                .currency['tob_${cap.helicopterTypeId}_${cap.tobCapabilityId}'],
            subtitle: 'TOB · ${cap.helicopterCode}',
            expiryText: _formatLongDate(
              auth
                  .currency['tob_${cap.helicopterTypeId}_${cap.tobCapabilityId}']
                  ?.expiryDate,
            ),
            onTap: () => context.go('/activities/my?type=tob'),
          ),
        ),
      if (auth.hasMdbCrew)
        _CurrencyCard(
          title: 'Mitragliere di Bordo',
          status: auth.currency['mdb'],
          subtitle: _flightSubtitle(auth.currency['mdb']),
          expiryText: _formatLongDate(auth.currency['mdb']?.expiryDate),
          onTap: () => context.go('/activities/my?type=flight'),
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
                if (user.isTi || user.isEtp) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (user.isTi)
                        Chip(
                          label: const Text('TI'),
                          backgroundColor: Colors.blue.shade700,
                        ),
                      if (user.isEtp)
                        Chip(
                          label: const Text('ETP'),
                          backgroundColor: Colors.purple.shade700,
                        ),
                    ],
                  ),
                ],
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
    final avatar = Tooltip(
      message: 'Vai al profilo',
      child: GestureDetector(
        onTap: onProfileTap,
        child: UserAvatar(user: user, radius: 31),
      ),
    );

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
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Benvenuto ${user.nome}',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
                softWrap: true,
              ),
            ),
            if (showFleetShortcut) ...[
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.flight, size: 28),
                tooltip: 'La Mia Flotta',
                onPressed: onFleetTap,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CurrencyCard extends StatelessWidget {
  const _CurrencyCard({
    required this.title,
    required this.status,
    required this.subtitle,
    required this.expiryText,
    required this.onTap,
  });

  final String title;
  final CurrencyStatus? status;
  final String subtitle;
  final String expiryText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final currentStatus =
        status ??
        const CurrencyStatus(
          status: CurrencyStatusEnum.noData,
          label: 'Nessun dato',
        );
    final goText = currentStatus.hasData
        ? (currentStatus.isExpired || currentStatus.isSuspended
              ? 'NO GO'
              : 'GO')
        : 'N/D';

    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: IntrinsicHeight(
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        currentStatus.icon,
                        size: 36,
                        color: currentStatus.color,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        goText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: currentStatus.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  color: currentStatus.color.withValues(alpha: 0.3),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                          softWrap: true,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                          softWrap: true,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          expiryText,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: currentStatus.color,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                          softWrap: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
