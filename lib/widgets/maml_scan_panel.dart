// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/maml_scan_service.dart';

/// Scansione MAML di [userId]: la vede il titolare e qualsiasi admin. Il
/// titolare la carica in attesa di verifica; un admin ([isAdmin]) la carica
/// già approvata e approva o rifiuta quella in attesa.
class MamlScanPanel extends StatefulWidget {
  const MamlScanPanel({
    super.key,
    required this.userId,
    required this.viewerId,
    required this.isAdmin,
  });

  final String userId;
  final String viewerId;
  final bool isAdmin;

  @override
  State<MamlScanPanel> createState() => _MamlScanPanelState();
}

class _MamlScanPanelState extends State<MamlScanPanel> {
  final _service = MamlScanService();
  bool _busy = false;

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _run(Future<void> Function() job, String done) async {
    setState(() => _busy = true);
    try {
      await job();
      if (mounted && done.isNotEmpty) _snack(done);
    } catch (e) {
      if (mounted) _snack('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _pick() {
    final input = html.FileUploadInputElement()
      ..accept = 'application/pdf,image/*';
    input.onChange.first.then((_) async {
      final f = input.files?.firstOrNull;
      if (f == null) return;
      final reader = html.FileReader()..readAsArrayBuffer(f);
      await reader.onLoadEnd.first;
      final r = reader.result;
      final bytes = r is ByteBuffer ? r.asUint8List() : r as Uint8List;
      await _run(
        () => _service.upload(
          widget.userId,
          bytes,
          f.type.isEmpty ? 'application/pdf' : f.type,
          byId: widget.viewerId,
          approved: widget.isAdmin,
        ),
        widget.isAdmin
            ? 'Scansione caricata.'
            : 'Scansione inviata: un admin la verificherà.',
      );
    });
    input.click();
  }

  Future<void> _view(Map file) async {
    // Aperta subito, dentro il gesto: dopo l'await il browser la bloccherebbe.
    final win = html.window.open('', '_blank');
    setState(() => _busy = true);
    try {
      final bytes = await _service.load(Map<String, dynamic>.from(file));
      // ponytail: URL del blob mai revocato, lo libera la chiusura della scheda.
      final url = html.Url.createObjectUrlFromBlob(
        html.Blob([bytes], file['mime'] as String? ?? 'application/pdf'),
      );
      try {
        win.location.href = url;
      } catch (_) {
        html.AnchorElement(href: url)
          ..setAttribute('download', 'MAML')
          ..click();
      }
    } catch (e) {
      win.close();
      if (mounted) _snack('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rifiuta scansione'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              hintText: 'Motivo per l\'utente (facoltativo)',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Rifiuta'),
          ),
        ],
      ),
    );
    final reason = ctrl.text;
    ctrl.dispose();
    if (ok == true) {
      await _run(
        () => _service.reject(widget.userId, reason: reason),
        'Scansione rifiutata.',
      );
    }
  }

  String _when(Map file) {
    final at = DateTime.tryParse(file['at'] as String? ?? '');
    final kind = (file['mime'] as String? ?? '').startsWith('image/')
        ? 'immagine'
        : 'PDF';
    return at == null
        ? kind
        : '$kind del ${DateFormat('dd/MM/yyyy').format(at)}';
  }

  Widget _row(IconData icon, Color color, String text, List<Widget> actions) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Icon(icon, color: color, size: 20),
            Text(text),
            ...actions,
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final rec = _service.record(widget.userId);
    final approved = rec['approved'] as Map?;
    final pending = rec['pending'] as Map?;
    final off = _busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (approved != null)
          _row(
            Icons.verified_outlined,
            Colors.green,
            'Verificata · ${_when(approved)}',
            [
              TextButton.icon(
                onPressed: off ? null : () => _view(approved),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Visualizza'),
              ),
            ],
          )
        else
          _row(
            Icons.info_outline,
            Colors.grey,
            'Nessuna scansione verificata',
            const [],
          ),
        if (pending != null)
          _row(
            Icons.pending_outlined,
            Colors.amber,
            'In attesa di verifica · ${_when(pending)}',
            [
              TextButton.icon(
                onPressed: off ? null : () => _view(pending),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Visualizza'),
              ),
              if (widget.isAdmin) ...[
                FilledButton.icon(
                  onPressed: off
                      ? null
                      : () => _run(
                          () =>
                              _service.approve(widget.userId, widget.viewerId),
                          'Scansione approvata.',
                        ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Approva'),
                ),
                OutlinedButton.icon(
                  onPressed: off ? null : _reject,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Rifiuta'),
                ),
              ],
            ],
          ),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: off ? null : _pick,
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: Text(
                widget.isAdmin ? 'Carica scansione' : 'Invia per verifica',
              ),
            ),
            if (off) ...[
              const SizedBox(width: 12),
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        Text(
          'PDF o foto, massimo 8 MB.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
