import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import 'embedded_model_viewer.dart';

enum HelicopterViewerMode { normal, hologram }

class HelicopterViewerWidget extends StatefulWidget {
  const HelicopterViewerWidget({
    super.key,
    required this.normalModelAsset,
    required this.hologramModelAsset,
    required this.accent,
    required this.alt,
  });

  final String normalModelAsset;
  final String hologramModelAsset;
  final Color accent;
  final String alt;

  @override
  State<HelicopterViewerWidget> createState() => _HelicopterViewerWidgetState();
}

class _HelicopterViewerWidgetState extends State<HelicopterViewerWidget> {
  HelicopterViewerMode _mode = HelicopterViewerMode.normal;

  @override
  Widget build(BuildContext context) {
    final isHologram = _mode == HelicopterViewerMode.hologram;
    final modelSrc =
        isHologram ? widget.hologramModelAsset : widget.normalModelAsset;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 520;
            final selector = SegmentedButton<HelicopterViewerMode>(
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: const [
                ButtonSegment(
                  value: HelicopterViewerMode.normal,
                  icon: Icon(Icons.view_in_ar_outlined, size: 18),
                  label: Text('Normale'),
                ),
                ButtonSegment(
                  value: HelicopterViewerMode.hologram,
                  icon: Icon(Icons.blur_on, size: 18),
                  label: Text('Ologramma'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (value) {
                setState(() => _mode = value.first);
              },
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (compact) ...[
                  Text(
                    'Modello 3D',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerLeft, child: selector),
                ] else
                  Row(
                    children: [
                      Text(
                        'Modello 3D',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      selector,
                    ],
                  ),
                const SizedBox(height: 12),
                Text(
                  'Modello 3D reale con rotazione touch. Trascina per orbitare, pizzica per zoommare.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(
                    minHeight: 320,
                    maxHeight: 420,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: isHologram
                          ? [
                              widget.accent.withValues(alpha: 0.16),
                              AppColors.primary,
                              const Color(0xFF03111F),
                            ]
                          : [
                              AppColors.surfaceVariant,
                              AppColors.surface,
                              AppColors.primaryDark,
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: isHologram
                          ? widget.accent.withValues(alpha: 0.58)
                          : AppColors.border,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.accent.withValues(
                          alpha: isHologram ? 0.28 : 0.12,
                        ),
                        blurRadius: isHologram ? 28 : 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: EmbeddedModelViewer(
                          key: ValueKey(modelSrc),
                          src: modelSrc,
                          alt: widget.alt,
                          autoRotate: true,
                          minCameraOrbit: 'auto auto 65%',
                          maxCameraOrbit: 'auto auto 250%',
                        ),
                      ),
                      if (isHologram)
                        IgnorePointer(
                          child: CustomPaint(
                            painter: _ScanlinePainter(accent: widget.accent),
                          ),
                        ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: widget.accent.withValues(alpha: 0.35),
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Text('Touch = orbita / zoom'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  const _ScanlinePainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = accent.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 8) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [accent.withValues(alpha: 0.18), Colors.transparent],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width / 2, size.height / 2),
              radius: math.max(size.width, size.height) * 0.45,
            ),
          );
    canvas.drawRect(Offset.zero & size, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter oldDelegate) =>
      oldDelegate.accent != accent;
}
