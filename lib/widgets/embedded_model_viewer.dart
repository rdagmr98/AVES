import 'package:flutter/widgets.dart';

import 'embedded_model_viewer_stub.dart'
    if (dart.library.html) 'embedded_model_viewer_web.dart'
    as impl;

class EmbeddedModelViewer extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return impl.EmbeddedModelViewer(
      key: key,
      src: src,
      alt: alt,
      autoRotate: autoRotate,
      minCameraOrbit: minCameraOrbit,
      maxCameraOrbit: maxCameraOrbit,
    );
  }
}
