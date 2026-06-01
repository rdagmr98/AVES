import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../constants/app_constants.dart';
import '../../models/reference_models.dart';
import '../../models/user_models.dart';
import '../../services/user_service.dart';
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
  bool _isTi = false;
  bool _isEtp = false;
  DateTime? _flightFitnessExpiry;
  String? _lastProfileSyncKey;
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
    _isTi = profile?.isTi ?? false;
    _isEtp = profile?.isEtp ?? false;
    _flightFitnessExpiry = profile?.flightFitnessExpiry;
    _lastProfileSyncKey = _profileSyncKey(profile);
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
          isTi: _isTi,
          isEtp: _isEtp,
          flightFitnessExpiry: _flightFitnessExpiry,
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
              decoration: const InputDecoration(labelText: 'Password attuale'),
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

  String _profileSyncKey(UserProfile? profile) {
    if (profile == null) {
      return 'null';
    }
    return [
      profile.updatedAt.toIso8601String(),
      profile.nome,
      profile.cognome,
      profile.numeroLicenza ?? '',
      profile.email ?? '',
      profile.profilePhotoBase64 ?? '',
      '${profile.orgUnitId ?? ''}',
      '${profile.isTi}',
      '${profile.isEtp}',
      profile.flightFitnessExpiry?.toIso8601String() ?? '',
    ].join('|');
  }

  void _syncProfileState(UserProfile profile) {
    final syncKey = _profileSyncKey(profile);
    if (_lastProfileSyncKey == syncKey) {
      return;
    }
    _nomeCtrl.text = profile.nome;
    _cognomeCtrl.text = profile.cognome;
    _licenzaCtrl.text = profile.numeroLicenza ?? '';
    _emailCtrl.text = profile.email ?? '';
    _profilePhotoBase64 = profile.profilePhotoBase64;
    _orgUnitId = profile.orgUnitId;
    _isTi = profile.isTi;
    _isEtp = profile.isEtp;
    _flightFitnessExpiry = profile.flightFitnessExpiry;
    _lastProfileSyncKey = syncKey;
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Non impostata';
    }
    return DateFormat('dd/MM/yyyy').format(value);
  }

  Future<void> _pickFlightFitnessExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _flightFitnessExpiry ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 20),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _flightFitnessExpiry = picked);
  }

  Future<_MaintenanceEntry?> _showMaintenanceDialog(
    List<HelicopterType> helicopterTypes,
    List<LicenseType> licenseTypes,
    List<PrivilegeType> privilegeTypes, {
    int? initialHelicopterId,
    int? initialLicenseTypeId,
    Set<int> initialPrivilegeTypeIds = const {},
    List<int> excludeHelicopterIds = const [],
  }) async {
    return showDialog<_MaintenanceEntry>(
      context: context,
      builder: (dialogContext) {
        int? helicopterId = initialHelicopterId;
        int? licenseTypeId = initialLicenseTypeId;
        final selectedPrivilegeIds = Set<int>.from(initialPrivilegeTypeIds);
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final editing = initialHelicopterId != null;
            final availableHelicopters = editing
                ? helicopterTypes
                      .where((h) => h.id == initialHelicopterId)
                      .toList()
                : helicopterTypes
                      .where((h) => !excludeHelicopterIds.contains(h.id))
                      .toList();
            return AlertDialog(
              title: Text(
                editing ? 'Modifica manutenzione' : 'Aggiungi manutenzione',
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: helicopterId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Elicottero',
                        ),
                        items: availableHelicopters
                            .map(
                              (item) => DropdownMenuItem<int>(
                                value: item.id,
                                child: Text(item.name),
                              ),
                            )
                            .toList(),
                        onChanged: editing
                            ? null
                            : (value) =>
                                  setDialogState(() => helicopterId = value),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: licenseTypeId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Categoria licenza',
                        ),
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
                      const SizedBox(height: 16),
                      Text(
                        'Privilegi manutentivi',
                        style: Theme.of(ctx).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      ...privilegeTypes.map(
                        (item) => CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: selectedPrivilegeIds.contains(item.id),
                          title: Text(item.name, softWrap: true),
                          onChanged: (_) => setDialogState(() {
                            if (selectedPrivilegeIds.contains(item.id)) {
                              selectedPrivilegeIds.remove(item.id);
                            } else {
                              selectedPrivilegeIds.add(item.id);
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
                  onPressed: helicopterId == null || licenseTypeId == null
                      ? null
                      : () => Navigator.of(dialogContext).pop(
                          _MaintenanceEntry(
                            helicopterTypeId: helicopterId!,
                            licenseTypeId: licenseTypeId!,
                            privilegeTypeIds: selectedPrivilegeIds.toSet(),
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

  Future<void> _applyMaintenanceEntry(
    UserProfile profile,
    _MaintenanceEntry entry,
    List<UserLicense> existingLicenses,
    List<UserPrivilege> existingPrivileges,
  ) async {
    await _runMutation(() async {
      // Handle license: remove old for this helicopter, add new
      final oldLicenses = existingLicenses
          .where((l) => l.helicopterTypeId == entry.helicopterTypeId)
          .toList();
      for (final old in oldLicenses) {
        if (old.id != null) await _userService.deleteUserLicense(old.id!);
      }
      await _userService.addUserLicense(
        UserLicense(
          userId: profile.id,
          helicopterTypeId: entry.helicopterTypeId,
          licenseTypeId: entry.licenseTypeId,
        ),
      );
      // Update privileges: keep other helicopters, replace this helicopter
      final otherPrivileges = existingPrivileges
          .where((p) => p.helicopterTypeId != entry.helicopterTypeId)
          .map(
            (p) => {
              'helicopter_type_id': p.helicopterTypeId,
              'privilege_type_id': p.privilegeTypeId,
            },
          )
          .toList();
      for (final privTypeId in entry.privilegeTypeIds) {
        otherPrivileges.add({
          'helicopter_type_id': entry.helicopterTypeId,
          'privilege_type_id': privTypeId,
        });
      }
      await _userService.setUserPrivileges(profile.id, otherPrivileges);
    }, successMessage: 'Manutenzione aggiornata.');
  }

  Future<void> _removeMaintenanceHelicopter(
    UserProfile profile,
    int helicopterTypeId,
    List<UserLicense> existingLicenses,
    List<UserPrivilege> existingPrivileges,
  ) async {
    await _runMutation(() async {
      final toDelete = existingLicenses
          .where((l) => l.helicopterTypeId == helicopterTypeId && l.id != null)
          .toList();
      for (final lic in toDelete) {
        await _userService.deleteUserLicense(lic.id!);
      }
      final remaining = existingPrivileges
          .where((p) => p.helicopterTypeId != helicopterTypeId)
          .map(
            (p) => {
              'helicopter_type_id': p.helicopterTypeId,
              'privilege_type_id': p.privilegeTypeId,
            },
          )
          .toList();
      await _userService.setUserPrivileges(profile.id, remaining);
    }, successMessage: 'Manutenzione rimossa.');
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
                      children: ['T', 'TOB', 'MTB']
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
                        crewType == 'MTB'
                            ? 'MTB richiede solo la selezione dell\'elicottero.'
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
    await _runMutation(() async {
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
      await _userService.setUserTobCapabilities(
        profile.id,
        updatedCapabilities,
      );
    }, successMessage: 'Equipaggio rimosso.');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final profile = auth.userProfile;
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    _syncProfileState(profile);
    final isAdminProfile = profile.isAdmin;
    final today = DateTime.now();
    final isFlightFitnessExpired =
        _flightFitnessExpiry != null &&
        _flightFitnessExpiry!.isBefore(
          DateTime(today.year, today.month, today.day),
        );

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
                  padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
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
                      if (isFlightFitnessExpired)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade700.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade400),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.redAccent,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Idoneità al volo scaduta. Aggiorna la data di scadenza.',
                                ),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.medical_services_outlined,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Idoneità al volo — Scadenza',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                        softWrap: true,
                                      ),
                                      Text(
                                        _formatDate(_flightFitnessExpiry),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                if (_flightFitnessExpiry != null)
                                  OutlinedButton.icon(
                                    onPressed: () => setState(
                                      () => _flightFitnessExpiry = null,
                                    ),
                                    icon: const Icon(Icons.close, size: 16),
                                    label: const Text('Rimuovi'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      textStyle: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                OutlinedButton.icon(
                                  onPressed: _pickFlightFitnessExpiry,
                                  icon: const Icon(
                                    Icons.calendar_month_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Seleziona data'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    textStyle: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Istruttore T.A. (TI)'),
                        subtitle: const Text('Istruttore Tecnico-Aeronautico'),
                        value: _isTi,
                        onChanged: (value) => setState(() => _isTi = value),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Esaminatore T.P. (ETP)'),
                        subtitle: const Text('Esaminatore Teorico-Pratico'),
                        value: _isEtp,
                        onChanged: (value) => setState(() => _isEtp = value),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _showChangePasswordDialog,
                        icon: const Icon(Icons.lock_reset_outlined),
                        label: const Text('Cambia password'),
                      ),
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
                // ---- MANUTENZIONE (licenze + privilegi combinati per elicottero) ----
                Builder(
                  builder: (context) {
                    // Group licenses and privileges by helicopter
                    final byHeli =
                        <
                          int,
                          ({
                            String code,
                            UserLicense? license,
                            List<UserPrivilege> privs,
                          })
                        >{};
                    for (final lic in auth.licenses) {
                      byHeli[lic.helicopterTypeId] = (
                        code: lic.helicopterCode,
                        license: lic,
                        privs: <UserPrivilege>[],
                      );
                    }
                    for (final priv in auth.privileges) {
                      if (byHeli.containsKey(priv.helicopterTypeId)) {
                        byHeli[priv.helicopterTypeId]!.privs.add(priv);
                      } else {
                        byHeli[priv.helicopterTypeId] = (
                          code: priv.helicopterCode,
                          license: null,
                          privs: [priv],
                        );
                      }
                    }
                    return _EditableSection(
                      title: 'Manutenzione',
                      addLabel: 'Aggiungi',
                      onAdd: () async {
                        final excludeIds = byHeli.keys.toList();
                        final result = await _showMaintenanceDialog(
                          auth.helicopterTypes,
                          auth.licenseTypes,
                          auth.privilegeTypes,
                          excludeHelicopterIds: excludeIds,
                        );
                        if (result == null) return;
                        await _applyMaintenanceEntry(
                          profile,
                          result,
                          auth.licenses,
                          auth.privileges,
                        );
                      },
                      child: byHeli.isEmpty
                          ? const Text(
                              'Nessuna manutenzione assegnata.',
                              textAlign: TextAlign.center,
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: byHeli.entries.map((entry) {
                                final heliId = entry.key;
                                final group = entry.value;
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      10,
                                      8,
                                      10,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                group.license != null
                                                    ? '${group.code}  ·  Cat. ${group.license!.licenseCode}'
                                                    : group.code,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                softWrap: true,
                                              ),
                                              if (group.privs.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  group.privs
                                                      .map(
                                                        (p) => p.privilegeName,
                                                      )
                                                      .join(' · '),
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall,
                                                  softWrap: true,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 18,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () async {
                                            final result =
                                                await _showMaintenanceDialog(
                                                  auth.helicopterTypes,
                                                  auth.licenseTypes,
                                                  auth.privilegeTypes,
                                                  initialHelicopterId: heliId,
                                                  initialLicenseTypeId: group
                                                      .license
                                                      ?.licenseTypeId,
                                                  initialPrivilegeTypeIds: group
                                                      .privs
                                                      .map(
                                                        (p) =>
                                                            p.privilegeTypeId,
                                                      )
                                                      .toSet(),
                                                );
                                            if (result == null) return;
                                            await _applyMaintenanceEntry(
                                              profile,
                                              result,
                                              auth.licenses,
                                              auth.privileges,
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () =>
                                              _removeMaintenanceHelicopter(
                                                profile,
                                                heliId,
                                                auth.licenses,
                                                auth.privileges,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                // ---- EQUIPAGGI DI VOLO (crew + capacità TOB combinati) ----
                Builder(
                  builder: (context) {
                    return _EditableSection(
                      title: 'Equipaggi di volo',
                      addLabel: 'Aggiungi',
                      onAdd: () async {
                        final result = await _showCrewDialog(
                          auth.helicopterTypes,
                          auth.tobCapabilityTypes,
                        );
                        if (result == null) return;
                        await _runMutation(() async {
                          await _userService.addUserCrewAssignment(
                            UserCrewAssignment(
                              userId: profile.id,
                              helicopterTypeId:
                                  result['helicopterTypeId'] as int,
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
                                'helicopter_type_id':
                                    result['helicopterTypeId'],
                                'tob_capability_id': capabilityId as int,
                              });
                            }
                            await _userService.setUserTobCapabilities(
                              profile.id,
                              updatedCapabilities,
                            );
                          }
                        }, successMessage: 'Equipaggio aggiunto.');
                      },
                      child: auth.crewAssignments.isEmpty
                          ? const Text(
                              'Nessun equipaggio assegnato.',
                              textAlign: TextAlign.center,
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: auth.crewAssignments.map((item) {
                                final caps = auth.tobCapabilities
                                    .where(
                                      (c) =>
                                          c.helicopterTypeId ==
                                          item.helicopterTypeId,
                                    )
                                    .toList();
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      10,
                                      8,
                                      10,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.crewType == 'TOB'
                                                    ? '${item.helicopterCode}  ·  ${item.crewType} (Fascia ${item.fascia ?? '-'})'
                                                    : '${item.helicopterCode}  ·  ${item.crewType}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                softWrap: true,
                                              ),
                                              if (item.crewType == 'TOB' &&
                                                  caps.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  caps
                                                      .map(
                                                        (c) => c.capabilityName,
                                                      )
                                                      .join(' · '),
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall,
                                                  softWrap: true,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        if (item.crewType == 'TOB')
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                              size: 18,
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () =>
                                                _manageTobCapabilities(
                                                  profile,
                                                  auth.tobCapabilities,
                                                  auth.helicopterTypes,
                                                  auth.tobCapabilityTypes,
                                                ),
                                          ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: item.id == null
                                              ? null
                                              : () => _removeCrewAssignment(
                                                  profile,
                                                  item,
                                                  auth.crewAssignments,
                                                  auth.tobCapabilities,
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                    );
                  },
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

class _MaintenanceEntry {
  const _MaintenanceEntry({
    required this.helicopterTypeId,
    required this.licenseTypeId,
    required this.privilegeTypeIds,
  });

  final int helicopterTypeId;
  final int licenseTypeId;
  final Set<int> privilegeTypeIds;
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
