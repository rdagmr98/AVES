-- ============================================================
-- AVES - Row Level Security (RLS)
-- Eseguire DOPO schema.sql e seed.sql
-- ============================================================

-- Funzione helper per recuperare il ruolo dell'utente corrente
CREATE OR REPLACE FUNCTION current_user_role()
RETURNS TEXT AS $$
  SELECT role FROM user_profiles WHERE id = auth.uid();
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- Funzione helper: è un admin?
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
  SELECT current_user_role() IN ('admin_priv', 'admin_crew');
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- ==================== user_profiles ====================
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_profiles_select"
  ON user_profiles FOR SELECT
  USING (auth.uid() = id OR is_admin());

CREATE POLICY "user_profiles_insert"
  ON user_profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "user_profiles_update_own"
  ON user_profiles FOR UPDATE
  USING (auth.uid() = id AND role = 'user')
  WITH CHECK (role = 'user');

CREATE POLICY "admin_update_any_profile"
  ON user_profiles FOR UPDATE
  USING (is_admin());

-- ==================== user_licenses ====================
ALTER TABLE user_licenses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "licenses_select"
  ON user_licenses FOR SELECT
  USING (user_id = auth.uid() OR is_admin());

CREATE POLICY "admin_manage_licenses"
  ON user_licenses FOR ALL
  USING (is_admin());

-- ==================== user_privileges ====================
ALTER TABLE user_privileges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "privileges_select"
  ON user_privileges FOR SELECT
  USING (user_id = auth.uid() OR is_admin());

CREATE POLICY "admin_manage_privileges"
  ON user_privileges FOR ALL
  USING (is_admin());

-- ==================== user_crew_assignments ====================
ALTER TABLE user_crew_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "crew_select"
  ON user_crew_assignments FOR SELECT
  USING (user_id = auth.uid() OR is_admin());

CREATE POLICY "admin_manage_crew"
  ON user_crew_assignments FOR ALL
  USING (is_admin());

-- ==================== user_tob_capabilities ====================
ALTER TABLE user_tob_capabilities ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tob_cap_select"
  ON user_tob_capabilities FOR SELECT
  USING (user_id = auth.uid() OR is_admin());

CREATE POLICY "admin_manage_tob_cap"
  ON user_tob_capabilities FOR ALL
  USING (is_admin());

-- ==================== currency_criteria ====================
ALTER TABLE currency_criteria ENABLE ROW LEVEL SECURITY;

CREATE POLICY "criteria_select_all"
  ON currency_criteria FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "admin_manage_criteria"
  ON currency_criteria FOR ALL
  USING (is_admin());

-- ==================== maintenance_activities ====================
ALTER TABLE maintenance_activities ENABLE ROW LEVEL SECURITY;

CREATE POLICY "maintenance_select"
  ON maintenance_activities FOR SELECT
  USING (user_id = auth.uid() OR is_admin());

CREATE POLICY "maintenance_insert_own"
  ON maintenance_activities FOR INSERT
  WITH CHECK (submitted_by = auth.uid() AND (user_id = auth.uid() OR is_admin()));

CREATE POLICY "admin_update_maintenance"
  ON maintenance_activities FOR UPDATE
  USING (is_admin());

-- ==================== flight_activities ====================
ALTER TABLE flight_activities ENABLE ROW LEVEL SECURITY;

CREATE POLICY "flight_select"
  ON flight_activities FOR SELECT
  USING (user_id = auth.uid() OR is_admin());

CREATE POLICY "flight_insert_own"
  ON flight_activities FOR INSERT
  WITH CHECK (submitted_by = auth.uid() AND (user_id = auth.uid() OR is_admin()));

CREATE POLICY "admin_update_flight"
  ON flight_activities FOR UPDATE
  USING (is_admin());

-- ==================== tob_activities ====================
ALTER TABLE tob_activities ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tob_act_select"
  ON tob_activities FOR SELECT
  USING (user_id = auth.uid() OR is_admin());

CREATE POLICY "tob_act_insert_own"
  ON tob_activities FOR INSERT
  WITH CHECK (submitted_by = auth.uid() AND (user_id = auth.uid() OR is_admin()));

CREATE POLICY "admin_update_tob_act"
  ON tob_activities FOR UPDATE
  USING (is_admin());

-- ==================== notifications ====================
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notif_select_own"
  ON notifications FOR SELECT
  USING (user_id = auth.uid() OR is_admin());

CREATE POLICY "admin_insert_notif"
  ON notifications FOR INSERT
  WITH CHECK (is_admin() OR user_id = auth.uid());

CREATE POLICY "notif_update_own"
  ON notifications FOR UPDATE
  USING (user_id = auth.uid());

-- ==================== Reference tables (public read) ====================
ALTER TABLE helicopter_types ENABLE ROW LEVEL SECURITY;
CREATE POLICY "heli_public_read" ON helicopter_types FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "admin_manage_heli" ON helicopter_types FOR ALL USING (is_admin());

ALTER TABLE license_types ENABLE ROW LEVEL SECURITY;
CREATE POLICY "lic_public_read" ON license_types FOR SELECT USING (auth.uid() IS NOT NULL);

ALTER TABLE privilege_types ENABLE ROW LEVEL SECURITY;
CREATE POLICY "priv_public_read" ON privilege_types FOR SELECT USING (auth.uid() IS NOT NULL);

ALTER TABLE tob_capabilities ENABLE ROW LEVEL SECURITY;
CREATE POLICY "tob_cap_public_read" ON tob_capabilities FOR SELECT USING (auth.uid() IS NOT NULL);

ALTER TABLE org_units ENABLE ROW LEVEL SECURITY;
CREATE POLICY "org_public_read" ON org_units FOR SELECT USING (auth.uid() IS NOT NULL);
