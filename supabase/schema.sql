-- ============================================================
-- AVES CURRENCY MANAGEMENT SYSTEM - Database Schema
-- Eseguire in ordine: schema.sql → seed.sql → rls.sql
-- ============================================================

-- Tipi di elicottero in dotazione AVES
CREATE TABLE IF NOT EXISTS helicopter_types (
  id SERIAL PRIMARY KEY,
  code TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  active BOOLEAN DEFAULT TRUE
);

-- Tipi di licenza manutentore aeronautico militare
CREATE TABLE IF NOT EXISTS license_types (
  id SERIAL PRIMARY KEY,
  code TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL
);

-- Tipi di privilegio manutentivo (dalla CSL)
CREATE TABLE IF NOT EXISTS privilege_types (
  id SERIAL PRIMARY KEY,
  code TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  sort_order INT DEFAULT 0
);

-- Capacità TOB
CREATE TABLE IF NOT EXISTS tob_capabilities (
  id SERIAL PRIMARY KEY,
  code TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL
);

-- Unità organizzative
CREATE TABLE IF NOT EXISTS org_units (
  id SERIAL PRIMARY KEY,
  code TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL
);

-- Profili utente (estende auth.users di Supabase)
CREATE TABLE IF NOT EXISTS user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nome TEXT NOT NULL DEFAULT '',
  cognome TEXT NOT NULL DEFAULT '',
  numero_licenza TEXT UNIQUE,
  qualifica TEXT DEFAULT '',
  org_unit_id INT REFERENCES org_units(id),
  role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin_priv', 'admin_crew')),
  is_approved BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Trigger per updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER user_profiles_updated_at
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Licenze manutentore per elicottero
CREATE TABLE IF NOT EXISTS user_licenses (
  id SERIAL PRIMARY KEY,
  user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
  helicopter_type_id INT REFERENCES helicopter_types(id),
  license_type_id INT REFERENCES license_types(id),
  license_number TEXT,
  expiry_date DATE,
  active BOOLEAN DEFAULT TRUE,
  UNIQUE(user_id, helicopter_type_id, license_type_id)
);

-- Privilegi manutentivi per elicottero
CREATE TABLE IF NOT EXISTS user_privileges (
  id SERIAL PRIMARY KEY,
  user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
  helicopter_type_id INT REFERENCES helicopter_types(id),
  privilege_type_id INT REFERENCES privilege_types(id),
  expiry_date DATE,
  active BOOLEAN DEFAULT TRUE,
  UNIQUE(user_id, helicopter_type_id, privilege_type_id)
);

-- Assegnazione equipaggio fisso
CREATE TABLE IF NOT EXISTS user_crew_assignments (
  id SERIAL PRIMARY KEY,
  user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
  helicopter_type_id INT REFERENCES helicopter_types(id),
  crew_type TEXT NOT NULL CHECK (crew_type IN ('T', 'TOB')),
  tob_grade TEXT CHECK (tob_grade IN ('A', 'B', 'C')),
  active BOOLEAN DEFAULT TRUE
);

-- Capacità TOB dell'utente
CREATE TABLE IF NOT EXISTS user_tob_capabilities (
  id SERIAL PRIMARY KEY,
  user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
  helicopter_type_id INT REFERENCES helicopter_types(id),
  tob_capability_id INT REFERENCES tob_capabilities(id),
  expiry_date DATE,
  active BOOLEAN DEFAULT TRUE,
  UNIQUE(user_id, helicopter_type_id, tob_capability_id)
);

-- Criteri di mantenimento currency (configurabili dagli admin)
CREATE TABLE IF NOT EXISTS currency_criteria (
  id SERIAL PRIMARY KEY,
  criteria_type TEXT NOT NULL CHECK (criteria_type IN ('MAINTENANCE', 'FLIGHT_T', 'TOB_CAPABILITY')),
  tob_capability_id INT REFERENCES tob_capabilities(id),
  period_days INT NOT NULL DEFAULT 180,
  min_hours DECIMAL(5,1),
  description TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  updated_by UUID REFERENCES user_profiles(id),
  UNIQUE(criteria_type, tob_capability_id)
);

-- Attività manutentive
CREATE TABLE IF NOT EXISTS maintenance_activities (
  id SERIAL PRIMARY KEY,
  user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
  helicopter_type_id INT REFERENCES helicopter_types(id),
  privilege_type_id INT REFERENCES privilege_types(id),
  activity_date DATE NOT NULL,
  description TEXT,
  is_validated BOOLEAN DEFAULT FALSE,
  validated_by UUID REFERENCES user_profiles(id),
  validated_at TIMESTAMPTZ,
  submitted_by UUID REFERENCES user_profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Attività di volo (per equipaggio T)
CREATE TABLE IF NOT EXISTS flight_activities (
  id SERIAL PRIMARY KEY,
  user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
  helicopter_type_id INT REFERENCES helicopter_types(id),
  activity_date DATE NOT NULL,
  flight_hours DECIMAL(4,1) NOT NULL,
  description TEXT,
  is_validated BOOLEAN DEFAULT FALSE,
  validated_by UUID REFERENCES user_profiles(id),
  validated_at TIMESTAMPTZ,
  submitted_by UUID REFERENCES user_profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Attività TOB
CREATE TABLE IF NOT EXISTS tob_activities (
  id SERIAL PRIMARY KEY,
  user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
  helicopter_type_id INT REFERENCES helicopter_types(id),
  tob_capability_id INT REFERENCES tob_capabilities(id),
  activity_date DATE NOT NULL,
  description TEXT,
  is_validated BOOLEAN DEFAULT FALSE,
  validated_by UUID REFERENCES user_profiles(id),
  validated_at TIMESTAMPTZ,
  submitted_by UUID REFERENCES user_profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Notifiche in-app
CREATE TABLE IF NOT EXISTS notifications (
  id SERIAL PRIMARY KEY,
  user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN (
    'MAINTENANCE_EXPIRING', 'MAINTENANCE_EXPIRED',
    'FLIGHT_EXPIRING', 'FLIGHT_EXPIRED',
    'TOB_EXPIRING', 'TOB_EXPIRED',
    'ACTIVITY_VALIDATED', 'ACTIVITY_REJECTED',
    'PROFILE_APPROVED'
  )),
  message TEXT NOT NULL,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indici per performance
CREATE INDEX IF NOT EXISTS idx_maintenance_activities_user ON maintenance_activities(user_id, is_validated, activity_date DESC);
CREATE INDEX IF NOT EXISTS idx_flight_activities_user ON flight_activities(user_id, is_validated, activity_date DESC);
CREATE INDEX IF NOT EXISTS idx_tob_activities_user ON tob_activities(user_id, is_validated, activity_date DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON notifications(user_id, is_read, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_profiles_role ON user_profiles(role);
CREATE INDEX IF NOT EXISTS idx_user_profiles_license ON user_profiles(numero_licenza);
