-- ============================================
-- USER DATA
-- ============================================
-- User management and B2B/Organization management

-- Users table (links to Clerk user IDs)
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    user_clerk_user_id VARCHAR(255) NOT NULL UNIQUE,
    user_email VARCHAR(255) NOT NULL UNIQUE,
    user_first_name VARCHAR(255),
    user_last_name VARCHAR(255),
    user_phone_number VARCHAR(50),
    user_timezone VARCHAR(50) DEFAULT 'UTC',
    user_locale VARCHAR(10) DEFAULT 'en',
    user_default_customs_book_fk INTEGER REFERENCES customs_books(customs_book_id) ON DELETE RESTRICT,
    user_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    user_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    user_deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_user_clerk_user_id ON users(user_clerk_user_id);
CREATE INDEX idx_user_email ON users(user_email);
CREATE INDEX idx_user_deleted_at ON users(user_deleted_at) WHERE user_deleted_at IS NULL;

-- User profiles and preferences
CREATE TABLE user_profiles (
    user_profile_id SERIAL PRIMARY KEY,
    user_profile_user_fk INTEGER NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    user_profile_company_name VARCHAR(255),
    user_profile_job_title VARCHAR(255),
    user_profile_address_line1 VARCHAR(255),
    user_profile_address_line2 VARCHAR(255),
    user_profile_city VARCHAR(100),
    user_profile_state_province VARCHAR(100),
    user_profile_postal_code VARCHAR(20),
    user_profile_country_code VARCHAR(2), -- ISO 3166-1 alpha-2
    user_profile_currency_code VARCHAR(3) DEFAULT 'USD', -- ISO 4217
    user_profile_preferences JSONB DEFAULT '{}', -- Flexible preferences storage
    user_profile_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    user_profile_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_user_profile_user_id ON user_profiles(user_profile_user_fk);
CREATE INDEX idx_user_profile_country_code ON user_profiles(user_profile_country_code);

-- Organizations table (links to Clerk organization IDs)
CREATE TABLE organizations (
    organization_id SERIAL PRIMARY KEY,
    organization_clerk_organization_id VARCHAR(255) NOT NULL UNIQUE,
    organization_name VARCHAR(255) NOT NULL,
    organization_slug VARCHAR(255) NOT NULL UNIQUE,
    organization_email VARCHAR(255),
    organization_phone_number VARCHAR(50),
    organization_address_line1 VARCHAR(255),
    organization_address_line2 VARCHAR(255),
    organization_city VARCHAR(100),
    organization_state_province VARCHAR(100),
    organization_postal_code VARCHAR(20),
    organization_country_code VARCHAR(2), -- ISO 3166-1 alpha-2
    organization_currency_code VARCHAR(3) DEFAULT 'USD', -- ISO 4217
    organization_timezone VARCHAR(50) DEFAULT 'UTC',
    organization_default_customs_book_fk INTEGER REFERENCES customs_books(customs_book_id) ON DELETE RESTRICT,
    organization_settings JSONB DEFAULT '{}', -- Organization-level settings
    organization_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    organization_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    organization_deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_organization_clerk_org_id ON organizations(organization_clerk_organization_id);
CREATE INDEX idx_organization_slug ON organizations(organization_slug);
CREATE INDEX idx_organization_deleted_at ON organizations(organization_deleted_at) WHERE organization_deleted_at IS NULL;

-- Organization members (users in organizations)
CREATE TABLE organization_members (
    organization_member_id SERIAL PRIMARY KEY,
    organization_member_organization_fk INTEGER NOT NULL REFERENCES organizations(organization_id) ON DELETE RESTRICT,
    organization_member_user_fk INTEGER NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    organization_member_role VARCHAR(50) NOT NULL DEFAULT 'member', -- owner, admin, member, viewer
    organization_member_permissions JSONB DEFAULT '{}', -- Role-specific permissions
    organization_member_invited_by_user_fk INTEGER REFERENCES users(user_id) ON DELETE RESTRICT,
    organization_member_invited_at TIMESTAMPTZ,
    organization_member_joined_at TIMESTAMPTZ,
    organization_member_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    organization_member_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    organization_member_deleted_at TIMESTAMPTZ,
    UNIQUE(organization_member_organization_fk, organization_member_user_fk)
);

CREATE INDEX idx_org_members_org_id ON organization_members(organization_member_organization_fk);
CREATE INDEX idx_org_members_user_id ON organization_members(organization_member_user_fk);
CREATE INDEX idx_org_members_role ON organization_members(organization_member_role);
CREATE INDEX idx_org_members_deleted_at ON organization_members(organization_member_deleted_at) WHERE organization_member_deleted_at IS NULL;

-- Groups/teams within organizations
CREATE TABLE organization_groups (
    organization_group_id SERIAL PRIMARY KEY,
    organization_group_organization_fk INTEGER NOT NULL REFERENCES organizations(organization_id) ON DELETE RESTRICT,
    organization_group_name VARCHAR(255) NOT NULL,
    organization_group_description TEXT,
    organization_group_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    organization_group_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    organization_group_deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_org_groups_org_id ON organization_groups(organization_group_organization_fk);
CREATE INDEX idx_org_groups_deleted_at ON organization_groups(organization_group_deleted_at) WHERE organization_group_deleted_at IS NULL;

-- Group members
CREATE TABLE organization_group_members (
    organization_group_member_id SERIAL PRIMARY KEY,
    organization_group_member_group_fk INTEGER NOT NULL REFERENCES organization_groups(organization_group_id) ON DELETE RESTRICT,
    organization_group_member_user_fk INTEGER NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    organization_group_member_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    organization_group_member_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(organization_group_member_group_fk, organization_group_member_user_fk)
);

CREATE INDEX idx_org_group_members_group_id ON organization_group_members(organization_group_member_group_fk);
CREATE INDEX idx_org_group_members_user_id ON organization_group_members(organization_group_member_user_fk);

COMMENT ON TABLE users IS 'Users linked to Clerk user IDs';
COMMENT ON TABLE organizations IS 'B2B organizations linked to Clerk organization IDs';

