import 'package:flutter/material.dart';

import '../models/reference_models.dart';

class HelicopterCatalogEntry {
  final String code;
  final String title;
  final String subtitle;
  final String description;
  final String? imageAsset;
  final String? normalModelAsset;
  final String? hologramModelAsset;
  final List<(String label, String value)> specs;

  const HelicopterCatalogEntry({
    required this.code,
    required this.title,
    required this.subtitle,
    required this.description,
    this.imageAsset,
    this.normalModelAsset,
    this.hologramModelAsset,
    required this.specs,
  });
}

const _catalog = <String, HelicopterCatalogEntry>{
  'UH169B': HelicopterCatalogEntry(
    code: 'UH169B',
    title: 'UH-169B',
    subtitle: 'Piattaforma utility / addestrativa di nuova generazione',
    description:
        'Configurazione ideale per familiarizzazione operativa, training e missioni utility leggere. Cabina digitale, profilo moderno e impiego versatile.',
    imageAsset: 'assets/images/helicopters/aw169b.jpg',
    normalModelAsset: 'assets/models/helicopters/uh169b_normal.glb',
    hologramModelAsset: 'assets/models/helicopters/uh169b_hologram.glb',
    specs: [
      ('Categoria', 'Elicottero utility leggero'),
      ('Propulsione', 'Bimotore'),
      ('Rotore principale', '5 pale'),
      ('Impiego', 'Training, utility, supporto'),
      ('Avionica', 'Glass cockpit'),
    ],
  ),
  'UH169D': HelicopterCatalogEntry(
    code: 'UH169D',
    title: 'UH-169D',
    subtitle: 'Piattaforma multiruolo operativa',
    description:
        'Versione orientata all’impiego operativo, con configurazione adatta a missioni utility, supporto tattico e profili avanzati su piattaforma moderna.',
    imageAsset: 'assets/images/helicopters/aw169d.jpg',
    normalModelAsset: 'assets/models/helicopters/uh169d_normal.glb',
    hologramModelAsset: 'assets/models/helicopters/uh169d_hologram.glb',
    specs: [
      ('Categoria', 'Elicottero multiruolo'),
      ('Propulsione', 'Bimotore'),
      ('Rotore principale', '5 pale'),
      ('Impiego', 'Supporto tattico, utility, missioni operative'),
      ('Avionica', 'Glass cockpit evoluta'),
    ],
  ),
};

HelicopterCatalogEntry catalogForHelicopter(HelicopterType helicopter) {
  return _catalog[helicopter.code] ??
      HelicopterCatalogEntry(
        code: helicopter.code,
        title: helicopter.name,
        subtitle: 'Piattaforma assegnata al profilo utente',
        description:
            'Scheda sintetica del velivolo con qualifiche, ruoli equipaggio e privilegi associati al tuo profilo.',
        normalModelAsset:
            'assets/models/helicopters/${helicopter.code.toLowerCase()}_normal.glb',
        hologramModelAsset:
            'assets/models/helicopters/${helicopter.code.toLowerCase()}_hologram.glb',
        specs: [
          ('Codice', helicopter.code),
          ('Denominazione', helicopter.name),
          ('Profilo', 'Operativo AVES'),
        ],
      );
}

Color catalogAccent(String code) {
  switch (code) {
    case 'UH169B':
      return const Color(0xFF35C2FF);
    case 'UH169D':
      return const Color(0xFF7CF29A);
    default:
      return const Color(0xFFFFB300);
  }
}
