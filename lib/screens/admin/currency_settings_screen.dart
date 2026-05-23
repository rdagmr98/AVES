import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../models/activity_models.dart';
import '../../widgets/admin_write_pat_button.dart';

class CurrencySettingsScreen extends ConsumerStatefulWidget {
  const CurrencySettingsScreen({super.key});

  @override
  ConsumerState<CurrencySettingsScreen> createState() =>
      _CurrencySettingsScreenState();
}

class _CurrencySettingsScreenState
    extends ConsumerState<CurrencySettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currencyProviderProv).loadCriteria();
    });
  }

  Future<void> _editCriteria(CurrencyCriteria criteria) async {
    final auth = ref.read(authProvider);
    final isAdminCrew = auth.isAdminCrew;

    // Admin priv edits MAINTENANCE; admin crew edits TOB_BASE and TOB_CAPABILITY and FLIGHT_T
    final canEdit = (auth.isAdminPriv && criteria.criteriaType == 'MAINTENANCE') ||
        (isAdminCrew &&
            (criteria.criteriaType == 'FLIGHT_T' ||
                criteria.criteriaType == 'TOB_BASE' ||
                criteria.criteriaType == 'TOB_CAPABILITY'));
    if (!canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Non hai i permessi per modificare questo criterio.')),
      );
      return;
    }

    final periodCtrl = TextEditingController(text: '${criteria.periodDays}');
    final hoursCtrl = TextEditingController(
      text: criteria.minHours == null ? '' : '${criteria.minHours}',
    );
    // Fascia-specific fields (only for TOB_BASE and TOB_CAPABILITY)
    final hasFascia = criteria.criteriaType == 'TOB_BASE' ||
        criteria.criteriaType == 'TOB_CAPABILITY';
    final periodACtrl = TextEditingController(
      text: criteria.periodDaysA != null ? '${criteria.periodDaysA}' : '',
    );
    final periodBCCtrl = TextEditingController(
      text: criteria.periodDaysBC != null ? '${criteria.periodDaysBC}' : '',
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_criteriaLabel(criteria)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!hasFascia) ...[
                TextField(
                  controller: periodCtrl,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Periodo (giorni)'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: hoursCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration:
                      const InputDecoration(labelText: 'Ore minime (volo)'),
                ),
              ] else ...[
                const Text(
                  'Periodi massimi di inattività per fascia:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: periodACtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Fascia A (giorni)',
                    helperText: 'Periodo massimo per TOB di fascia A',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: periodBCCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Fascia B/C (giorni) — vuoto = N/A',
                    helperText: 'Lasciare vuoto se non applicabile per fascia B/C',
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () async {
              final userId = auth.userProfile?.id;
              if (userId == null) return;
              try {
                if (hasFascia) {
                  final periodA =
                      int.tryParse(periodACtrl.text.trim()) ?? criteria.periodDays;
                  final periodBC =
                      periodBCCtrl.text.trim().isEmpty
                          ? null
                          : int.tryParse(periodBCCtrl.text.trim());
                  // Use period A as the main period for backward compat
                  await ref.read(currencyProviderProv).updateCriteriaFascia(
                        criteria,
                        periodA,
                        periodBC,
                        userId,
                      );
                } else {
                  final period = int.tryParse(periodCtrl.text);
                  final hours = hoursCtrl.text.trim().isEmpty
                      ? null
                      : double.tryParse(
                          hoursCtrl.text.replaceAll(',', '.'),
                        );
                  if (period == null) return;
                  await ref.read(currencyProviderProv).updateCriteria(
                        CurrencyCriteria(
                          id: criteria.id,
                          criteriaType: criteria.criteriaType,
                          tobCapabilityId: criteria.tobCapabilityId,
                          periodDays: period,
                          minHours: hours,
                          description: criteria.description,
                          tobCapabilityName: criteria.tobCapabilityName,
                        ),
                        userId,
                      );
                }
                if (!mounted || !dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Criterio aggiornato.')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString())),
                );
              }
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );

    periodCtrl.dispose();
    hoursCtrl.dispose();
    periodACtrl.dispose();
    periodBCCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final provider = ref.watch(currencyProviderProv);

    // Filter criteria by admin type
    final criteria = provider.criteria.where((c) {
      if (auth.isAdminPriv && auth.isAdminCrew) return true;
      if (auth.isAdminPriv) return c.criteriaType == 'MAINTENANCE';
      if (auth.isAdminCrew) {
        return c.criteriaType == 'FLIGHT_T' ||
            c.criteriaType == 'TOB_BASE' ||
            c.criteriaType == 'TOB_CAPABILITY';
      }
      return false;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Impostazioni Currency'),
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: AdminWritePatButton(),
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: criteria.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final c = criteria[index];
                return Card(
                  child: ListTile(
                    title: Text(_criteriaLabel(c)),
                    subtitle: Text(_criteriaSubtitle(c)),
                    trailing: IconButton(
                      onPressed: () => _editCriteria(c),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _criteriaLabel(CurrencyCriteria criteria) {
    switch (criteria.criteriaType) {
      case 'MAINTENANCE':
        return 'Currency manutentiva';
      case 'FLIGHT_T':
        return 'Currency volo T (piloti/copiloti)';
      case 'TOB_BASE':
        return 'Currency base TOB (qualsiasi volo come equipaggio)';
      case 'TOB_CAPABILITY':
        return 'TOB · ${criteria.tobCapabilityName ?? 'Capacità'}';
      default:
        return criteria.criteriaType;
    }
  }

  String _criteriaSubtitle(CurrencyCriteria c) {
    if (c.criteriaType == 'TOB_BASE' || c.criteriaType == 'TOB_CAPABILITY') {
      final a = c.periodDaysA ?? c.periodDays;
      final bc = c.periodDaysBC != null ? '${c.periodDaysBC} gg' : 'N/A';
      return 'Fascia A: $a gg · Fascia B/C: $bc';
    }
    if (c.criteriaType == 'FLIGHT_T') {
      return 'Periodo: ${c.periodDays} gg · Ore minime: ${c.minHours?.toStringAsFixed(1) ?? '-'}';
    }
    return 'Periodo: ${c.periodDays} giorni';
  }
}
