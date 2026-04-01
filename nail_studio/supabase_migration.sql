-- =====================================================
-- Nail Studio Kyiv OB — Instagram Booking Bot + Google Calendar
-- Supabase Migration + Seed Data
-- Timezone: Europe/Kyiv | Language: Ukrainian | Currency: UAH (грн)
-- Instagram: @nail.studio.kyiv_ob
-- Google Calendar: cumasergej08@gmail.com
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
  google_calendar_id text,  -- individual calendar per master (optional)
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
  end_time time NOT NULL,
  google_calendar_event_id text,  -- ID события в Google Calendar
  status text NOT NULL DEFAULT 'confirmed'
    CHECK (status IN ('confirmed', 'cancelled', 'completed', 'no_show')),
  created_at timestamptz NOT NULL DEFAULT now(),
  reminder_sent boolean NOT NULL DEFAULT false
);

CREATE INDEX idx_bookings_client ON bookings(client_id, status, date);
CREATE INDEX idx_bookings_gcal ON bookings(google_calendar_event_id) WHERE google_calendar_event_id IS NOT NULL;

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
-- 2. SEED DATA — Services (Nail Studio)
-- =====================================================

INSERT INTO services (name, category, duration_minutes, price, description) VALUES
  -- Манікюр
  ('Манікюр класичний',       'Манікюр',      60,   400, 'Класичний обрізний манікюр'),
  ('Манікюр апаратний',       'Манікюр',      60,   450, 'Апаратний манікюр без обрізання'),
  ('Манікюр + гель-лак',      'Манікюр',      90,   600, 'Апаратний манікюр з покриттям гель-лаком'),
  ('Зняття гель-лаку',        'Манікюр',      30,   150, 'Зняття старого покриття гель-лак'),
  ('Зміцнення нігтів',        'Манікюр',      30,   200, 'Зміцнення натуральних нігтів базою'),
  -- Нарощування
  ('Нарощування нігтів гелем','Нарощування',  120,  1000, 'Нарощування нігтів гелем на форми'),
  ('Корекція нарощування',    'Нарощування',   90,   800, 'Корекція нарощених нігтів'),
  ('Зняття нарощування',      'Нарощування',   60,   300, 'Зняття нарощених нігтів'),
  -- Педикюр
  ('Педикюр класичний',       'Педикюр',       60,   500, 'Класичний педикюр'),
  ('Педикюр апаратний',       'Педикюр',       75,   550, 'Апаратний педикюр'),
  ('Педикюр + гель-лак',      'Педикюр',       90,   700, 'Апаратний педикюр з покриттям гель-лаком'),
  -- Дизайн
  ('Дизайн нігтів (1 ніготь)','Дизайн',       15,    50, 'Художній дизайн одного нігтя'),
  ('Дизайн French',           'Дизайн',       30,   200, 'Французький манікюр (всі нігті)');

-- =====================================================
-- 3. SEED DATA — Masters
-- =====================================================

INSERT INTO masters (name, specializations, instagram_handle) VALUES
  ('Іванна',   ARRAY['Манікюр', 'Нарощування', 'Дизайн'], '@ivanna_nails'),
  ('Вікторія', ARRAY['Манікюр', 'Педикюр', 'Дизайн'],     '@vika_nails'),
  ('Аліна',    ARRAY['Манікюр', 'Нарощування', 'Педикюр'], '@alina_nails');

-- =====================================================
-- 4. SEED DATA — Master-Service links
-- =====================================================

INSERT INTO master_services (master_id, service_id)
SELECT m.id, s.id
FROM masters m
JOIN services s ON s.category = ANY(m.specializations)
WHERE m.is_active = true AND s.is_active = true;

-- =====================================================
-- 5. SEED DATA — Schedule slots (7 days ahead, 9:00–18:00, 30-min step, skip Sunday)
-- =====================================================

INSERT INTO schedule_slots (master_id, date, start_time, end_time, is_booked)
SELECT
  m.id,
  d::date,
  (CURRENT_DATE + (slot_num * interval '30 minutes') + interval '9 hours')::time,
  (CURRENT_DATE + (slot_num * interval '30 minutes') + interval '9 hours 30 minutes')::time,
  false
FROM masters m
CROSS JOIN generate_series(
  CURRENT_DATE,
  CURRENT_DATE + interval '6 days',
  interval '1 day'
) AS d
CROSS JOIN generate_series(0, 17) AS slot_num  -- 9:00-18:00 = 18 slots
WHERE EXTRACT(DOW FROM d::date) != 0  -- skip Sunday
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

-- Find available consecutive slots for a service duration
CREATE OR REPLACE FUNCTION find_available_times(
  p_service_id uuid DEFAULT NULL,
  p_master_id uuid DEFAULT NULL,
  p_date date DEFAULT NULL
)
RETURNS TABLE(
  slot_id uuid,
  master_id uuid,
  master_name text,
  service_name text,
  date date,
  start_time time,
  end_time time,
  price decimal
) AS $$
DECLARE
  v_duration int;
  v_slots_needed int;
BEGIN
  -- Get service duration
  IF p_service_id IS NOT NULL THEN
    SELECT duration_minutes INTO v_duration FROM services WHERE id = p_service_id;
  ELSE
    v_duration := 60; -- default 1 hour
  END IF;
  v_slots_needed := CEIL(v_duration / 30.0);

  RETURN QUERY
  WITH available AS (
    SELECT
      ss.id AS sid,
      ss.master_id AS mid,
      ms2.name AS mname,
      COALESCE(sv.name, '') AS sname,
      ss.date AS sdate,
      ss.start_time AS st,
      COALESCE(sv.price, 0) AS sprice,
      (EXTRACT(EPOCH FROM ss.start_time) / 1800)::int AS slot_idx
    FROM schedule_slots ss
    JOIN masters ms2 ON ms2.id = ss.master_id AND ms2.is_active = true
    LEFT JOIN services sv ON sv.id = p_service_id
    WHERE ss.is_booked = false
      AND (p_master_id IS NULL OR ss.master_id = p_master_id)
      AND (p_date IS NULL OR ss.date = p_date)
      AND ss.date >= CURRENT_DATE
      AND (p_service_id IS NULL OR EXISTS (
        SELECT 1 FROM master_services ms WHERE ms.master_id = ss.master_id AND ms.service_id = p_service_id
      ))
    ORDER BY ss.date, ss.start_time
  ),
  consecutive_starts AS (
    SELECT a1.sid, a1.mid, a1.mname, a1.sname, a1.sdate, a1.st, a1.sprice
    FROM available a1
    WHERE (
      SELECT COUNT(*)
      FROM available a2
      WHERE a2.mid = a1.mid
        AND a2.sdate = a1.sdate
        AND a2.slot_idx >= a1.slot_idx
        AND a2.slot_idx < a1.slot_idx + v_slots_needed
    ) = v_slots_needed
  )
  SELECT
    cs.sid,
    cs.mid,
    cs.mname,
    cs.sname,
    cs.sdate,
    cs.st,
    (cs.st + (v_duration * interval '1 minute'))::time,
    cs.sprice
  FROM consecutive_starts cs
  ORDER BY cs.sdate, cs.st, cs.mname
  LIMIT 20;
END;
$$ LANGUAGE plpgsql;

-- Create booking + return data for Google Calendar event creation
CREATE OR REPLACE FUNCTION create_booking(
  p_client_instagram_id text,
  p_master_id uuid,
  p_service_id uuid,
  p_slot_id uuid,
  p_google_calendar_event_id text DEFAULT NULL
)
RETURNS TABLE(
  booking_id uuid,
  client_name text,
  master_name text,
  service_name text,
  booking_date date,
  start_time time,
  end_time time,
  price decimal,
  duration_minutes int
) AS $$
DECLARE
  v_client_id uuid;
  v_booking_id uuid;
  v_date date;
  v_start_time time;
  v_duration int;
  v_slots_needed int;
BEGIN
  -- Get or create client
  SELECT get_or_create_client(p_client_instagram_id) INTO v_client_id;

  -- Get slot info
  SELECT ss.date, ss.start_time INTO v_date, v_start_time
  FROM schedule_slots ss WHERE ss.id = p_slot_id;

  -- Get service duration
  SELECT s.duration_minutes INTO v_duration FROM services s WHERE s.id = p_service_id;
  v_slots_needed := CEIL(v_duration / 30.0);

  -- Mark slots as booked
  UPDATE schedule_slots ss
  SET is_booked = true
  WHERE ss.master_id = p_master_id
    AND ss.date = v_date
    AND ss.start_time >= v_start_time
    AND ss.start_time < v_start_time + (v_slots_needed * interval '30 minutes')
    AND ss.is_booked = false;

  -- Create booking
  INSERT INTO bookings (client_id, master_id, service_id, slot_id, date, start_time, end_time, google_calendar_event_id)
  VALUES (
    v_client_id, p_master_id, p_service_id, p_slot_id,
    v_date, v_start_time,
    (v_start_time + (v_duration * interval '1 minute'))::time,
    p_google_calendar_event_id
  )
  RETURNING id INTO v_booking_id;

  -- Return booking details
  RETURN QUERY
  SELECT
    v_booking_id,
    COALESCE(c.name, c.instagram_username, p_client_instagram_id),
    m.name,
    s.name,
    v_date,
    v_start_time,
    (v_start_time + (v_duration * interval '1 minute'))::time,
    s.price,
    s.duration_minutes
  FROM clients c
  JOIN masters m ON m.id = p_master_id
  JOIN services s ON s.id = p_service_id
  WHERE c.id = v_client_id;
END;
$$ LANGUAGE plpgsql;

-- Cancel booking + free up slots
CREATE OR REPLACE FUNCTION cancel_booking(
  p_booking_id uuid
)
RETURNS TABLE(
  google_calendar_event_id text,
  service_name text,
  booking_date date,
  start_time time
) AS $$
DECLARE
  v_booking bookings%ROWTYPE;
  v_duration int;
  v_slots_needed int;
BEGIN
  SELECT * INTO v_booking FROM bookings b WHERE b.id = p_booking_id AND b.status = 'confirmed';

  IF v_booking.id IS NULL THEN
    RAISE EXCEPTION 'Booking not found or already cancelled';
  END IF;

  -- Get duration
  SELECT s.duration_minutes INTO v_duration FROM services s WHERE s.id = v_booking.service_id;
  v_slots_needed := CEIL(v_duration / 30.0);

  -- Free up slots
  UPDATE schedule_slots ss
  SET is_booked = false
  WHERE ss.master_id = v_booking.master_id
    AND ss.date = v_booking.date
    AND ss.start_time >= v_booking.start_time
    AND ss.start_time < v_booking.start_time + (v_slots_needed * interval '30 minutes');

  -- Cancel booking
  UPDATE bookings b SET status = 'cancelled' WHERE b.id = p_booking_id;

  RETURN QUERY
  SELECT
    v_booking.google_calendar_event_id,
    s.name,
    v_booking.date,
    v_booking.start_time
  FROM services s WHERE s.id = v_booking.service_id;
END;
$$ LANGUAGE plpgsql;
