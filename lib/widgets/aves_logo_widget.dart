import 'package:flutter/material.dart';

class AvesLogoWidget extends StatelessWidget {
  const AvesLogoWidget({
    super.key,
    this.size = 36,
    this.withBackground = false,
  });

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
      width: size + 16,
      height: size + 16,
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: img,
    );
  }
}
