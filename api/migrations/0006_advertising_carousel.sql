-- ENSPY v2.3.0 - managed advertising carousel
-- Safe to run more than once.
CREATE TABLE IF NOT EXISTS advertisements (
  id SERIAL PRIMARY KEY,
  title TEXT NOT NULL,
  subtitle TEXT NOT NULL DEFAULT '',
  image_url TEXT NOT NULL,
  click_url TEXT,
  button_label TEXT NOT NULL DEFAULT '',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  priority INTEGER NOT NULL DEFAULT 0,
  display_seconds INTEGER NOT NULL DEFAULT 5 CHECK (display_seconds BETWEEN 2 AND 30),
  start_at TIMESTAMPTZ,
  end_at TIMESTAMPTZ,
  level_id INTEGER REFERENCES levels(id) ON UPDATE CASCADE ON DELETE SET NULL,
  filiere_id INTEGER REFERENCES filieres(id) ON UPDATE CASCADE ON DELETE SET NULL,
  created_by_id INTEGER REFERENCES users(id) ON UPDATE CASCADE ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS advertisements_public_idx
  ON advertisements(is_active, priority DESC, start_at, end_at, created_at DESC);
CREATE INDEX IF NOT EXISTS advertisements_target_idx
  ON advertisements(level_id, filiere_id, is_active, priority DESC);
