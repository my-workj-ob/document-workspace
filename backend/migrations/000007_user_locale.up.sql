-- Add locale column to users for persistent cross-device language synchronization
ALTER TABLE users ADD COLUMN IF NOT EXISTS locale VARCHAR(10) NOT NULL DEFAULT 'uz';
