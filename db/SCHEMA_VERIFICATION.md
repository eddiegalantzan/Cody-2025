# Database Schema Verification for WCO Markdown Files

Verification that the database schema can properly store all data extracted from the 111 WCO Markdown files.

## Data Structure in Markdown Files

### From Sample Files Analysis:

**1. Chapter/Heading Files (e.g., `0101_2022e.md`):**
- Chapter number and title (e.g., "Chapter 1", "Live animals")
- Chapter notes (e.g., "This Chapter covers all live animals except...")
- 4-digit headings (e.g., "01.01", "01.02", "01.03")
- Heading titles (e.g., "Live horses, asses, mules and hinnies")
- 6-digit HS codes (e.g., "0101.21", "0101.29", "0101.30", "0101.90")
- HS code descriptions (e.g., "Pure-bred breeding animals", "Other")
- Heading notes (if any)

**2. GIR File (`0001_2022e-gir.md`):**
- General Rules for Interpretation (Rules 1-6)
- These are classification rules that apply to all HS codes

**3. Introduction File (`introduction_2022e.md`):**
- Introduction to HS Nomenclature
- General information about the system

**4. Table of Contents (`table-of-contents_2022e_rev.md`):**
- Overview of sections and chapters

## Schema Verification

### ✅ Supported Data Structures

**1. WCO Edition:**
- ✅ `wco_editions` table supports edition year (2022)
- Fields: `wco_edition_year`, `wco_edition_name`, `wco_edition_description`, `wco_edition_effective_date`

**2. Sections:**
- ✅ `wco_sections` table supports sections (I-XXI)
- Fields: `wco_section_number`, `wco_section_roman_numeral`, `wco_section_title`, `wco_section_notes`
- Note: Section information may need to be extracted from table of contents or chapter files

**3. Chapters:**
- ✅ `wco_chapters` table supports chapters (1-97)
- Fields: `wco_chapter_number`, `wco_chapter_title`, `wco_chapter_notes`
- Links to section via `wco_chapter_wco_section_fk`

**4. Headings (4-digit):**
- ✅ `wco_headings` table supports 4-digit headings (e.g., 01.01, 01.02)
- Fields: `wco_heading_code` (VARCHAR(5)), `wco_heading_title`, `wco_heading_notes`
- Links to chapter via `wco_heading_wco_chapter_fk`

**5. HS Codes (6-digit):**
- ✅ `wco_hs_codes` table supports 6-digit HS codes (e.g., 010121, 010129)
- Fields: `wco_hs_code_code` (VARCHAR(7)), `wco_hs_code_description`
- Links to heading via `wco_hs_code_wco_heading_fk`
- Note: Code format in Markdown is "0101.21" but should be stored as "010121" (6 digits)

**6. Notes:**
- ✅ Section notes: `wco_section_notes` (TEXT)
- ✅ Chapter notes: `wco_chapter_notes` (TEXT)
- ✅ Heading notes: `wco_heading_notes` (TEXT)

### ⚠️ Potential Issues / Missing Elements

**1. GIR (General Rules for Interpretation):**
- ❓ **Question:** Where should GIR rules be stored?
- Current schema: No dedicated table for GIR rules
- Options:
  - Store in `wco_editions.wco_edition_description` (not ideal - too specific)
  - Add `wco_editions.wco_edition_gir_rules` JSONB field (recommended)
  - Create separate `wco_gir_rules` table (if rules need versioning)

**2. Section Information:**
- ⚠️ **Issue:** Section information (I-XXI) may not be in individual chapter files
- May need to extract from table of contents or introduction file
- Schema supports it, but extraction logic needs to handle this

**3. HS Code Format:**
- ⚠️ **Issue:** Markdown shows codes as "0101.21" (with dots)
- Schema expects "010121" (6 digits, no dots)
- Extraction logic must normalize: remove dots, ensure 6 digits

**4. Subheading Hierarchy:**
- ⚠️ **Issue:** Markdown shows indentation/hierarchy (e.g., "- Horses :", "-- Pure-bred")
- Schema stores flat 6-digit codes under headings
- Need to verify if hierarchy information is needed or if flat structure is sufficient

**5. Introduction Content:**
- ❓ **Question:** Should introduction content be stored?
- Current schema: No dedicated field
- Options:
  - Store in `wco_editions.wco_edition_description`
  - Add `wco_editions.wco_edition_introduction` TEXT field

**6. Table of Contents:**
- ❓ **Question:** Should table of contents be stored?
- Current schema: No dedicated field
- May not be needed if we can reconstruct from database queries

## Recommended Schema Enhancements

### 1. Add GIR Rules Field (Recommended)

GIR rules are critical for classification and should be stored with the edition:

```sql
ALTER TABLE wco_editions 
ADD COLUMN wco_edition_gir_rules JSONB;
-- Store GIR rules as structured JSON
-- Example: {
--   "rule_1": {"title": "Rule 1", "text": "..."},
--   "rule_2": {"title": "Rule 2", "text": "..."},
--   ...
-- }
```

**Alternative:** If rules need individual querying/versioning, create separate table:
```sql
CREATE TABLE wco_gir_rules (
    wco_gir_rule_id SERIAL PRIMARY KEY,
    wco_gir_rule_wco_edition_fk INTEGER NOT NULL REFERENCES wco_editions(wco_edition_id),
    wco_gir_rule_number INTEGER NOT NULL, -- Rule 1, 2, 3, etc.
    wco_gir_rule_title VARCHAR(255),
    wco_gir_rule_text TEXT NOT NULL,
    wco_gir_rule_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    wco_gir_rule_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(wco_gir_rule_wco_edition_fk, wco_gir_rule_number)
);
```

### 2. Add Introduction Field (Optional)

Introduction content can be stored in edition description or separate field:

```sql
ALTER TABLE wco_editions 
ADD COLUMN wco_edition_introduction TEXT;
```

## Data Extraction Mapping

### From Markdown to Database:

**Chapter File (e.g., `0101_2022e.md`):**
```
Markdown: "Chapter 1" + "Live animals"
→ wco_chapters: wco_chapter_number = 1, wco_chapter_title = "Live animals"

Markdown: "Note. 1.- This Chapter covers..."
→ wco_chapters: wco_chapter_notes = "1.- This Chapter covers..."

Markdown: "01.01 Live horses, asses, mules and hinnies."
→ wco_headings: wco_heading_code = "01.01", wco_heading_title = "Live horses, asses, mules and hinnies."

Markdown: "0101.21 -- Pure-bred breeding animals"
→ wco_hs_codes: wco_hs_code_code = "010121", wco_hs_code_description = "Pure-bred breeding animals"
```

**GIR File (`0001_2022e-gir.md`):**
```
Markdown: "1. The titles of Sections..."
→ wco_editions.wco_edition_gir_rules (JSONB) or wco_gir_rules table
```

## Verification Checklist

- [x] Edition storage (wco_editions)
- [x] Section storage (wco_sections) - extractable from table-of-contents file
- [x] Chapter storage (wco_chapters)
- [x] Heading storage (wco_headings) - 4-digit codes
- [x] HS code storage (wco_hs_codes) - 6-digit codes
- [x] Notes storage (at section, chapter, heading levels)
- [x] GIR rules storage - **ADDED** to `wco_editions.wco_edition_gir_rules` (JSONB)
- [x] Introduction storage - **ADDED** to `wco_editions.wco_edition_introduction` (TEXT)
- [x] Table of contents - Not needed (can be reconstructed from database)

## Schema Updates Applied

✅ **GIR Rules:** Added `wco_edition_gir_rules` JSONB field to `wco_editions` table in `db/02_customs_data.sql`
✅ **Introduction:** Added `wco_edition_introduction` TEXT field to `wco_editions` table in `db/02_customs_data.sql`

The schema has been updated directly in `db/02_customs_data.sql` (no ALTER statements needed - we're in planning phase).

## Next Steps

1. ✅ **Schema updated** - GIR and Introduction fields added
2. **Verify section extraction:** Section info available in `table-of-contents_2022e_rev.md`
3. **Test extraction:** Create sample extraction to verify schema compatibility
4. **LLM extraction:** Proceed with creating LLM extraction script

