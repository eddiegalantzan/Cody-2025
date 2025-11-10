# Download Previous WCO Edition

This guide shows how to download and convert a previous WCO HS Nomenclature edition (e.g., 2017).

## Available Editions

Common WCO editions:
- **2022** (current) - ✅ Already downloaded
- **2017** (previous) - Most common previous edition
- **2012** (older)
- **2007** (older)

## Steps

### 1. Download PDFs for Previous Edition

**Using browser-based script (recommended):**
```bash
# Download 2017 edition
yarn download-wco-pdfs:browser --headless --edition 2017

# Or download 2012 edition
yarn download-wco-pdfs:browser --headless --edition 2012
```

**Using HTTP-based script:**
```bash
# Download 2017 edition
yarn download-wco-pdfs --edition 2017

# Or download 2012 edition
yarn download-wco-pdfs --edition 2012
```

### 2. Convert PDFs to Markdown

```bash
# Convert 2017 edition PDFs to Markdown
yarn pdf-to-markdown --edition 2017 --tool marker

# Or convert 2012 edition
yarn pdf-to-markdown --edition 2012 --tool marker
```

### 3. Verify Files

```bash
# Check downloaded PDFs
ls -la data/wco/2017/pdfs/*.pdf | wc -l

# Check converted Markdown files
ls -la data/wco/2017/md/*.md | wc -l
```

## Output Structure

Files will be organized by edition:
```
data/wco/
├── 2022/          (already downloaded)
│   ├── pdfs/
│   │   └── *.pdf
│   └── md/
│       └── *.md
├── 2017/          (previous edition)
│   ├── pdfs/
│   │   └── *.pdf
│   └── md/
│       └── *.md
└── 2012/          (older edition)
    ├── pdfs/
    │   └── *.pdf
    └── md/
        └── *.md
```

## Database Schema

The database schema already supports multiple editions:
- `wco_editions` table stores edition year (unique)
- All WCO tables link to `wco_editions` via foreign keys
- Each edition can have its own sections, chapters, headings, and HS codes

No schema changes needed - just download and convert!

## Next Steps

After downloading and converting:
1. Run LLM extraction script (when created) for the new edition
2. Import extracted data to database
3. The edition will be stored in `wco_editions` table with year 2017 (or other)

