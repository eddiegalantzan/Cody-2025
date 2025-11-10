# Next Steps: PDF to Markdown Conversion

> **See:** `documents/WORKFLOW_PDF_TO_DATABASE.md` for complete workflow overview

## Current Status

✅ **Completed:**
- PDF download scripts (browser-based and HTTP-based)
- 111 WCO PDFs downloaded for 2022 edition
- PDF to Markdown conversion script created
- **111 Markdown files converted** ✅

## Quick Start

1. **Install conversion tool:**
   ```bash
   pip install marker-pdf  # Recommended
   # OR: pip install pdfplumber
   # OR: yarn add pdfjs-dist
   ```

2. **Convert PDFs:**
   ```bash
   yarn pdf-to-markdown --tool marker
   ```

3. **Verify:**
   ```bash
   ls -1 data/wco-pdfs/2022/markdown/*.md | wc -l
   ```

## Next: LLM-Based Data Extraction

See `documents/WORKFLOW_PDF_TO_DATABASE.md` Step 3 for details.

## Documentation

- **Setup:** `scripts/pdf-to-markdown-setup.md`
- **Complete docs:** `scripts/README.md` - PDF to Markdown Conversion section
- **Workflow:** `documents/WORKFLOW_PDF_TO_DATABASE.md`
- **Help:** `yarn pdf-to-markdown:help`

