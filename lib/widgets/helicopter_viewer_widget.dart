import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

enum HelicopterViewerMode { normal, hologram }

class HelicopterViewerWidget extends StatefulWidget {
  const HelicopterViewerWidget({
    super.key,
    required this.imageAsset,
    required this.accent,
  });

  final String imageAsset;
  final Color accent;

  @override
  State<HelicopterViewerWidget> createState() => _HelicopterViewerWidgetState();
}

class _HelicopterViewerWidgetState extends State<HelicopterViewerWidget> {
  HelicopterViewerMode _mode = HelicopterViewerMode.normal;
  double _yaw = 0;
  double _pitch = 0;

  @override
  Widget build(BuildContext context) {
    final isHologram = _mode == HelicopterViewerMode.hologram;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Viewer interattivo',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                SegmentedButton<HelicopterViewerMode>(
                  segments: const [
                    ButtonSegment(
                      value: HelicopterViewerMode.normal,
                      icon: Icon(Icons.image_outlined),
                      label: Text('Normale'),
                    ),
                    ButtonSegment(
                      value: HelicopterViewerMode.hologram,
                      icon: Icon(Icons.blur_on),
                      label: Text('Ologramma'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (value) {
                    setState(() => _mode = value.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Trascina con il dito per ruotare la vista.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _yaw += details.delta.dx * 0.01;
                  _pitch = (_pitch - details.delta.dy * 0.006).clamp(-0.45, 0.45);
                });
              },
              onDoubleTap: () {
                setState(() {
                  _yaw = 0;
                  _pitch = 0;
                });
              },
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 260, maxHeight: 360),
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
                        ? widget.accent.withValues(alpha: 0.6)
                        : AppColors.border,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accent.withValues(alpha: isHologram ? 0.28 : 0.12),
                      blurRadius: isHologram ? 28 : 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (isHologram)
                      IgnorePointer(
                        child: CustomPaint(
                          painter: _ScanlinePainter(accent: widget.accent),
                        ),
                      ),
                    Center(
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0015)
                          ..rotateX(_pitch)
                          ..rotateY(_yaw),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: isHologram
                                  ? [
                                      widget.accent.withValues(alpha: 0.12),
                                      Colors.transparent,
                                    ]
                                  : [
                                      Colors.white.withValues(alpha: 0.04),
                                      Colors.transparent,
                                    ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                isHologram
                                    ? widget.accent.withValues(alpha: 0.42)
                                    : Colors.transparent,
                                isHologram ? BlendMode.screen : BlendMode.dst,
                              ),
                              child: Image.asset(
                                widget.imageAsset,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.32),
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
                          child: Text('Doppio tap = reset'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
      ..shader = RadialGradient(
        colors: [
          accent.withValues(alpha: 0.18),
          Colors.transparent,
        ],
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
