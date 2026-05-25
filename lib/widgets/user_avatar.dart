import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/user_models.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.user,
    this.radius = 22,
    this.backgroundColor,
    this.textStyle,
  });

  final UserProfile user;
  final double radius;
  final Color? backgroundColor;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final bytes = _decodePhoto(user.profilePhotoBase64);
    if (bytes != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.transparent,
        backgroundImage: MemoryImage(bytes),
      );
    }

    final theme = Theme.of(context);
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? theme.colorScheme.primary,
      child: Text(
        buildUserInitials('${user.nome} ${user.cognome}'),
        style:
            textStyle ??
            theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Uint8List? _decodePhoto(String? encoded) {
    if (encoded == null || encoded.trim().isEmpty) {
      return null;
    }
    try {
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }
}

String buildUserInitials(String value) {
  final parts = value
      .split(RegExp(r'\s+'))
      .where((part) => part.trim().isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return 'AV';
  }
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}
