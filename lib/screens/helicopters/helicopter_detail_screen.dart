import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../constants/app_constants.dart';
import '../../data/helicopter_catalog.dart';
import '../../models/reference_models.dart';

class HelicopterDetailScreen extends ConsumerWidget {
  const HelicopterDetailScreen({super.key, required this.helicopterId});

  final int helicopterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    HelicopterType? helicopter;
    for (final item in auth.helicopterTypes) {
      if (item.id == helicopterId) {
        helicopter = item;
        break;
      }
    }
    if (helicopter == null) {
      return const Scaffold(
        body: Center(child: Text('Elicottero non trovato.')),
      );
    }

    final accent = catalogAccent(helicopter.code);
    final userLicenses = auth.licenses
        .where((item) => item.helicopterTypeId == helicopterId)
        .toList();
    final userPrivileges = auth.privileges
        .where((item) => item.helicopterTypeId == helicopterId)
        .toList();
    final crews = auth.crewAssignments
        .where((item) => item.helicopterTypeId == helicopterId)
        .toList();
    final tobCaps = auth.tobCapabilities
        .where((item) => item.helicopterTypeId == helicopterId)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(helicopter.name, overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            shrinkWrap: false,
            padding: const EdgeInsets.all(16),
            children: [
              _HeroCard(
                helicopter: helicopter,
                imageAsset: helicopterImage(helicopter.code),
                accent: accent,
              ),
              const SizedBox(height: 16),
              _AssignmentCard(
                title: 'Abilitazioni utente',
                accent: accent,
                emptyText:
                    'Nessuna abilitazione associata a questo elicottero.',
                groups: [
                  _AssignmentGroup(
                    label: 'Licenze',
                    values: userLicenses
                        .map((item) => item.licenseName)
                        .toList(),
                  ),
                  _AssignmentGroup(
                    label: 'Privilegi',
                    values: userPrivileges
                        .map((item) => item.privilegeName)
                        .toList(),
                  ),
                  _AssignmentGroup(
                    label: 'Equipaggi',
                    values: crews
                        .map(
                          (item) => item.crewType == 'TOB'
                              ? 'TOB fascia ${item.fascia ?? '-'}'
                              : 'T',
                        )
                        .toList(),
                  ),
                  _AssignmentGroup(
                    label: 'Capacità TOB',
                    values: tobCaps.map((item) => item.capabilityName).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _AssignmentCard(
                title: 'Stato operativo sintetico',
                accent: accent,
                emptyText: 'Nessun dato operativo disponibile.',
                groups: [
                  if (userLicenses.isNotEmpty || userPrivileges.isNotEmpty)
                    _AssignmentGroup(
                      label: 'Currency manutenzione',
                      values: [
                        auth.currency['maintenance']?.statusText ?? 'N/D',
                      ],
                    ),
                  if (crews.any((item) => item.crewType == 'T'))
                    _AssignmentGroup(
                      label: 'Currency T',
                      values: [auth.currency['flight_t']?.statusText ?? 'N/D'],
                    ),
                  if (crews.any((item) => item.crewType == 'TOB'))
                    _AssignmentGroup(
                      label: 'Currency TOB base',
                      values: [auth.currency['tob_base']?.statusText ?? 'N/D'],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.helicopter,
    required this.imageAsset,
    required this.accent,
  });

  final HelicopterType helicopter;
  final String? imageAsset;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.hardEdge,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent.withValues(alpha: 0.14), AppColors.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (imageAsset != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.12),
                  padding: const EdgeInsets.all(14),
                  child: Image.asset(imageAsset!, fit: BoxFit.contain),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                helicopter.name,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
                softWrap: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentGroup {
  const _AssignmentGroup({required this.label, required this.values});

  final String label;
  final List<String> values;
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.title,
    required this.accent,
    required this.emptyText,
    required this.groups,
  });

  final String title;
  final Color accent;
  final String emptyText;
  final List<_AssignmentGroup> groups;

  @override
  Widget build(BuildContext context) {
    final visibleGroups = groups
        .where((group) => group.values.isNotEmpty)
        .toList();
    return Card(
      clipBehavior: Clip.hardEdge,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (visibleGroups.isEmpty)
              Text(emptyText, textAlign: TextAlign.center)
            else
              ...visibleGroups.map(
                (group) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.label,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: accent),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final value in group.values)
                            Chip(label: Text(value)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
