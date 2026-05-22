import 'package:flutter/material.dart';

import '../services/gh_db_service.dart';

class AdminWritePatButton extends StatefulWidget {
  const AdminWritePatButton({super.key});

  @override
  State<AdminWritePatButton> createState() => _AdminWritePatButtonState();
}

class _AdminWritePatButtonState extends State<AdminWritePatButton> {
  bool get _configured => GhDbService().hasWritePat;

  Future<void> _openDialog() async {
    final controller = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    var obscure = true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogBodyContext, setDialogState) => AlertDialog(
          title: const Text('Write PAT GitHub'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _configured
                    ? 'PAT già configurato su questo browser. Puoi aggiornarlo o rimuoverlo.'
                    : 'Inserisci il Fine-Grained PAT con permessi di scrittura sul repository aves-data.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Write PAT',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () => setDialogState(() => obscure = !obscure),
                    icon: Icon(
                      obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            if (_configured)
              TextButton(
                onPressed: () async {
                  await GhDbService().clearWritePat();
                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }
                  Navigator.of(dialogContext).pop();
                  setState(() {});
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Write PAT rimosso.')),
                  );
                },
                child: const Text('Rimuovi'),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () async {
                final pat = controller.text.trim();
                if (pat.isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Inserisci un PAT valido.')),
                  );
                  return;
                }
                await GhDbService().setWritePat(pat);
                if (!mounted || !dialogContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop();
                setState(() {});
                messenger.showSnackBar(
                  const SnackBar(content: Text('Write PAT salvato.')),
                );
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _openDialog,
      icon: Icon(_configured ? Icons.key : Icons.key_outlined),
      label: Text(_configured ? 'Write PAT configurato' : 'Configura Write PAT'),
    );
  }
}
