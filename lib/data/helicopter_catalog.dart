import 'package:flutter/material.dart';

// Descrizioni e schede tecniche disattivate il 2026-10-24: il testo è
// conservato nel vault (AVES Corsi/Catalogo elicotteri descrizioni.md).
const _withImage = {
  'AB206',
  'AB212',
  'AB412',
  'AW109',
  'AW129',
  'CH47',
  'NH90',
  'UH169B',
  'UH169D',
  'UH205',
};

/// Ritaglio senza sfondo dell'elicottero, null se il tipo non ne ha uno.
String? helicopterImage(String code) => _withImage.contains(code)
    ? 'assets/images/helicopters/${code.toLowerCase()}.webp'
    : null;

Color catalogAccent(String code) {
  switch (code) {
    case 'AB206':
      return const Color(0xFFFFC14D);
    case 'UH205':
      return const Color(0xFFFF8A65);
    case 'UH169B':
      return const Color(0xFF35C2FF);
    case 'UH169D':
      return const Color(0xFF7CF29A);
    case 'NH90':
      return const Color(0xFF5CE1E6);
    case 'AW129':
      return const Color(0xFFFF6B6B);
    case 'CH47':
      return const Color(0xFFE0B24A);
    case 'AW109':
      return const Color(0xFFA98BFF);
    case 'AB212':
      return const Color(0xFF64B5F6);
    case 'AB412':
      return const Color(0xFF81C784);
    default:
      return const Color(0xFFFFB300);
  }
}
