import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../models/user_models.dart';

class PrivilegeGridWidget extends StatelessWidget {
  const PrivilegeGridWidget({super.key, required this.privileges});

  final List<UserPrivilege> privileges;

  @override
  Widget build(BuildContext context) {
    if (privileges.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Nessun privilegio assegnato.'),
        ),
      );
    }

    final grouped = <String, List<UserPrivilege>>{};
    for (final privilege in privileges) {
      final key = privilege.helicopterCode.isEmpty
          ? privilege.helicopterName
          : privilege.helicopterCode;
      grouped.putIfAbsent(key, () => <UserPrivilege>[]).add(privilege);
    }

    final groups = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups.map((entry) {
        final items = [...entry.value]
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth > 800
                          ? 3
                          : constraints.maxWidth > 520
                          ? 2
                          : 1;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisExtent: 64,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemBuilder: (context, index) {
                          final privilege = items[index];
                          final label = privilege.privilegeCode.isEmpty
                              ? privilege.privilegeName
                              : '${privilege.privilegeCode} · ${privilege.privilegeName}';
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.verified,
                                  color: AppColors.secondary,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
      }).toList(),
    );
  }
}
