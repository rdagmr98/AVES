import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../constants/app_constants.dart';
import '../../models/activity_models.dart';
import '../../services/pta_service.dart';

class PtaManagementScreen extends ConsumerStatefulWidget {
  const PtaManagementScreen({super.key});

  @override
  ConsumerState<PtaManagementScreen> createState() =>
      _PtaManagementScreenState();
}

class _PtaManagementScreenState extends ConsumerState<PtaManagementScreen>
    with SingleTickerProviderStateMixin {
  final _ptaService = PtaService();
  late TabController _tabs;
  bool _loading = false;

  List<PtaRecord> _allPta = [];
  List<PtaAcknowledgment> _pendingAcks = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    _allPta = _ptaService.getAllPta();
    _pendingAcks = _ptaService.getPendingAcknowledgments();
    if (mounted) setState(() => _loading = false);
  }

  // ── Create PTA dialog ────────────────────────────────────────────────────

  Future<void> _showCreateDialog({PtaRecord? existing}) async {
    final auth = ref.read(authProvider);
    await showDialog<void>(
      context: context,
      builder: (ctx) => _CreatePtaDialog(
        initialPta: existing,
        onSaved: (helicopterTypeId, number, title, issueDate) async {
          final adminUsername =
              auth.userProfile?.numeroLicenza ?? auth.userProfile?.id ?? '';
          if (existing == null) {
            await _ptaService.createPta(
              helicopterTypeId: helicopterTypeId,
              number: number,
              title: title,
              issueDate: issueDate,
              createdBy: adminUsername,
            );
          } else {
            await _ptaService.updatePta(
              PtaRecord(
                id: existing.id,
                helicopterTypeId: helicopterTypeId,
                helicopterCode: existing.helicopterCode,
                number: number,
                title: title,
                issueDate: issueDate,
                createdBy: existing.createdBy,
                createdAt: existing.createdAt,
                isClosed: existing.isClosed,
              ),
            );
          }
          await _loadData();
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
    );
  }

  // ── Validate acknowledgment ───────────────────────────────────────────────

  Future<void> _validateAck(PtaAcknowledgment ack) async {
    final auth = ref.read(authProvider);
    final adminUsername =
        auth.userProfile?.numeroLicenza ?? auth.userProfile?.id ?? '';
    try {
      await _ptaService.validateAcknowledgment(ack.id!, adminUsername);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Presa visione validata'),
            backgroundColor: AppColors.currencyValid,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    }
  }

  // ── Close PTA ────────────────────────────────────────────────────────────

  Future<void> _closePta(PtaRecord pta) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chiudi PTA'),
        content: Text(
          'Chiudere la PTA ${pta.number}?\nNon bloccherà più la currency manutentiva.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Chiudi PTA'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _ptaService.closePta(pta.id!);
    await _loadData();
  }

  Future<void> _deletePta(PtaRecord pta) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina PTA'),
        content: Text(
          'Eliminare definitivamente la PTA ${pta.number}? Verranno rimosse anche le prese visione collegate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.currencyExpired,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _ptaService.deletePta(pta.id!);
    await _loadData();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione PTA'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(
              text: 'PTA (${_allPta.length})',
              icon: const Icon(Icons.article_outlined),
            ),
            Tab(
              text: 'Prese visione (${_pendingAcks.length})',
              icon: Icon(
                Icons.pending_actions,
                color: _pendingAcks.isNotEmpty ? AppColors.currencyExpired : null,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Aggiorna',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nuova PTA'),
        backgroundColor: AppColors.currencyExpired,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [_buildPtaList(), _buildAckList()],
            ),
    );
  }

  Widget _buildPtaList() {
    if (_allPta.isEmpty) {
      return const Center(
        child: Text('Nessuna PTA inserita'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _allPta.length,
      itemBuilder: (context, i) {
        final pta = _allPta[i];
        final acks = _ptaService.getAcknowledgmentsForPta(pta.id!);
        final validatedCount = acks.where((a) => a.isValidated).length;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  pta.isClosed ? Colors.grey : AppColors.currencyExpired,
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
            title: Text(
              '${pta.number} — ${pta.helicopterCode}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pta.title),
                const SizedBox(height: 4),
                Text(
                  'Emessa: ${DateFormat('dd/MM/yyyy').format(pta.issueDate)}  •  '
                  'Prese visione validate: $validatedCount/${acks.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _showCreateDialog(existing: pta);
                    break;
                  case 'close':
                    _closePta(pta);
                    break;
                  case 'delete':
                    _deletePta(pta);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Modifica PTA'),
                ),
                if (!pta.isClosed)
                  const PopupMenuItem(
                    value: 'close',
                    child: Text('Chiudi PTA'),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Elimina PTA'),
                ),
              ],
              child: pta.isClosed
                  ? Chip(
                      label: const Text('CHIUSA'),
                      backgroundColor: Colors.grey.shade700,
                    )
                  : const Icon(Icons.more_horiz),
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildAckList() {
    if (_pendingAcks.isEmpty) {
      return const Center(
        child: Text('Nessuna presa visione da validare'),
      );
    }
    // Group by PTA
    final byPta = <int, List<PtaAcknowledgment>>{};
    for (final ack in _pendingAcks) {
      byPta.putIfAbsent(ack.ptaId, () => []).add(ack);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: byPta.entries.map((entry) {
        final ptaRecord = _allPta.firstWhere(
          (p) => p.id == entry.key,
          orElse: () => PtaRecord(
            id: entry.key,
            helicopterTypeId: 0,
            helicopterCode: '?',
            number: '?',
            title: 'PTA sconosciuta',
            issueDate: DateTime.now(),
            createdBy: '',
            createdAt: DateTime.now(),
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'PTA ${ptaRecord.number} — ${ptaRecord.helicopterCode}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...entry.value.map(
              (ack) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ack.userFullName.isNotEmpty
                                  ? ack.userFullName
                                  : ack.userId,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Licenza: ${ack.userLicenza.isNotEmpty ? ack.userLicenza : "-"}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        'Preso visione il: ${DateFormat('dd/MM/yyyy HH:mm').format(ack.acknowledgedAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _validateAck(ack),
                          icon: const Icon(Icons.verified_outlined, size: 18),
                          label: const Text('Valida presa visione'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.currencyValid,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

// ── Create PTA dialog ─────────────────────────────────────────────────────────

class _CreatePtaDialog extends StatefulWidget {
  final PtaRecord? initialPta;
  final Future<void> Function(
    int helicopterTypeId,
    String number,
    String title,
    DateTime issueDate,
  ) onSaved;

  const _CreatePtaDialog({required this.onSaved, this.initialPta});

  @override
  State<_CreatePtaDialog> createState() => _CreatePtaDialogState();
}

class _CreatePtaDialogState extends State<_CreatePtaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _numberCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  DateTime _issueDate = DateTime.now();
  int? _helicopterTypeId;
  bool _saving = false;

  // Loaded from reference data
  List<Map<String, dynamic>> _helicopters = [];

  @override
  void initState() {
    super.initState();
    final ptaService = PtaService();
    // Access reference data directly from the db singleton
    final ghDb = ptaService.referenceData;
    _helicopters = List<Map<String, dynamic>>.from(
      (ghDb['helicopterTypes'] as List<dynamic>? ?? const []),
    );
    _numberCtrl.text = widget.initialPta?.number ?? '';
    _titleCtrl.text = widget.initialPta?.title ?? '';
    _issueDate = widget.initialPta?.issueDate ?? DateTime.now();
    _helicopterTypeId = widget.initialPta?.helicopterTypeId;
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _issueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _issueDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_helicopterTypeId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Seleziona un elicottero')));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSaved(
        _helicopterTypeId!,
        _numberCtrl.text.trim().toUpperCase(),
        _titleCtrl.text.trim(),
        _issueDate,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialPta == null ? 'Nuova PTA' : 'Modifica PTA'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ignore: deprecated_member_use
              DropdownButtonFormField<int>(
                initialValue: _helicopterTypeId,
                decoration: const InputDecoration(
                  labelText: 'Elicottero *',
                  prefixIcon: Icon(Icons.flight),
                ),
                items: _helicopters
                    .map(
                      (h) => DropdownMenuItem<int>(
                        value: h['id'] as int,
                        child: Text(h['code'] as String? ?? '?'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _helicopterTypeId = v),
                validator: (v) => v == null ? 'Obbligatorio' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _numberCtrl,
                decoration: const InputDecoration(
                  labelText: 'Numero PTA *',
                  hintText: 'es. PTA-2025-001',
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Obbligatorio' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descrizione / Titolo *',
                ),
                maxLines: 2,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Obbligatorio' : null,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: const Text('Data emissione'),
                subtitle: Text(
                  DateFormat('dd/MM/yyyy').format(_issueDate),
                ),
                onTap: _pickDate,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.initialPta == null ? 'Crea PTA' : 'Salva PTA'),
        ),
      ],
    );
  }
}
