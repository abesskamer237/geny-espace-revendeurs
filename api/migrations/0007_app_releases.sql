-- ENSPY v2.3.0 - mobile application release management
-- Safe to run repeatedly.
CREATE TABLE IF NOT EXISTS app_releases (
  id SERIAL PRIMARY KEY,
  version_name TEXT NOT NULL,
  version_code INTEGER NOT NULL UNIQUE,
  release_notes TEXT NOT NULL DEFAULT '',
  file_url TEXT NOT NULL,
  original_name TEXT NOT NULL,
  stored_name TEXT NOT NULL UNIQUE,
  mime_type TEXT NOT NULL DEFAULT 'application/vnd.android.package-archive',
  file_size BIGINT NOT NULL DEFAULT 0,
  sha256 TEXT,
  download_count INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT FALSE,
  created_by_id INTEGER REFERENCES users(id) ON UPDATE CASCADE ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  published_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS app_releases_active_idx ON app_releases(is_active, version_code DESC);
CREATE INDEX IF NOT EXISTS app_releases_created_idx ON app_releases(created_at DESC);
