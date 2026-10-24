import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../constants/app_constants.dart';
import '../../models/activity_models.dart';
import '../../models/user_models.dart';
import '../../services/notification_service.dart';
import '../../services/pta_service.dart';
import '../../services/view_prefs.dart';
import '../../services/web_notification_service.dart';
import '../../widgets/aves_logo_widget.dart';
import '../../services/hours_format.dart';
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

  @override
  void initState() {
    super.initState();
    compactDashboard.addListener(_onViewChanged);
  }

  @override
  void dispose() {
    compactDashboard.removeListener(_onViewChanged);
    super.dispose();
  }

  void _onViewChanged() => setState(() {});

  // GO/NO GO dice già lo stato: il sottotitolo serve solo se la causa è il seminario.
  String _maintenanceSubtitle(CurrencyStatus? status) {
    if (status == null ||
        !status.hasData ||
        !status.label.toLowerCase().contains('seminario')) {
      return '';
    }
    if (status.isExpired) return 'Seminario NAM/MHF scaduto';
    if (status.isWarning) return 'Seminario NAM/MHF in scadenza';
    return '';
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
      return '${formatHours(hours)} h  /  ${formatHours(minHours)} h';
    }
    return 'Nessun dato ore di volo';
  }

  @override
  Widget build(BuildContext context) {
    final compact = compactDashboard.value;
    final auth = ref.watch(authProvider);
    final user = auth.userProfile;
    final today = DateTime.now();
    final flightFitnessDate = user?.flightFitnessExpiry;
    final flightFitnessBlocking =
        flightFitnessDate != null &&
        flightFitnessDate.isBefore(
          DateTime(today.year, today.month, today.day),
        );

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

    // Idoneità al volo scaduta: sospende tutte le currency di equipaggio.
    const fitnessExpired = CurrencyStatus(
      status: CurrencyStatusEnum.expired,
      label: 'Idoneità al volo scaduta',
    );
    CurrencyStatus? crewStatus(String key) =>
        flightFitnessBlocking ? fitnessExpired : auth.currency[key];
    DateTime? crewExpiry(String key) => flightFitnessBlocking
        ? flightFitnessDate
        : auth.currency[key]?.expiryDate;

    final currencyCards = <Widget>[
      if (hasMaintenanceAccess)
        _CurrencyCard(
          compact: compact,
          title: 'Manutenzione',
          status: auth.currency['maintenance'],
          subtitle: _maintenanceSubtitle(auth.currency['maintenance']),
          expiry: _maintenanceExpiryDate(auth.currency['maintenance']),
          onTap: () => context.go('/activities/my?type=maintenance'),
        ),
      if (auth.hasTCrew)
        _CurrencyCard(
          compact: compact,
          title: 'Volo T',
          status: crewStatus('flight_t'),
          subtitle: flightFitnessBlocking
              ? 'Idoneità scaduta'
              : _flightSubtitle(auth.currency['flight_t']),
          expiry: crewExpiry('flight_t'),
          onTap: () => context.go('/activities/my?type=flight'),
        ),
      if (auth.hasTobCrew) ...[
        _CurrencyCard(
          compact: compact,
          title: 'Base TOB',
          status: crewStatus('tob_base'),
          subtitle: flightFitnessBlocking
              ? 'Idoneità scaduta'
              : 'Fascia ${tobFascia ?? '-'}',
          expiry: crewExpiry('tob_base'),
          onTap: () => context.go('/activities/my?type=tob'),
        ),
        for (final cap in auth.tobCapabilities)
          _CurrencyCard(
            compact: compact,
            title: cap.capabilityName,
            status: crewStatus(
              'tob_${cap.helicopterTypeId}_${cap.tobCapabilityId}',
            ),
            subtitle: flightFitnessBlocking
                ? 'Idoneità scaduta'
                : 'TOB · ${cap.helicopterCode}',
            expiry: crewExpiry(
              'tob_${cap.helicopterTypeId}_${cap.tobCapabilityId}',
            ),
            onTap: () => context.go('/activities/my?type=tob'),
          ),
      ],
      if (auth.hasMdbCrew)
        _CurrencyCard(
          compact: compact,
          title: 'Mitragliere di Bordo',
          status: crewStatus('mdb'),
          subtitle: flightFitnessBlocking
              ? 'Idoneità scaduta'
              : _flightSubtitle(auth.currency['mdb']),
          expiry: crewExpiry('mdb'),
          onTap: () => context.go('/activities/my?type=flight'),
        ),
    ];

    final textTheme = Theme.of(context).textTheme;
    final sectionStyle = textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    );
    final fitnessText = flightFitnessDate == null
        ? null
        : DateFormat('dd/MM/yyyy').format(flightFitnessDate);

    final header = _UserHeaderCard(
      user: user,
      compact: compact,
      badges: [
        if (compact && fitnessText != null)
          _Badge(
            flightFitnessBlocking
                ? 'Idoneità volo scaduta $fitnessText · SOSPESO'
                : 'Idoneità volo $fitnessText',
            flightFitnessBlocking ? Colors.redAccent : Colors.green,
            icon: flightFitnessBlocking
                ? Icons.warning_amber_rounded
                : Icons.verified_outlined,
            onTap: () => context.go('/profile'),
          ),
        if (compact && user.isTi) _Badge('TI', Colors.blue.shade300),
        if (compact && user.isEtp) _Badge('ETP', Colors.purple.shade200),
      ],
      showFleetShortcut: assignedHelicopters.isNotEmpty,
      onProfileTap: () => context.go('/profile'),
      onFleetTap: assignedHelicopters.isNotEmpty
          ? () => context.go('/helicopters/fleet')
          : null,
    );

    final approvalBanner = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.currencyWarning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.currencyWarning),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.pending_actions, color: AppColors.currencyWarning),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'In attesa di approvazione. Alcune funzionalità saranno abilitate dopo la verifica del profilo.',
              softWrap: true,
            ),
          ),
        ],
      ),
    );

    final ptaBanner = InkWell(
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
            const Icon(Icons.chevron_right, color: Color(0xFFCE93D8)),
          ],
        ),
      ),
    );

    final Widget currencySection = currencyCards.isEmpty
        ? const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Nessuna currency operativa assegnata al tuo profilo.',
                textAlign: TextAlign.center,
                softWrap: true,
              ),
            ),
          )
        : compact
        ? _CompactGrid(currencyCards)
        : LayoutBuilder(
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
          );

    final children = compact
        ? <Widget>[
            header,
            _PushPermissionBanner(userId: user.id),
            if (!user.isApproved) ...[
              const SizedBox(height: 12),
              approvalBanner,
            ],
            if (blockingPtas.isNotEmpty) ...[
              const SizedBox(height: 12),
              ptaBanner,
            ],
            const SizedBox(height: 24),
            // Su schermi larghi currency e privilegi stanno affiancati.
            LayoutBuilder(
              builder: (context, constraints) {
                final currency = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Currency', style: sectionStyle),
                    const SizedBox(height: 12),
                    currencySection,
                  ],
                );
                if (auth.privileges.isEmpty) return currency;
                final privileges = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Privilegi', style: sectionStyle),
                    const SizedBox(height: 12),
                    PrivilegeGridWidget(
                      privileges: auth.privileges,
                      compact: true,
                    ),
                  ],
                );
                if (constraints.maxWidth < 900) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      currency,
                      const SizedBox(height: 28),
                      privileges,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: currency),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: privileges),
                  ],
                );
              },
            ),
          ]
        : <Widget>[
            header,
            _PushPermissionBanner(userId: user.id),
            if (flightFitnessDate != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: flightFitnessBlocking
                      ? Colors.red.shade700.withValues(alpha: 0.15)
                      : Colors.green.shade800.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: flightFitnessBlocking
                        ? Colors.red.shade400
                        : Colors.green.shade600,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      flightFitnessBlocking
                          ? Icons.warning_amber_rounded
                          : Icons.verified_outlined,
                      color: flightFitnessBlocking
                          ? Colors.redAccent
                          : Colors.green,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        flightFitnessBlocking
                            ? 'Idoneità al volo scaduta il $fitnessText — Volo SOSPESO'
                            : 'Idoneità al volo: scadenza $fitnessText',
                        style: TextStyle(
                          color: flightFitnessBlocking
                              ? Colors.redAccent
                              : Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                        softWrap: true,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/profile'),
                      child: const Text('Aggiorna'),
                    ),
                  ],
                ),
              ),
            ],
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
              approvalBanner,
            ],
            if (blockingPtas.isNotEmpty) ...[
              const SizedBox(height: 16),
              ptaBanner,
            ],
            const SizedBox(height: 24),
            Text('Stato Currency', style: textTheme.titleLarge),
            const SizedBox(height: 12),
            currencySection,
            if (auth.privileges.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Privilegi assegnati',
                style: textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              PrivilegeGridWidget(privileges: auth.privileges),
            ],
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
      floatingActionButton: _RadialAddButton(
        onSelected: (tab) => context.go('/activities/add?tab=$tab'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: RefreshIndicator(
        onRefresh: () => ref.read(authProvider).refreshUserData(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: children,
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
    required this.compact,
    required this.showFleetShortcut,
    required this.onProfileTap,
    this.badges = const [],
    this.onFleetTap,
  });

  final UserProfile user;
  final bool compact;
  final List<Widget> badges;
  final bool showFleetShortcut;
  final VoidCallback onProfileTap;
  final VoidCallback? onFleetTap;

  @override
  Widget build(BuildContext context) {
    final avatar = Tooltip(
      message: 'Vai al profilo',
      child: GestureDetector(
        onTap: onProfileTap,
        child: UserAvatar(user: user, radius: compact ? 32 : 31),
      ),
    );

    return Container(
      // Compatta: superficie piatta, la gerarchia la fanno spazio e tipografia.
      decoration: compact
          ? BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
            )
          : BoxDecoration(
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
        padding: EdgeInsets.all(compact ? 18 : 20),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!compact)
                    Text(
                      'Benvenuto',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  Text(
                    user.nome,
                    style: compact
                        ? Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            height: 1.15,
                          )
                        : Theme.of(context).textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (badges.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: badges),
                  ],
                ],
              ),
            ),
            if (showFleetShortcut) ...[
              SizedBox(width: compact ? 8 : 16),
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

/// Pillola di stato nell'header compatto (TI, ETP, idoneità al volo).
class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color, {this.icon, this.onTap});

  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                softWrap: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Griglia a colonne fisse con card della stessa altezza per riga.
class _CompactGrid extends StatelessWidget {
  const _CompactGrid(this.cards);

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = math.max(2, constraints.maxWidth ~/ 190);
        return Column(
          children: [
            for (var i = 0; i < cards.length; i += columns)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var j = i; j < i + columns; j++) ...[
                        if (j > i) const SizedBox(width: 12),
                        Expanded(
                          child: j < cards.length
                              ? cards[j]
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CurrencyCard extends StatelessWidget {
  const _CurrencyCard({
    required this.compact,
    required this.title,
    required this.status,
    required this.subtitle,
    required this.expiry,
    required this.onTap,
  });

  final bool compact;
  final String title;
  final CurrencyStatus? status;
  final String subtitle;
  final DateTime? expiry;
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
    final date = expiry;
    final expiryText = compact
        ? (date == null
              ? ''
              : '${date.isBefore(DateUtils.dateOnly(DateTime.now())) ? 'Scaduta' : 'Scade'} '
                    '${DateFormat('d MMM yyyy', 'it').format(date)}')
        : (date == null
              ? 'Nessuna data registrata'
              : 'Scadenza: ${DateFormat('d MMMM yyyy', 'it').format(date)}');
    final textTheme = Theme.of(context).textTheme;

    final decoration = BoxDecoration(
      border: Border(left: BorderSide(color: currentStatus.color, width: 4)),
      gradient: LinearGradient(
        colors: [
          currentStatus.color.withValues(alpha: 0.08),
          AppColors.surface,
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
    );

    if (compact) {
      // Stile widget iOS: nome in alto, stato grande in basso, scadenza piccola.
      const secondary = TextStyle(color: AppColors.textSecondary, fontSize: 12);
      return Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: secondary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const Spacer(),
                const SizedBox(height: 18),
                Text(
                  goText,
                  style: TextStyle(
                    color: currentStatus.color,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    height: 1.05,
                  ),
                ),
                if (expiryText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    expiryText,
                    style: secondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: decoration,
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
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          softWrap: true,
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            softWrap: true,
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          expiryText,
                          style: textTheme.bodyMedium?.copyWith(
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

/// "+" che apre a ventaglio le 4 tipologie di attività (indice = tab).
class _RadialAddButton extends StatefulWidget {
  const _RadialAddButton({required this.onSelected});

  final ValueChanged<int> onSelected;

  @override
  State<_RadialAddButton> createState() => _RadialAddButtonState();
}

class _RadialAddButtonState extends State<_RadialAddButton>
    with SingleTickerProviderStateMixin {
  static const _options = [
    (Icons.build_outlined, 'Manutenzione'),
    (Icons.flight, 'Volo'),
    (Icons.groups_outlined, 'TOB'),
    (Icons.school_outlined, 'Seminario'),
  ];
  static const _radius = 122.0;
  static const _width = 320.0;
  static const _height = 210.0;

  late final _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final _anim = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeIn,
  );

  bool get _open =>
      _ctrl.status == AnimationStatus.forward ||
      _ctrl.status == AnimationStatus.completed;

  void _toggle() => setState(() => _open ? _ctrl.reverse() : _ctrl.forward());

  void _select(int tab) {
    _ctrl.reverse();
    widget.onSelected(tab);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      height: _height,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          final t = _anim.value;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Alone scuro sfumato dietro il ventaglio: stacca le icone dallo sfondo.
              Positioned(
                left: _width / 2 - 210,
                top: _height - 28 - 210,
                width: 420,
                height: 420,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.95),
                            AppColors.primary.withValues(alpha: 0.8),
                            AppColors.primary.withValues(alpha: 0),
                          ],
                          stops: const [0, 0.6, 1],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              for (var i = 0; i < _options.length; i++) _option(i, t),
              Positioned(
                left: _width / 2 - 28,
                bottom: 0,
                child: FloatingActionButton(
                  onPressed: _toggle,
                  tooltip: _open ? 'Chiudi' : 'Inserisci Attività',
                  child: Transform.rotate(
                    angle: t.clamp(0.0, 1.0) * math.pi / 4,
                    child: const Icon(Icons.add),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _option(int i, double t) {
    // Ventaglio da 160° a 20° sopra il "+".
    final angle = (160 - i * 140 / (_options.length - 1)) * math.pi / 180;
    final cx = _width / 2 + _radius * t * math.cos(angle);
    final cy = _height - 28 - _radius * t * math.sin(angle);
    final (icon, label) = _options[i];
    return Positioned(
      left: cx - 55,
      top: cy - 28,
      width: 110,
      child: IgnorePointer(
        ignoring: !_open,
        child: Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentGlow.withValues(alpha: 0.55),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: FloatingActionButton(
                  heroTag: null,
                  tooltip: label,
                  backgroundColor: AppColors.accentGlow,
                  foregroundColor: AppColors.primary,
                  onPressed: () => _select(i),
                  child: Icon(icon, size: 28),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.accentGlow.withValues(alpha: 0.6),
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 6),
                  ],
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Invita a consentire le notifiche di sistema: il permesso va chiesto da un
/// tocco (iPhone e Chrome bloccano la richiesta automatica al login).
class _PushPermissionBanner extends StatefulWidget {
  const _PushPermissionBanner({required this.userId});

  final String userId;

  @override
  State<_PushPermissionBanner> createState() => _PushPermissionBannerState();
}

class _PushPermissionBannerState extends State<_PushPermissionBanner> {
  bool _hidden = false;
  bool _busy = false;

  Future<void> _enable() async {
    setState(() => _busy = true);
    await NotificationService().enablePush(widget.userId);
    if (!mounted) return;
    setState(() => _busy = false);
    final err = WebNotificationService.lastError;
    if (WebNotificationService.pushActive.value || err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            err == null ? 'Notifiche attivate' : 'Notifiche non attivate: $err',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: WebNotificationService.pushActive,
    builder: (context, active, _) => _banner(active),
  );

  Widget _banner(bool active) {
    final permission = WebNotificationService.permission;
    final install = WebNotificationService.needsHomeScreen;
    // Permesso già concesso (anche da un'altra app sulla stessa origine, es.
    // Squadrone) ma nessuna sottoscrizione qui: serve comunque un tocco.
    if (_hidden || active || (permission == 'unsupported' && !install)) {
      return const SizedBox.shrink();
    }
    final denied = permission == 'denied';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.accent),
        ),
        child: Row(
          children: [
            Icon(
              denied || install
                  ? Icons.notifications_off_outlined
                  : Icons.notifications_active_outlined,
              color: AppColors.accentGlow,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                install
                    ? "Per le notifiche su iPhone: Condividi → Aggiungi alla schermata Home, poi apri l'app da lì"
                    : denied
                    ? 'Notifiche bloccate: riattivale dalle impostazioni del sito nel browser'
                    : permission == 'granted'
                    ? 'Notifiche non ancora attive su questo dispositivo'
                    : 'Consenti le notifiche per ricevere gli avvisi di scadenza anche ad app chiusa',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            if (!denied && !install)
              _busy
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : TextButton(
                      onPressed: _enable,
                      child: Text(
                        permission == 'granted' ? 'Attiva' : 'Consenti',
                      ),
                    ),
            IconButton(
              tooltip: 'Nascondi',
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _hidden = true),
            ),
          ],
        ),
      ),
    );
  }
}
