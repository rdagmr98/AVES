import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../app.dart';
import '../../constants/app_constants.dart';
import '../../models/reference_models.dart';
import '../../models/user_models.dart';
import '../../services/user_service.dart';
import '../../widgets/privilege_selection_dialog.dart';
import '../../widgets/user_avatar.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _userService = UserService();
  final _imagePicker = ImagePicker();
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _cognomeCtrl;
  late final TextEditingController _licenzaCtrl;
  late final TextEditingController _emailCtrl;
  int? _orgUnitId;
  bool _saving = false;
  String? _emailError;
  String? _profilePhotoBase64;
  AccountDeletionRequest? _pendingDeletionRequest;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(authProvider).userProfile;
    _nomeCtrl = TextEditingController(text: profile?.nome ?? '');
    _cognomeCtrl = TextEditingController(text: profile?.cognome ?? '');
    _licenzaCtrl = TextEditingController(text: profile?.numeroLicenza ?? '');
    _emailCtrl = TextEditingController(text: profile?.email ?? '');
    _profilePhotoBase64 = profile?.profilePhotoBase64;
    _orgUnitId = profile?.orgUnitId;
    _loadDeletionRequest();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _cognomeCtrl.dispose();
    _licenzaCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  String? _validateInstitutionalEmail(String? value) {
    final email = value?.trim().toLowerCase() ?? '';
    if (email.isEmpty) {
      return 'Campo obbligatorio';
    }
    if (!email.endsWith('@esercito.difesa.it')) {
      return 'Usa un indirizzo @esercito.difesa.it';
    }
    return null;
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

    if (!profile.isAdmin) {
      final emailError = _validateInstitutionalEmail(_emailCtrl.text);
      if (emailError != null) {
        setState(() => _emailError = emailError);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(emailError)));
        return;
      }
    }

    setState(() => _emailError = null);
    await _runMutation(
      () => auth.updateProfile(
        profile.copyWith(
          nome: _nomeCtrl.text.trim(),
          cognome: _cognomeCtrl.text.trim(),
          email: profile.isAdmin
              ? profile.email
              : _emailCtrl.text.trim().toLowerCase(),
          profilePhotoBase64: _profilePhotoBase64,
          orgUnitId: _orgUnitId,
        ),
      ),
      successMessage: 'Profilo aggiornato con successo.',
    );
  }

  Future<void> _loadDeletionRequest() async {
    final profile = ref.read(authProvider).userProfile;
    if (profile == null) {
      return;
    }
    final request = await _userService.getPendingDeletionRequestForUser(
      profile.id,
    );
    if (!mounted) {
      return;
    }
    setState(() => _pendingDeletionRequest = request);
  }

  Future<void> _showDeleteAccountRequestDialog() async {
    final profile = ref.read(authProvider).userProfile;
    if (profile == null) {
      return;
    }
    final reasonCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Richiedi eliminazione account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'La richiesta verrà inviata agli admin. L\'account sarà eliminato solo dopo approvazione.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Motivo (opzionale)',
              ),
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
              await _runMutation(
                () => _userService.requestAccountDeletion(
                  profile.id,
                  reason: reasonCtrl.text.trim(),
                ),
                successMessage: 'Richiesta di eliminazione inviata agli admin.',
              );
              await _loadDeletionRequest();
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Invia richiesta'),
          ),
        ],
      ),
    );
    reasonCtrl.dispose();
  }

  Future<void> _showChangePasswordDialog() async {
    final currentPasswordCtrl = TextEditingController();
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
              controller: currentPasswordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password attuale',
              ),
            ),
            const SizedBox(height: 12),
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
              if (currentPasswordCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Inserisci la password attuale.'),
                  ),
                );
                return;
              }
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
                await ref
                    .read(authProvider)
                    .changePassword(
                      currentPasswordCtrl.text,
                      newPasswordCtrl.text,
                    );
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

    currentPasswordCtrl.dispose();
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

  Map<int, Set<int>> _currentPrivilegeSelections(
    List<UserPrivilege> privileges,
  ) {
    final selections = <int, Set<int>>{};
    for (final item in privileges) {
      selections
          .putIfAbsent(item.helicopterTypeId, () => <int>{})
          .add(item.privilegeTypeId);
    }
    return selections;
  }

  Future<void> _managePrivileges(
    UserProfile profile,
    List<UserPrivilege> privileges,
    List<HelicopterType> helicopterTypes,
    List<PrivilegeType> privilegeTypes,
  ) async {
    final result = await showPrivilegeSelectionDialog(
      context: context,
      helicopterTypes: helicopterTypes,
      privilegeTypes: privilegeTypes,
      selectionsByHelicopter: _currentPrivilegeSelections(privileges),
      title: 'Seleziona privilegi manutentivi',
    );
    if (result == null) {
      return;
    }

    final updatedPrivileges = privileges
        .where((item) => item.helicopterTypeId != result.helicopterTypeId)
        .map(
          (item) => {
            'helicopter_type_id': item.helicopterTypeId,
            'privilege_type_id': item.privilegeTypeId,
          },
        )
        .toList();
    for (final privilegeTypeId in result.selectedPrivilegeTypeIds) {
      updatedPrivileges.add({
        'helicopter_type_id': result.helicopterTypeId,
        'privilege_type_id': privilegeTypeId,
      });
    }

    await _runMutation(
      () => _userService.setUserPrivileges(profile.id, updatedPrivileges),
      successMessage: 'Privilegi aggiornati.',
    );
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final file = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (file == null) {
        return;
      }
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw Exception('Immagine non valida');
      }
      final resized = decoded.width > 200 || decoded.height > 200
          ? img.copyResize(
              decoded,
              width: decoded.width >= decoded.height ? 200 : null,
              height: decoded.height > decoded.width ? 200 : null,
              interpolation: img.Interpolation.average,
            )
          : decoded;
      final jpgBytes = img.encodeJpg(resized, quality: 30);
      if (!mounted) {
        return;
      }
      setState(() => _profilePhotoBase64 = base64Encode(jpgBytes));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Errore foto profilo: $e')));
    }
  }

  Future<Map<String, dynamic>?> _showCrewDialog(
    List<HelicopterType> helicopterTypes,
    List<TobCapability> tobCapabilities,
  ) async {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        int? helicopterId;
        String crewType = 'T';
        String fascia = 'A';
        final selectedCapabilityIds = <int>{};
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Aggiungi equipaggio'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => helicopterId = value),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tipo equipaggio',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['T', 'TOB', 'MDB']
                          .map(
                            (value) => ChoiceChip(
                              label: Text(value),
                              selected: crewType == value,
                              onSelected: (_) => setDialogState(() {
                                crewType = value;
                                if (crewType != 'TOB') {
                                  selectedCapabilityIds.clear();
                                }
                              }),
                            ),
                          )
                          .toList(),
                    ),
                    if (crewType == 'TOB') ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: fascia,
                        decoration: const InputDecoration(
                          labelText: 'Fascia TOB',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'A', child: Text('A')),
                          DropdownMenuItem(value: 'B', child: Text('B')),
                          DropdownMenuItem(value: 'C', child: Text('C')),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => fascia = value ?? 'A'),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Capacità TOB',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      ...tobCapabilities.map(
                        (item) => CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: selectedCapabilityIds.contains(item.id),
                          title: Text(item.name, softWrap: true),
                          onChanged: (_) => setDialogState(() {
                            if (selectedCapabilityIds.contains(item.id)) {
                              selectedCapabilityIds.remove(item.id);
                            } else {
                              selectedCapabilityIds.add(item.id);
                            }
                          }),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      Text(
                        crewType == 'MDB'
                            ? 'MDB richiede solo la selezione dell\'elicottero.'
                            : 'T richiede solo la selezione dell\'elicottero.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
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
                  if (helicopterId == null) {
                    return;
                  }
                  Navigator.of(dialogContext).pop({
                    'helicopterTypeId': helicopterId,
                    'crewType': crewType,
                    'fascia': crewType == 'TOB' ? fascia : null,
                    'capabilityIds': selectedCapabilityIds.toList(),
                  });
                },
                child: const Text('Conferma'),
              ),
            ],
          ),
        );
      },
    );
  }

  Map<int, Set<int>> _currentTobSelections(
    List<UserTobCapability> capabilities,
  ) {
    final selections = <int, Set<int>>{};
    for (final item in capabilities) {
      selections
          .putIfAbsent(item.helicopterTypeId, () => <int>{})
          .add(item.tobCapabilityId);
    }
    return selections;
  }

  Future<_HelicopterCapabilitySelection?> _showTobCapabilityDialog(
    List<HelicopterType> helicopterTypes,
    List<TobCapability> tobCapabilities,
    Map<int, Set<int>> selectionsByHelicopter,
  ) async {
    return showDialog<_HelicopterCapabilitySelection>(
      context: context,
      builder: (dialogContext) {
        final initialHelicopterId = helicopterTypes.isNotEmpty
            ? helicopterTypes.first.id
            : null;
        int? helicopterId = initialHelicopterId;
        final workingSelections = {
          for (final item in helicopterTypes)
            item.id: {...(selectionsByHelicopter[item.id] ?? <int>{})},
        };
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedIds = helicopterId == null
                ? <int>{}
                : workingSelections.putIfAbsent(helicopterId!, () => <int>{});
            return AlertDialog(
              title: const Text('Gestisci capacità TOB'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: helicopterId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Elicottero',
                        ),
                        items: helicopterTypes
                            .map(
                              (item) => DropdownMenuItem<int>(
                                value: item.id,
                                child: Text(item.name, softWrap: true),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setDialogState(() => helicopterId = value),
                      ),
                      const SizedBox(height: 16),
                      ...tobCapabilities.map(
                        (item) => CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: selectedIds.contains(item.id),
                          title: Text(item.name, softWrap: true),
                          onChanged: helicopterId == null
                              ? null
                              : (_) => setDialogState(() {
                                  if (selectedIds.contains(item.id)) {
                                    selectedIds.remove(item.id);
                                  } else {
                                    selectedIds.add(item.id);
                                  }
                                }),
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
                  onPressed: helicopterId == null
                      ? null
                      : () => Navigator.of(dialogContext).pop(
                          _HelicopterCapabilitySelection(
                            helicopterTypeId: helicopterId!,
                            selectedCapabilityIds: selectedIds.toSet(),
                          ),
                        ),
                  child: const Text('Salva'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _manageTobCapabilities(
    UserProfile profile,
    List<UserTobCapability> capabilities,
    List<HelicopterType> helicopterTypes,
    List<TobCapability> tobCapabilities,
  ) async {
    final currentSelections = _currentTobSelections(capabilities);
    final result = await _showTobCapabilityDialog(
      helicopterTypes,
      tobCapabilities,
      currentSelections,
    );
    if (result == null) {
      return;
    }

    final updatedCapabilities = capabilities
        .where((item) => item.helicopterTypeId != result.helicopterTypeId)
        .map(
          (item) => {
            'helicopter_type_id': item.helicopterTypeId,
            'tob_capability_id': item.tobCapabilityId,
          },
        )
        .toList();
    for (final capabilityId in result.selectedCapabilityIds) {
      updatedCapabilities.add({
        'helicopter_type_id': result.helicopterTypeId,
        'tob_capability_id': capabilityId,
      });
    }

    await _runMutation(
      () =>
          _userService.setUserTobCapabilities(profile.id, updatedCapabilities),
      successMessage: 'Capacità TOB aggiornate.',
    );
  }

  Future<void> _removeCrewAssignment(
    UserProfile profile,
    UserCrewAssignment assignment,
    List<UserCrewAssignment> assignments,
    List<UserTobCapability> capabilities,
  ) async {
    await _runMutation(
      () async {
        if (assignment.id == null || assignment.crewType != 'TOB') {
          if (assignment.id != null) {
            await _userService.deleteUserCrewAssignment(assignment.id!);
          }
          return;
        }

        final updatedAssignments = assignments
            .where((item) => item.id != assignment.id)
            .map(
              (item) => {
                'helicopter_type_id': item.helicopterTypeId,
                'crew_type': item.crewType,
                'tob_grade': item.crewType == 'TOB' ? item.fascia : null,
              },
            )
            .toList();
        final updatedCapabilities = capabilities
            .where((item) => item.helicopterTypeId != assignment.helicopterTypeId)
            .map(
              (item) => {
                'helicopter_type_id': item.helicopterTypeId,
                'tob_capability_id': item.tobCapabilityId,
              },
            )
            .toList();

        await _userService.setUserCrewAssignments(profile.id, updatedAssignments);
        await _userService.setUserTobCapabilities(profile.id, updatedCapabilities);
      },
      successMessage: 'Equipaggio rimosso.',
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
    if (_emailCtrl.text != (profile.email ?? '')) {
      _emailCtrl.text = profile.email ?? '';
    }
    _profilePhotoBase64 ??= profile.profilePhotoBase64;
    _orgUnitId ??= profile.orgUnitId;
    final isAdminProfile = profile.isAdmin;

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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            shrinkWrap: false,
            padding: const EdgeInsets.all(24),
            children: [
              if (_saving || auth.isLoading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(
                  'Salvataggio...',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
              if (!isAdminProfile && _pendingDeletionRequest != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.hourglass_top, color: Colors.amber),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Richiesta di eliminazione account in attesa di approvazione admin.',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _saving ? null : _pickProfilePhoto,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            UserAvatar(
                              user: profile.copyWith(
                                profilePhotoBase64: _profilePhotoBase64,
                              ),
                              radius: 44,
                            ),
                            const CircleAvatar(
                              radius: 14,
                              child: Icon(
                                Icons.photo_camera_outlined,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tocca l\'avatar per aggiornare la foto profilo.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Dati anagrafici',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nomeCtrl,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(labelText: 'Nome'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _cognomeCtrl,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(labelText: 'Cognome'),
                      ),
                      if (!isAdminProfile) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _licenzaCtrl,
                          readOnly: true,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            labelText: 'Numero licenza',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            labelText: 'Email istituzionale',
                            hintText: 'nome.cognome@esercito.difesa.it',
                            errorText: _emailError,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      DropdownButtonFormField<int>(
                        initialValue: _orgUnitId,
                        alignment: Alignment.center,
                        decoration: const InputDecoration(
                          labelText: 'Unità organizzativa',
                        ),
                        items: auth.orgUnits
                            .map(
                              (item) => DropdownMenuItem<int>(
                                value: item.id,
                                child: Text(
                                  item.name,
                                  textAlign: TextAlign.center,
                                  softWrap: true,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _orgUnitId = value),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _showChangePasswordDialog,
                        icon: const Icon(Icons.lock_reset_outlined),
                        label: const Text('Cambia password'),
                      ),
                      if (profile.isTi || profile.isEtp) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (profile.isTi)
                              Chip(
                                label: const Text(
                                  'TI – Istruttore Tecnico-Aeronautico',
                                ),
                                backgroundColor: Colors.blue.shade700,
                              ),
                            if (profile.isEtp)
                              Chip(
                                label: const Text(
                                  'ETP – Esaminatore Teorico-Pratico',
                                ),
                                backgroundColor: Colors.purple.shade700,
                              ),
                          ],
                        ),
                      ],
                      if (isAdminProfile) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Profilo amministrativo: i campi personali, le assegnazioni e le capacità operative non sono richiesti per gli admin.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                          softWrap: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (!isAdminProfile) ...[
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
                                  title: Text(
                                    '${item.helicopterCode} · ${item.licenseName}',
                                    softWrap: true,
                                  ),
                                  trailing: IconButton(
                                    onPressed: item.id == null
                                        ? null
                                        : () => _runMutation(
                                            () => _userService
                                                .deleteUserLicense(item.id!),
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
                  addLabel: 'Gestisci',
                  onAdd: () => _managePrivileges(
                    profile,
                    auth.privileges,
                    auth.helicopterTypes,
                    auth.privilegeTypes,
                  ),
                  child: auth.privileges.isEmpty
                      ? const Text(
                          'Nessun privilegio assegnato.',
                          textAlign: TextAlign.center,
                        )
                      : Column(
                          children: auth.privileges
                              .map(
                                (item) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    '${item.helicopterCode} · ${item.privilegeName}',
                                    textAlign: TextAlign.center,
                                    softWrap: true,
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
                    final result = await _showCrewDialog(
                      auth.helicopterTypes,
                      auth.tobCapabilityTypes,
                    );
                    if (result == null) {
                      return;
                    }
                    await _runMutation(
                      () async {
                        await _userService.addUserCrewAssignment(
                          UserCrewAssignment(
                            userId: profile.id,
                            helicopterTypeId: result['helicopterTypeId'] as int,
                            crewType: result['crewType'] as String,
                            fascia: result['fascia'] as String?,
                          ),
                        );
                        if (result['crewType'] == 'TOB') {
                          final updatedCapabilities = auth.tobCapabilities
                              .where(
                                (item) =>
                                    item.helicopterTypeId !=
                                    result['helicopterTypeId'],
                              )
                              .map(
                                (item) => {
                                  'helicopter_type_id': item.helicopterTypeId,
                                  'tob_capability_id': item.tobCapabilityId,
                                },
                              )
                              .toList();
                          for (final capabilityId
                              in (result['capabilityIds'] as List<dynamic>)) {
                            updatedCapabilities.add({
                              'helicopter_type_id': result['helicopterTypeId'],
                              'tob_capability_id': capabilityId as int,
                            });
                          }
                          await _userService.setUserTobCapabilities(
                            profile.id,
                            updatedCapabilities,
                          );
                        }
                      },
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
                                  title: Text(
                                    '${item.helicopterCode} · ${item.crewType}',
                                    softWrap: true,
                                  ),
                                  subtitle: item.crewType == 'TOB'
                                      ? Text(
                                          'Fascia ${item.fascia ?? '-'}',
                                          softWrap: true,
                                        )
                                      : null,
                                  trailing: IconButton(
                                    onPressed: item.id == null
                                        ? null
                                        : () => _removeCrewAssignment(
                                            profile,
                                            item,
                                            auth.crewAssignments,
                                            auth.tobCapabilities,
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
                  addLabel: 'Gestisci',
                  onAdd: () => _manageTobCapabilities(
                    profile,
                    auth.tobCapabilities,
                    auth.helicopterTypes,
                    auth.tobCapabilityTypes,
                  ),
                  child: auth.tobCapabilities.isEmpty
                      ? const Text('Nessuna capacità TOB assegnata.')
                      : Column(
                          children: auth.tobCapabilities
                              .map(
                                (item) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    '${item.helicopterCode} · ${item.capabilityName}',
                                    softWrap: true,
                                  ),
                                  trailing: IconButton(
                                    onPressed: item.id == null
                                        ? null
                                        : () => _runMutation(
                                            () => _userService
                                                .deleteUserTobCapability(
                                                  item.id!,
                                                ),
                                            successMessage:
                                                'Capacità TOB rimossa.',
                                          ),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gestione account',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Puoi richiedere l\'eliminazione del tuo account. La cancellazione sarà eseguita solo dopo approvazione di un admin.',
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _pendingDeletionRequest != null
                              ? null
                              : _showDeleteAccountRequestDialog,
                          icon: const Icon(Icons.delete_forever_outlined),
                          label: Text(
                            _pendingDeletionRequest != null
                                ? 'Richiesta già inviata'
                                : 'Richiedi eliminazione account',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HelicopterCapabilitySelection {
  const _HelicopterCapabilitySelection({
    required this.helicopterTypeId,
    required this.selectedCapabilityIds,
  });

  final int helicopterTypeId;
  final Set<int> selectedCapabilityIds;
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
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
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
