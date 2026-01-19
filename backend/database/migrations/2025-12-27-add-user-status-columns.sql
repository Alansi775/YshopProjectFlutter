-- Migration: add status and is_banned columns to yshopusers
-- Run: mysql -u USER -p DATABASE < 2025-12-27-add-user-status-columns.sql

SET @TABLE_NAME = 'yshopusers';

-- Add `status` column if not exists
ALTER TABLE yshopusers
  ADD COLUMN IF NOT EXISTS status VARCHAR(32) DEFAULT 'active' AFTER role;

-- Add `is_banned` column if not exists
ALTER TABLE yshopusers
  ADD COLUMN IF NOT EXISTS is_banned TINYINT(1) DEFAULT 0 AFTER status;

-- Optional: create an index on admin_id for quicker admin lookups
CREATE INDEX IF NOT EXISTS idx_yshopusers_admin_id ON yshopusers(admin_id);
