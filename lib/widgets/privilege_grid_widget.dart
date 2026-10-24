import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../models/user_models.dart';

class PrivilegeGridWidget extends StatelessWidget {
  const PrivilegeGridWidget({
    super.key,
    required this.privileges,
    this.compact = false,
  });

  final List<UserPrivilege> privileges;

  /// Pillole affiancate invece della griglia a righe alte.
  final bool compact;

  static String _label(UserPrivilege privilege) =>
      privilege.privilegeCode.isEmpty
      ? privilege.privilegeName
      : '${privilege.privilegeCode} · ${privilege.privilegeName}';

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
      crossAxisAlignment: compact
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      children: groups.map((entry) {
        final items = [...entry.value]
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        return Padding(
          padding: EdgeInsets.only(bottom: compact ? 8 : 16),
          child: Card(
            margin: compact ? EdgeInsets.zero : null,
            child: Padding(
              padding: EdgeInsets.all(compact ? 12 : 16),
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
                  SizedBox(height: compact ? 8 : 12),
                  if (compact)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final privilege in items)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.verified,
                                  color: AppColors.secondary,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _label(privilege),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    )
                  else
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
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisExtent: 64,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemBuilder: (context, index) {
                            final privilege = items[index];
                            final label = _label(privilege);
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
