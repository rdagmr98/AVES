import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../models/reference_models.dart';
import '../../models/user_models.dart';
import '../../services/user_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _userService = UserService();
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _cognomeCtrl;
  late final TextEditingController _licenzaCtrl;
  int? _orgUnitId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(authProvider).userProfile;
    _nomeCtrl = TextEditingController(text: profile?.nome ?? '');
    _cognomeCtrl = TextEditingController(text: profile?.cognome ?? '');
    _licenzaCtrl = TextEditingController(text: profile?.numeroLicenza ?? '');
    _orgUnitId = profile?.orgUnitId;
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _cognomeCtrl.dispose();
    _licenzaCtrl.dispose();
    super.dispose();
  }

  Future<void> _runMutation(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    setState(() => _saving = true);
    try {
      await action();
      await ref.read(authProvider).refreshUserData();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    final auth = ref.read(authProvider);
    final profile = auth.userProfile;
    if (profile == null) {
      return;
    }

    await _runMutation(
      () => auth.updateProfile(
        profile.copyWith(
          nome: _nomeCtrl.text.trim(),
          cognome: _cognomeCtrl.text.trim(),
          orgUnitId: _orgUnitId,
        ),
      ),
      successMessage: 'Profilo aggiornato con successo.',
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cambia password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: newPasswordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nuova password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPasswordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Conferma password'),
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
              if (newPasswordCtrl.text.length < 6 ||
                  newPasswordCtrl.text != confirmPasswordCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Verifica la nuova password inserita.'),
                  ),
                );
                return;
              }
              try {
                await ref.read(authProvider).changePassword(newPasswordCtrl.text);
                if (!mounted || !dialogContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password aggiornata.')),
                );
              } catch (e) {
                if (!mounted) {
                  return;
                }
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );

    newPasswordCtrl.dispose();
    confirmPasswordCtrl.dispose();
  }

  Future<Map<String, int>?> _showLicenseDialog(
    List<HelicopterType> helicopterTypes,
    List<LicenseType> licenseTypes,
  ) async {
    return showDialog<Map<String, int>>(
      context: context,
      builder: (dialogContext) {
        int? helicopterId;
        int? licenseTypeId;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Aggiungi licenza'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: helicopterId,
                  decoration: const InputDecoration(labelText: 'Elicottero'),
                  items: helicopterTypes
                      .map(
                        (item) => DropdownMenuItem<int>(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => helicopterId = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: licenseTypeId,
                  decoration: const InputDecoration(labelText: 'Tipo licenza'),
                  items: licenseTypes
                      .map(
                        (item) => DropdownMenuItem<int>(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => licenseTypeId = value),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (helicopterId == null || licenseTypeId == null) {
                    return;
                  }
                  Navigator.of(dialogContext).pop({
                    'helicopterTypeId': helicopterId!,
                    'licenseTypeId': licenseTypeId!,
                  });
                },
                child: const Text('Aggiungi'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, int>?> _showPrivilegeDialog(
    List<HelicopterType> helicopterTypes,
    List<PrivilegeType> privilegeTypes,
  ) async {
    return showDialog<Map<String, int>>(
      context: context,
      builder: (dialogContext) {
        int? helicopterId;
        int? privilegeTypeId;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Aggiungi privilegio'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: helicopterId,
                  decoration: const InputDecoration(labelText: 'Elicottero'),
                  items: helicopterTypes
                      .map(
                        (item) => DropdownMenuItem<int>(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => helicopterId = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: privilegeTypeId,
                  decoration: const InputDecoration(labelText: 'Privilegio'),
                  items: privilegeTypes
                      .map(
                        (item) => DropdownMenuItem<int>(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => privilegeTypeId = value),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (helicopterId == null || privilegeTypeId == null) {
                    return;
                  }
                  Navigator.of(dialogContext).pop({
                    'helicopterTypeId': helicopterId!,
                    'privilegeTypeId': privilegeTypeId!,
                  });
                },
                child: const Text('Aggiungi'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _showCrewDialog(
    List<HelicopterType> helicopterTypes,
  ) async {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        int? helicopterId;
        String crewType = 'T';
        String fascia = 'A';
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Aggiungi equipaggio'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: helicopterId,
                  decoration: const InputDecoration(labelText: 'Elicottero'),
                  items: helicopterTypes
                      .map(
                        (item) => DropdownMenuItem<int>(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => helicopterId = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: crewType,
                  decoration: const InputDecoration(labelText: 'Tipo equipaggio'),
                  items: const [
                    DropdownMenuItem(value: 'T', child: Text('T')),
                    DropdownMenuItem(value: 'TOB', child: Text('TOB')),
                  ],
                  onChanged: (value) => setDialogState(() {
                    crewType = value ?? 'T';
                  }),
                ),
                if (crewType == 'TOB') ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: fascia,
                    decoration: const InputDecoration(labelText: 'Fascia TOB'),
                    items: const [
                      DropdownMenuItem(value: 'A', child: Text('A')),
                      DropdownMenuItem(value: 'B', child: Text('B')),
                      DropdownMenuItem(value: 'C', child: Text('C')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => fascia = value ?? 'A'),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (helicopterId == null) {
                    return;
                  }
                  Navigator.of(dialogContext).pop({
                    'helicopterTypeId': helicopterId,
                    'crewType': crewType,
                    'fascia': crewType == 'TOB' ? fascia : null,
                  });
                },
                child: const Text('Aggiungi'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, int>?> _showTobCapabilityDialog(
    List<HelicopterType> helicopterTypes,
    List<TobCapability> tobCapabilities,
  ) async {
    return showDialog<Map<String, int>>(
      context: context,
      builder: (dialogContext) {
        int? helicopterId;
        int? capabilityId;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Aggiungi capacità TOB'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: helicopterId,
                  decoration: const InputDecoration(labelText: 'Elicottero'),
                  items: helicopterTypes
                      .map(
                        (item) => DropdownMenuItem<int>(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => helicopterId = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: capabilityId,
                  decoration: const InputDecoration(labelText: 'Capacità TOB'),
                  items: tobCapabilities
                      .map(
                        (item) => DropdownMenuItem<int>(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => capabilityId = value),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (helicopterId == null || capabilityId == null) {
                    return;
                  }
                  Navigator.of(dialogContext).pop({
                    'helicopterTypeId': helicopterId!,
                    'capabilityId': capabilityId!,
                  });
                },
                child: const Text('Aggiungi'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final profile = auth.userProfile;
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_nomeCtrl.text != profile.nome) {
      _nomeCtrl.text = profile.nome;
    }
    if (_cognomeCtrl.text != profile.cognome) {
      _cognomeCtrl.text = profile.cognome;
    }
    if (_licenzaCtrl.text != (profile.numeroLicenza ?? '')) {
      _licenzaCtrl.text = profile.numeroLicenza ?? '';
    }
    _orgUnitId ??= profile.orgUnitId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilo'),
        actions: [
          IconButton(
            onPressed: _saving ? null : _saveProfile,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_saving || auth.isLoading) const LinearProgressIndicator(),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dati anagrafici',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nomeCtrl,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _cognomeCtrl,
                    decoration: const InputDecoration(labelText: 'Cognome'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _licenzaCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Numero licenza',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: _orgUnitId,
                    decoration: const InputDecoration(
                      labelText: 'Unità organizzativa',
                    ),
                    items: auth.orgUnits
                        .map(
                          (item) => DropdownMenuItem<int>(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _orgUnitId = value),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _showChangePasswordDialog,
                      icon: const Icon(Icons.lock_reset_outlined),
                      label: const Text('Cambia password'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _EditableSection(
            title: 'Licenze',
            addLabel: 'Aggiungi',
            onAdd: () async {
              final result = await _showLicenseDialog(
                auth.helicopterTypes,
                auth.licenseTypes,
              );
              if (result == null) {
                return;
              }
              await _runMutation(
                () => _userService.addUserLicense(
                  UserLicense(
                    userId: profile.id,
                    helicopterTypeId: result['helicopterTypeId']!,
                    licenseTypeId: result['licenseTypeId']!,
                  ),
                ),
                successMessage: 'Licenza aggiunta.',
              );
            },
            child: auth.licenses.isEmpty
                ? const Text('Nessuna licenza assegnata.')
                : Column(
                    children: auth.licenses
                        .map(
                          (item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${item.helicopterCode} · ${item.licenseName}'),
                            trailing: IconButton(
                              onPressed: item.id == null
                                  ? null
                                  : () => _runMutation(
                                        () => _userService.deleteUserLicense(
                                          item.id!,
                                        ),
                                        successMessage: 'Licenza rimossa.',
                                      ),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 16),
          _EditableSection(
            title: 'Privilegi manutentivi',
            addLabel: 'Aggiungi',
            onAdd: () async {
              final result = await _showPrivilegeDialog(
                auth.helicopterTypes,
                auth.privilegeTypes,
              );
              if (result == null) {
                return;
              }
              await _runMutation(
                () => _userService.addUserPrivilege(
                  UserPrivilege(
                    userId: profile.id,
                    helicopterTypeId: result['helicopterTypeId']!,
                    privilegeTypeId: result['privilegeTypeId']!,
                  ),
                ),
                successMessage: 'Privilegio aggiunto.',
              );
            },
            child: auth.privileges.isEmpty
                ? const Text('Nessun privilegio assegnato.')
                : Column(
                    children: auth.privileges
                        .map(
                          (item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${item.helicopterCode} · ${item.privilegeName}'),
                            trailing: IconButton(
                              onPressed: item.id == null
                                  ? null
                                  : () => _runMutation(
                                        () => _userService.deleteUserPrivilege(
                                          item.id!,
                                        ),
                                        successMessage: 'Privilegio rimosso.',
                                      ),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 16),
          _EditableSection(
            title: 'Equipaggi di volo',
            addLabel: 'Aggiungi',
            onAdd: () async {
              final result = await _showCrewDialog(auth.helicopterTypes);
              if (result == null) {
                return;
              }
              await _runMutation(
                () => _userService.addUserCrewAssignment(
                  UserCrewAssignment(
                    userId: profile.id,
                    helicopterTypeId: result['helicopterTypeId'] as int,
                    crewType: result['crewType'] as String,
                    fascia: result['fascia'] as String?,
                  ),
                ),
                successMessage: 'Equipaggio aggiunto.',
              );
            },
            child: auth.crewAssignments.isEmpty
                ? const Text('Nessun equipaggio assegnato.')
                : Column(
                    children: auth.crewAssignments
                        .map(
                          (item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${item.helicopterCode} · ${item.crewType}'),
                            subtitle: item.crewType == 'TOB'
                                ? Text('Fascia ${item.fascia ?? '-'}')
                                : null,
                            trailing: IconButton(
                              onPressed: item.id == null
                                  ? null
                                  : () => _runMutation(
                                        () => _userService.deleteUserCrewAssignment(
                                          item.id!,
                                        ),
                                        successMessage: 'Equipaggio rimosso.',
                                      ),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 16),
          _EditableSection(
            title: 'Capacità TOB',
            addLabel: 'Aggiungi',
            onAdd: () async {
              final result = await _showTobCapabilityDialog(
                auth.helicopterTypes,
                auth.tobCapabilityTypes,
              );
              if (result == null) {
                return;
              }
              await _runMutation(
                () => _userService.addUserTobCapability(
                  UserTobCapability(
                    userId: profile.id,
                    helicopterTypeId: result['helicopterTypeId']!,
                    tobCapabilityId: result['capabilityId']!,
                  ),
                ),
                successMessage: 'Capacità TOB aggiunta.',
              );
            },
            child: auth.tobCapabilities.isEmpty
                ? const Text('Nessuna capacità TOB assegnata.')
                : Column(
                    children: auth.tobCapabilities
                        .map(
                          (item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${item.helicopterCode} · ${item.capabilityName}'),
                            trailing: IconButton(
                              onPressed: item.id == null
                                  ? null
                                  : () => _runMutation(
                                        () => _userService.deleteUserTobCapability(
                                          item.id!,
                                        ),
                                        successMessage: 'Capacità TOB rimossa.',
                                      ),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EditableSection extends StatelessWidget {
  const _EditableSection({
    required this.title,
    required this.addLabel,
    required this.onAdd,
    required this.child,
  });

  final String title;
  final String addLabel;
  final VoidCallback onAdd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.titleLarge),
                ),
                OutlinedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text(addLabel),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
