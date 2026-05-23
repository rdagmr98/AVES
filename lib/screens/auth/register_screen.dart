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

  final List<Map<String, dynamic>> _pendingLicenses = [];
  final List<Map<String, dynamic>> _pendingCrew = [];
  final List<Map<String, dynamic>> _pendingPrivileges = [];
  final List<Map<String, dynamic>> _pendingTobCaps = [];

  int? _orgUnitId;
  bool _obscure = true;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _cognomeCtrl.dispose();
    _passwordCtrl.dispose();
    _licenseCtrl.dispose();
    super.dispose();
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

  Future<void> _addLicense(
    List<HelicopterType> helicopterTypes,
    List<LicenseType> licenseTypes,
  ) async {
    final helicopterItems = helicopterTypes
        .map(
          (item) =>
              DropdownMenuItem<int>(value: item.id, child: Text(item.name)),
        )
        .toList(growable: false);
    final licenseItems = licenseTypes
        .map(
          (item) =>
              DropdownMenuItem<int>(value: item.id, child: Text(item.name)),
        )
        .toList(growable: false);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        int? helicopterId;
        int? licenseTypeId;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Aggiungi licenza'),
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
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: licenseTypeId,
                menuMaxHeight: 300,
                decoration: const InputDecoration(labelText: 'Tipo licenza'),
                items: licenseItems,
                onChanged: (value) =>
                    setDialogState(() => licenseTypeId = value),
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
                  if (helicopterId == null || licenseTypeId == null) {
                    return;
                  }
                  Navigator.of(dialogContext).pop({
                    'helicopter_type_id': helicopterId,
                    'license_type_id': licenseTypeId,
                  });
                },
                child: const Text('Aggiungi'),
              ),
            ],
          ),
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    final exists = _pendingLicenses.any(
      (item) =>
          item['helicopter_type_id'] == result['helicopter_type_id'] &&
          item['license_type_id'] == result['license_type_id'],
    );
    if (exists) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Licenza già presente.')));
      return;
    }

    setState(() => _pendingLicenses.add(result));
  }

  Future<void> _addCrew(List<HelicopterType> helicopterTypes) async {
    final helicopterItems = helicopterTypes
        .map(
          (item) =>
              DropdownMenuItem<int>(value: item.id, child: Text(item.name)),
        )
        .toList(growable: false);
    const crewTypeItems = [
      DropdownMenuItem(value: 'T', child: Text('T')),
      DropdownMenuItem(value: 'TOB', child: Text('TOB')),
    ];
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
              DropdownButtonFormField<String>(
                initialValue: crewType,
                menuMaxHeight: 300,
                decoration: const InputDecoration(labelText: 'Tipo equipaggio'),
                items: crewTypeItems,
                onChanged: (value) =>
                    setDialogState(() => crewType = value ?? 'T'),
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
                  });
                },
                child: const Text('Aggiungi'),
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

    setState(() => _pendingCrew.add(result));
  }

  Future<void> _addPrivilege(
    List<HelicopterType> helicopterTypes,
    List<PrivilegeType> privilegeTypes,
  ) async {
    final helicopterItems = helicopterTypes
        .map(
          (item) =>
              DropdownMenuItem<int>(value: item.id, child: Text(item.name)),
        )
        .toList(growable: false);
    final privilegeItems = privilegeTypes
        .map(
          (item) =>
              DropdownMenuItem<int>(value: item.id, child: Text(item.name)),
        )
        .toList(growable: false);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        int? helicopterId;
        int? privilegeTypeId;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Aggiungi privilegio'),
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
              DropdownButtonFormField<int>(
                initialValue: privilegeTypeId,
                menuMaxHeight: 300,
                decoration: const InputDecoration(
                  labelText: 'Privilegio manutentivo',
                ),
                items: privilegeItems,
                onChanged: (value) =>
                    setDialogState(() => privilegeTypeId = value),
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
                  if (helicopterId == null || privilegeTypeId == null) {
                    return;
                  }
                  Navigator.of(dialogContext).pop({
                    'helicopter_type_id': helicopterId,
                    'privilege_type_id': privilegeTypeId,
                  });
                },
                child: const Text('Aggiungi'),
              ),
            ],
          ),
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    final exists = _pendingPrivileges.any(
      (item) =>
          item['helicopter_type_id'] == result['helicopter_type_id'] &&
          item['privilege_type_id'] == result['privilege_type_id'],
    );
    if (exists) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Privilegio già presente.')));
      return;
    }

    setState(() => _pendingPrivileges.add(result));
  }

  Future<void> _addTobCapability(
    List<HelicopterType> helicopterTypes,
    List<TobCapability> tobCapabilities,
  ) async {
    final helicopterItems = helicopterTypes
        .map(
          (item) =>
              DropdownMenuItem<int>(value: item.id, child: Text(item.name)),
        )
        .toList(growable: false);
    final capabilityItems = tobCapabilities
        .map(
          (item) =>
              DropdownMenuItem<int>(value: item.id, child: Text(item.name)),
        )
        .toList(growable: false);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        int? helicopterId;
        int? capabilityId;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Aggiungi capacità TOB'),
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
              DropdownButtonFormField<int>(
                initialValue: capabilityId,
                menuMaxHeight: 300,
                decoration: const InputDecoration(labelText: 'Capacità TOB'),
                items: capabilityItems,
                onChanged: (value) =>
                    setDialogState(() => capabilityId = value),
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
                  if (helicopterId == null || capabilityId == null) {
                    return;
                  }
                  Navigator.of(dialogContext).pop({
                    'helicopter_type_id': helicopterId,
                    'tob_capability_id': capabilityId,
                  });
                },
                child: const Text('Aggiungi'),
              ),
            ],
          ),
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    final exists = _pendingTobCaps.any(
      (item) =>
          item['helicopter_type_id'] == result['helicopter_type_id'] &&
          item['tob_capability_id'] == result['tob_capability_id'],
    );
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capacità TOB già presente.')),
      );
      return;
    }

    setState(() => _pendingTobCaps.add(result));
  }

  String _helicopterLabel(List<HelicopterType> items, int helicopterId) {
    for (final item in items) {
      if (item.id == helicopterId) {
        return item.code;
      }
    }
    return 'N/D';
  }

  String _licenseLabel(List<LicenseType> items, int licenseTypeId) {
    for (final item in items) {
      if (item.id == licenseTypeId) {
        return item.name;
      }
    }
    return 'N/D';
  }

  String _privilegeLabel(List<PrivilegeType> items, int privilegeTypeId) {
    for (final item in items) {
      if (item.id == privilegeTypeId) {
        return item.name;
      }
    }
    return 'N/D';
  }

  String _tobCapabilityLabel(List<TobCapability> items, int capabilityId) {
    for (final item in items) {
      if (item.id == capabilityId) {
        return item.name;
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
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Campo obbligatorio'
                            : null,
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
                        validator: (value) => value == null || value.length < 6
                            ? 'Minimo 6 caratteri'
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
                      _PendingSection(
                        title: 'Tipo Licenza',
                        itemCount: _pendingLicenses.length,
                        emptyText: 'Nessuna licenza aggiunta.',
                        onAdd: () => _addLicense(helicopterTypes, licenseTypes),
                        addLabel: 'Aggiungi licenza',
                        children: _pendingLicenses
                            .asMap()
                            .entries
                            .map(
                              (entry) => ListTile(
                                title: Text(
                                  "${_helicopterLabel(helicopterTypes, entry.value['helicopter_type_id'] as int)} · ${_licenseLabel(licenseTypes, entry.value['license_type_id'] as int)}",
                                ),
                                trailing: IconButton(
                                  onPressed: () => setState(
                                    () => _pendingLicenses.removeAt(entry.key),
                                  ),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      _PendingSection(
                        title: 'Equipaggi di Volo',
                        itemCount: _pendingCrew.length,
                        emptyText: 'Nessun equipaggio aggiunto.',
                        onAdd: () => _addCrew(helicopterTypes),
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
                                    ? Text('Fascia ${entry.value['tob_grade']}')
                                    : null,
                                trailing: IconButton(
                                  onPressed: () => setState(
                                    () => _pendingCrew.removeAt(entry.key),
                                  ),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      _PendingSection(
                        title: 'Privilegi Manutentivi',
                        itemCount: _pendingPrivileges.length,
                        emptyText: 'Nessun privilegio aggiunto.',
                        onAdd: () =>
                            _addPrivilege(helicopterTypes, privilegeTypes),
                        addLabel: 'Aggiungi privilegio',
                        children: _pendingPrivileges
                            .asMap()
                            .entries
                            .map(
                              (entry) => ListTile(
                                title: Text(
                                  "${_helicopterLabel(helicopterTypes, entry.value['helicopter_type_id'] as int)} · ${_privilegeLabel(privilegeTypes, entry.value['privilege_type_id'] as int)}",
                                ),
                                trailing: IconButton(
                                  onPressed: () => setState(
                                    () =>
                                        _pendingPrivileges.removeAt(entry.key),
                                  ),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      _PendingSection(
                        title: 'Capacità TOB',
                        itemCount: _pendingTobCaps.length,
                        emptyText: 'Nessuna capacità TOB aggiunta.',
                        onAdd: () =>
                            _addTobCapability(helicopterTypes, tobCapabilities),
                        addLabel: 'Aggiungi capacità',
                        children: _pendingTobCaps
                            .asMap()
                            .entries
                            .map(
                              (entry) => ListTile(
                                title: Text(
                                  "${_helicopterLabel(helicopterTypes, entry.value['helicopter_type_id'] as int)} · ${_tobCapabilityLabel(tobCapabilities, entry.value['tob_capability_id'] as int)}",
                                ),
                                trailing: IconButton(
                                  onPressed: () => setState(
                                    () => _pendingTobCaps.removeAt(entry.key),
                                  ),
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
        title: Text('$title ($itemCount)'),
        children: [
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(emptyText),
              ),
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
