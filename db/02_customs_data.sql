-- ============================================
-- CUSTOMS DATA
-- ============================================
-- WCO HS Nomenclature and country-specific customs books

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
    wco_edition_introduction TEXT, -- Introduction text from introduction_2022e.md
    wco_edition_gir_rules JSONB, -- General Rules for Interpretation (GIR) from 0001_2022e-gir.md
    -- Format: {"rule_1": {"title": "Rule 1", "text": "..."}, "rule_2": {...}, ...}
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
    -- Automated sync tracking fields (for data synchronization mechanisms)
    customs_book_data_source_url TEXT, -- URL where data is downloaded from (WCO, country authority, etc.)
    customs_book_sync_status VARCHAR(50) DEFAULT 'never_synced', -- never_synced, pending, in_progress, success, failed
    customs_book_last_sync_time TIMESTAMPTZ, -- Last successful sync timestamp
    customs_book_last_sync_attempt_time TIMESTAMPTZ, -- Last sync attempt (success or failure)
    customs_book_next_sync_scheduled_at TIMESTAMPTZ, -- When next sync is scheduled
    customs_book_sync_error_message TEXT, -- Error message if sync failed
    customs_book_sync_retry_count INTEGER DEFAULT 0, -- Number of retry attempts
    customs_book_sync_max_retries INTEGER DEFAULT 3, -- Maximum retries before alerting
    customs_book_sync_checksum VARCHAR(255), -- Checksum/hash of last synced data for change detection
    customs_book_sync_metadata JSONB, -- Additional sync metadata (source version, file size, etc.)
    customs_book_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    customs_book_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(customs_book_country_fk, customs_book_name, customs_book_version)
);

CREATE INDEX idx_customs_book_country_fk ON customs_books(customs_book_country_fk);
CREATE INDEX idx_customs_book_is_active ON customs_books(customs_book_is_active);
CREATE INDEX idx_customs_book_sync_status ON customs_books(customs_book_sync_status) WHERE customs_book_sync_status IN ('pending', 'in_progress', 'failed');
CREATE INDEX idx_customs_book_next_sync ON customs_books(customs_book_next_sync_scheduled_at) WHERE customs_book_next_sync_scheduled_at IS NOT NULL;
CREATE INDEX idx_customs_book_last_sync ON customs_books(customs_book_last_sync_time) WHERE customs_book_last_sync_time IS NOT NULL;

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

