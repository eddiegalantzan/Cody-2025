# Workflow: PDF to Database via Markdown and LLM

Complete workflow for converting WCO PDFs to structured database data.

## Overview

```
PDF Download → Markdown Conversion → LLM Extraction → Database Import
```

## Step 1: Download WCO PDFs ✅ COMPLETED

**Status:** ✅ All 111 PDFs downloaded for 2022 edition

**Scripts:**
- Browser-based (recommended): `yarn download-wco-pdfs:browser --headless`
- HTTP-based: `yarn download-wco-pdfs`

**Output:** `./data/wco-pdfs/2022/*.pdf`

**Documentation:**
- `scripts/README.md` - Full script documentation
- `scripts/download-wco-pdfs-browser.ts` - Browser-based script
- `scripts/download-wco-pdfs.ts` - HTTP-based script

## Step 2: Convert PDFs to Markdown ✅ COMPLETED

**Status:** ✅ All 111 PDFs converted to Markdown

**Script:** `yarn pdf-to-markdown --tool pdfjs` (or `marker`/`pdfplumber`)

**Quick Start:**
```bash
# Install tool (choose one)
pip install marker-pdf  # Recommended for best quality
# OR: pip install pdfplumber
# OR: yarn add pdfjs-dist

# Convert all PDFs
yarn pdf-to-markdown --tool marker
```

**Output:** `./data/wco-pdfs/2022/markdown/*.md` (111 files)

**Documentation:**
- `scripts/README.md` - Complete documentation with tool comparison
- `scripts/pdf-to-markdown-setup.md` - Quick setup guide
- `scripts/pdf-to-markdown.ts` - Conversion script

## Step 3: LLM-Based Data Extraction ⏳ TODO

**Status:** ⏳ Next step after Markdown conversion

**Goal:** Extract structured data from Markdown files using LLM

**Process:**
1. Read Markdown files from `./data/wco-pdfs/2022/markdown/`
2. Use LLM to extract:
   - **HS Codes:**
     - 4-digit headings (e.g., 0101, 0102)
     - 6-digit subheadings (e.g., 010111, 010121)
   - **Descriptions:**
     - Heading descriptions
     - Subheading descriptions
   - **Rules:**
     - Classification rules
     - General Rules for Interpretation (GIR)
     - Section notes
     - Chapter notes
     - Explanatory notes
   - **Hierarchical Structure:**
     - Section → Chapter → Heading → Subheading relationships
   - **Country-Specific Data:**
     - Country-specific codes (if applicable)
     - Check digit algorithms

3. **Transform to Database Schema:**
   - `wco_sections` - Sections (I-XI)
   - `wco_chapters` - Chapters (1-97)
   - `wco_headings` - 4-digit headings
   - `wco_hs_codes` - 6-digit HS codes
   - `customs_books` - Country-specific customs books
   - `customs_book_hs_codes` - Country-specific HS codes
   - `customs_book_hs_code_country_rules` - Classification rules (JSONB)

4. **Validate:**
   - HS code format validation
   - Check digit validation (country-specific)
   - Hierarchical relationship validation
   - Data completeness checks

**LLM Providers:**
- OpenAI (GPT-4, GPT-3.5)
- Anthropic (Claude 3)
- Google (Gemini Pro/Ultra)
- xAI (Grok-1, Grok-2)

**Implementation Tasks:**
- [ ] Create LLM extraction script
- [ ] Design prompts for structured extraction
- [ ] Implement batch processing
- [ ] Add error handling and retry logic
- [ ] Track LLM usage and costs
- [ ] Validate extracted data
- [ ] Transform to database schema

**Documentation:**
- See `documents/5.0_PLAN.md` Phase 3.1 for detailed LLM integration tasks
- See `documents/9.0_INTEGRATIONS.md` for LLM provider details

## Step 4: Database Import ⏳ TODO

**Status:** ⏳ After LLM extraction

**Goal:** Import extracted structured data into PostgreSQL

**Process:**
1. **Prepare Data:**
   - Validate all extracted data
   - Check hierarchical relationships
   - Verify HS code formats

2. **Batch Import:**
   - Use PostgreSQL `COPY` command for large datasets
   - Use transactions for data integrity
   - Handle foreign key constraints

3. **Post-Import:**
   - Verify data completeness
   - Run validation queries
   - Update sync tracking in `customs_books` table

**Database Tables:**
- `wco_editions` - WCO edition metadata
- `wco_sections` - Sections (I-XI)
- `wco_chapters` - Chapters (1-97)
- `wco_headings` - 4-digit headings
- `wco_hs_codes` - 6-digit HS codes
- `customs_books` - Customs book metadata
- `customs_book_hs_codes` - Country-specific HS codes
- `customs_book_hs_code_country_rules` - Classification rules (JSONB)

**Implementation Tasks:**
- [ ] Create database import script
- [ ] Implement batch insert logic
- [ ] Add transaction management
- [ ] Handle foreign key constraints
- [ ] Add rollback on errors
- [ ] Update sync tracking

**Documentation:**
- See `db/README.md` for database schema
- See `db/init.sql` for table definitions

## Current Status Summary

| Step | Status | Script/Tool | Output Location |
|------|--------|-------------|-----------------|
| 1. PDF Download | ✅ Complete | `download-wco-pdfs-browser.ts` | `./data/wco-pdfs/2022/*.pdf` (111 files) |
| 2. Markdown Conversion | ✅ Complete | `pdf-to-markdown.ts` | `./data/wco-pdfs/2022/markdown/*.md` (111 files) |
| 3. LLM Extraction | ⏳ TODO | TBD | Structured JSON/Data |
| 4. Database Import | ⏳ TODO | TBD | PostgreSQL database |

## Next Actions

### Immediate Next Step:
1. Create LLM extraction script
2. Design extraction prompts
3. Test on sample Markdown files
4. Batch process all files
5. Validate extracted data
6. Import to database

## Related Documentation

- **PDF Download:** `scripts/README.md`, `scripts/download-wco-pdfs-browser.ts`
- **Markdown Conversion:** `scripts/pdf-to-markdown-setup.md`, `scripts/pdf-to-markdown.ts`
- **LLM Integration:** `documents/5.0_PLAN.md` Phase 3.1, `documents/9.0_INTEGRATIONS.md`
- **Database Schema:** `db/README.md`, `db/init.sql`
- **Customs Data:** `documents/11.0_CUSTOMS_DATA_DOWNLOAD.md`

## Notes

- **Markdown format** preserves structure better than plain text for LLM processing
- **LLM extraction** can handle complex structures and unstructured rules
- **Batch processing** is essential for 111+ PDFs
- **Error handling** and **retry logic** are critical for production use
- **Cost tracking** is important for LLM usage monitoring

> **For detailed tool information and setup:** See `scripts/README.md` and `scripts/pdf-to-markdown-setup.md`

