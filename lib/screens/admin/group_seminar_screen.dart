import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../models/user_models.dart';
import '../../services/gh_db_service.dart';
import '../../services/user_service.dart';
import '../../widgets/aves_logo_widget.dart';

class GroupSeminarScreen extends ConsumerStatefulWidget {
  const GroupSeminarScreen({super.key});

  @override
  ConsumerState<GroupSeminarScreen> createState() => _GroupSeminarScreenState();
}

class _GroupSeminarScreenState extends ConsumerState<GroupSeminarScreen> {
  final _userService = UserService();
  final _db = GhDbService();
  final _searchCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  List<UserProfile> _allUsers = [];
  List<UserProfile> _filteredUsers = [];
  final Set<String> _selectedUserIds = {};
  DateTime _selectedDate = DateTime.now();
  String _seminarType = 'NAM';
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    final users = await _userService.getAllUsers();
    final approvedUsers = users.where((u) => u.isApprovedMaint).toList();
    approvedUsers.sort((a, b) => a.fullName.compareTo(b.fullName));

    if (!mounted) return;
    setState(() {
      _allUsers = approvedUsers;
      _filteredUsers = approvedUsers;
      _loading = false;
    });
  }

  void _updateSearch(String value) {
    setState(() {
      _search = value.trim().toLowerCase();
      if (_search.isEmpty) {
        _filteredUsers = _allUsers;
      } else {
        _filteredUsers = _allUsers
            .where((u) => u.fullName.toLowerCase().contains(_search))
            .toList();
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedUserIds.length == _filteredUsers.length) {
        _selectedUserIds.clear();
      } else {
        _selectedUserIds.clear();
        _selectedUserIds.addAll(_filteredUsers.map((u) => u.id));
      }
    });
  }

  Future<void> _saveSeminars() async {
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona almeno un partecipante.')),
      );
      return;
    }

    setState(() => _saving = true);

    final auth = ref.read(authProvider);
    final adminId = auth.userProfile?.id ?? 'admin_priv_001';
    final now = DateTime.now();
    final rows = _db.seminars.toList();
    final nextId = rows
        .map((item) => item['id'])
        .whereType<int>()
        .fold<int>(0, (maxId, id) => id > maxId ? id : maxId);

    var offset = 1;
    for (final userId in _selectedUserIds) {
      rows.add({
        'id': nextId + offset,
        'user_id': userId,
        'seminar_type': _seminarType,
        'seminar_date': _selectedDate.toIso8601String().split('T').first,
        'description': _noteCtrl.text.trim().isEmpty
            ? null
            : _noteCtrl.text.trim(),
        'is_validated': true,
        'submitted_by': adminId,
        'validated_by': adminId,
        'validated_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
      });
      offset++;
    }

    try {
      await _db.saveSeminars(rows);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Salvati ${rows.length} seminari $_seminarType.'),
        ),
      );
      context.go('/admin/priv');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Errore: $e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AvesLogoWidget(size: 32),
            const SizedBox(width: 8),
            Text(isMobile ? 'Seminario' : 'Inserisci Seminario'),
          ],
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dettagli Seminario',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                initialValue: _seminarType,
                                decoration: const InputDecoration(
                                  labelText: 'Tipo Seminario',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'NAM',
                                    child: Text('NAM'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'MHF',
                                    child: Text('MHF'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _seminarType = value);
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Data Seminario'),
                                subtitle: Text(
                                  DateFormat(
                                    'dd/MM/yyyy',
                                  ).format(_selectedDate),
                                ),
                                trailing: const Icon(Icons.calendar_today),
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null) {
                                    setState(() => _selectedDate = picked);
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _noteCtrl,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: 'Note (opzionale)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Partecipanti approvati (${_selectedUserIds.length}/${_filteredUsers.length})',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _toggleSelectAll,
                                    icon: Icon(
                                      _selectedUserIds.length ==
                                              _filteredUsers.length
                                          ? Icons.check_box
                                          : Icons.check_box_outline_blank,
                                    ),
                                    label: Text(
                                      _selectedUserIds.length ==
                                              _filteredUsers.length
                                          ? 'Deseleziona'
                                          : 'Seleziona',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _searchCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Cerca partecipante',
                                  prefixIcon: Icon(Icons.search),
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: _updateSearch,
                              ),
                              const SizedBox(height: 16),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 400,
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _filteredUsers.length,
                                  itemBuilder: (context, index) {
                                    final user = _filteredUsers[index];
                                    final isSelected = _selectedUserIds
                                        .contains(user.id);
                                    return CheckboxListTile(
                                      value: isSelected,
                                      title: Text(user.fullName),
                                      subtitle: Text(
                                        '${user.orgUnitName}${user.numeroLicenza != null ? ' • ${user.numeroLicenza}' : ''}',
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          if (value == true) {
                                            _selectedUserIds.add(user.id);
                                          } else {
                                            _selectedUserIds.remove(user.id);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _saving
                                ? null
                                : () => context.go('/admin/priv'),
                            child: const Text('Annulla'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _saving ? null : _saveSeminars,
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: const Text('Salva Seminari'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
