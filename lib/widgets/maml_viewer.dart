// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/gh_db_service.dart';
import '../services/maml_scan_service.dart';

Future<void>? _pdfJs;

/// pdf.js (web/pdfjs/, v3.11.174) caricato alla prima apertura. `define`
/// nascosto durante il caricamento: con un loader AMD (build di debug)
/// pdf.js non esporrebbe `window.pdfjsLib`.
Future<void> _loadPdfJs() => _pdfJs ??= () async {
  final define = globalContext['define'];
  globalContext['define'] = null;
  final script = html.ScriptElement()..src = 'pdfjs/pdf.min.js';
  html.document.head!.append(script);
  try {
    await Future.any([
      script.onLoad.first,
      script.onError.first.then((_) => throw Exception('pdf.js non caricato')),
    ]);
  } catch (_) {
    _pdfJs = null;
    rethrow;
  } finally {
    globalContext['define'] = define;
  }
  final lib = globalContext['pdfjsLib'] as JSObject;
  (lib['GlobalWorkerOptions'] as JSObject)['workerSrc'] =
      'pdfjs/pdf.worker.min.js'.toJS;
}();

JSObject _obj(Map<String, JSAny?> m) {
  final o = JSObject();
  m.forEach((k, v) => o[k] = v);
  return o;
}

double _num(JSObject o, String k) => (o[k] as JSNumber).toDartDouble;

/// Pagine del PDF come JPEG larghe ~1800 px (circa 220 dpi su A4).
Future<List<Uint8List>> _pdfPages(Uint8List pdf) async {
  await _loadPdfJs();
  final lib = globalContext['pdfjsLib'] as JSObject;
  // Copia: pdf.js trasferisce il buffer al worker e lo svuota.
  final task = lib.callMethod<JSObject>(
    'getDocument'.toJS,
    _obj({'data': Uint8List.fromList(pdf).toJS}),
  );
  final doc = await (task['promise'] as JSPromise<JSObject>).toDart;
  final document = globalContext['document'] as JSObject;
  final pages = <Uint8List>[];
  for (var i = 1; i <= _num(doc, 'numPages'); i++) {
    final page = await doc
        .callMethod<JSPromise<JSObject>>('getPage'.toJS, i.toJS)
        .toDart;
    final base = page.callMethod<JSObject>(
      'getViewport'.toJS,
      _obj({'scale': 1.toJS}),
    );
    final vp = page.callMethod<JSObject>(
      'getViewport'.toJS,
      _obj({'scale': (1800 / _num(base, 'width')).toJS}),
    );
    final canvas = document.callMethod<JSObject>(
      'createElement'.toJS,
      'canvas'.toJS,
    );
    canvas['width'] = _num(vp, 'width').ceil().toJS;
    canvas['height'] = _num(vp, 'height').ceil().toJS;
    final ctx = canvas.callMethod<JSObject>('getContext'.toJS, '2d'.toJS);
    final render = page.callMethod<JSObject>(
      'render'.toJS,
      _obj({'canvasContext': ctx, 'viewport': vp}),
    );
    await (render['promise'] as JSPromise).toDart;
    final url = canvas
        .callMethod<JSString>('toDataURL'.toJS, 'image/jpeg'.toJS, 0.92.toJS)
        .toDart;
    pages.add(base64Decode(url.split(',').last));
  }
  return pages;
}

/// Stampa le pagine già disegnate da un iframe nascosto: stessa resa per PDF e
/// foto, senza dipendere dal visualizzatore PDF del browser.
void _print(List<Uint8List> pages) {
  html.document.getElementById('maml-print')?.remove();
  final imgs = pages
      .map(
        (p) =>
            '<img src="${html.Url.createObjectUrlFromBlob(html.Blob([p]))}">',
      )
      .join();
  html.document.body!.append(
    html.IFrameElement()
      ..id = 'maml-print'
      ..style.cssText =
          'position:fixed;right:0;bottom:0;width:0;height:0;border:0'
      ..srcdoc =
          '<style>@page{margin:10mm}body{margin:0}img{display:block;width:100%;'
          'max-height:100vh;object-fit:contain;break-after:page}</style>'
          '<body onload="print()">$imgs</body>',
  );
}

/// Scansione a tutto schermo dentro l'app, con zoom; [canPrint] solo admin.
Future<void> showMamlViewer(
  BuildContext context,
  Map file, {
  required String title,
  bool canPrint = false,
}) => showDialog<void>(
  context: context,
  builder: (_) => Dialog.fullscreen(
    child: _MamlViewer(
      file: Map<String, dynamic>.from(file),
      title: title,
      canPrint: canPrint,
    ),
  ),
);

class _MamlViewer extends StatefulWidget {
  const _MamlViewer({
    required this.file,
    required this.title,
    required this.canPrint,
  });

  final Map<String, dynamic> file;
  final String title;
  final bool canPrint;

  @override
  State<_MamlViewer> createState() => _MamlViewerState();
}

class _MamlViewerState extends State<_MamlViewer> {
  late final Future<List<Uint8List>> _pages = () async {
    final bytes = await MamlScanService().load(widget.file);
    final mime = widget.file['mime'] as String? ?? '';
    if (mime.startsWith('image/')) return [bytes];
    return _pdfPages(bytes);
  }();

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Uint8List>>(
    future: _pages,
    builder: (context, snap) => Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Chiudi',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (widget.canPrint)
            IconButton(
              tooltip: 'Stampa',
              icon: const Icon(Icons.print_outlined),
              onPressed: snap.hasData ? () => _print(snap.data!) : null,
            ),
        ],
      ),
      body: snap.hasError
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${snap.error}'.replaceFirst('Exception: ', ''),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : !snap.hasData
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, box) => InteractiveViewer(
                constrained: false,
                maxScale: 6,
                child: SizedBox(
                  width: box.maxWidth,
                  child: Column(
                    children: [
                      for (final p in snap.data!)
                        Container(
                          constraints: const BoxConstraints(maxWidth: 900),
                          padding: const EdgeInsets.all(8),
                          child: Image.memory(p),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    ),
  );
}

/// Icona MAML per le schede: apre la scansione approvata (o quella in attesa).
/// Senza scansione si nasconde, salvo [onMissing] (es. vai al profilo).
class MamlButton extends StatelessWidget {
  const MamlButton({
    super.key,
    required this.userId,
    required this.name,
    this.canPrint = false,
    this.onMissing,
  });

  final String userId;
  final String name;
  final bool canPrint;
  final VoidCallback? onMissing;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: GhDbService().changes,
    builder: (context, _, _) {
      final rec = MamlScanService().record(userId);
      final file = (rec['approved'] ?? rec['pending']) as Map?;
      if (file == null && onMissing == null) return const SizedBox.shrink();
      final pendingOnly = rec['approved'] == null && file != null;
      return IconButton(
        tooltip: file == null
            ? 'MAML: carica la scansione dal profilo'
            : pendingOnly
            ? 'MAML (in attesa di verifica)'
            : 'MAML',
        icon: Icon(
          Icons.badge_outlined,
          color: pendingOnly ? Colors.amber : null,
        ),
        onPressed: file == null
            ? onMissing
            : () => showMamlViewer(
                context,
                file,
                title: 'MAML · $name',
                canPrint: canPrint,
              ),
      );
    },
  );
}
