-- Migration: add status and is_banned columns to yshopadmins
-- Run: mysql -u USER -p DATABASE < 2025-12-27-add-admin-status-columns.sql

ALTER TABLE yshopadmins
  ADD COLUMN IF NOT EXISTS status VARCHAR(32) DEFAULT 'active' AFTER role;

ALTER TABLE yshopadmins
  ADD COLUMN IF NOT EXISTS is_banned TINYINT(1) DEFAULT 0 AFTER status;

CREATE INDEX IF NOT EXISTS idx_yshopadmins_role ON yshopadmins(role);
