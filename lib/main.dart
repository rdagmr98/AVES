import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'config/gh_config.dart';
import 'services/gh_db_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!GhConfig.isConfigured) {
    runApp(const _SetupApp());
    return;
  }
  await GhDbService().init();
  runApp(const ProviderScope(child: AvesApp()));
}

class _SetupApp extends StatelessWidget {
  const _SetupApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AVES Currency - Setup',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B4332)),
      ),
      home: const _SetupScreen(),
    );
  }
}

class _SetupScreen extends StatelessWidget {
  const _SetupScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AVES Currency - Configurazione')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.settings, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Configurazione richiesta',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text(
                'Apri lib/config/gh_config.dart\n'
                'e inserisci il Read PAT per il repository aves-data.\n'
                'Vedi README.md per le istruzioni.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
