import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../constants/app_constants.dart';
import '../../models/activity_models.dart';
import '../../services/pta_service.dart';

class PtaScreen extends ConsumerStatefulWidget {
  const PtaScreen({super.key});

  @override
  ConsumerState<PtaScreen> createState() => _PtaScreenState();
}

class _PtaScreenState extends ConsumerState<PtaScreen> {
  final _ptaService = PtaService();

  bool _loading = true;
  List<PtaRecord> _unread = [];
  // PTAs affecting this user that still require action
  List<PtaRecord> _blocking = [];
  // All PTAs relevant to the user's helicopters (for info)
  List<PtaRecord> _allUserPta = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = ref.read(authProvider).userProfile;
    if (user == null) return;
    setState(() => _loading = true);

    _unread = _ptaService.getUserUnreadPtas(user.id);
    _blocking = _ptaService.getBlockingPtaForUser(user.id);

    // All PTAs where user is blocking or has already acknowledged
    _allUserPta = _ptaService.getAllPta().where((pta) {
      return _blocking.any((b) => b.id == pta.id) ||
          _ptaService.hasAck(user.id, pta.id!);
    }).toList();

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _acknowledge(PtaRecord pta) async {
    final user = ref.read(authProvider).userProfile;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Presa visione PTA'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PTA ${pta.number} — ${pta.helicopterCode}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(pta.title),
            const SizedBox(height: 16),
            const Text(
              'Confermo di aver preso visione della presente Prescrizione Tecnica '
              'di Aeronavigabilità e di essere consapevole della sospensione della '
              'mia currency manutentiva fino a validazione.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Preso visione'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _ptaService.acknowledgepta(
        pta.id!,
        user.id,
        user.fullName,
        user.numeroLicenza ?? '',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Presa visione inviata. In attesa di validazione admin.',
            ),
            backgroundColor: AppColors.currencyWarning,
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(authProvider);
    final hasMaintenanceAccess =
        auth.licenses.isNotEmpty || auth.privileges.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PTA Manutenzione'),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !hasMaintenanceAccess
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nessun privilegio manutentivo assegnato. Le PTA si applicano solo alla currency manutentiva.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _allUserPta.isEmpty && _blocking.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: AppColors.currencyValid,
                            size: 64,
                          ),
                          SizedBox(height: 16),
                          Text('Nessuna PTA attiva per i tuoi elicotteri'),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_unread.isNotEmpty) ...[
                          _SectionHeader(
                            label: 'Da prendere visione (${_unread.length})',
                            color: AppColors.currencyExpired,
                            icon: Icons.block,
                          ),
                          const SizedBox(height: 8),
                          ..._unread.map(
                            (pta) => _PtaCard(
                              pta: pta,
                              hasPendingAck: false,
                              isValidated: false,
                              onAcknowledge: () => _acknowledge(pta),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        if (_allUserPta.any(
                          (p) => !_unread.any((u) => u.id == p.id),
                        )) ...[
                          const _SectionHeader(
                            label: 'Già preso visione',
                            color: AppColors.currencyValid,
                            icon: Icons.check_circle,
                          ),
                          const SizedBox(height: 8),
                          ..._allUserPta
                              .where((p) => !_unread.any((u) => u.id == p.id))
                              .map(
                                (pta) => _PtaCard(
                                  pta: pta,
                                  hasPendingAck: _ptaService.hasAck(
                                    ref.read(authProvider).userProfile!.id,
                                    pta.id!,
                                  ),
                                  isValidated: _ptaService.hasValidatedAck(
                                    ref.read(authProvider).userProfile!.id,
                                    pta.id!,
                                  ),
                                  onAcknowledge: null,
                                ),
                              ),
                        ],
                      ],
                    ),
            ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _SectionHeader({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _PtaCard extends StatelessWidget {
  final PtaRecord pta;
  final bool hasPendingAck;
  final bool isValidated;
  final VoidCallback? onAcknowledge;

  const _PtaCard({
    required this.pta,
    required this.hasPendingAck,
    required this.isValidated,
    required this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    final bool needsAction = onAcknowledge != null && !hasPendingAck;
    final bool waitingValidation = hasPendingAck && !isValidated;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: needsAction
                      ? AppColors.currencyExpired
                      : waitingValidation
                      ? AppColors.currencyWarning
                      : AppColors.currencyValid,
                  radius: 20,
                  child: Text(
                    pta.helicopterCode.length > 3
                        ? pta.helicopterCode.substring(0, 3)
                        : pta.helicopterCode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pta.number,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        pta.helicopterCode,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                _statusChip(needsAction, waitingValidation, isValidated),
              ],
            ),
            const SizedBox(height: 12),
            Text(pta.title),
            const SizedBox(height: 8),
            Text(
              'Emessa il ${DateFormat('dd/MM/yyyy').format(pta.issueDate)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (needsAction) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onAcknowledge,
                  icon: const Icon(Icons.check),
                  label: const Text('Preso visione'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.currencyExpired,
                  ),
                ),
              ),
            ] else if (waitingValidation) ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(
                    Icons.hourglass_top,
                    size: 16,
                    color: AppColors.currencyWarning,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'In attesa di validazione admin',
                    style: TextStyle(color: AppColors.currencyWarning),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusChip(bool needsAction, bool waitingValidation, bool validated) {
    if (validated) {
      return Chip(
        label: const Text('VALIDATA'),
        backgroundColor: AppColors.currencyValid,
        labelStyle: const TextStyle(color: Colors.white, fontSize: 11),
      );
    }
    if (waitingValidation) {
      return Chip(
        label: const Text('IN ATTESA'),
        backgroundColor: AppColors.currencyWarning,
        labelStyle: const TextStyle(color: Colors.white, fontSize: 11),
      );
    }
    return Chip(
      label: const Text('DA LEGGERE'),
      backgroundColor: AppColors.currencyExpired,
      labelStyle: const TextStyle(color: Colors.white, fontSize: 11),
    );
  }
}
