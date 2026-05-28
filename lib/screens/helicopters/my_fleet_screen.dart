import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../constants/app_constants.dart';
import '../../data/helicopter_catalog.dart';
import '../../models/reference_models.dart';

class MyFleetScreen extends ConsumerWidget {
  const MyFleetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final helicopterIds = <int>{
      ...auth.licenses.map((item) => item.helicopterTypeId),
      ...auth.privileges.map((item) => item.helicopterTypeId),
      ...auth.crewAssignments.map((item) => item.helicopterTypeId),
      ...auth.tobCapabilities.map((item) => item.helicopterTypeId),
    };
    final assignedHelicopters = auth.helicopterTypes
        .where((item) => helicopterIds.contains(item.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).maybePop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: const Text('La Mia Flotta'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            shrinkWrap: false,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Flotta assegnata',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Apri una scheda per consultare foto, specifiche e abilitazioni associate al tuo profilo.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (assignedHelicopters.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Nessun elicottero associato al tuo profilo.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 960
                        ? 3
                        : constraints.maxWidth >= 640
                        ? 2
                        : 1;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: assignedHelicopters.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisExtent: 420,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemBuilder: (context, index) {
                        final helicopter = assignedHelicopters[index];
                        return _FleetHelicopterCard(
                          helicopter: helicopter,
                          licenseCount: auth.licenses
                              .where(
                                (item) =>
                                    item.helicopterTypeId == helicopter.id,
                              )
                              .length,
                          privilegeCount: auth.privileges
                              .where(
                                (item) =>
                                    item.helicopterTypeId == helicopter.id,
                              )
                              .length,
                          crewCount: auth.crewAssignments
                              .where(
                                (item) =>
                                    item.helicopterTypeId == helicopter.id,
                              )
                              .length,
                          onTap: () =>
                              context.go('/helicopters/${helicopter.id}'),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FleetHelicopterCard extends StatelessWidget {
  const _FleetHelicopterCard({
    required this.helicopter,
    required this.licenseCount,
    required this.privilegeCount,
    required this.crewCount,
    required this.onTap,
  });

  final HelicopterType helicopter;
  final int licenseCount;
  final int privilegeCount;
  final int crewCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final catalog = catalogForHelicopter(helicopter);
    final accent = catalogAccent(helicopter.code);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Card(
        clipBehavior: Clip.hardEdge,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent.withValues(alpha: 0.12), AppColors.surface],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (catalog.imageAsset != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.12),
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                        catalog.imageAsset!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        helicopter.name,
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                        softWrap: true,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        catalog.subtitle,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: accent),
                        textAlign: TextAlign.center,
                        softWrap: true,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: Text(
                              '$licenseCount licenze',
                              softWrap: true,
                            ),
                          ),
                          Chip(
                            label: Text(
                              '$privilegeCount privilegi',
                              softWrap: true,
                            ),
                          ),
                          Chip(
                            label: Text(
                              '$crewCount ruoli equipaggio',
                              softWrap: true,
                            ),
                          ),
                        ],
                      ),
                    ],
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
