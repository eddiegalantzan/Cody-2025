-- ============================================
-- SCHEMA VERSIONING
-- ============================================

-- Schema versions table (track database schema versions)
-- Note: Migrations are NOT needed until production is running.
-- During planning and development, all schema changes go directly into init.sql.
-- Migration procedures will only be needed after production deployment when we need to modify the schema without losing data.
CREATE TABLE schema_versions (
    schema_version_id SERIAL PRIMARY KEY,
    schema_version_version VARCHAR(50) NOT NULL UNIQUE, -- e.g., "1.0.0", "1.1.0"
    schema_version_description TEXT NOT NULL, -- What changed in this migration
    schema_version_up_sql TEXT NOT NULL, -- SQL to apply this version (can contain multiple statements)
    schema_version_is_current BOOLEAN DEFAULT false, -- Current active version
    schema_version_applied_at TIMESTAMPTZ, -- When this version was applied (NULL if not applied yet)
    schema_version_applied_by VARCHAR(255) -- User/system that applied migration
);

CREATE INDEX idx_schema_version_version ON schema_versions(schema_version_version);
CREATE INDEX idx_schema_version_is_current ON schema_versions(schema_version_is_current) WHERE schema_version_is_current = true;

-- Insert initial schema version
INSERT INTO schema_versions (schema_version_version, schema_version_description, schema_version_up_sql, schema_version_is_current, schema_version_applied_at, schema_version_applied_by)
VALUES (
    '1.0.0',
    'Initial database schema - Cody-2025',
    '-- Initial schema applied via init.sql',
    true,
    NOW(),
    'system'
);

COMMENT ON TABLE schema_versions IS 'Database schema version tracking for rollback';

