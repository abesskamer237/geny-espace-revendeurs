-- ENSPY v2.3.1 compatibility: notification targeting by filière.
-- Fixes event creation notifications and allows administrators to target a filière.
ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS filiere_id INTEGER REFERENCES filieres(id) ON UPDATE CASCADE ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS notifications_filiere_idx
  ON notifications(filiere_id, created_at DESC);
