import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../constants/app_constants.dart';
import '../../data/helicopter_catalog.dart';
import '../../models/activity_models.dart';
import '../../models/reference_models.dart';
import '../../models/user_models.dart';
import '../../services/currency_service.dart';
import '../../services/notification_service.dart';
import '../../services/pta_service.dart';
import '../../services/web_notification_service.dart';
import '../../widgets/aves_logo_widget.dart';
import '../../services/hours_format.dart';
import '../../widgets/notification_panel_widget.dart';
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

    // Tocco su una miniatura: privilegi con GO/NO GO e qualifiche di volo.
    void openHelicopter(HelicopterType heli) {
      String? fascia;
      for (final c in auth.crewAssignments) {
        if (c.helicopterTypeId == heli.id && c.crewType == 'TOB') {
          fascia = c.fascia;
        }
      }
      final crewTypes = auth.crewAssignments
          .where((c) => c.helicopterTypeId == heli.id)
          .map((c) => c.crewType)
          .toSet();
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: AppColors.surface,
        builder: (_) => _HelicopterSheet(
          helicopter: heli,
          privileges: auth.privileges
              .where((p) => p.helicopterTypeId == heli.id)
              .toList(),
          licenses: [
            for (final l in auth.licenses)
              if (l.helicopterTypeId == heli.id) l.licenseName,
          ],
          maintenance: auth.currency['maintenance'],
          perPrivilege: CurrencyService().getPerPrivilegeCurrency(
            user.id,
            helicopterTypeIds: {heli.id},
          ),
          flight: [
            if (crewTypes.contains('T')) ('Volo T', '', crewStatus('flight_t')),
            if (crewTypes.contains('TOB'))
              ('Base TOB', 'Fascia ${fascia ?? '-'}', crewStatus('tob_base')),
            for (final cap in auth.tobCapabilities)
              if (cap.helicopterTypeId == heli.id)
                (
                  cap.capabilityName,
                  'Capacità TOB',
                  crewStatus('tob_${heli.id}_${cap.tobCapabilityId}'),
                ),
            if (crewTypes.contains('MDB'))
              ('Mitragliere di Bordo', '', crewStatus('mdb')),
          ],
        ),
      );
    }

    final currencyCards = <_CurrencyCard>[
      if (hasMaintenanceAccess)
        _CurrencyCard(
          title: 'Manutenzione',
          status: auth.currency['maintenance'],
          subtitle: _maintenanceSubtitle(auth.currency['maintenance']),
          expiry: _maintenanceExpiryDate(auth.currency['maintenance']),
          onTap: () => context.go('/activities/my?type=maintenance'),
        ),
      if (auth.hasTCrew)
        _CurrencyCard(
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
    // Anello attorno all'avatar = stato peggiore tra le currency mostrate.
    const rank = [
      CurrencyStatusEnum.valid,
      CurrencyStatusEnum.noData,
      CurrencyStatusEnum.warning,
      CurrencyStatusEnum.suspended,
      CurrencyStatusEnum.expired,
    ];
    final worst =
        [
          for (final card in currencyCards)
            card.status?.status ?? CurrencyStatusEnum.noData,
          if (blockingPtas.isNotEmpty) CurrencyStatusEnum.suspended,
        ].fold<CurrencyStatusEnum?>(
          null,
          (a, b) => a == null || rank.indexOf(b) > rank.indexOf(a) ? b : a,
        );

    final header = _CompactHeader(
      user: user,
      ringColor: worst == null
          ? null
          : CurrencyStatus(status: worst, label: '').color,
      badges: [
        if (user.isTi) _Badge('TI', Colors.blue.shade300),
        if (user.isEtp) _Badge('ETP', Colors.purple.shade200),
      ],
      caption: flightFitnessDate == null
          ? null
          : _FitnessCaption(
              date: flightFitnessDate,
              blocking: flightFitnessBlocking,
            ),
      onTap: () => context.go('/profile'),
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
        : _CompactGrid(currencyCards);

    final children = <Widget>[
      header,
      _PushPermissionBanner(userId: user.id),
      if (!user.isApproved) ...[const SizedBox(height: 12), approvalBanner],
      if (blockingPtas.isNotEmpty) ...[const SizedBox(height: 12), ptaBanner],
      const SizedBox(height: 24),
      Text('Currency', style: sectionStyle),
      const SizedBox(height: 12),
      currencySection,
      if (assignedHelicopters.isNotEmpty) ...[
        const SizedBox(height: 28),
        Text('Elicotteri', style: sectionStyle),
        const SizedBox(height: 12),
        _HelicopterTiles(
          helicopters: assignedHelicopters,
          onTap: openHelicopter,
        ),
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

/// Header compatto: riga profilo stile iOS (tutta tappabile), avatar con
/// anello colorato dallo stato peggiore, nome grande, TI/ETP, idoneità.
class _CompactHeader extends StatelessWidget {
  const _CompactHeader({
    required this.user,
    required this.ringColor,
    required this.badges,
    required this.caption,
    required this.onTap,
  });

  final UserProfile user;
  final Color? ringColor;
  final List<Widget> badges;
  final Widget? caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.surfaceVariant, AppColors.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ringColor ?? Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: UserAvatar(user: user, radius: 34),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.nome,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.6,
                                height: 1.15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          for (final badge in badges) ...[
                            const SizedBox(width: 8),
                            badge,
                          ],
                        ],
                      ),
                      if (caption != null) ...[
                        const SizedBox(height: 6),
                        caption!,
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Riga idoneità al volo sotto il nome: discreta se valida, rossa se scaduta.
class _FitnessCaption extends StatelessWidget {
  const _FitnessCaption({required this.date, required this.blocking});

  final DateTime date;
  final bool blocking;

  @override
  Widget build(BuildContext context) {
    final text = DateFormat('dd/MM/yyyy').format(date);
    return Row(
      children: [
        Icon(
          blocking ? Icons.warning_amber_rounded : Icons.verified_outlined,
          size: 15,
          color: blocking ? Colors.redAccent : AppColors.currencyValid,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            blocking
                ? 'Idoneità volo scaduta $text · SOSPESO'
                : 'Idoneità volo $text',
            style: TextStyle(
              color: blocking ? Colors.redAccent : AppColors.textSecondary,
              fontSize: 13,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Pillola accanto al nome nell'header compatto (TI, ETP).
class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Miniature degli elicotteri assegnati: ritaglio senza sfondo e nome.
class _HelicopterTiles extends StatelessWidget {
  const _HelicopterTiles({required this.helicopters, required this.onTap});

  final List<HelicopterType> helicopters;
  final ValueChanged<HelicopterType> onTap;

  @override
  Widget build(BuildContext context) {
    final sorted = [...helicopters]..sort((a, b) => a.code.compareTo(b.code));
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = math.max(3, constraints.maxWidth ~/ 150);
        final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final heli in sorted)
              SizedBox(width: width, child: _tile(heli)),
          ],
        );
      },
    );
  }

  Widget _tile(HelicopterType heli) {
    final image = helicopterImage(heli.code);
    final accent = catalogAccent(heli.code);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent.withValues(alpha: 0.16), AppColors.surface],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: InkWell(
          onTap: () => onTap(heli),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: image == null
                      ? Icon(Icons.flight, color: accent, size: 32)
                      : Image.asset(image, fit: BoxFit.contain),
                ),
                const SizedBox(height: 10),
                Text(
                  heli.name.isEmpty ? heli.code : heli.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Scheda dell'elicottero: privilegi con GO/NO GO e qualifiche di volo.
class _HelicopterSheet extends StatelessWidget {
  const _HelicopterSheet({
    required this.helicopter,
    required this.privileges,
    required this.licenses,
    required this.maintenance,
    required this.perPrivilege,
    required this.flight,
  });

  final HelicopterType helicopter;
  final List<UserPrivilege> privileges;
  final List<String> licenses;
  final CurrencyStatus? maintenance;
  final Future<List<PrivilegeCurrencyStatus>> perPrivilege;
  final List<(String, String, CurrencyStatus?)> flight;

  @override
  Widget build(BuildContext context) {
    final image = helicopterImage(helicopter.code);
    final sorted = [...privileges]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    // PTA o seminario mancante/scaduto fermano tutti i privilegi: sono gli
    // unici NO GO generali senza data del seminario (currency_service).
    final general = maintenance;
    final blocked =
        general != null &&
            (general.isSuspended ||
                (general.isExpired && general.secondaryExpiryDate == null))
        ? general
        : null;
    final sectionStyle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (image != null)
              SizedBox(
                height: 120,
                child: Image.asset(image, fit: BoxFit.contain),
              ),
            const SizedBox(height: 12),
            Text(
              helicopter.name.isEmpty ? helicopter.code : helicopter.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            if (sorted.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Privilegi', style: sectionStyle),
              const SizedBox(height: 8),
              FutureBuilder<List<PrivilegeCurrencyStatus>>(
                future: perPrivilege,
                builder: (context, snap) {
                  CurrencyStatus? statusFor(UserPrivilege p) {
                    if (blocked != null) return blocked;
                    for (final s in snap.data ?? const []) {
                      if (s.privilegeTypeId == p.privilegeTypeId) {
                        return s.status;
                      }
                    }
                    return null;
                  }

                  return _SheetGroup([
                    for (final p in sorted)
                      _SheetRow(
                        title: p.privilegeCode.isEmpty
                            ? p.privilegeName
                            : '${p.privilegeCode} · ${p.privilegeName}',
                        status: snap.hasData ? statusFor(p) : null,
                        loading: !snap.hasData,
                      ),
                  ]);
                },
              ),
            ],
            if (flight.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Qualifiche di volo', style: sectionStyle),
              const SizedBox(height: 8),
              _SheetGroup([
                for (final f in flight)
                  _SheetRow(title: f.$1, subtitle: f.$2, status: f.$3),
              ]),
            ],
            if (licenses.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Licenze', style: sectionStyle),
              const SizedBox(height: 8),
              _SheetGroup([
                for (final l in licenses)
                  _SheetRow(title: l, showStatus: false),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _SheetGroup extends StatelessWidget {
  const _SheetGroup(this.rows);

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: 16, color: AppColors.border),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// Riga della scheda: pallino e GO/NO GO a destra.
class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.title,
    this.subtitle = '',
    this.status,
    this.loading = false,
    this.showStatus = true,
  });

  final String title;
  final String subtitle;
  final CurrencyStatus? status;
  final bool loading;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final go = s == null || !s.hasData
        ? 'N/D'
        : s.isExpired || s.isSuspended
        ? 'NO GO'
        : 'GO';
    final color = s?.color ?? AppColors.textHint;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (loading)
            const SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (showStatus) ...[
            const SizedBox(width: 12),
            Icon(Icons.circle, size: 10, color: color),
            const SizedBox(width: 6),
            Text(
              go,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
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
    required this.title,
    required this.status,
    required this.subtitle,
    required this.expiry,
    required this.onTap,
  });

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
    final textTheme = Theme.of(context).textTheme;

    // Stile widget iOS/Fitness: nome in alto, stato grande con anello,
    // countdown e data. Anello = ore del semestre se c'è un minimo ore,
    // altrimenti tempo residuo tra ultima attività e scadenza.
    const secondary = TextStyle(color: AppColors.textSecondary, fontSize: 12);
    final color = currentStatus.color;
    final today = DateUtils.dateOnly(DateTime.now());
    final days = date == null ? null : _daysBetween(today, date);
    final hours = currentStatus.flightHours;
    final minHours = currentStatus.minFlightHours;
    final last = currentStatus.lastActivityDate;
    final progress = hours != null && minHours != null && minHours > 0
        ? hours / minHours
        : days != null && last != null
        ? days / math.max(1, _daysBetween(last, date!))
        : 0.0;
    final countdown = days == null
        ? ''
        : days > 0
        ? 'Scade tra $days gg'
        : days == 0
        ? 'Scade oggi'
        : 'Scaduta da ${-days} gg';
    // Effetto 3D: cornice piena nel colore di stato (lo stesso dell'anello
    // avatar) con luce in alto a sinistra e ombra in basso a destra, alone
    // colorato, ombra scura di stacco e riflesso lucido sulla metà alta.
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Color.lerp(color, Colors.white, 0.45)!,
            color,
            Color.lerp(color, Colors.black, 0.4)!,
          ],
          stops: const [0, 0.45, 1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(17.5),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.42),
                color.withValues(alpha: 0.12),
                AppColors.surface,
              ],
              stops: const [0, 0.5, 1],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.14),
                  Colors.white.withValues(alpha: 0),
                ],
                stops: const [0, 0.45],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
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
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              goText,
                              style: TextStyle(
                                color: color,
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.8,
                                height: 1,
                                shadows: [
                                  Shadow(
                                    color: color.withValues(alpha: 0.8),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox.square(
                          dimension: 38,
                          child: CircularProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            strokeWidth: 5,
                            strokeCap: StrokeCap.round,
                            color: color,
                            backgroundColor: color.withValues(alpha: 0.18),
                          ),
                        ),
                      ],
                    ),
                    if (date != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        countdown,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        DateFormat('d MMM yyyy', 'it').format(date),
                        style: secondary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Giorni di calendario tra due date (UTC: niente sorprese da ora legale).
int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

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
