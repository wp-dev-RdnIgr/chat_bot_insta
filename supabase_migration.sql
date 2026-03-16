-- =====================================================
-- Bloom Beauty Studio — Instagram Booking Bot
-- Supabase Migration + Seed Data
-- Timezone: Europe/Kyiv | Language: Ukrainian | Currency: UAH (грн)
-- =====================================================

-- 1. TABLES
-- =====================================================

CREATE TABLE IF NOT EXISTS services (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  category text NOT NULL,
  duration_minutes int NOT NULL,
  price decimal(10,2) NOT NULL,
  description text,
  is_active boolean NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS masters (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  specializations text[] NOT NULL,
  instagram_handle text,
  is_active boolean NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS master_services (
  master_id uuid NOT NULL REFERENCES masters(id) ON DELETE CASCADE,
  service_id uuid NOT NULL REFERENCES services(id) ON DELETE CASCADE,
  PRIMARY KEY (master_id, service_id)
);

CREATE TABLE IF NOT EXISTS schedule_slots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  master_id uuid NOT NULL REFERENCES masters(id) ON DELETE CASCADE,
  date date NOT NULL,
  start_time time NOT NULL,
  end_time time NOT NULL,
  is_booked boolean NOT NULL DEFAULT false
);

CREATE INDEX idx_schedule_slots_master_date ON schedule_slots(master_id, date);
CREATE INDEX idx_schedule_slots_available ON schedule_slots(master_id, date, is_booked) WHERE is_booked = false;

CREATE TABLE IF NOT EXISTS clients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  instagram_id text UNIQUE NOT NULL,
  instagram_username text,
  name text,
  phone text,
  created_at timestamptz NOT NULL DEFAULT now(),
  last_visit timestamptz
);

CREATE TABLE IF NOT EXISTS bookings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  master_id uuid NOT NULL REFERENCES masters(id),
  service_id uuid NOT NULL REFERENCES services(id),
  slot_id uuid NOT NULL REFERENCES schedule_slots(id),
  date date NOT NULL,
  start_time time NOT NULL,
  status text NOT NULL DEFAULT 'confirmed'
    CHECK (status IN ('confirmed', 'cancelled', 'completed', 'no_show')),
  created_at timestamptz NOT NULL DEFAULT now(),
  reminder_sent boolean NOT NULL DEFAULT false
);

CREATE INDEX idx_bookings_client ON bookings(client_id, status, date);

CREATE TABLE IF NOT EXISTS conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  current_step text NOT NULL DEFAULT 'GREETING',
  selected_category text,
  selected_service_id uuid,
  selected_master_id uuid,
  selected_slot_id uuid,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(client_id)
);

-- =====================================================
-- 2. SEED DATA — Services
-- =====================================================

INSERT INTO services (name, category, duration_minutes, price, description) VALUES
  -- Ногти
  ('Манікюр',             'Ногті',   60,   500, 'Класичний манікюр з покриттям'),
  ('Педикюр',             'Ногті',   75,   600, 'Класичний педикюр з покриттям'),
  ('Манікюр + гель-лак',  'Ногті',   90,   700, 'Манікюр з покриттям гель-лаком'),
  -- Ресницы
  ('Нарощування класика', 'Вії',    120,   800, 'Класичне нарощування вій'),
  ('Нарощування 2D',      'Вії',    150,  1000, 'Обʼємне нарощування 2D'),
  ('Ламінування вій',     'Вії',     60,   600, 'Ламінування та фарбування вій'),
  -- Брови
  ('Корекція + фарбування', 'Брови',  45,   400, 'Корекція форми та фарбування бровей'),
  ('Ламінування бровей',    'Брови',  50,   500, 'Ламінування та укладка бровей'),
  -- Волосы
  ('Жіноча стрижка',      'Волосся', 60,   500, 'Стрижка будь-якої довжини'),
  ('Фарбування',          'Волосся',180,  1500, 'Фарбування волосся в один тон'),
  ('Укладка',             'Волосся', 45,   400, 'Укладка феном або плойкою');

-- =====================================================
-- 3. SEED DATA — Masters
-- =====================================================

INSERT INTO masters (name, specializations, instagram_handle) VALUES
  ('Анна',     ARRAY['Ногті'],           '@anna_bloom'),
  ('Марина',   ARRAY['Вії', 'Брови'],    '@marina_bloom'),
  ('Олеся',    ARRAY['Волосся'],          '@olesya_bloom'),
  ('Катерина', ARRAY['Ногті', 'Брови'],   '@kateryna_bloom');

-- =====================================================
-- 4. SEED DATA — Master-Service links (auto from specializations)
-- =====================================================

INSERT INTO master_services (master_id, service_id)
SELECT m.id, s.id
FROM masters m
JOIN services s ON s.category = ANY(m.specializations)
WHERE m.is_active = true AND s.is_active = true;

-- =====================================================
-- 5. SEED DATA — Schedule slots (7 days ahead, 9:00–19:00, 30-min step, skip Sunday)
-- =====================================================

INSERT INTO schedule_slots (master_id, date, start_time, end_time, is_booked)
SELECT
  m.id,
  d::date,
  (CURRENT_DATE + (slot_num * interval '30 minutes') + interval '9 hours')::time,
  (CURRENT_DATE + (slot_num * interval '30 minutes') + interval '9 hours 30 minutes')::time,
  (random() < 0.2)
FROM masters m
CROSS JOIN generate_series(
  CURRENT_DATE,
  CURRENT_DATE + interval '6 days',
  interval '1 day'
) AS d
CROSS JOIN generate_series(0, 19) AS slot_num
WHERE EXTRACT(DOW FROM d::date) != 0
  AND m.is_active = true;

-- =====================================================
-- 6. HELPER FUNCTIONS
-- =====================================================

-- Get or create client by instagram_id
CREATE OR REPLACE FUNCTION get_or_create_client(p_instagram_id text)
RETURNS uuid AS $$
DECLARE
  v_client_id uuid;
BEGIN
  SELECT id INTO v_client_id FROM clients WHERE instagram_id = p_instagram_id;
  IF v_client_id IS NULL THEN
    INSERT INTO clients (instagram_id) VALUES (p_instagram_id) RETURNING id INTO v_client_id;
  END IF;
  RETURN v_client_id;
END;
$$ LANGUAGE plpgsql;

-- Get or create conversation for client
CREATE OR REPLACE FUNCTION get_or_create_conversation(p_client_id uuid)
RETURNS TABLE(
  id uuid,
  current_step text,
  selected_category text,
  selected_service_id uuid,
  selected_master_id uuid,
  selected_slot_id uuid
) AS $$
BEGIN
  RETURN QUERY
  INSERT INTO conversations (client_id, current_step)
  VALUES (p_client_id, 'GREETING')
  ON CONFLICT (client_id) DO UPDATE SET updated_at = now()
  RETURNING
    conversations.id,
    conversations.current_step,
    conversations.selected_category,
    conversations.selected_service_id,
    conversations.selected_master_id,
    conversations.selected_slot_id;
END;
$$ LANGUAGE plpgsql;

-- Reset conversation to GREETING
CREATE OR REPLACE FUNCTION reset_conversation(p_client_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE conversations
  SET current_step = 'GREETING',
      selected_category = NULL,
      selected_service_id = NULL,
      selected_master_id = NULL,
      selected_slot_id = NULL,
      updated_at = now()
  WHERE client_id = p_client_id;
END;
$$ LANGUAGE plpgsql;

-- Find available consecutive slots for a service duration
CREATE OR REPLACE FUNCTION find_available_times(
  p_master_id uuid,
  p_date date,
  p_duration_minutes int
)
RETURNS TABLE(slot_id uuid, start_time time) AS $$
DECLARE
  slots_needed int;
BEGIN
  slots_needed := CEIL(p_duration_minutes / 30.0);

  RETURN QUERY
  WITH available AS (
    SELECT ss.id, ss.start_time AS st,
           ROW_NUMBER() OVER (ORDER BY ss.start_time) AS rn,
           (EXTRACT(EPOCH FROM ss.start_time) / 1800)::int AS slot_idx
    FROM schedule_slots ss
    WHERE ss.master_id = p_master_id
      AND ss.date = p_date
      AND ss.is_booked = false
    ORDER BY ss.start_time
  ),
  consecutive_starts AS (
    SELECT a1.id, a1.st
    FROM available a1
    WHERE (
      SELECT COUNT(*)
      FROM available a2
      WHERE a2.slot_idx >= a1.slot_idx
        AND a2.slot_idx < a1.slot_idx + slots_needed
    ) = slots_needed
  )
  SELECT cs.id, cs.st FROM consecutive_starts cs ORDER BY cs.st;
END;
$$ LANGUAGE plpgsql;

-- Create booking: insert booking row + mark slots as booked
CREATE OR REPLACE FUNCTION create_booking(
  p_client_id uuid,
  p_master_id uuid,
  p_service_id uuid,
  p_slot_id uuid
)
RETURNS uuid AS $$
DECLARE
  v_booking_id uuid;
  v_date date;
  v_start_time time;
  v_duration int;
  v_slots_needed int;
BEGIN
  -- Get slot info
  SELECT date, start_time INTO v_date, v_start_time
  FROM schedule_slots WHERE id = p_slot_id;

  -- Get service duration
  SELECT duration_minutes INTO v_duration FROM services WHERE id = p_service_id;
  v_slots_needed := CEIL(v_duration / 30.0);

  -- Mark all needed consecutive slots as booked
  UPDATE schedule_slots
  SET is_booked = true
  WHERE master_id = p_master_id
    AND date = v_date
    AND start_time >= v_start_time
    AND start_time < v_start_time + (v_slots_needed * interval '30 minutes')
    AND is_booked = false;

  -- Create booking
  INSERT INTO bookings (client_id, master_id, service_id, slot_id, date, start_time)
  VALUES (p_client_id, p_master_id, p_service_id, p_slot_id, v_date, v_start_time)
  RETURNING id INTO v_booking_id;

  -- Reset conversation
  PERFORM reset_conversation(p_client_id);

  RETURN v_booking_id;
END;
$$ LANGUAGE plpgsql;
