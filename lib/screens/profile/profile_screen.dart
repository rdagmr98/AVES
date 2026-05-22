import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../models/user_models.dart';
import '../../widgets/privilege_grid_widget.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _cognomeCtrl;
  late final TextEditingController _qualificaCtrl;
  late final TextEditingController _licenzaCtrl;
  int? _orgUnitId;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(authProvider).userProfile;
    _nomeCtrl = TextEditingController(text: profile?.nome ?? '');
    _cognomeCtrl = TextEditingController(text: profile?.cognome ?? '');
    _qualificaCtrl = TextEditingController(text: profile?.qualifica ?? '');
    _licenzaCtrl = TextEditingController(text: profile?.numeroLicenza ?? '');
    _orgUnitId = profile?.orgUnitId;
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _cognomeCtrl.dispose();
    _qualificaCtrl.dispose();
    _licenzaCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final auth = ref.read(authProvider);
    final profile = auth.userProfile;
    if (profile == null) {
      return;
    }
    await auth.updateProfile(
      profile.copyWith(
        nome: _nomeCtrl.text.trim(),
        cognome: _cognomeCtrl.text.trim(),
        qualifica: _qualificaCtrl.text.trim(),
        orgUnitId: _orgUnitId,
      ),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profilo aggiornato con successo.')),
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
              await ref.read(authProvider).changePassword(newPasswordCtrl.text);
              if (!mounted || !dialogContext.mounted) {
                return;
              }
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password aggiornata.')),
              );
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );

    newPasswordCtrl.dispose();
    confirmPasswordCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final profile = auth.userProfile;
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilo'),
        actions: [
          IconButton(
            onPressed: _saveProfile,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
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
                    controller: _qualificaCtrl,
                    decoration: const InputDecoration(labelText: 'Qualifica'),
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
                            child: Text('${item.code} - ${item.name}'),
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
          _SectionCard(
            title: 'Licenze',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: auth.licenses.isEmpty
                  ? const [Text('Nessuna licenza assegnata.')]
                  : auth.licenses
                        .map(
                          (item) => Chip(
                            label: Text(
                              '${item.helicopterCode} · ${item.licenseName}',
                            ),
                          ),
                        )
                        .toList(),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Privilegi',
            child: PrivilegeGridWidget(privileges: auth.privileges),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Assegnazioni equipaggio',
            child: _CrewAssignmentsList(assignments: auth.crewAssignments),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Capacità TOB',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: auth.tobCapabilities.isEmpty
                  ? const [Text('Nessuna capacità TOB assegnata.')]
                  : auth.tobCapabilities
                        .map(
                          (item) => Chip(
                            label: Text(
                              '${item.helicopterCode} · ${item.capabilityName}',
                            ),
                            avatar: const Icon(
                              Icons.build_circle_outlined,
                              size: 18,
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _CrewAssignmentsList extends StatelessWidget {
  const _CrewAssignmentsList({required this.assignments});

  final List<UserCrewAssignment> assignments;

  @override
  Widget build(BuildContext context) {
    if (assignments.isEmpty) {
      return const Text('Nessuna assegnazione equipaggio.');
    }

    return Column(
      children: assignments
          .map(
            (assignment) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flight_takeoff_outlined),
              title: Text(
                '${assignment.helicopterCode} · ${assignment.crewType}',
              ),
              subtitle: Text(
                assignment.fascia == null
                    ? assignment.helicopterName
                    : 'Fascia TOB ${assignment.fascia}',
              ),
            ),
          )
          .toList(),
    );
  }
}
