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
  'AB206': HelicopterCatalogEntry(
    code: 'AB206',
    title: 'AB 206',
    subtitle: 'Piattaforma leggera per collegamento, addestramento e utility',
    description:
        'Velivolo leggero storico della linea AVES, adatto a collegamento, osservazione, mantenimento capacità basiche e supporto addestrativo.',
    imageAsset: 'assets/images/helicopters/ab206.jpg',
    normalModelAsset: 'assets/models/helicopters/ab206_normal.glb',
    hologramModelAsset: 'assets/models/helicopters/ab206_hologram.glb',
    specs: [
      ('Categoria', 'Elicottero leggero utility'),
      ('Propulsione', 'Monoturbina'),
      ('Impiego', 'Collegamento, osservazione, addestramento'),
      ('Cabina', 'Compatta, equipaggio ridotto'),
      ('Profilo AVES', 'Baseline leggera e versatile'),
    ],
  ),
  'UH205': HelicopterCatalogEntry(
    code: 'UH205',
    title: 'UH-205',
    subtitle: 'Piattaforma utility media ad alta diffusione operativa',
    description:
        'Macchina robusta e polivalente, impiegata per trasporto leggero, supporto operativo, addestramento e missioni di utility generale.',
    imageAsset: 'assets/images/helicopters/uh205.jpg',
    normalModelAsset: 'assets/models/helicopters/uh205_normal.glb',
    hologramModelAsset: 'assets/models/helicopters/uh205_hologram.glb',
    specs: [
      ('Categoria', 'Elicottero utility medio'),
      ('Propulsione', 'Monoturbina'),
      ('Impiego', 'Trasporto, supporto, utility'),
      ('Cabina', 'Configurazione ampia e modulare'),
      ('Profilo AVES', 'Piattaforma storica multiruolo'),
    ],
  ),
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
  'NH90': HelicopterCatalogEntry(
    code: 'NH90',
    title: 'NH-90',
    subtitle: 'Piattaforma tattica multiruolo di fascia media',
    description:
        'Elicottero bimotore digitale adatto a missioni tattiche, trasporto, supporto e proiezione operativa con elevato livello di integrazione avionica.',
    imageAsset: 'assets/images/helicopters/nh90.jpg',
    normalModelAsset: 'assets/models/helicopters/nh90_normal.glb',
    hologramModelAsset: 'assets/models/helicopters/nh90_hologram.glb',
    specs: [
      ('Categoria', 'Elicottero tattico multiruolo'),
      ('Propulsione', 'Bimotore'),
      ('Impiego', 'Trasporto tattico, supporto, utility'),
      ('Cabina', 'Ampia, modulare, mission oriented'),
      ('Avionica', 'Suite digitale avanzata'),
    ],
  ),
  'AW129': HelicopterCatalogEntry(
    code: 'AW129',
    title: 'AW-129',
    subtitle: 'Piattaforma d’attacco e scorta',
    description:
        'Configurazione dedicata a ricognizione armata, protezione, supporto tattico e missioni ad alta manovrabilità nel dominio operativo AVES.',
    imageAsset: 'assets/images/helicopters/aw129.jpg',
    normalModelAsset: 'assets/models/helicopters/aw129_normal.glb',
    hologramModelAsset: 'assets/models/helicopters/aw129_hologram.glb',
    specs: [
      ('Categoria', 'Elicottero da attacco'),
      ('Propulsione', 'Bimotore'),
      ('Impiego', 'Scorta, ricognizione, supporto tattico'),
      ('Cabina', 'Tandem ad alta visibilità'),
      ('Profilo AVES', 'Combat / supporto avanzato'),
    ],
  ),
  'CH47': HelicopterCatalogEntry(
    code: 'CH47',
    title: 'CH-47F',
    subtitle: 'Piattaforma da trasporto pesante',
    description:
        'Velivolo ad alta capacità per trasporto uomini, materiali e carichi esterni, ideale per missioni logistiche, recupero e supporto pesante.',
    imageAsset: 'assets/images/helicopters/ch47.jpg',
    normalModelAsset: 'assets/models/helicopters/ch47_normal.glb',
    hologramModelAsset: 'assets/models/helicopters/ch47_hologram.glb',
    specs: [
      ('Categoria', 'Elicottero heavy lift'),
      ('Propulsione', 'Bimotore tandem'),
      ('Impiego', 'Trasporto pesante, recupero, logistica'),
      ('Cabina', 'Grande volume utile'),
      ('Profilo AVES', 'Lift strategico e tattico'),
    ],
  ),
  'AW109': HelicopterCatalogEntry(
    code: 'AW109',
    title: 'AW-109',
    subtitle: 'Piattaforma leggera ad alte prestazioni',
    description:
        'Elicottero leggero e veloce, utilizzabile per collegamento, utility rapida, ricognizione e supporto missione con impronta compatta.',
    imageAsset: 'assets/images/helicopters/aw109.jpg',
    normalModelAsset: 'assets/models/helicopters/aw109_normal.glb',
    hologramModelAsset: 'assets/models/helicopters/aw109_hologram.glb',
    specs: [
      ('Categoria', 'Elicottero leggero bimotore'),
      ('Propulsione', 'Bimotore'),
      ('Impiego', 'Collegamento, utility rapida, ricognizione'),
      ('Cabina', 'Compatta e performante'),
      ('Profilo AVES', 'Leggero ad alta mobilità'),
    ],
  ),
  'AB212': HelicopterCatalogEntry(
    code: 'AB212',
    title: 'AB-212',
    subtitle: 'Twin Huey – utility biturbina ad alta affidabilità',
    description:
        'Versione bimotore del classico UH-1, dotata di due turbine Pratt & Whitney PT6T-3 in una caratteristica navicella gemella. Impiegato per trasporto, SAR, supporto tattico e ricerca in ambito AVES.',
    imageAsset: 'assets/images/helicopters/ab212.jpg',
    normalModelAsset: 'assets/models/helicopters/ab212_normal.glb',
    hologramModelAsset: 'assets/models/helicopters/ab212_hologram.glb',
    specs: [
      ('Categoria', 'Elicottero utility medio'),
      ('Propulsione', 'Biturbina PT6T-3 accoppiata'),
      ('Rotore principale', '2 pale semi-rigide'),
      ('Impiego', 'Trasporto, SAR, utility, addestramento'),
      ('Profilo AVES', 'Piattaforma biturbina consolidata'),
    ],
  ),
  'AB412': HelicopterCatalogEntry(
    code: 'AB412',
    title: 'AB-412',
    subtitle: 'Griffone – rotore quadripala composito, alta capacità',
    description:
        "Evoluzione dell'AB-212 con rotore quadripala semi-rigido in materiale composito. Impronta acustica ridotta, migliori prestazioni e carico utile aumentato. Impiegato per SAR, trasporto tattico e supporto logistico.",
    imageAsset: 'assets/images/helicopters/ab412.jpg',
    normalModelAsset: 'assets/models/helicopters/ab412_normal.glb',
    hologramModelAsset: 'assets/models/helicopters/ab412_hologram.glb',
    specs: [
      ('Categoria', 'Elicottero utility medio-pesante'),
      ('Propulsione', 'Biturbina PT6T-3B'),
      ('Rotore principale', '4 pale composite semi-rigide'),
      ('Impiego', 'SAR, trasporto tattico, logistica, utility'),
      ('Profilo AVES', 'Evoluzione potenziata del Twin Huey'),
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
