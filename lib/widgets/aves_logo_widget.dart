import 'package:flutter/material.dart';

/// Displays the AVES logo with an optional circular background.
class AvesLogoWidget extends StatelessWidget {
  const AvesLogoWidget({super.key, this.size = 36, this.withBackground = false});

  final double size;
  final bool withBackground;

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(
      'assets/images/aves_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (ctx, err, _) =>
          Icon(Icons.flight, size: size, color: Colors.white),
    );

    if (!withBackground) return img;

    return Container(
      width: size + 8,
      height: size + 8,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1B4332),
        border: Border.all(color: const Color(0xFFD4AC0D), width: 1.5),
      ),
      child: ClipOval(child: img),
    );
  }
}
