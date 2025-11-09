-- ============================================
-- Cody-2025 Database Schema
-- Single source of truth for all database definitions
-- ============================================
-- 
-- This file defines the complete database schema for:
-- - User Management (Clerk integration)
-- - B2B/Organization Management
-- - HS Code Classifier
-- - Payments (Payoneer integration)
-- - Service Access (API keys, webhooks, job queue)
-- - Audit & Logging
--
-- Environment: Staging (cody2025staging)
-- Database: cody2025
-- Naming Convention: table_name_field_name
-- Primary Keys: SERIAL/BIGSERIAL (auto-increment)
-- ============================================

-- Enable timezone support
SET timezone = 'UTC';

-- ============================================
-- MIGRATIONS & VERSIONING
-- ============================================

-- Schema versions table (track database schema changes)
-- Migration Strategy: Before applying migration, create database backup.
-- If migration fails, restore from backup. If successful, delete backup.
-- One migration can contain multiple changes (add fields, delete fields, etc.)
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

-- ============================================
-- HS CODE CLASSIFIER
-- ============================================

-- Countries table
CREATE TABLE countries (
    country_id SERIAL PRIMARY KEY,
    country_code VARCHAR(2) NOT NULL UNIQUE, -- ISO 3166-1 alpha-2
    country_name VARCHAR(255) NOT NULL,
    country_currency_code VARCHAR(3), -- ISO 4217
    country_timezone VARCHAR(50),
    country_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    country_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_country_code ON countries(country_code);

-- WCO HS Nomenclature Editions (base international standard)
-- Reference: https://www.wcoomd.org/en/topics/nomenclature/instrument-and-tools/hs-nomenclature-2022-edition/hs-nomenclature-2022-edition.aspx
CREATE TABLE wco_editions (
    wco_edition_id SERIAL PRIMARY KEY,
    wco_edition_year INTEGER NOT NULL UNIQUE, -- e.g., 2022, 2017
    wco_edition_name VARCHAR(255) NOT NULL, -- e.g., "HS Nomenclature 2022 Edition"
    wco_edition_description TEXT,
    wco_edition_effective_date DATE,
    wco_edition_is_active BOOLEAN DEFAULT true,
    wco_edition_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    wco_edition_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_wco_edition_year ON wco_editions(wco_edition_year);
CREATE INDEX idx_wco_edition_is_active ON wco_editions(wco_edition_is_active) WHERE wco_edition_is_active = true;

-- WCO Sections (I-XXI) with Section Notes
CREATE TABLE wco_sections (
    wco_section_id SERIAL PRIMARY KEY,
    wco_section_wco_edition_fk INTEGER NOT NULL REFERENCES wco_editions(wco_edition_id) ON DELETE RESTRICT,
    wco_section_number INTEGER NOT NULL, -- Section number (I-XXI, stored as 1-21)
    wco_section_roman_numeral VARCHAR(5) NOT NULL, -- e.g., "I", "II", "XXI"
    wco_section_title VARCHAR(500) NOT NULL, -- e.g., "LIVE ANIMALS; ANIMAL PRODUCTS"
    wco_section_notes TEXT, -- Section Notes content
    wco_section_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    wco_section_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(wco_section_wco_edition_fk, wco_section_number)
);

CREATE INDEX idx_wco_section_edition_fk ON wco_sections(wco_section_wco_edition_fk);
CREATE INDEX idx_wco_section_number ON wco_sections(wco_section_wco_edition_fk, wco_section_number);

-- WCO Chapters (1-97)
CREATE TABLE wco_chapters (
    wco_chapter_id SERIAL PRIMARY KEY,
    wco_chapter_wco_section_fk INTEGER NOT NULL REFERENCES wco_sections(wco_section_id) ON DELETE RESTRICT,
    wco_chapter_number INTEGER NOT NULL, -- Chapter number (1-97)
    wco_chapter_title VARCHAR(500) NOT NULL, -- e.g., "Live animals"
    wco_chapter_notes TEXT, -- Chapter notes
    wco_chapter_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    wco_chapter_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(wco_chapter_wco_section_fk, wco_chapter_number)
);

CREATE INDEX idx_wco_chapter_section_fk ON wco_chapters(wco_chapter_wco_section_fk);
CREATE INDEX idx_wco_chapter_number ON wco_chapters(wco_chapter_wco_section_fk, wco_chapter_number);

-- WCO Headings (4-digit codes, e.g., 01.01, 01.02, 01.03)
-- Reference: https://www.wcoomd.org/-/media/wco/public/global/pdf/topics/nomenclature/instruments-and-tools/hs-nomenclature-2022/2022/0101_2022e.pdf?la=en
CREATE TABLE wco_headings (
    wco_heading_id SERIAL PRIMARY KEY,
    wco_heading_wco_chapter_fk INTEGER NOT NULL REFERENCES wco_chapters(wco_chapter_id) ON DELETE RESTRICT,
    wco_heading_code VARCHAR(5) NOT NULL, -- 4-digit heading code (e.g., "01.01", "01.02")
    wco_heading_title VARCHAR(500) NOT NULL, -- e.g., "Live horses, asses, mules and hinnies"
    wco_heading_notes TEXT, -- Heading notes
    wco_heading_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    wco_heading_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(wco_heading_wco_chapter_fk, wco_heading_code)
);

CREATE INDEX idx_wco_heading_chapter_fk ON wco_headings(wco_heading_wco_chapter_fk);
CREATE INDEX idx_wco_heading_code ON wco_headings(wco_heading_code);

-- WCO 6-digit HS codes (international standard)
CREATE TABLE wco_hs_codes (
    wco_hs_code_id SERIAL PRIMARY KEY,
    wco_hs_code_wco_heading_fk INTEGER NOT NULL REFERENCES wco_headings(wco_heading_id) ON DELETE RESTRICT,
    wco_hs_code_code VARCHAR(7) NOT NULL, -- 6-digit HS code + optional check digit (e.g., "010121", "0101210")
    wco_hs_code_description TEXT NOT NULL, -- Product description
    wco_hs_code_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    wco_hs_code_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(wco_hs_code_wco_heading_fk, wco_hs_code_code)
);

CREATE INDEX idx_wco_hs_code_heading_fk ON wco_hs_codes(wco_hs_code_wco_heading_fk);
CREATE INDEX idx_wco_hs_code_code ON wco_hs_codes(wco_hs_code_code);
CREATE INDEX idx_wco_hs_code_description ON wco_hs_codes USING gin(to_tsvector('english', wco_hs_code_description));

-- Customs books (country-specific HS code classification books)
-- Each country extends the WCO 6-digit codes to full country HS codes (8-11 digits, may include check digit)
-- Note: WCO edition is determined through customs_book_hs_codes -> wco_hs_codes -> wco_editions hierarchy
-- A customs book may contain HS codes from different WCO editions (though typically one edition)
CREATE TABLE customs_books (
    customs_book_id SERIAL PRIMARY KEY,
    customs_book_country_fk INTEGER NOT NULL REFERENCES countries(country_id) ON DELETE RESTRICT,
    customs_book_name VARCHAR(255) NOT NULL,
    customs_book_version VARCHAR(50) NOT NULL,
    customs_book_description TEXT,
    customs_book_checksum_algorithm TEXT, -- Check digit/checksum calculation algorithm (NULL if not used)
    -- Algorithm format: JSON or text description of calculation method
    -- Example: {"type": "modulo", "divisor": 10, "weights": [1,2,3,4,5,6,7,8], "position": 9}
    -- NULL for countries that don't use check digits
    customs_book_is_active BOOLEAN DEFAULT true,
    customs_book_effective_date DATE,
    customs_book_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    customs_book_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(customs_book_country_fk, customs_book_name, customs_book_version)
);

CREATE INDEX idx_customs_book_country_fk ON customs_books(customs_book_country_fk);
CREATE INDEX idx_customs_book_is_active ON customs_books(customs_book_is_active);

-- Country-specific HS codes (extend WCO 6-digit codes to 8-11 digits, may include check digit)
-- Each country adds their own digits and rules based on country laws and needs
-- Note: Some countries create codes that don't exist in WCO, so wco_hs_code_fk is optional
-- Note: Some countries use check digits (7th, 9th, or 11th digit) for validation
CREATE TABLE customs_book_hs_codes (
    customs_book_hs_code_id SERIAL PRIMARY KEY,
    customs_book_hs_code_customs_book_fk INTEGER NOT NULL REFERENCES customs_books(customs_book_id) ON DELETE RESTRICT,
    customs_book_hs_code_wco_hs_code_fk INTEGER REFERENCES wco_hs_codes(wco_hs_code_id) ON DELETE RESTRICT, -- Base 6-digit WCO code (nullable - some countries create codes not in WCO)
    customs_book_hs_code_code VARCHAR(20) NOT NULL, -- Full country HS code (8-11 digits with optional check digit, e.g., "1234.56.78.90" or "1234.56.78.901")
    customs_book_hs_code_description TEXT NOT NULL, -- Country-specific description (may differ from WCO)
    customs_book_hs_code_country_rules JSONB, -- Country-specific classification rules and criteria
    customs_book_hs_code_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    customs_book_hs_code_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(customs_book_hs_code_customs_book_fk, customs_book_hs_code_code)
);

CREATE INDEX idx_cb_hs_codes_book_fk ON customs_book_hs_codes(customs_book_hs_code_customs_book_fk);
CREATE INDEX idx_cb_hs_codes_wco_fk ON customs_book_hs_codes(customs_book_hs_code_wco_hs_code_fk);
CREATE INDEX idx_cb_hs_codes_code ON customs_book_hs_codes(customs_book_hs_code_code);
CREATE INDEX idx_cb_hs_codes_description ON customs_book_hs_codes USING gin(to_tsvector('english', customs_book_hs_code_description));

-- ============================================
-- USER MANAGEMENT
-- ============================================

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

-- ============================================
-- B2B/ORGANIZATION MANAGEMENT
-- ============================================

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

-- ============================================
-- HS CODE CLASSIFIER (continued)
-- ============================================

-- Classifications table (classification requests and results)
CREATE TABLE classifications (
    classification_id SERIAL PRIMARY KEY,
    classification_organization_fk INTEGER REFERENCES organizations(organization_id) ON DELETE RESTRICT,
    classification_user_fk INTEGER REFERENCES users(user_id) ON DELETE RESTRICT,
    classification_customs_book_fk INTEGER NOT NULL REFERENCES customs_books(customs_book_id) ON DELETE RESTRICT,
    classification_product_description TEXT NOT NULL,
    classification_hs_code VARCHAR(20), -- Result HS code (may include check digit, 7-11 digits)
    classification_confidence_score DECIMAL(5,4), -- 0.0000 to 1.0000 (99.99% = 0.9999)
    classification_status VARCHAR(50) NOT NULL DEFAULT 'pending', -- pending, completed, failed, rejected
    classification_rejection_reason TEXT, -- If status is 'rejected' (e.g., "abstract description")
    classification_classification_type VARCHAR(50) NOT NULL DEFAULT 'standard', -- standard, list_lookup, interactive
    classification_company_item_list_fk INTEGER, -- If classification_type is 'list_lookup'
    classification_session_fk INTEGER, -- If classification_type is 'interactive'
    classification_cost_multiplier DECIMAL(10,2) DEFAULT 1.0, -- X, X/D, or M×X
    classification_access_method VARCHAR(50), -- frontend, email, api_webhook, api_sync
    classification_job_id VARCHAR(255), -- For async API webhook method
    classification_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    classification_completed_at TIMESTAMPTZ,
    classification_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_classification_org_id ON classifications(classification_organization_fk);
CREATE INDEX idx_classification_user_id ON classifications(classification_user_fk);
CREATE INDEX idx_classification_customs_book_id ON classifications(classification_customs_book_fk);
CREATE INDEX idx_classification_status ON classifications(classification_status);
CREATE INDEX idx_classification_created_at ON classifications(classification_created_at);
CREATE INDEX idx_classification_session_id ON classifications(classification_session_fk) WHERE classification_session_fk IS NOT NULL;
CREATE INDEX idx_classification_job_id ON classifications(classification_job_id) WHERE classification_job_id IS NOT NULL;

-- Interactive workflow sessions (for Q&A when HS code unknown)
CREATE TABLE interactive_sessions (
    interactive_session_id SERIAL PRIMARY KEY,
    interactive_session_session_id VARCHAR(255) NOT NULL UNIQUE, -- External session ID for API
    interactive_session_classification_fk INTEGER REFERENCES classifications(classification_id) ON DELETE RESTRICT,
    interactive_session_organization_fk INTEGER REFERENCES organizations(organization_id) ON DELETE RESTRICT,
    interactive_session_user_fk INTEGER REFERENCES users(user_id) ON DELETE RESTRICT,
    interactive_session_customs_book_fk INTEGER NOT NULL REFERENCES customs_books(customs_book_id) ON DELETE RESTRICT,
    interactive_session_product_description TEXT NOT NULL,
    interactive_session_status VARCHAR(50) NOT NULL DEFAULT 'active', -- active, completed, expired, cancelled
    interactive_session_current_question_id INTEGER, -- Current question being asked
    interactive_session_question_asked JSONB DEFAULT '[]', -- Array of question IDs asked
    interactive_session_answers_received JSONB DEFAULT '{}', -- Map of question_id -> answer
    interactive_session_pending_questions JSONB DEFAULT '[]', -- Array of pending question IDs
    interactive_session_expires_at TIMESTAMPTZ NOT NULL,
    interactive_session_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    interactive_session_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    interactive_session_completed_at TIMESTAMPTZ
);

CREATE INDEX idx_interactive_session_session_id ON interactive_sessions(interactive_session_session_id);
CREATE INDEX idx_interactive_session_classification_id ON interactive_sessions(interactive_session_classification_fk);
CREATE INDEX idx_interactive_session_status ON interactive_sessions(interactive_session_status);
CREATE INDEX idx_interactive_session_expires_at ON interactive_sessions(interactive_session_expires_at);
CREATE INDEX idx_interactive_session_org_id ON interactive_sessions(interactive_session_organization_fk);

-- Questions table (interactive Q&A for classification)
CREATE TABLE questions (
    question_id SERIAL PRIMARY KEY,
    question_session_fk INTEGER NOT NULL REFERENCES interactive_sessions(interactive_session_id) ON DELETE RESTRICT,
    question_question_text TEXT NOT NULL,
    question_question_type VARCHAR(50) NOT NULL, -- multiple_choice, text, yes_no, etc.
    question_options JSONB, -- For multiple choice questions
    question_answer TEXT, -- User's answer
    question_answer_received_at TIMESTAMPTZ,
    question_order_index INTEGER NOT NULL, -- Order in which question was asked
    question_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    question_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_question_session_id ON questions(question_session_fk);
CREATE INDEX idx_question_order_index ON questions(question_session_fk, question_order_index);

-- Company item code lists (uploaded lists for lookup)
CREATE TABLE company_item_lists (
    company_item_list_id SERIAL PRIMARY KEY,
    company_item_list_organization_fk INTEGER NOT NULL REFERENCES organizations(organization_id) ON DELETE RESTRICT,
    company_item_list_name VARCHAR(255) NOT NULL,
    company_item_list_description TEXT,
    company_item_list_item_count INTEGER DEFAULT 0,
    company_item_list_uploaded_by_user_fk INTEGER REFERENCES users(user_id) ON DELETE RESTRICT,
    company_item_list_file_name VARCHAR(255),
    company_item_list_file_size_bytes INTEGER,
    company_item_list_upload_status VARCHAR(50) DEFAULT 'pending', -- pending, processing, completed, failed
    company_item_list_error_message TEXT,
    company_item_list_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    company_item_list_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    company_item_list_deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_company_item_list_org_id ON company_item_lists(company_item_list_organization_fk);
CREATE INDEX idx_company_item_list_deleted_at ON company_item_lists(company_item_list_deleted_at) WHERE company_item_list_deleted_at IS NULL;

-- Company item code mappings (items in uploaded lists)
CREATE TABLE company_item_mappings (
    company_item_mapping_id SERIAL PRIMARY KEY,
    company_item_mapping_company_item_list_fk INTEGER NOT NULL REFERENCES company_item_lists(company_item_list_id) ON DELETE RESTRICT,
    company_item_mapping_company_item_code VARCHAR(255) NOT NULL,
    company_item_mapping_product_description TEXT,
    company_item_mapping_hs_code VARCHAR(20) NOT NULL,
    company_item_mapping_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    company_item_mapping_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(company_item_mapping_company_item_list_fk, company_item_mapping_company_item_code)
);

CREATE INDEX idx_item_mappings_list_id ON company_item_mappings(company_item_mapping_company_item_list_fk);
CREATE INDEX idx_item_mappings_item_code ON company_item_mappings(company_item_mapping_company_item_code);
CREATE INDEX idx_item_mappings_hs_code ON company_item_mappings(company_item_mapping_hs_code);
CREATE INDEX idx_item_mappings_description ON company_item_mappings USING gin(to_tsvector('english', company_item_mapping_product_description));

-- Transactions/pricing table (track costs per transaction)
CREATE TABLE transactions (
    transaction_id SERIAL PRIMARY KEY,
    transaction_classification_fk INTEGER REFERENCES classifications(classification_id) ON DELETE RESTRICT,
    transaction_organization_fk INTEGER NOT NULL REFERENCES organizations(organization_id) ON DELETE RESTRICT,
    transaction_user_fk INTEGER REFERENCES users(user_id) ON DELETE RESTRICT,
    transaction_transaction_type VARCHAR(50) NOT NULL, -- standard, list_lookup, interactive, abstract
    transaction_base_cost DECIMAL(10,2) NOT NULL, -- Base cost X
    transaction_cost_multiplier DECIMAL(10,2) DEFAULT 1.0, -- Multiplier M or divisor D
    transaction_final_cost DECIMAL(10,2) NOT NULL, -- Final cost (X, X/D, or M×X)
    transaction_currency_code VARCHAR(3) DEFAULT 'USD',
    transaction_status VARCHAR(50) DEFAULT 'pending', -- pending, billed, paid, cancelled
    transaction_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    transaction_billed_at TIMESTAMPTZ,
    transaction_paid_at TIMESTAMPTZ,
    transaction_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_transaction_classification_id ON transactions(transaction_classification_fk);
CREATE INDEX idx_transaction_org_id ON transactions(transaction_organization_fk);
CREATE INDEX idx_transaction_user_id ON transactions(transaction_user_fk);
CREATE INDEX idx_transaction_status ON transactions(transaction_status);
CREATE INDEX idx_transaction_created_at ON transactions(transaction_created_at);

-- ============================================
-- PAYMENTS (Payoneer Integration)
-- ============================================

-- Payment accounts (link to Payoneer, organization linkage)
CREATE TABLE payment_accounts (
    payment_account_id SERIAL PRIMARY KEY,
    payment_account_organization_fk INTEGER NOT NULL REFERENCES organizations(organization_id) ON DELETE RESTRICT,
    payment_account_payoneer_account_id VARCHAR(255) NOT NULL,
    payment_account_account_type VARCHAR(50) NOT NULL, -- receiving, sending, both
    payment_account_currency_code VARCHAR(3) DEFAULT 'USD',
    payment_account_status VARCHAR(50) DEFAULT 'active', -- active, pending_approval, suspended, closed
    payment_account_metadata JSONB DEFAULT '{}', -- Additional Payoneer account metadata
    payment_account_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    payment_account_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_payment_account_org_id ON payment_accounts(payment_account_organization_fk);
CREATE INDEX idx_payment_account_payoneer_id ON payment_accounts(payment_account_payoneer_account_id);
CREATE INDEX idx_payment_account_status ON payment_accounts(payment_account_status);

-- Payment transactions (incoming/outgoing, status, currency)
CREATE TABLE payment_transactions (
    payment_transaction_id SERIAL PRIMARY KEY,
    payment_transaction_payment_account_fk INTEGER NOT NULL REFERENCES payment_accounts(payment_account_id) ON DELETE RESTRICT,
    payment_transaction_organization_fk INTEGER NOT NULL REFERENCES organizations(organization_id) ON DELETE RESTRICT,
    payment_transaction_payoneer_payment_id VARCHAR(255) UNIQUE,
    payment_transaction_transaction_type VARCHAR(50) NOT NULL, -- incoming, outgoing
    payment_transaction_amount DECIMAL(15,2) NOT NULL,
    payment_transaction_currency_code VARCHAR(3) NOT NULL,
    payment_transaction_status VARCHAR(50) NOT NULL DEFAULT 'pending', -- pending, processing, completed, failed, cancelled
    payment_transaction_payment_method VARCHAR(50), -- ACH, SEPA, BACS, BECS, card, PayPal
    payment_transaction_recipient_payee_id VARCHAR(255), -- For outgoing payments
    payment_transaction_description TEXT,
    payment_transaction_invoice_id INTEGER, -- Link to invoices table
    payment_transaction_webhook_received_at TIMESTAMPTZ,
    payment_transaction_metadata JSONB DEFAULT '{}', -- Additional transaction metadata
    payment_transaction_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    payment_transaction_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    payment_transaction_completed_at TIMESTAMPTZ
);

CREATE INDEX idx_payment_transaction_account_id ON payment_transactions(payment_transaction_payment_account_fk);
CREATE INDEX idx_payment_transaction_org_id ON payment_transactions(payment_transaction_organization_fk);
CREATE INDEX idx_payment_transaction_payoneer_id ON payment_transactions(payment_transaction_payoneer_payment_id);
CREATE INDEX idx_payment_transaction_status ON payment_transactions(payment_transaction_status);
CREATE INDEX idx_payment_transaction_created_at ON payment_transactions(payment_transaction_created_at);
CREATE INDEX idx_payment_transaction_invoice_id ON payment_transactions(payment_transaction_invoice_id) WHERE payment_transaction_invoice_id IS NOT NULL;

-- Invoices table (B2B invoice tracking, payment terms)
CREATE TABLE invoices (
    invoice_id SERIAL PRIMARY KEY,
    invoice_organization_fk INTEGER NOT NULL REFERENCES organizations(organization_id) ON DELETE RESTRICT,
    invoice_invoice_number VARCHAR(255) NOT NULL UNIQUE,
    invoice_invoice_date DATE NOT NULL,
    invoice_due_date DATE NOT NULL,
    invoice_payment_terms VARCHAR(50) DEFAULT 'net_30', -- net_30, net_60, due_on_receipt, etc.
    invoice_subtotal DECIMAL(15,2) NOT NULL,
    invoice_tax_amount DECIMAL(15,2) DEFAULT 0,
    invoice_total_amount DECIMAL(15,2) NOT NULL,
    invoice_currency_code VARCHAR(3) DEFAULT 'USD',
    invoice_status VARCHAR(50) DEFAULT 'draft', -- draft, sent, paid, overdue, cancelled
    invoice_payment_account_fk INTEGER REFERENCES payment_accounts(payment_account_id) ON DELETE RESTRICT,
    invoice_paid_at TIMESTAMPTZ,
    invoice_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    invoice_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_invoice_org_id ON invoices(invoice_organization_fk);
CREATE INDEX idx_invoice_invoice_number ON invoices(invoice_invoice_number);
CREATE INDEX idx_invoice_status ON invoices(invoice_status);
CREATE INDEX idx_invoice_due_date ON invoices(invoice_due_date);

-- Invoice line items
CREATE TABLE invoice_line_items (
    invoice_line_item_id SERIAL PRIMARY KEY,
    invoice_line_item_invoice_fk INTEGER NOT NULL REFERENCES invoices(invoice_id) ON DELETE RESTRICT,
    invoice_line_item_transaction_fk INTEGER REFERENCES transactions(transaction_id) ON DELETE RESTRICT,
    invoice_line_item_description TEXT NOT NULL,
    invoice_line_item_quantity INTEGER DEFAULT 1,
    invoice_line_item_unit_price DECIMAL(15,2) NOT NULL,
    invoice_line_item_total_price DECIMAL(15,2) NOT NULL,
    invoice_line_item_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    invoice_line_item_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_invoice_line_item_invoice_id ON invoice_line_items(invoice_line_item_invoice_fk);
CREATE INDEX idx_invoice_line_item_transaction_id ON invoice_line_items(invoice_line_item_transaction_fk) WHERE invoice_line_item_transaction_fk IS NOT NULL;

-- Scheduled payments table (custom recurring payment logic)
CREATE TABLE scheduled_payments (
    scheduled_payment_id SERIAL PRIMARY KEY,
    scheduled_payment_organization_fk INTEGER NOT NULL REFERENCES organizations(organization_id) ON DELETE RESTRICT,
    scheduled_payment_payment_account_fk INTEGER NOT NULL REFERENCES payment_accounts(payment_account_id) ON DELETE RESTRICT,
    scheduled_payment_recipient_payee_id VARCHAR(255) NOT NULL,
    scheduled_payment_amount DECIMAL(15,2) NOT NULL,
    scheduled_payment_currency_code VARCHAR(3) NOT NULL,
    scheduled_payment_frequency VARCHAR(50) NOT NULL, -- daily, weekly, monthly, yearly, custom
    scheduled_payment_next_payment_date DATE NOT NULL,
    scheduled_payment_timezone VARCHAR(50) DEFAULT 'UTC',
    scheduled_payment_status VARCHAR(50) DEFAULT 'active', -- active, paused, cancelled, completed
    scheduled_payment_metadata JSONB DEFAULT '{}', -- Custom schedule configuration
    scheduled_payment_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    scheduled_payment_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    scheduled_payment_cancelled_at TIMESTAMPTZ
);

CREATE INDEX idx_scheduled_payment_org_id ON scheduled_payments(scheduled_payment_organization_fk);
CREATE INDEX idx_scheduled_payment_account_id ON scheduled_payments(scheduled_payment_payment_account_fk);
CREATE INDEX idx_scheduled_payment_status ON scheduled_payments(scheduled_payment_status);
CREATE INDEX idx_scheduled_payment_next_date ON scheduled_payments(scheduled_payment_next_payment_date);

-- ============================================
-- SERVICE ACCESS
-- ============================================

-- API keys and authentication tokens
CREATE TABLE api_keys (
    api_key_id SERIAL PRIMARY KEY,
    api_key_organization_fk INTEGER NOT NULL REFERENCES organizations(organization_id) ON DELETE RESTRICT,
    api_key_user_fk INTEGER REFERENCES users(user_id) ON DELETE RESTRICT,
    api_key_key_name VARCHAR(255) NOT NULL,
    api_key_api_key VARCHAR(255) NOT NULL UNIQUE,
    api_key_key_hash VARCHAR(255) NOT NULL, -- Hashed version for verification
    api_key_permissions JSONB DEFAULT '{}', -- API permissions
    api_key_rate_limit_per_minute INTEGER DEFAULT 60,
    api_key_rate_limit_per_hour INTEGER DEFAULT 1000,
    api_key_last_used_at TIMESTAMPTZ,
    api_key_expires_at TIMESTAMPTZ,
    api_key_is_active BOOLEAN DEFAULT true,
    api_key_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    api_key_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    api_key_revoked_at TIMESTAMPTZ
);

CREATE INDEX idx_api_key_org_id ON api_keys(api_key_organization_fk);
CREATE INDEX idx_api_key_api_key ON api_keys(api_key_api_key);
CREATE INDEX idx_api_key_key_hash ON api_keys(api_key_key_hash);
CREATE INDEX idx_api_key_is_active ON api_keys(api_key_is_active) WHERE api_key_is_active = true;

-- Webhook configurations (client webhook URLs)
CREATE TABLE webhook_configurations (
    webhook_configuration_id SERIAL PRIMARY KEY,
    webhook_configuration_organization_fk INTEGER NOT NULL REFERENCES organizations(organization_id) ON DELETE RESTRICT,
    webhook_configuration_name VARCHAR(255) NOT NULL,
    webhook_configuration_webhook_url TEXT NOT NULL,
    webhook_configuration_webhook_secret VARCHAR(255), -- For signature verification
    webhook_configuration_events JSONB NOT NULL DEFAULT '[]', -- Array of event types to subscribe to
    webhook_configuration_is_active BOOLEAN DEFAULT true,
    webhook_configuration_last_triggered_at TIMESTAMPTZ,
    webhook_configuration_failure_count INTEGER DEFAULT 0,
    webhook_configuration_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    webhook_configuration_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_webhook_configs_org_id ON webhook_configurations(webhook_configuration_organization_fk);
CREATE INDEX idx_webhook_configs_is_active ON webhook_configurations(webhook_configuration_is_active) WHERE webhook_configuration_is_active = true;

-- Webhook delivery attempts (track individual webhook delivery attempts for async API)
CREATE TABLE webhook_deliveries (
    webhook_delivery_id SERIAL PRIMARY KEY,
    webhook_delivery_webhook_configuration_fk INTEGER NOT NULL REFERENCES webhook_configurations(webhook_configuration_id) ON DELETE RESTRICT,
    webhook_delivery_job_fk VARCHAR(255) REFERENCES job_queue(job_queue_job_id) ON DELETE RESTRICT,
    webhook_delivery_url TEXT NOT NULL,
    webhook_delivery_payload JSONB NOT NULL,
    webhook_delivery_status VARCHAR(50) NOT NULL DEFAULT 'pending', -- pending, sent, delivered, failed
    webhook_delivery_http_status_code INTEGER,
    webhook_delivery_response_body TEXT,
    webhook_delivery_error_message TEXT,
    webhook_delivery_retry_count INTEGER DEFAULT 0,
    webhook_delivery_max_retries INTEGER DEFAULT 3,
    webhook_delivery_sent_at TIMESTAMPTZ,
    webhook_delivery_delivered_at TIMESTAMPTZ,
    webhook_delivery_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    webhook_delivery_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_webhook_deliveries_config_id ON webhook_deliveries(webhook_delivery_webhook_configuration_fk);
CREATE INDEX idx_webhook_deliveries_job_id ON webhook_deliveries(webhook_delivery_job_fk) WHERE webhook_delivery_job_fk IS NOT NULL;
CREATE INDEX idx_webhook_deliveries_status ON webhook_deliveries(webhook_delivery_status);
CREATE INDEX idx_webhook_deliveries_created_at ON webhook_deliveries(webhook_delivery_created_at);

-- Job queue table (async API processing)
CREATE TABLE job_queue (
    job_queue_id SERIAL PRIMARY KEY,
    job_queue_job_id VARCHAR(255) NOT NULL UNIQUE,
    job_queue_organization_fk INTEGER REFERENCES organizations(organization_id) ON DELETE RESTRICT,
    job_queue_user_fk INTEGER REFERENCES users(user_id) ON DELETE RESTRICT,
    job_queue_job_type VARCHAR(50) NOT NULL, -- classification, webhook_delivery, email_send, etc.
    job_queue_status VARCHAR(50) NOT NULL DEFAULT 'pending', -- pending, processing, completed, failed, retrying
    job_queue_priority INTEGER DEFAULT 0, -- Higher number = higher priority
    job_queue_payload JSONB NOT NULL DEFAULT '{}', -- Job data
    job_queue_result JSONB, -- Job result
    job_queue_error_message TEXT,
    job_queue_retry_count INTEGER DEFAULT 0,
    job_queue_max_retries INTEGER DEFAULT 3,
    job_queue_scheduled_at TIMESTAMPTZ,
    job_queue_started_at TIMESTAMPTZ,
    job_queue_completed_at TIMESTAMPTZ,
    job_queue_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    job_queue_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_job_queue_job_id ON job_queue(job_queue_job_id);
CREATE INDEX idx_job_queue_status ON job_queue(job_queue_status);
CREATE INDEX idx_job_queue_scheduled_at ON job_queue(job_queue_scheduled_at) WHERE job_queue_scheduled_at IS NOT NULL;
CREATE INDEX idx_job_queue_priority ON job_queue(job_queue_priority DESC, job_queue_created_at);
CREATE INDEX idx_job_queue_org_id ON job_queue(job_queue_organization_fk) WHERE job_queue_organization_fk IS NOT NULL;

-- ============================================
-- AUDIT & LOGGING
-- ============================================

-- Audit logs table (user actions, classification history)
CREATE TABLE audit_logs (
    audit_log_id SERIAL PRIMARY KEY,
    audit_log_organization_fk INTEGER REFERENCES organizations(organization_id) ON DELETE RESTRICT,
    audit_log_user_fk INTEGER REFERENCES users(user_id) ON DELETE RESTRICT,
    audit_log_action_type VARCHAR(100) NOT NULL, -- classification_request, payment_created, user_login, etc.
    audit_log_resource_type VARCHAR(100), -- classification, payment, user, etc.
    audit_log_resource_id INTEGER,
    audit_log_details JSONB DEFAULT '{}', -- Action details
    audit_log_ip_address INET,
    audit_log_user_agent TEXT,
    audit_log_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    audit_log_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_log_org_id ON audit_logs(audit_log_organization_fk);
CREATE INDEX idx_audit_log_user_id ON audit_logs(audit_log_user_fk);
CREATE INDEX idx_audit_log_action_type ON audit_logs(audit_log_action_type);
CREATE INDEX idx_audit_log_resource ON audit_logs(audit_log_resource_type, audit_log_resource_id);
CREATE INDEX idx_audit_log_created_at ON audit_logs(audit_log_created_at);

-- Error logs table
CREATE TABLE error_logs (
    error_log_id SERIAL PRIMARY KEY,
    error_log_organization_fk INTEGER REFERENCES organizations(organization_id) ON DELETE RESTRICT,
    error_log_user_fk INTEGER REFERENCES users(user_id) ON DELETE RESTRICT,
    error_log_error_type VARCHAR(100) NOT NULL,
    error_log_error_message TEXT NOT NULL,
    error_log_stack_trace TEXT,
    error_log_context JSONB DEFAULT '{}', -- Additional context
    error_log_severity VARCHAR(20) DEFAULT 'error', -- info, warning, error, critical
    error_log_resolved BOOLEAN DEFAULT false,
    error_log_resolved_at TIMESTAMPTZ,
    error_log_resolved_by_user_fk INTEGER REFERENCES users(user_id) ON DELETE RESTRICT,
    error_log_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    error_log_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_error_log_org_id ON error_logs(error_log_organization_fk);
CREATE INDEX idx_error_log_user_id ON error_logs(error_log_user_fk);
CREATE INDEX idx_error_log_error_type ON error_logs(error_log_error_type);
CREATE INDEX idx_error_log_severity ON error_logs(error_log_severity);
CREATE INDEX idx_error_log_resolved ON error_logs(error_log_resolved) WHERE error_log_resolved = false;
CREATE INDEX idx_error_log_created_at ON error_logs(error_log_created_at);

-- ============================================
-- FUNCTIONS & TRIGGERS
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    -- Dynamically update the updated_at column based on table name
    -- Note: schema_versions doesn't have updated_at, so skip it
    IF TG_TABLE_NAME = 'users' THEN
        NEW.user_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'user_profiles' THEN
        NEW.user_profile_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'organizations' THEN
        NEW.organization_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'organization_members' THEN
        NEW.organization_member_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'organization_groups' THEN
        NEW.organization_group_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'organization_group_members' THEN
        NEW.organization_group_member_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'countries' THEN
        NEW.country_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'wco_editions' THEN
        NEW.wco_edition_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'wco_sections' THEN
        NEW.wco_section_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'wco_chapters' THEN
        NEW.wco_chapter_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'wco_headings' THEN
        NEW.wco_heading_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'wco_hs_codes' THEN
        NEW.wco_hs_code_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'customs_books' THEN
        NEW.customs_book_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'customs_book_hs_codes' THEN
        NEW.customs_book_hs_code_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'classifications' THEN
        NEW.classification_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'interactive_sessions' THEN
        NEW.interactive_session_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'questions' THEN
        NEW.question_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'company_item_lists' THEN
        NEW.company_item_list_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'company_item_mappings' THEN
        NEW.company_item_mapping_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'transactions' THEN
        NEW.transaction_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'payment_accounts' THEN
        NEW.payment_account_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'payment_transactions' THEN
        NEW.payment_transaction_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'invoices' THEN
        NEW.invoice_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'invoice_line_items' THEN
        NEW.invoice_line_item_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'scheduled_payments' THEN
        NEW.scheduled_payment_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'api_keys' THEN
        NEW.api_key_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'webhook_configurations' THEN
        NEW.webhook_configuration_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'webhook_deliveries' THEN
        NEW.webhook_delivery_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'job_queue' THEN
        NEW.job_queue_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'audit_logs' THEN
        NEW.audit_log_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'error_logs' THEN
        NEW.error_log_updated_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply updated_at trigger to all tables
-- Note: schema_versions doesn't have updated_at, so no trigger needed

CREATE TRIGGER update_user_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_profile_updated_at BEFORE UPDATE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_organization_updated_at BEFORE UPDATE ON organizations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_organization_member_updated_at BEFORE UPDATE ON organization_members
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_organization_group_updated_at BEFORE UPDATE ON organization_groups
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_organization_group_member_updated_at BEFORE UPDATE ON organization_group_members
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_country_updated_at BEFORE UPDATE ON countries
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_wco_edition_updated_at BEFORE UPDATE ON wco_editions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_wco_section_updated_at BEFORE UPDATE ON wco_sections
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_wco_chapter_updated_at BEFORE UPDATE ON wco_chapters
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_wco_heading_updated_at BEFORE UPDATE ON wco_headings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_wco_hs_code_updated_at BEFORE UPDATE ON wco_hs_codes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_customs_book_updated_at BEFORE UPDATE ON customs_books
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_customs_book_hs_code_updated_at BEFORE UPDATE ON customs_book_hs_codes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_classification_updated_at BEFORE UPDATE ON classifications
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_interactive_session_updated_at BEFORE UPDATE ON interactive_sessions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_question_updated_at BEFORE UPDATE ON questions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_company_item_list_updated_at BEFORE UPDATE ON company_item_lists
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_company_item_mapping_updated_at BEFORE UPDATE ON company_item_mappings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_transaction_updated_at BEFORE UPDATE ON transactions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_payment_account_updated_at BEFORE UPDATE ON payment_accounts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_payment_transaction_updated_at BEFORE UPDATE ON payment_transactions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_invoice_updated_at BEFORE UPDATE ON invoices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_invoice_line_item_updated_at BEFORE UPDATE ON invoice_line_items
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_scheduled_payment_updated_at BEFORE UPDATE ON scheduled_payments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_api_key_updated_at BEFORE UPDATE ON api_keys
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_webhook_configuration_updated_at BEFORE UPDATE ON webhook_configurations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_webhook_delivery_updated_at BEFORE UPDATE ON webhook_deliveries
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_job_queue_updated_at BEFORE UPDATE ON job_queue
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_audit_log_updated_at BEFORE UPDATE ON audit_logs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_error_log_updated_at BEFORE UPDATE ON error_logs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to update company_item_lists.item_count
CREATE OR REPLACE FUNCTION update_item_list_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE company_item_lists
        SET company_item_list_item_count = company_item_list_item_count + 1
        WHERE company_item_list_id = NEW.company_item_mapping_company_item_list_fk;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE company_item_lists
        SET company_item_list_item_count = GREATEST(0, company_item_list_item_count - 1)
        WHERE company_item_list_id = OLD.company_item_mapping_company_item_list_fk;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_item_list_count_trigger
    AFTER INSERT OR DELETE ON company_item_mappings
    FOR EACH ROW EXECUTE FUNCTION update_item_list_count();

-- ============================================
-- INITIAL DATA
-- ============================================

-- Insert common countries
INSERT INTO countries (country_code, country_name, country_currency_code, country_timezone) VALUES
    ('IL', 'Israel', 'ILS', 'Asia/Jerusalem'),
    ('US', 'United States', 'USD', 'America/New_York'),
    ('GB', 'United Kingdom', 'GBP', 'Europe/London'),
    ('DE', 'Germany', 'EUR', 'Europe/Berlin'),
    ('FR', 'France', 'EUR', 'Europe/Paris'),
    ('IT', 'Italy', 'EUR', 'Europe/Rome'),
    ('ES', 'Spain', 'EUR', 'Europe/Madrid'),
    ('NL', 'Netherlands', 'EUR', 'Europe/Amsterdam'),
    ('BE', 'Belgium', 'EUR', 'Europe/Brussels'),
    ('CH', 'Switzerland', 'CHF', 'Europe/Zurich'),
    ('AU', 'Australia', 'AUD', 'Australia/Sydney'),
    ('CA', 'Canada', 'CAD', 'America/Toronto'),
    ('JP', 'Japan', 'JPY', 'Asia/Tokyo'),
    ('CN', 'China', 'CNY', 'Asia/Shanghai'),
    ('IN', 'India', 'INR', 'Asia/Kolkata')
ON CONFLICT (country_code) DO NOTHING;

-- ============================================
-- COMMENTS
-- ============================================

COMMENT ON TABLE users IS 'Users linked to Clerk user IDs';
COMMENT ON TABLE organizations IS 'B2B organizations linked to Clerk organization IDs';
COMMENT ON TABLE classifications IS 'HS code classification requests and results';
COMMENT ON TABLE interactive_sessions IS 'Interactive Q&A sessions for classification when HS code is unknown';
COMMENT ON TABLE company_item_lists IS 'Uploaded company item code lists for lookup';
COMMENT ON TABLE transactions IS 'Transaction pricing tracking (X, X/D, M×X)';
COMMENT ON TABLE payment_accounts IS 'Payment accounts linked to Payoneer';
COMMENT ON TABLE payment_transactions IS 'Payment transactions (incoming/outgoing)';
COMMENT ON TABLE invoices IS 'B2B invoices with payment terms';
COMMENT ON TABLE scheduled_payments IS 'Custom recurring payment schedules';
COMMENT ON TABLE api_keys IS 'API keys for service access';
COMMENT ON TABLE webhook_configurations IS 'Client webhook URLs for async API';
COMMENT ON TABLE job_queue IS 'Async job processing queue';
COMMENT ON TABLE audit_logs IS 'Audit trail of user actions';
COMMENT ON TABLE error_logs IS 'Application error logging';
COMMENT ON TABLE schema_versions IS 'Database schema version tracking for rollback';
