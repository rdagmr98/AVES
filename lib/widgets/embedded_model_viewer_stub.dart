import 'package:flutter/material.dart';

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
    return const Center(
      child: Text('Il modello 3D e disponibile nella versione web.'),
    );
  }
}
