import 'package:flutter/material.dart';

import '../models/reference_models.dart';

class PrivilegeSelectionResult {
  const PrivilegeSelectionResult({
    required this.helicopterTypeId,
    required this.selectedPrivilegeTypeIds,
  });

  final int helicopterTypeId;
  final Set<int> selectedPrivilegeTypeIds;
}

Future<PrivilegeSelectionResult?> showPrivilegeSelectionDialog({
  required BuildContext context,
  required List<HelicopterType> helicopterTypes,
  required List<PrivilegeType> privilegeTypes,
  required Map<int, Set<int>> selectionsByHelicopter,
  int? initialHelicopterTypeId,
  String title = 'Gestisci privilegi',
}) async {
  if (helicopterTypes.isEmpty) {
    return null;
  }

  final initialId =
      initialHelicopterTypeId ??
      (selectionsByHelicopter.isNotEmpty
          ? selectionsByHelicopter.keys.first
          : helicopterTypes.first.id);

  return showDialog<PrivilegeSelectionResult>(
    context: context,
    builder: (dialogContext) {
      var helicopterId = initialId;
      final draftSelections = {
        for (final helicopter in helicopterTypes)
          helicopter.id: <int>{
            ...selectionsByHelicopter[helicopter.id] ?? const <int>{},
          },
      };

      return StatefulBuilder(
        builder: (context, setDialogState) {
          final selectedIds = draftSelections[helicopterId] ?? <int>{};
          return AlertDialog(
            title: Text(title, textAlign: TextAlign.center),
            content: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: helicopterId,
                      decoration: const InputDecoration(
                        labelText: 'Elicottero',
                      ),
                      items: helicopterTypes
                          .map(
                            (item) => DropdownMenuItem<int>(
                              value: item.id,
                              child: Text(
                                item.name,
                                softWrap: true,
                                overflow: TextOverflow.visible,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() => helicopterId = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: ListView(
                          shrinkWrap: true,
                          children: privilegeTypes
                              .map(
                                (privilege) => CheckboxListTile(
                                  value: selectedIds.contains(privilege.id),
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    '${privilege.code} — ${privilege.name}',
                                    softWrap: true,
                                  ),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  onChanged: (checked) {
                                    setDialogState(() {
                                      if (checked ?? false) {
                                        selectedIds.add(privilege.id);
                                      } else {
                                        selectedIds.remove(privilege.id);
                                      }
                                    });
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(
                    PrivilegeSelectionResult(
                      helicopterTypeId: helicopterId,
                      selectedPrivilegeTypeIds: {...selectedIds},
                    ),
                  );
                },
                child: const Text('Salva'),
              ),
            ],
          );
        },
      );
    },
  );
}
