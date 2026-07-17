import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../constants/app_constants.dart';
import '../../models/reference_models.dart';
import '../../services/user_service.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userService = UserService();
  final _nomeCtrl = TextEditingController();
  final _cognomeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  final List<Map<String, dynamic>> _pendingLicenses = [];
  final List<Map<String, dynamic>> _pendingCrew = [];
  final List<Map<String, dynamic>> _pendingPrivileges = [];
  final List<Map<String, dynamic>> _pendingTobCaps = [];

  int? _orgUnitId;
  bool _obscure = true;
  bool _isTi = false;
  bool _isEtp = false;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _cognomeCtrl.dispose();
    _passwordCtrl.dispose();
    _licenseCtrl.dispose();
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

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_orgUnitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona l\'unità organizzativa.')),
      );
      return;
    }

    final auth = ref.read(authProvider);
    final numeroLicenza = _licenseCtrl.text.trim().toUpperCase();
    final ok = await auth.signUp(
      password: _passwordCtrl.text,
      nome: _nomeCtrl.text.trim(),
      cognome: _cognomeCtrl.text.trim(),
      numeroLicenza: numeroLicenza,
      email: _emailCtrl.text.trim().toLowerCase(),
      isTi: _isTi,
      isEtp: _isEtp,
    );

    if (!mounted) {
      return;
    }

    if (!ok || auth.userProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Errore durante la registrazione'),
          backgroundColor: AppColors.currencyExpired,
        ),
      );
      return;
    }

    final userId = auth.userProfile!.id;

    try {
      await auth.updateProfile(
        auth.userProfile!.copyWith(
          username: numeroLicenza,
          numeroLicenza: numeroLicenza,
          email: _emailCtrl.text.trim().toLowerCase(),
          orgUnitId: _orgUnitId,
        ),
      );

      if (_pendingLicenses.isNotEmpty) {
        await _userService.setUserLicenses(userId, _pendingLicenses);
      }
      if (_pendingCrew.isNotEmpty) {
        await _userService.setUserCrewAssignments(userId, _pendingCrew);
      }
      if (_pendingPrivileges.isNotEmpty) {
        await _userService.setUserPrivileges(userId, _pendingPrivileges);
      }
      if (_pendingTobCaps.isNotEmpty) {
        await _userService.setUserTobCapabilities(userId, _pendingTobCaps);
      }

      await auth.signOut();

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Registrazione inviata'),
          content: const Text(
            'Registrazione inviata - in attesa di approvazione',
          ),
          actions: [
            ElevatedButton(
              style: _dialogActionStyle(),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.currencyExpired,
        ),
      );
    }
  }

  Widget _buildDialogContent(List<Widget> children) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }

  ButtonStyle _dialogActionStyle() {
    return ElevatedButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    );
  }

  Future<void> _addCrew(
    List<HelicopterType> helicopterTypes,
    List<TobCapability> tobCapabilities,
  ) async {
    final helicopterItems = helicopterTypes
        .map(
          (item) =>
              DropdownMenuItem<int>(value: item.id, child: Text(item.name)),
        )
        .toList(growable: false);
    const fasciaItems = [
      DropdownMenuItem(value: 'A', child: Text('A')),
      DropdownMenuItem(value: 'B', child: Text('B')),
      DropdownMenuItem(value: 'C', child: Text('C')),
    ];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        int? helicopterId;
        String crewType = 'T';
        String fascia = 'A';
        final selectedCapabilityIds = <int>{};
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Aggiungi equipaggio'),
            scrollable: true,
            content: _buildDialogContent([
              DropdownButtonFormField<int>(
                initialValue: helicopterId,
                menuMaxHeight: 300,
                decoration: const InputDecoration(labelText: 'Elicottero'),
                items: helicopterItems,
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
                    .toList(growable: false),
              ),
              if (crewType == 'TOB') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: fascia,
                  menuMaxHeight: 300,
                  decoration: const InputDecoration(labelText: 'Fascia TOB'),
                  items: fasciaItems,
                  onChanged: (value) =>
                      setDialogState(() => fascia = value ?? 'A'),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Capacità TOB',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 8),
                ...tobCapabilities.map(
                  (capability) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: selectedCapabilityIds.contains(capability.id),
                    title: Text(capability.name, softWrap: true),
                    onChanged: (_) => setDialogState(() {
                      if (selectedCapabilityIds.contains(capability.id)) {
                        selectedCapabilityIds.remove(capability.id);
                      } else {
                        selectedCapabilityIds.add(capability.id);
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
            ]),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                style: _dialogActionStyle(),
                onPressed: () {
                  if (helicopterId == null) {
                    return;
                  }
                  Navigator.of(dialogContext).pop({
                    'helicopter_type_id': helicopterId,
                    'crew_type': crewType,
                    'tob_grade': crewType == 'TOB' ? fascia : null,
                    'selected_capability_ids': selectedCapabilityIds.toList(),
                  });
                },
                child: const Text('Conferma'),
              ),
            ],
          ),
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    final exists = _pendingCrew.any(
      (item) =>
          item['helicopter_type_id'] == result['helicopter_type_id'] &&
          item['crew_type'] == result['crew_type'],
    );
    if (exists) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Equipaggio già presente.')));
      return;
    }

    setState(() {
      _pendingCrew.add({
        'helicopter_type_id': result['helicopter_type_id'],
        'crew_type': result['crew_type'],
        'tob_grade': result['tob_grade'],
      });
      if (result['crew_type'] == 'TOB') {
        _pendingTobCaps.removeWhere(
          (item) => item['helicopter_type_id'] == result['helicopter_type_id'],
        );
        for (final capabilityId
            in (result['selected_capability_ids'] as List<dynamic>)) {
          _pendingTobCaps.add({
            'helicopter_type_id': result['helicopter_type_id'],
            'tob_capability_id': capabilityId as int,
          });
        }
      }
    });
  }

  Future<void> _manageMaintenance(
    List<HelicopterType> helicopterTypes,
    List<LicenseType> licenseTypes,
    List<PrivilegeType> privilegeTypes, {
    int? forHelicopterId,
  }) async {
    final existingLicId = forHelicopterId == null
        ? null
        : _pendingLicenses
              .where((l) => l['helicopter_type_id'] == forHelicopterId)
              .map((l) => l['license_type_id'] as int)
              .firstOrNull;
    final existingPrivIds = forHelicopterId == null
        ? <int>{}
        : _pendingPrivileges
              .where((p) => p['helicopter_type_id'] == forHelicopterId)
              .map((p) => p['privilege_type_id'] as int)
              .toSet();

    final result = await showDialog<_MaintenanceDialogResult>(
      context: context,
      builder: (dialogContext) {
        int? selectedHelicopter = forHelicopterId;
        int? selectedLicenseId = existingLicId;
        final selectedPrivilegeIds = Set<int>.from(existingPrivIds);
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Configura manutenzione per elicottero'),
            scrollable: true,
            content: _buildDialogContent([
              if (forHelicopterId == null)
                DropdownButtonFormField<int>(
                  initialValue: selectedHelicopter,
                  menuMaxHeight: 300,
                  decoration: const InputDecoration(labelText: 'Elicottero'),
                  items: helicopterTypes
                      .map(
                        (h) => DropdownMenuItem<int>(
                          value: h.id,
                          child: Text(h.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (v) =>
                      setDialogState(() => selectedHelicopter = v),
                ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                initialValue: selectedLicenseId,
                menuMaxHeight: 300,
                decoration: const InputDecoration(labelText: 'Tipo licenza'),
                hint: const Text('Nessuna'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Nessuna'),
                  ),
                  ...licenseTypes.map(
                    (lt) => DropdownMenuItem<int?>(
                      value: lt.id,
                      child: Text(lt.code),
                    ),
                  ),
                ],
                onChanged: (v) => setDialogState(() => selectedLicenseId = v),
              ),
              const SizedBox(height: 16),
              Text(
                'Privilegi manutentivi',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...privilegeTypes.map(
                (pt) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(pt.name),
                  value: selectedPrivilegeIds.contains(pt.id),
                  onChanged: (_) => setDialogState(() {
                    if (selectedPrivilegeIds.contains(pt.id)) {
                      selectedPrivilegeIds.remove(pt.id);
                    } else {
                      selectedPrivilegeIds.add(pt.id);
                    }
                  }),
                ),
              ),
            ]),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                style: _dialogActionStyle(),
                onPressed: () {
                  if (selectedHelicopter == null) return;
                  Navigator.of(dialogContext).pop(
                    _MaintenanceDialogResult(
                      helicopterId: selectedHelicopter!,
                      licenseTypeId: selectedLicenseId,
                      privilegeTypeIds: selectedPrivilegeIds.toList(),
                    ),
                  );
                },
                child: const Text('Conferma'),
              ),
            ],
          ),
        );
      },
    );

    if (result == null || !mounted) return;

    setState(() {
      _pendingLicenses.removeWhere(
        (l) => l['helicopter_type_id'] == result.helicopterId,
      );
      _pendingPrivileges.removeWhere(
        (p) => p['helicopter_type_id'] == result.helicopterId,
      );
      if (result.licenseTypeId != null) {
        _pendingLicenses.add({
          'helicopter_type_id': result.helicopterId,
          'license_type_id': result.licenseTypeId,
        });
      }
      for (final privId in result.privilegeTypeIds) {
        _pendingPrivileges.add({
          'helicopter_type_id': result.helicopterId,
          'privilege_type_id': privId,
        });
      }
    });
  }

  List<_HeliMaintenanceItem> _maintenanceByHelicopterView(
    List<HelicopterType> helicopterTypes,
    List<LicenseType> licenseTypes,
    List<PrivilegeType> privilegeTypes,
  ) {
    final helicIds = <int>{};
    for (final l in _pendingLicenses) {
      helicIds.add(l['helicopter_type_id'] as int);
    }
    for (final p in _pendingPrivileges) {
      helicIds.add(p['helicopter_type_id'] as int);
    }
    return helicIds.map((heliId) {
      final ht = helicopterTypes.firstWhere(
        (h) => h.id == heliId,
        orElse: () =>
            HelicopterType(id: heliId, code: '$heliId', name: '$heliId'),
      );
      final licId = _pendingLicenses
          .where((l) => l['helicopter_type_id'] == heliId)
          .map((l) => l['license_type_id'] as int)
          .firstOrNull;
      final licLabel = licId == null
          ? null
          : licenseTypes
                .firstWhere(
                  (lt) => lt.id == licId,
                  orElse: () =>
                      LicenseType(id: licId, code: '$licId', name: '$licId'),
                )
                .name;
      final privCount = _pendingPrivileges
          .where((p) => p['helicopter_type_id'] == heliId)
          .length;
      return _HeliMaintenanceItem(
        helicopterId: heliId,
        helicopterCode: ht.code,
        licenseLabel: licLabel,
        privilegeCount: privCount,
      );
    }).toList();
  }

  String _helicopterLabel(List<HelicopterType> items, int helicopterId) {
    for (final item in items) {
      if (item.id == helicopterId) {
        return item.code;
      }
    }
    return 'N/D';
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final helicopterTypes = auth.helicopterTypes;
    final licenseTypes = auth.licenseTypes;
    final privilegeTypes = auth.privilegeTypes;
    final tobCapabilities = auth.tobCapabilityTypes;
    final orgUnits = auth.orgUnits;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final horizontalPadding = isMobile ? 16.0 : 24.0;
    final formPadding = isMobile ? 20.0 : 24.0;
    final orgUnitItems = orgUnits
        .map(
          (unit) =>
              DropdownMenuItem<int>(value: unit.id, child: Text(unit.name)),
        )
        .toList(growable: false);
    final byHeli = _maintenanceByHelicopterView(
      helicopterTypes,
      licenseTypes,
      privilegeTypes,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Registrazione')),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(formPadding),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Nuovo account AVES',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Inserisci i dati del profilo e le qualifiche iniziali.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _nomeCtrl,
                        decoration: const InputDecoration(labelText: 'Nome'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Campo obbligatorio'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _cognomeCtrl,
                        decoration: const InputDecoration(labelText: 'Cognome'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Campo obbligatorio'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _licenseCtrl,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9]'),
                          ),
                          LengthLimitingTextInputFormatter(20),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Numero licenza',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Campo obbligatorio';
                          }
                          final cleaned = value.trim().toUpperCase();
                          if (!RegExp(r'^[A-Z]{2}\d{6}$').hasMatch(cleaned)) {
                            return 'Formato MAML non valido. Esempio: EI123456 (2 lettere + 6 cifre)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email istituzionale',
                          hintText: 'nome.cognome@esercito.difesa.it',
                        ),
                        validator: _validateInstitutionalEmail,
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Istruttore Tecnico-Aeronautico (TI)',
                        ),
                        value: _isTi,
                        onChanged: (v) => setState(() => _isTi = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Esaminatore Teorico-Pratico (ETP)'),
                        value: _isEtp,
                        onChanged: (v) => setState(() => _isEtp = v),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Campo obbligatorio'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: _orgUnitId,
                        menuMaxHeight: 300,
                        decoration: const InputDecoration(
                          labelText: 'Unità organizzativa',
                        ),
                        items: orgUnitItems,
                        onChanged: (value) =>
                            setState(() => _orgUnitId = value),
                        validator: (value) =>
                            value == null ? 'Campo obbligatorio' : null,
                      ),
                      const SizedBox(height: 24),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Manutenzione (${byHeli.length} elicotteri)',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const Spacer(),
                                  OutlinedButton.icon(
                                    onPressed: () => _manageMaintenance(
                                      helicopterTypes,
                                      licenseTypes,
                                      privilegeTypes,
                                    ),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Aggiungi'),
                                  ),
                                ],
                              ),
                              if (byHeli.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: Text(
                                    'Nessun elicottero configurato.',
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: byHeli.map((item) {
                                      return InkWell(
                                        onTap: () => _manageMaintenance(
                                          helicopterTypes,
                                          licenseTypes,
                                          privilegeTypes,
                                          forHelicopterId: item.helicopterId,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: AppColors.border,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            color: AppColors.primary.withValues(
                                              alpha: 0.06,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    item.helicopterCode,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyLarge
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Icon(
                                                    Icons.edit,
                                                    size: 14,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ],
                                              ),
                                              if (item.licenseLabel != null)
                                                Text(
                                                  item.licenseLabel!,
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall,
                                                ),
                                              Text(
                                                '${item.privilegeCount} privilegi',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _PendingSection(
                        title: 'Equipaggi di Volo',
                        itemCount: _pendingCrew.length,
                        emptyText: 'Nessun equipaggio aggiunto.',
                        onAdd: () => _addCrew(helicopterTypes, tobCapabilities),
                        addLabel: 'Aggiungi equipaggio',
                        children: _pendingCrew
                            .asMap()
                            .entries
                            .map(
                              (entry) => ListTile(
                                title: Text(
                                  "${_helicopterLabel(helicopterTypes, entry.value['helicopter_type_id'] as int)} · ${entry.value['crew_type']}",
                                ),
                                subtitle: entry.value['crew_type'] == 'TOB'
                                    ? Text(
                                        'Fascia ${entry.value['tob_grade']} · ${_pendingTobCaps.where((item) => item['helicopter_type_id'] == entry.value['helicopter_type_id']).length} capacità',
                                      )
                                    : null,
                                trailing: IconButton(
                                  onPressed: () => setState(() {
                                    final removed = _pendingCrew.removeAt(
                                      entry.key,
                                    );
                                    if (removed['crew_type'] == 'TOB') {
                                      _pendingTobCaps.removeWhere(
                                        (item) =>
                                            item['helicopter_type_id'] ==
                                            removed['helicopter_type_id'],
                                      );
                                    }
                                  }),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Text(
                          'Dopo la registrazione il profilo resterà in attesa di approvazione amministrativa.',
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (auth.isLoading)
                        const Center(child: CircularProgressIndicator())
                      else
                        ElevatedButton(
                          onPressed: _register,
                          child: const Text('Registrati'),
                        ),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Hai già un account? Torna al login'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingSection extends StatelessWidget {
  const _PendingSection({
    required this.title,
    required this.itemCount,
    required this.emptyText,
    required this.onAdd,
    required this.addLabel,
    required this.children,
  });

  final String title;
  final int itemCount;
  final String emptyText;
  final VoidCallback onAdd;
  final String addLabel;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Text('$title ($itemCount)', textAlign: TextAlign.center),
        children: [
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(emptyText, textAlign: TextAlign.center),
            )
          else
            ...children,
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle_outline),
              label: Text(addLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeliMaintenanceItem {
  const _HeliMaintenanceItem({
    required this.helicopterId,
    required this.helicopterCode,
    this.licenseLabel,
    required this.privilegeCount,
  });

  final int helicopterId;
  final String helicopterCode;
  final String? licenseLabel;
  final int privilegeCount;
}

class _MaintenanceDialogResult {
  const _MaintenanceDialogResult({
    required this.helicopterId,
    this.licenseTypeId,
    required this.privilegeTypeIds,
  });

  final int helicopterId;
  final int? licenseTypeId;
  final List<int> privilegeTypeIds;
}
