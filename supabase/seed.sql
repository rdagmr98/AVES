-- ============================================================
-- AVES - Dati iniziali (seed)
-- Eseguire DOPO schema.sql
-- ============================================================

-- Tipi di elicottero
INSERT INTO helicopter_types (code, name) VALUES
  ('RH-206C',   'Bell 206C-1 Ranger'),
  ('UH-205A',   'Bell 205A-1 Iroquois'),
  ('UH-169B',   'AgustaWestland AW169B'),
  ('UH-169D',   'AgustaWestland AW169D'),
  ('NH-90 TTH', 'NHI NH-90 Tactical Transport Helicopter'),
  ('AW129',     'AgustaWestland A129 Mangusta'),
  ('CH-47F',    'Boeing CH-47F Chinook'),
  ('AW109',     'AgustaWestland AW109')
ON CONFLICT (code) DO NOTHING;

-- Tipi di licenza manutentore aeronautico militare
INSERT INTO license_types (code, name) VALUES
  ('A3',   'Categoria A3 – Elicotteri a Turbina (linea)'),
  ('B1.3', 'Categoria B1.3 – Aeromobili Turbina (struttura e motore)'),
  ('B2',   'Categoria B2 – Avionica'),
  ('C',    'Categoria C – Release to Service')
ON CONFLICT (code) DO NOTHING;

-- Privilegi manutentivi (dalla CSL AVES)
INSERT INTO privilege_types (code, name, sort_order) VALUES
  ('DELIBERA_VOLO',       'Delibera al Volo',                                                          1),
  ('CORREZIONE_REGISTRI', 'Correzione Registri di Aeronavigabilità',                                   2),
  ('COMPILAZIONE_DOC',    'Compilazione Documentazione Tecnica (AER 00.1.24 – CIP)',                   3),
  ('REDAZIONE_CRA_FIS',   'Redazione CRA Controllo Fisico',                                            4),
  ('REDAZIONE_CRA_DOC',   'Redazione CRA Controllo Documentale',                                       5),
  ('MAN_LINEA',           'Manutenzione di Linea (Isp. Prevolo, Giornaliera, Post Volo, Routinari)',   6),
  ('MAN_TM',              'Manutenzione T/M',                                                          7),
  ('MAN_DINAMICI',        'Manutenzione Dinamici',                                                     8),
  ('MAN_IDRAULICO',       'Manutenzione Impianto Idraulico',                                           9),
  ('MAN_STRUTTURA',       'Manutenzione Struttura',                                                   10),
  ('MAN_ELETTRICA',       'Manutenzione su Parte Elettrica/Elettronica/Avionica',                     11),
  ('ISP_LAVORAZIONE',     'Esecuzione Ispezione Pre e Post Lavorazione',                              12)
ON CONFLICT (code) DO NOTHING;

-- Capacità TOB
INSERT INTO tob_capabilities (code, name) VALUES
  ('BENNA',             'Benna Antincendio'),
  ('GANCIO_BARIC',      'Gancio Baricentrico (Sling Load)'),
  ('NVG',               'Night Vision Goggles (NVG)'),
  ('CARICO_ESTERNO',    'Carico Esterno Standard'),
  ('ELITRASPORTO',      'Elitrasporto'),
  ('VERRICELLO',        'Verricello di Salvataggio')
ON CONFLICT (code) DO NOTHING;

-- Unità organizzative
INSERT INTO org_units (code, name) VALUES
  ('SDTMA', 'Sezione Documentazione Tecnica e Materiali AVES'),
  ('SMV',   'Squadrone Mantenimento Velivoli'),
  ('SLV',   'Squadroni Linea Volo'),
  ('ALTRO', 'Altro Personale Tecnico')
ON CONFLICT (code) DO NOTHING;

-- Criteri currency default
INSERT INTO currency_criteria (criteria_type, period_days, min_hours, description) VALUES
  ('MAINTENANCE', 180, NULL, 'Almeno 1 task manutentivo ogni 6 mesi (180 giorni)'),
  ('FLIGHT_T',    180, 3.0,  '3 ore di volo per semestre (180 giorni)')
ON CONFLICT (criteria_type, tob_capability_id) DO NOTHING;

-- Criteri TOB per ciascuna capacità
INSERT INTO currency_criteria (criteria_type, tob_capability_id, period_days, description)
SELECT
  'TOB_CAPABILITY',
  id,
  CASE code
    WHEN 'NVG' THEN 60
    ELSE 90
  END,
  'Attività ' || name || ' entro il periodo stabilito'
FROM tob_capabilities
ON CONFLICT (criteria_type, tob_capability_id) DO NOTHING;
