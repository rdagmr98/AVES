// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
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

/// Ultima vista scelta (2 pagine / 8 riquadri), resta per la sessione.
bool _panelsMode = false;

/// Riquadri della MAML in ordine I-III, IV-VII, VIII, IX-XI, XII, XIII, XIV,
/// XV: (pagina, quarto del foglio, capovolto). La metà bassa di pagina 1 è
/// stampata capovolta (si piega), quindi lì destra e sinistra si scambiano.
const _panels = [
  (0, Alignment.topRight, false),
  (0, Alignment.topLeft, false),
  (0, Alignment.bottomRight, true),
  (0, Alignment.bottomLeft, true),
  (1, Alignment.topLeft, false),
  (1, Alignment.topRight, false),
  (1, Alignment.bottomLeft, false),
  (1, Alignment.bottomRight, false),
];

class _MamlViewerState extends State<_MamlViewer> {
  late final Future<List<Uint8List>> _pages = () async {
    final bytes = await MamlScanService().load(widget.file);
    final mime = widget.file['mime'] as String? ?? '';
    if (mime.startsWith('image/')) return [bytes];
    return _pdfPages(bytes);
  }();

  /// Un quarto della pagina largo [w]: l'immagine è disegnata al doppio e
  /// ritagliata. ponytail: proporzioni A4 fisse, come tutte le MAML viste.
  Widget _panel(Uint8List page, Alignment at, double w) => SizedBox(
    width: w,
    height: w * math.sqrt2,
    child: ClipRect(
      child: OverflowBox(
        alignment: at,
        minWidth: 2 * w,
        maxWidth: 2 * w,
        minHeight: 2 * w * math.sqrt2,
        maxHeight: 2 * w * math.sqrt2,
        child: Image.memory(page, fit: BoxFit.fill),
      ),
    ),
  );

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
          if (snap.data?.length == 2)
            SegmentedButton<bool>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.description_outlined),
                  label: Text('2'),
                  tooltip: '2 pagine',
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.grid_view),
                  label: Text('8'),
                  tooltip: '8 riquadri',
                ),
              ],
              selected: {_panelsMode},
              onSelectionChanged: (s) => setState(() => _panelsMode = s.first),
            ),
          if (widget.canPrint)
            IconButton(
              tooltip: 'Stampa',
              icon: const Icon(Icons.print_outlined),
              onPressed: snap.hasData ? () => _print(snap.data!) : null,
            ),
          const SizedBox(width: 8),
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
                  child: _panelsMode && snap.data!.length == 2
                      ? Wrap(
                          alignment: WrapAlignment.center,
                          children: [
                            for (final (page, at, flip) in _panels)
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: RotatedBox(
                                  quarterTurns: flip ? 2 : 0,
                                  child: _panel(
                                    snap.data![page],
                                    at,
                                    math.min(box.maxWidth - 16, 420),
                                  ),
                                ),
                              ),
                          ],
                        )
                      : Column(
                          children: [
                            for (final p in snap.data!)
                              Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 900,
                                ),
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
    this.fab = false,
    this.onMissing,
  });

  final String userId;
  final String name;
  final bool canPrint;

  /// Pulsante tondo come il "+" (dashboard utente) invece dell'icona.
  final bool fab;
  final VoidCallback? onMissing;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: GhDbService().changes,
    builder: (context, _, _) {
      final rec = MamlScanService().record(userId);
      final file = (rec['approved'] ?? rec['pending']) as Map?;
      if (file == null && onMissing == null) return const SizedBox.shrink();
      final pendingOnly = rec['approved'] == null && file != null;
      final tooltip = file == null
          ? 'MAML: carica la scansione dal profilo'
          : pendingOnly
          ? 'MAML (in attesa di verifica)'
          : 'MAML';
      final VoidCallback? open = file == null
          ? onMissing
          : () => showMamlViewer(
              context,
              file,
              title: 'MAML · $name',
              canPrint: canPrint,
            );
      if (fab) {
        return FloatingActionButton(
          heroTag: null,
          tooltip: tooltip,
          onPressed: open,
          child: Badge(
            isLabelVisible: pendingOnly,
            backgroundColor: Colors.amber,
            child: const Icon(Icons.badge_outlined),
          ),
        );
      }
      return IconButton(
        tooltip: tooltip,
        icon: Icon(
          Icons.badge_outlined,
          color: pendingOnly ? Colors.amber : null,
        ),
        onPressed: open,
      );
    },
  );
}
