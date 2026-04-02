-- =====================================================
-- GAS miniCRM — Database Migration
-- Run this in Supabase SQL Editor
-- =====================================================

-- 1. Add missing columns to bookings
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS comment text;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS source text NOT NULL DEFAULT 'instagram_bot'
  CHECK (source IN ('instagram_bot', 'manual_crm', 'phone'));

-- 2. Add phone & notes to clients
ALTER TABLE clients ADD COLUMN IF NOT EXISTS notes text;

-- 3. Add color to masters (for calendar display)
ALTER TABLE masters ADD COLUMN IF NOT EXISTS color text DEFAULT '#6C5CE7';

-- 4. Update existing masters with distinct colors
UPDATE masters SET color = '#6C5CE7' WHERE color IS NULL OR color = '#6C5CE7';
UPDATE masters SET color = '#00D2FF' WHERE name = 'Вікторія';
UPDATE masters SET color = '#FF6B6B' WHERE name = 'Аліна';

-- 5. Create index for bookings by date range (for calendar view)
CREATE INDEX IF NOT EXISTS idx_bookings_date_range ON bookings(date, status);
CREATE INDEX IF NOT EXISTS idx_bookings_master_date ON bookings(master_id, date, status);
