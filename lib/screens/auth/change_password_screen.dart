import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';

/// Cambio obbligatorio dopo il reset dell'admin. Ci porta il redirect del router,
/// che riporta alla home appena `mustChangePassword` cade. "Esci" serve a chi ha
/// una sessione ripristinata e non conosce la password temporanea.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _tempCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _tempCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (_tempCtrl.text.isEmpty) {
      _showError('Inserisci la password temporanea.');
      return;
    }
    if (_newCtrl.text.isEmpty || _newCtrl.text != _confirmCtrl.text) {
      _showError('Verifica la nuova password inserita.');
      return;
    }
    if (_newCtrl.text == _tempCtrl.text) {
      _showError('Scegli una password diversa da quella temporanea.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(authProvider)
          .changePassword(_tempCtrl.text, _newCtrl.text);
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
      setState(() => _saving = false);
    }
  }

  Future<void> _requestReset() async {
    var message =
        'Richiesta inviata: gli amministratori ti daranno una password temporanea.';
    try {
      await ref.read(authProvider).requestPasswordReset();
    } catch (_) {
      message = 'Impossibile contattare il server. Riprova.';
    }
    if (mounted) _showError(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Scegli una nuova password'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'La password è stata reimpostata da un amministratore: '
                  'per continuare scegline una nuova.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _tempCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password temporanea',
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _saving ? null : _requestReset,
                    child: const Text('Password dimenticata?'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nuova password',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Conferma password',
                  ),
                ),
                const SizedBox(height: 24),
                if (_saving)
                  const Center(child: CircularProgressIndicator())
                else
                  ElevatedButton(onPressed: _save, child: const Text('SALVA')),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.read(authProvider).signOut(),
                  child: const Text('Esci'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
