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
    final periodCtrl = TextEditingController(text: '${criteria.periodDays}');
    final hoursCtrl = TextEditingController(
      text: criteria.minHours == null ? '' : '${criteria.minHours}',
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_criteriaLabel(criteria)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: periodCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Periodo (giorni)'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: hoursCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Ore minime'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () async {
              final period = int.tryParse(periodCtrl.text);
              final hours = hoursCtrl.text.trim().isEmpty
                  ? null
                  : double.tryParse(hoursCtrl.text.replaceAll(',', '.'));
              if (period == null) {
                return;
              }
              final auth = ref.read(authProvider);
              final userId = auth.userProfile?.id;
              if (userId == null) {
                return;
              }
              try {
                await ref
                    .read(currencyProviderProv)
                    .updateCriteria(
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
                if (!mounted || !dialogContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Criterio aggiornato.')),
                );
              } catch (e) {
                if (!mounted) {
                  return;
                }
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
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(currencyProviderProv);

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
              itemCount: provider.criteria.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final criteria = provider.criteria[index];
                return Card(
                  child: ListTile(
                    title: Text(_criteriaLabel(criteria)),
                    subtitle: Text(
                      'Periodo: ${criteria.periodDays} giorni · Ore minime: ${criteria.minHours?.toStringAsFixed(1) ?? '-'}',
                    ),
                    trailing: IconButton(
                      onPressed: () => _editCriteria(criteria),
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
        return 'Currency volo T';
      case 'TOB_CAPABILITY':
        return 'TOB · ${criteria.tobCapabilityName ?? 'Capacità'}';
      default:
        return criteria.criteriaType;
    }
  }
}
