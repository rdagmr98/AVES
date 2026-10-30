import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../widgets/app_dropdown.dart';
import '../../app.dart';
import '../../constants/app_constants.dart';
import '../../models/reference_models.dart';
import '../../models/user_models.dart';
import '../../services/user_service.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/admin_app_bar_leading.dart';
import '../../widgets/currency_badge_widget.dart';
import '../../widgets/form_parts.dart';

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
  Map<int, PrivilegeRequest> _privilegeRequests = {};

  @override
  void initState() {
    super.initState();
    final profile = ref.read(authProvider).userProfile;
    _nomeCtrl = TextEditingController(text: profile?.nome ?? '');
    _cognomeCtrl = TextEditingController(text: profile?.cognome ?? '');
    _emailCtrl = TextEditingController(text: profile?.email ?? '');
    _profilePhotoBase64 = profile?.profilePhotoBase64;
    _orgUnitId = profile?.orgUnitId;
    _isTi = profile?.isTi ?? false;
    _isEtp = profile?.isEtp ?? false;
    _flightFitnessExpiry = profile?.flightFitnessExpiry;
    _lastProfileSyncKey = _profileSyncKey(profile);
    _loadDeletionRequest();
    _loadPrivilegeRequests();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _cognomeCtrl.dispose();
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

  Future<void> _loadPrivilegeRequests() async {
    final profile = ref.read(authProvider).userProfile;
    if (profile == null) {
      return;
    }
    final requests = await _userService.getPrivilegeRequests(
      userId: profile.id,
      onlyPending: true,
    );
    if (!mounted) {
      return;
    }
    setState(
      () => _privilegeRequests = {
        for (final r in requests) r.helicopterTypeId: r,
      },
    );
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
            if (ref.read(authProvider).userProfile?.isAdmin == false)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    var message =
                        'Richiesta inviata: gli amministratori ti daranno una password temporanea.';
                    try {
                      await ref.read(authProvider).requestPasswordReset();
                    } catch (_) {
                      message = 'Impossibile contattare il server. Riprova.';
                    }
                    if (!mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(message)));
                  },
                  child: const Text('Password dimenticata?'),
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
              if (newPasswordCtrl.text.isEmpty ||
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
                      AppDropdown<int>(
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
                      AppDropdown<int>(
                        initialValue: licenseTypeId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Categoria licenza',
                        ),
                        items: licenseTypes
                            .map(
                              (item) => DropdownMenuItem<int>(
                                value: item.id,
                                child: Text(item.code),
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
                      MultiCheckList<int>(
                        options: {
                          for (final item in privilegeTypes) item.id: item.name,
                        },
                        selected: selectedPrivilegeIds,
                        onChanged: (ids) => setDialogState(
                          () => selectedPrivilegeIds
                            ..clear()
                            ..addAll(ids),
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

  /// Le modifiche alla manutenzione diventano una richiesta: valgono quando
  /// l'admin la approva registrando l'OJT.
  Future<void> _requestMaintenance(
    UserProfile profile,
    int helicopterTypeId, {
    int? licenseTypeId,
    Set<int> privilegeTypeIds = const {},
  }) => _runMutation(() async {
    await _userService.requestPrivilegeChange(
      profile.id,
      helicopterTypeId,
      licenseTypeId: licenseTypeId,
      privilegeTypeIds: privilegeTypeIds,
    );
    await _loadPrivilegeRequests();
  }, successMessage: "Modifica inviata all'admin per l'approvazione.");

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
                    AppDropdown<int>(
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
                      AppDropdown<String>(
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
                      AppDropdown<int>(
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
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    final fitnessDays = _flightFitnessExpiry
        ?.difference(DateTime(now.year, now.month, now.day))
        .inDays;
    final isFlightFitnessExpired = fitnessDays != null && fitnessDays < 0;
    final unitName = auth.orgUnits
        .where((u) => u.id == _orgUnitId)
        .firstOrNull
        ?.name;
    final licenza = profile.numeroLicenza ?? '';

    // Licenze e privilegi raggruppati per elicottero
    final byHeli =
        <
          int,
          ({String code, UserLicense? license, List<UserPrivilege> privs})
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
    // Elicotteri solo richiesti, non ancora approvati.
    for (final r in _privilegeRequests.values) {
      byHeli.putIfAbsent(
        r.helicopterTypeId,
        () => (
          code:
              auth.helicopterTypes
                  .where((h) => h.id == r.helicopterTypeId)
                  .firstOrNull
                  ?.code ??
              '',
          license: null,
          privs: <UserPrivilege>[],
        ),
      );
    }
    String requested(PrivilegeRequest r) =>
        r.licenseTypeId == null && r.privilegeTypeIds.isEmpty
        ? 'rimozione'
        : [
            for (final l in auth.licenseTypes)
              if (l.id == r.licenseTypeId) 'Cat. ${l.code}',
            for (final p in auth.privilegeTypes)
              if (r.privilegeTypeIds.contains(p.id)) p.name,
          ].join(' · ');

    Widget empty(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: textTheme.bodySmall),
    );

    return Scaffold(
      appBar: AppBar(
        leading: AdminAppBarLeading(
          fallbackRoute: isAdminProfile ? null : '/dashboard',
        ),
        title: const Text('Profilo'),
        bottom: _saving || auth.isLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Tooltip(
                        message: 'Cambia foto',
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _saving ? null : _pickProfilePhoto,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              UserAvatar(
                                user: profile.copyWith(
                                  profilePhotoBase64: _profilePhotoBase64,
                                ),
                                radius: 38,
                              ),
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.primary,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.photo_camera_outlined,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.fullName.isEmpty
                                  ? 'Il tuo profilo'
                                  : profile.fullName,
                              style: textTheme.titleLarge,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (licenza.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Licenza $licenza',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (unitName != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                unitName,
                                style: textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _Section(
                    icon: Icons.person_outline,
                    title: 'Dati personali',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LabeledField(
                          label: 'Nome',
                          child: TextField(
                            controller: _nomeCtrl,
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                        LabeledField(
                          label: 'Cognome',
                          child: TextField(
                            controller: _cognomeCtrl,
                            textCapitalization: TextCapitalization.characters,
                          ),
                        ),
                        if (!isAdminProfile)
                          LabeledField(
                            label: 'Email istituzionale',
                            child: TextField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                hintText: 'nome.cognome@esercito.difesa.it',
                                errorText: _emailError,
                              ),
                            ),
                          ),
                        LabeledField(
                          label: 'Unità organizzativa',
                          child: AppDropdown<int>(
                            initialValue: _orgUnitId,
                            hint: const Text('Seleziona'),
                            items: auth.orgUnits
                                .map(
                                  (item) => DropdownMenuItem<int>(
                                    value: item.id,
                                    child: Text(item.name, softWrap: true),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _orgUnitId = value),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _Section(
                    icon: Icons.verified_user_outlined,
                    title: 'Idoneità e qualifiche',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LabeledField(
                          label: 'Idoneità al volo',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _pickFlightFitnessExpiry,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                prefixIcon: const Icon(
                                  Icons.medical_services_outlined,
                                ),
                                errorText: isFlightFitnessExpired
                                    ? 'Scaduta: tocca per aggiornare la data'
                                    : null,
                                suffixIcon: _flightFitnessExpiry == null
                                    ? null
                                    : IconButton(
                                        tooltip: 'Rimuovi',
                                        icon: const Icon(Icons.close),
                                        onPressed: () => setState(
                                          () => _flightFitnessExpiry = null,
                                        ),
                                      ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _flightFitnessExpiry == null
                                          ? 'Seleziona la scadenza'
                                          : _formatDate(_flightFitnessExpiry),
                                      style: _flightFitnessExpiry == null
                                          ? const TextStyle(
                                              color: AppColors.textHint,
                                            )
                                          : null,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (fitnessDays != null)
                                    _Pill(
                                      text: fitnessDays < 0
                                          ? 'Scaduta'
                                          : fitnessDays == 0
                                          ? 'Scade oggi'
                                          : 'Tra $fitnessDays gg',
                                      color: expiryBadge(
                                        _flightFitnessExpiry,
                                      ).$2,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Istruttore T.A. (TI)'),
                          subtitle: const Text(
                            'Istruttore Tecnico-Aeronautico',
                          ),
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
                      ],
                    ),
                  ),
                  if (!isAdminProfile) ...[
                    _Section(
                      icon: Icons.build_outlined,
                      title: 'Manutenzione',
                      onAdd: () async {
                        final result = await _showMaintenanceDialog(
                          auth.helicopterTypes,
                          auth.licenseTypes,
                          auth.privilegeTypes,
                          excludeHelicopterIds: byHeli.keys.toList(),
                        );
                        if (result == null) return;
                        await _requestMaintenance(
                          profile,
                          result.helicopterTypeId,
                          licenseTypeId: result.licenseTypeId,
                          privilegeTypeIds: result.privilegeTypeIds,
                        );
                      },
                      child: byHeli.isEmpty
                          ? empty('Nessuna manutenzione assegnata.')
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final MapEntry(key: heliId, value: group)
                                    in byHeli.entries)
                                  _AssignmentTile(
                                    title: group.code,
                                    badge: group.license == null
                                        ? null
                                        : 'Cat. ${group.license!.licenseCode}',
                                    subtitle: group.privs.isEmpty
                                        ? null
                                        : group.privs
                                              .map((p) => p.privilegeName)
                                              .join(' · '),
                                    pending: _privilegeRequests[heliId] == null
                                        ? null
                                        : 'In attesa di approvazione: '
                                              '${requested(_privilegeRequests[heliId]!)}',
                                    onEdit: () async {
                                      final r = _privilegeRequests[heliId];
                                      final result =
                                          await _showMaintenanceDialog(
                                            auth.helicopterTypes,
                                            auth.licenseTypes,
                                            auth.privilegeTypes,
                                            initialHelicopterId: heliId,
                                            initialLicenseTypeId: r != null
                                                ? r.licenseTypeId
                                                : group.license?.licenseTypeId,
                                            initialPrivilegeTypeIds:
                                                r?.privilegeTypeIds ??
                                                group.privs
                                                    .map(
                                                      (p) => p.privilegeTypeId,
                                                    )
                                                    .toSet(),
                                          );
                                      if (result == null) return;
                                      await _requestMaintenance(
                                        profile,
                                        heliId,
                                        licenseTypeId: result.licenseTypeId,
                                        privilegeTypeIds:
                                            result.privilegeTypeIds,
                                      );
                                    },
                                    onDelete: () =>
                                        _requestMaintenance(profile, heliId),
                                  ),
                              ],
                            ),
                    ),
                    _Section(
                      icon: Icons.flight_outlined,
                      title: 'Equipaggi di volo',
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
                          ? empty('Nessun equipaggio assegnato.')
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final item in auth.crewAssignments)
                                  _AssignmentTile(
                                    title: item.helicopterCode,
                                    badge: item.crewType == 'TOB'
                                        ? 'TOB · Fascia ${item.fascia ?? '-'}'
                                        : item.crewType,
                                    subtitle: item.crewType == 'TOB'
                                        ? auth.tobCapabilities
                                              .where(
                                                (c) =>
                                                    c.helicopterTypeId ==
                                                    item.helicopterTypeId,
                                              )
                                              .map((c) => c.capabilityName)
                                              .join(' · ')
                                        : null,
                                    onEdit: item.crewType == 'TOB'
                                        ? () => _manageTobCapabilities(
                                            profile,
                                            auth.tobCapabilities,
                                            auth.helicopterTypes,
                                            auth.tobCapabilityTypes,
                                          )
                                        : null,
                                    onDelete: item.id == null
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
                  ],
                  _Section(
                    icon: Icons.manage_accounts_outlined,
                    title: 'Account',
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.lock_reset_outlined),
                          title: const Text('Cambia password'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _showChangePasswordDialog,
                        ),
                        if (!isAdminProfile)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            enabled: _pendingDeletionRequest == null,
                            iconColor: AppColors.currencyExpired,
                            textColor: AppColors.currencyExpired,
                            leading: Icon(
                              _pendingDeletionRequest == null
                                  ? Icons.delete_forever_outlined
                                  : Icons.hourglass_top,
                            ),
                            title: const Text('Richiedi eliminazione account'),
                            subtitle: Text(
                              _pendingDeletionRequest == null
                                  ? "L'account sarà eliminato solo dopo l'approvazione di un admin."
                                  : 'Richiesta inviata, in attesa di approvazione admin.',
                            ),
                            onTap: _showDeleteAccountRequestDialog,
                          ),
                      ],
                    ),
                  ),
                  if (isAdminProfile)
                    Text(
                      'Profilo amministrativo: i campi personali, le assegnazioni e le capacità operative non sono richiesti per gli admin.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SaveBar(
        label: 'Salva profilo',
        icon: Icons.check_rounded,
        saving: _saving,
        onPressed: _saveProfile,
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

/// Card di sezione: intestazione con icona e, se [onAdd], pulsante Aggiungi.
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
    this.onAdd,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormHeader(
                icon: icon,
                title: title,
                trailing: onAdd == null
                    ? null
                    : TextButton.icon(
                        onPressed: onAdd,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Aggiungi'),
                      ),
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Riga di un'assegnazione (elicottero + categoria/ruolo + dettagli).
class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({
    required this.title,
    required this.onDelete,
    this.badge,
    this.subtitle,
    this.pending,
    this.onEdit,
  });

  final String title;
  final String? badge;
  final String? subtitle;
  final String? pending;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: _Pill(text: badge!, color: AppColors.accentGlow),
                      ),
                    ],
                  ],
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: textTheme.bodySmall),
                ],
                if (pending != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    pending!,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.currencyWarning,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              tooltip: 'Modifica',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit,
            ),
          IconButton(
            tooltip: 'Rimuovi',
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
