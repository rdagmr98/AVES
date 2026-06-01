import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../constants/app_constants.dart';
import '../../services/p66_service.dart';
import '../../services/report_service.dart';
import '../../widgets/admin_app_bar_leading.dart';
import '../../widgets/aves_logo_widget.dart';
import '../../widgets/user_avatar.dart';

class AdminP66Dashboard extends ConsumerStatefulWidget {
  const AdminP66Dashboard({super.key});

  @override
  ConsumerState<AdminP66Dashboard> createState() => _AdminP66DashboardState();
}

class _AdminP66DashboardState extends ConsumerState<AdminP66Dashboard> {
  final _p66Service = P66Service();
  final _reportService = ReportService();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  bool _gridView = true;
  String _search = '';
  List<P66UserData> _rows = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final rows = await _p66Service.getAllP66Data();
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  List<P66UserData> _filteredRows() {
    final search = _search.trim().toLowerCase();
    if (search.isEmpty) {
      return _rows;
    }
    return _rows
        .where((row) {
          return row.user.fullName.toLowerCase().contains(search) ||
              row.licenseNumber.toLowerCase().contains(search);
        })
        .toList(growable: false);
  }

  Color _backgroundColor(P66Status status) => switch (status) {
    P66Status.noGo => const Color(0xFF3A0A0A),
    P66Status.warning => const Color(0xFF3A2A0A),
    P66Status.go => const Color(0xFF1A3A1A),
  };

  Color _borderColor(P66Status status) => switch (status) {
    P66Status.noGo => const Color(0xFFC0392B),
    P66Status.warning => const Color(0xFFE67E22),
    P66Status.go => const Color(0xFF27AE60),
  };

  Future<void> _showUserDetail(P66UserData row) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(row.user.fullName, textAlign: TextAlign.center),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                UserAvatar(user: row.user, radius: 30),
                const SizedBox(height: 12),
                Text(
                  '${row.monthCount}/24 mesi · ${row.statusText}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _borderColor(row.status),
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '${row.licenseTypes} · ${row.licenseNumber}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  row.seminarStatusText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: row.hasRequiredSeminars
                        ? const Color(0xFF27AE60)
                        : const Color(0xFFC0392B),
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(row.statusReason, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(
                  'Ultima attività: ${_formatDate(row.lastActivityDate)}',
                  textAlign: TextAlign.center,
                ),
                Text(
                  'Ultimo seminario: ${_formatDate(row.lastSeminarDate)}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Mesi coperti (24 mesi)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: row.coveredMonths.isEmpty
                      ? const [Chip(label: Text('Nessuna attività valida'))]
                      : row.coveredMonths
                            .map((month) => Chip(label: Text(month)))
                            .toList(),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Seminari validi (24 mesi)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (row.validSeminars.isEmpty)
                      const Chip(label: Text('Nessun seminario valido')),
                    ...row.validSeminars.map((type) => Chip(label: Text(type))),
                    ...row.missingSeminars.map(
                      (type) => Chip(label: Text('Manca $type')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  Widget _buildUserGrid(List<P66UserData> rows) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 110,
        childAspectRatio: 1.0,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemBuilder: (context, index) {
        final row = rows[index];
        return InkWell(
          onTap: () => _showUserDetail(row),
          borderRadius: BorderRadius.circular(16),
          child: Card(
            color: _backgroundColor(row.status),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: _borderColor(row.status), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
                children: [
                Expanded(
                  child: Center(
                    child: UserAvatar(user: row.user, radius: 16),
                  ),
                ),
                Text(
                  row.user.nome,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
                Text(
                  row.user.cognome,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildListView(List<P66UserData> rows) {
    return rows
        .map(
          (row) => Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _showUserDetail(row),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              UserAvatar(user: row.user, radius: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      row.user.fullName,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                      softWrap: true,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${row.licenseTypes} · ${row.licenseNumber}',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _backgroundColor(row.status),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: _borderColor(row.status)),
                          ),
                          child: Text(
                            '${row.monthCount}/24 · ${row.statusText}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        row.coveredMonths.isEmpty
                            ? 'Mesi attività: nessuna attività valida'
                            : 'Mesi attività: ${row.coveredMonths.join(', ')}',
                        softWrap: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Seminari: ${row.seminarStatusText}',
                        style: TextStyle(
                          color: row.hasRequiredSeminars
                              ? const Color(0xFF27AE60)
                              : const Color(0xFFC0392B),
                          fontWeight: FontWeight.w700,
                        ),
                        softWrap: true,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(row.statusReason, softWrap: true),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .toList(growable: false);
  }

  Widget _buildNavigationSidebar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Navigazione', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _NavButton(
              label: 'Dashboard Principale',
              icon: Icons.dashboard_outlined,
              onTap: () => context.go('/admin/priv'),
            ),
            const SizedBox(height: 8),
            _NavButton(
              label: 'Gestione Utenti',
              icon: Icons.manage_accounts_outlined,
              onTap: () => context.go('/admin/users'),
            ),
            const SizedBox(height: 8),
            _NavButton(
              label: 'Valida Attività',
              icon: Icons.verified_outlined,
              onTap: () => context.go('/admin/validate'),
            ),
            const SizedBox(height: 8),
            _NavButton(
              label: 'Gestione PTA',
              icon: Icons.block_outlined,
              onTap: () => context.go('/admin/pta'),
            ),
            const SizedBox(height: 8),
            _NavButton(
              label: 'Inserisci Attività',
              icon: Icons.add_task_outlined,
              onTap: () => context.go('/admin/insert'),
            ),
            const SizedBox(height: 8),
            _NavButton(
              label: 'Report P-66',
              icon: Icons.picture_as_pdf_outlined,
              onTap: _reportService.downloadP66Report,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final rows = _filteredRows();
    final goCount = _rows.where((row) => row.status == P66Status.go).length;
    final warningCount = _rows
        .where((row) => row.status == P66Status.warning)
        .length;
    final noGoCount = _rows.where((row) => row.status == P66Status.noGo).length;
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (!auth.isAdminPriv) {
      return const Scaffold(
        body: Center(child: Text('Accesso riservato ad Admin CSL.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: const AdminAppBarLeading(fallbackRoute: '/admin/p66'),
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AvesLogoWidget(size: 32),
            const SizedBox(width: 8),
            Text(isMobile ? 'P-66' : 'Sezione P-66'),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => setState(() => _gridView = !_gridView),
            icon: Icon(_gridView ? Icons.view_list : Icons.grid_view),
            tooltip: _gridView ? 'Vista estesa' : 'Vista compatta',
          ),
          IconButton(
            onPressed: _reportService.downloadP66Report,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Scarica report P-66',
          ),
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: () async {
              await ref.read(authProvider).signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 1200;
                final statCards = [
                  _P66StatCard(
                    title: 'Utenti P-66',
                    value: '${_rows.length}',
                    icon: Icons.groups,
                  ),
                  _P66StatCard(
                    title: 'GO',
                    value: '$goCount',
                    icon: Icons.check_circle,
                    color: const Color(0xFF27AE60),
                  ),
                  _P66StatCard(
                    title: 'Warning',
                    value: '$warningCount',
                    icon: Icons.warning_amber_rounded,
                    color: const Color(0xFFE67E22),
                  ),
                  _P66StatCard(
                    title: 'NO GO',
                    value: '$noGoCount',
                    icon: Icons.cancel,
                    color: const Color(0xFFC0392B),
                  ),
                ];

                final content = [
                  TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Cerca per nome o licenza',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => setState(() => _search = value),
                  ),
                  const SizedBox(height: 16),
                  Wrap(spacing: 16, runSpacing: 16, children: statCards),
                  const SizedBox(height: 24),
                  Text(
                    'Conformità P-66 e seminari (ultimi 24 mesi)',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  if (rows.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Nessun utente corrisponde ai filtri selezionati.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else if (_gridView)
                    _buildUserGrid(rows)
                  else
                    ..._buildListView(rows),
                ];

                if (isDesktop) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 300,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [_buildNavigationSidebar()],
                        ),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _loadData,
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: content,
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildNavigationSidebar(),
                      const SizedBox(height: 16),
                      ...content,
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _P66StatCard extends StatelessWidget {
  const _P66StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.secondary;
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label, softWrap: true),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
