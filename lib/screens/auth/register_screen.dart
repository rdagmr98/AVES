import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../constants/app_constants.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  static const _qualifiche = <String>[
    '1° Lgt',
    'M.llo',
    'S. Ten.',
    'Cap. Sc.',
    'Ten. Col.',
    'Altro',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _cognomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();

  String? _qualifica;
  int? _orgUnitId;
  bool _obscure = true;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _cognomeCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _licenseCtrl.dispose();
    super.dispose();
  }

  String? _validateLicense(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return RegExp(r'^EI\d{6}$').hasMatch(value.trim().toUpperCase())
        ? null
        : 'Formato richiesto: EI123456';
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_qualifica == null || _orgUnitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleziona qualifica e unità organizzativa.'),
        ),
      );
      return;
    }

    final auth = ref.read(authProvider);
    final ok = await auth.signUp(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      nome: _nomeCtrl.text.trim(),
      cognome: _cognomeCtrl.text.trim(),
      numeroLicenza: _licenseCtrl.text.trim().isEmpty
          ? null
          : _licenseCtrl.text.trim().toUpperCase(),
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

    await auth.updateProfile(
      auth.userProfile!.copyWith(qualifica: _qualifica, orgUnitId: _orgUnitId),
    );
    await auth.signOut();

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registrazione inviata'),
        content: const Text(
          'Il tuo account è stato creato correttamente. Resterà in attesa di approvazione da parte di un amministratore prima di poter utilizzare tutte le funzionalità.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final orgUnits = auth.orgUnits;

    return Scaffold(
      appBar: AppBar(title: const Text('Registrazione')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
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
                        controller: _emailCtrl,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) =>
                            value == null || !value.contains('@')
                            ? 'Email non valida'
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
                      TextFormField(
                        controller: _licenseCtrl,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9]'),
                          ),
                          LengthLimitingTextInputFormatter(8),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Numero licenza (EI123456)',
                        ),
                        validator: _validateLicense,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _qualifica,
                        decoration: const InputDecoration(
                          labelText: 'Qualifica',
                        ),
                        items: _qualifiche
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _qualifica = value),
                        validator: (value) =>
                            value == null ? 'Campo obbligatorio' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: _orgUnitId,
                        decoration: const InputDecoration(
                          labelText: 'Unità organizzativa',
                        ),
                        items: orgUnits
                            .map(
                              (unit) => DropdownMenuItem<int>(
                                value: unit.id,
                                child: Text('${unit.code} - ${unit.name}'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _orgUnitId = value),
                        validator: (value) =>
                            value == null ? 'Campo obbligatorio' : null,
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
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
