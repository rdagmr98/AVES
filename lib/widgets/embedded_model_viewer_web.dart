// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

class EmbeddedModelViewer extends StatefulWidget {
  const EmbeddedModelViewer({
    super.key,
    required this.src,
    required this.alt,
    this.autoRotate = true,
    this.minCameraOrbit,
    this.maxCameraOrbit,
  });

  final String src;
  final String alt;
  final bool autoRotate;
  final String? minCameraOrbit;
  final String? maxCameraOrbit;

  @override
  State<EmbeddedModelViewer> createState() => _EmbeddedModelViewerState();
}

class _EmbeddedModelViewerState extends State<EmbeddedModelViewer> {
  late final String _viewType;
  late final String _resolvedSrc;

  @override
  void initState() {
    super.initState();
    final baseUri = html.document.baseUri;
    _resolvedSrc = baseUri == null
        ? widget.src
        : Uri.parse(baseUri).resolve(widget.src).toString();
    _viewType =
        'embedded-model-viewer-${DateTime.now().microsecondsSinceEpoch}-${widget.src.hashCode}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, _buildElement);
  }

  Object _buildElement(int viewId) {
    final wrapper = html.DivElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.background = 'transparent'
      ..style.display = 'block';

    final model = html.Element.tag('model-viewer')
      ..setAttribute('src', _resolvedSrc)
      ..setAttribute('alt', widget.alt)
      ..setAttribute('camera-controls', '')
      ..setAttribute('touch-action', 'pan-y')
      ..setAttribute('interaction-prompt', 'auto')
      ..setAttribute('shadow-intensity', '0')
      ..setAttribute('shadow-softness', '0')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.display = 'block'
      ..style.background = 'transparent';

    if (widget.autoRotate) {
      model.setAttribute('auto-rotate', '');
      model.setAttribute('auto-rotate-delay', '0');
    }
    if (widget.minCameraOrbit != null) {
      model.setAttribute('min-camera-orbit', widget.minCameraOrbit!);
    }
    if (widget.maxCameraOrbit != null) {
      model.setAttribute('max-camera-orbit', widget.maxCameraOrbit!);
    }

    wrapper.children.add(model);
    return wrapper;
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
