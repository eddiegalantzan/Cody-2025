# Database Schema vs. Actual Data Analysis

**Date**: 2025-01-XX  
**Purpose**: Verify database schema design matches the actual WCO HS Nomenclature data structure

## Data Available

We have downloaded and converted 4 editions:
- **2007 edition**: 108 PDFs → 108 Markdown files
- **2012 edition**: 109 PDFs → 109 Markdown files
- **2017 edition**: 111 PDFs → 111 Markdown files
- **2022 edition**: 111 PDFs → 111 Markdown files

**Total**: 439 Markdown files ready for analysis

## File Structure Analysis

### File Naming Patterns

Based on 2022 edition analysis:

1. **`0001_2022e-gir.md`** - General Rules for Interpretation (GIR)
2. **`0100_2022e.md`** - Section I (Section title and notes)
3. **`0101_2022e.md`** - Chapter 1 (Chapter title, notes, headings, and 6-digit codes)
4. **`0102_2022e.md`** - Chapter 2 (Chapter title, notes, headings, and 6-digit codes)
5. **`0200_2022e.md`** - Section II (Section title and notes)
6. **`0206_2022e.md`** - Chapter 2, Heading 02.06 (Individual heading file)
7. **`introduction_2022e.md`** - Introduction text
8. **`table-of-contents_2022e_rev.pdf`** - Table of contents (not converted yet)

### Data Structure in Files

#### 1. Introduction File (`introduction_2022e.md`)
- **Content**: Introduction text explaining the HS Nomenclature
- **Schema Field**: `wco_editions.wco_edition_introduction` (TEXT)
- **Status**: ✅ **MATCHES** - Schema has field for introduction

#### 2. GIR Rules File (`0001_2022e-gir.md`)
- **Content**: 6 General Rules for Interpretation
- **Schema Field**: `wco_editions.wco_edition_gir_rules` (JSONB)
- **Status**: ✅ **MATCHES** - Schema has JSONB field for structured GIR rules
- **Note**: Need to parse and structure the 6 rules into JSON format

#### 3. Section Files (e.g., `0100_2022e.md`)
- **Content**: 
  - Section number (e.g., "Section I")
  - Section title (e.g., "LIVE ANIMALS; ANIMAL PRODUCTS")
  - Section notes (numbered list)
- **Schema Fields**: 
  - `wco_sections.wco_section_number` (INTEGER) - ✅
  - `wco_sections.wco_section_roman_numeral` (VARCHAR) - ✅
  - `wco_sections.wco_section_title` (VARCHAR) - ✅
  - `wco_sections.wco_section_notes` (TEXT) - ✅
- **Status**: ✅ **MATCHES** - All required fields present

#### 4. Chapter Files (e.g., `0101_2022e.md`)
- **Content**:
  - Chapter number (e.g., "Chapter 1")
  - Chapter title (e.g., "Live animals")
  - Chapter notes (numbered list)
  - Headings (4-digit codes, e.g., 01.01, 01.02) - stored as "0101", "0102" without dots
  - 6-digit HS codes (e.g., 0101.21, 0101.29) - stored as "010121", "010129" without dots
- **Schema Fields**:
  - `wco_chapters.wco_chapter_number` (INTEGER) - ✅
  - `wco_chapters.wco_chapter_title` (VARCHAR) - ✅
  - `wco_chapters.wco_chapter_notes` (TEXT) - ✅
- **Status**: ✅ **MATCHES** - All required fields present
- **Note**: Chapter files contain headings and 6-digit codes, which need to be parsed into separate tables. Both heading codes and HS codes are stored without dots.

#### 5. Heading Files (e.g., `0206_2022e.md`)
- **Content**:
  - Heading code (e.g., "02.06") - stored as "0206" without dot
  - Heading title (e.g., "Live poultry...")
  - 6-digit HS codes under the heading
- **Schema Fields**:
  - `wco_headings.wco_heading_code` (VARCHAR(4)) - ✅ Stored without dot (e.g., "0206")
  - `wco_headings.wco_heading_title` (VARCHAR) - ✅
  - `wco_headings.wco_heading_notes` (TEXT) - ✅
- **Status**: ✅ **MATCHES** - All required fields present

#### 6. 6-Digit HS Codes
- **Content**: Found in chapter files and heading files
- **Format**: 6-digit codes (e.g., 0101.21, 0101.29, 0102.21)
- **Structure**:
  - First 2 digits: Chapter number (01)
  - Next 2 digits: Heading number (01)
  - Last 2 digits: Subheading (21, 29, etc.)
- **Schema Fields**:
  - `wco_hs_codes.wco_hs_code_code` (VARCHAR(7)) - ✅ Supports 6 digits + optional check digit
  - `wco_hs_codes.wco_hs_code_description` (TEXT) - ✅
- **Status**: ✅ **MATCHES** - Schema supports 6-digit codes

## Schema Hierarchy Verification

### Expected Hierarchy
```
wco_editions (2022, 2017, 2012, 2007)
  └── wco_sections (I-XXI, 21 sections)
      └── wco_chapters (1-97, 97 chapters)
          └── wco_headings (4-digit without dot, e.g., 0101, 0102)
              └── wco_hs_codes (6-digit, e.g., 010121, 010129)
```

### Schema Implementation
✅ **CORRECT** - Schema matches expected hierarchy:
- `wco_sections.wco_section_wco_edition_fk` → `wco_editions`
- `wco_chapters.wco_chapter_wco_section_fk` → `wco_sections`
- `wco_headings.wco_heading_wco_chapter_fk` → `wco_chapters`
- `wco_hs_codes.wco_hs_code_wco_heading_fk` → `wco_headings`

## Data Mapping Analysis

### Sample Data from `0101_2022e.md`

**Chapter Level:**
- Chapter: "Chapter 1"
- Title: "Live animals"
- Notes: "1.- This Chapter covers all live animals except..."

**Heading Level:**
- Heading: "01.01" (stored as "0101" without dot)
- Title: "Live horses, asses, mules and hinnies."

**6-Digit Codes:**
- `0101.21` - "Pure-bred breeding animals" (horses)
- `0101.29` - "Other" (horses)
- `0101.30` - "Asses"
- `0101.90` - "Other"

### Schema Mapping

| Data Element | Schema Table | Schema Field | Status |
|-------------|-------------|--------------|--------|
| Edition year (2022) | `wco_editions` | `wco_edition_year` | ✅ |
| Introduction text | `wco_editions` | `wco_edition_introduction` | ✅ |
| GIR rules | `wco_editions` | `wco_edition_gir_rules` (JSONB) | ✅ |
| Section I | `wco_sections` | `wco_section_number=1, wco_section_roman_numeral='I'` | ✅ |
| Section title | `wco_sections` | `wco_section_title` | ✅ |
| Section notes | `wco_sections` | `wco_section_notes` | ✅ |
| Chapter 1 | `wco_chapters` | `wco_chapter_number=1` | ✅ |
| Chapter title | `wco_chapters` | `wco_chapter_title` | ✅ |
| Chapter notes | `wco_chapters` | `wco_chapter_notes` | ✅ |
| Heading 01.01 | `wco_headings` | `wco_heading_code='0101'` (without dot) | ✅ |
| Heading title | `wco_headings` | `wco_heading_title` | ✅ |
| Heading notes | `wco_headings` | `wco_heading_notes` | ✅ |
| Code 010121 | `wco_hs_codes` | `wco_hs_code_code='010121'` | ✅ |
| Code description | `wco_hs_codes` | `wco_hs_code_description` | ✅ |

## Potential Issues & Recommendations

### ✅ Strengths

1. **Complete Hierarchy**: Schema correctly models the WCO hierarchy (Edition → Section → Chapter → Heading → HS Code)
2. **Multi-Edition Support**: Schema supports multiple editions (2007, 2012, 2017, 2022)
3. **Notes Storage**: All notes fields (section, chapter, heading) are properly stored as TEXT
4. **Flexible Code Storage**: `wco_hs_code_code` VARCHAR(7) supports 6-digit codes + optional check digit
5. **Full-Text Search**: GIN indexes on description fields for search functionality
6. **GIR Rules**: JSONB field allows structured storage of the 6 GIR rules

### ⚠️ Potential Issues

1. **Heading Notes**: 
   - **Issue**: Some headings may have notes, but we need to verify if heading notes are stored in chapter files or separate heading files
   - **Status**: Schema has `wco_heading_notes` field, but need to verify data extraction
   - **Recommendation**: Check if heading notes exist in the markdown files

2. **Code Format**:
   - **Issue**: Data shows codes as `0101.21` (with dot), but schema stores as `010121` (no dot)
   - **Status**: Schema uses VARCHAR without dots (standard format)
   - **Recommendation**: ✅ **CORRECT** - Remove dots during import (standard HS code format)

3. **Section Numbering**:
   - **Issue**: Need to verify section numbering (I-XXI maps to 1-21)
   - **Status**: Schema has both `wco_section_number` (INTEGER) and `wco_section_roman_numeral` (VARCHAR)
   - **Recommendation**: ✅ **CORRECT** - Both fields present

4. **Multiple Editions**:
   - **Issue**: Each edition may have slightly different structure (e.g., 2007 has 108 files, 2022 has 111 files)
   - **Status**: Schema supports multiple editions via `wco_edition_year`
   - **Recommendation**: ✅ **CORRECT** - Each edition is stored separately

5. **GIR Rules Structure**:
   - **Issue**: GIR rules need to be parsed from markdown into structured JSONB
   - **Status**: Schema has JSONB field, but format needs to be defined
   - **Recommendation**: Define JSONB structure for GIR rules:
     ```json
     {
       "rule_1": {
         "title": "Rule 1",
         "text": "The titles of Sections, Chapters and sub-Chapters..."
       },
       "rule_2": {
         "title": "Rule 2",
         "subrules": {
           "2a": {...},
           "2b": {...}
         }
       },
       ...
     }
     ```

### 📋 Missing Data Elements

1. **Table of Contents**: 
   - File exists: `table-of-contents_2022e_rev.pdf`
   - **Status**: Not converted to markdown yet
   - **Recommendation**: Convert and store in `wco_editions.wco_edition_description` or add new field

2. **Subheading Notes**:
   - **Issue**: 6-digit codes may have subheading notes
   - **Status**: Schema doesn't have a field for subheading notes
   - **Recommendation**: Check if subheading notes exist in data. If yes, add `wco_hs_code_notes` field or store in description

3. **Additional PDFs**:
   - Files like `abbrev_2022e.pdf`, `access-request-form-for-members-site_new.pdf`
   - **Status**: Not critical for classification, but may contain useful metadata
   - **Recommendation**: Store metadata in `wco_editions.wco_edition_description` or ignore

## Data Import Strategy

### Recommended Import Order

1. **Editions**: Import edition metadata first
   - `wco_edition_year`, `wco_edition_name`, `wco_edition_introduction`, `wco_edition_gir_rules`

2. **Sections**: Import sections for each edition
   - Parse `0100_2022e.md`, `0200_2022e.md`, etc.
   - Extract section number, roman numeral, title, notes

3. **Chapters**: Import chapters for each section
   - Parse chapter files (e.g., `0101_2022e.md`)
   - Extract chapter number, title, notes
   - Link to parent section

4. **Headings**: Import headings for each chapter
   - Parse headings from chapter files or individual heading files
   - Extract heading code (4-digit), title, notes
   - Link to parent chapter

5. **HS Codes**: Import 6-digit codes for each heading
   - Parse 6-digit codes from chapter/heading files
   - Extract code (remove dots), description
   - Link to parent heading

### Parsing Challenges

1. **Chapter Files Contain Multiple Headings**: 
   - Chapter files (e.g., `0101_2022e.md`) contain multiple headings (01.01, 01.02, 01.03, etc.)
   - Need to parse and split into separate heading records

2. **Code Format**:
   - **Heading codes**: Data: `01.01` (with dot) → Database: `0101` (without dot)
   - **HS codes**: Data: `0101.21` (with dot) → Database: `010121` (without dot)
   - Need to remove dots during import for both heading codes and HS codes

3. **Description Extraction**:
   - Descriptions may span multiple lines
   - Need to handle line breaks and formatting

4. **Notes Extraction**:
   - Notes are numbered lists (1.-, 2.-, etc.)
   - Need to preserve formatting or convert to structured format

## Conclusion

### ✅ Schema Design is GOOD

The database schema correctly models the WCO HS Nomenclature structure:
- ✅ Complete hierarchy (Edition → Section → Chapter → Heading → HS Code)
- ✅ All required fields present
- ✅ Multi-edition support
- ✅ Notes storage for all levels
- ✅ Flexible code storage
- ✅ Full-text search support

### 📝 Next Steps

1. **Create LLM extraction script** to parse markdown files and extract structured data
2. **Define GIR rules JSONB structure** for consistent storage
3. **Test import** with one chapter to verify parsing logic
4. **Handle edge cases** (missing data, formatting variations)
5. **Import all editions** (2007, 2012, 2017, 2022)

### 🔍 Verification Needed

1. Check if heading notes exist in separate files or chapter files
2. Verify section numbering across all editions
3. Test code format conversion (dots removal)
4. Verify description extraction accuracy

---

**Status**: ✅ **SCHEMA DESIGN IS APPROPRIATE FOR THE DATA**

The database schema is well-designed and matches the actual WCO HS Nomenclature data structure. The main work is in creating the extraction/parsing logic to populate the schema from the markdown files.

