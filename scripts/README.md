# Scripts

Utility scripts for database setup and data management.

## Table of Contents

1. [WCO PDF Download Scripts](#wco-pdf-download-scripts)
2. [PDF to Markdown Conversion](#pdf-to-markdown-conversion)

## WCO PDF Download Scripts

Two scripts are available for downloading WCO HS Nomenclature PDF files from the official WCO website:

1. **Browser-based script** (`download-wco-pdfs-browser.ts`) - **Recommended** ✅
   - Uses Puppeteer to navigate the WCO website and discover actual PDF links
   - Automatically handles authentication and sessions
   - Discovers which PDFs actually exist on the website
   - More reliable for discovering and downloading all available PDFs

2. **HTTP-based script** (`download-wco-pdfs.ts`)
   - Uses direct HTTP requests with known URL patterns
   - Faster but requires correct URL patterns
   - May encounter 404s if URL patterns change

### Prerequisites

- Node.js 20+
- TypeScript support (tsx or ts-node)
- Internet connection
- Node.js type definitions (for TypeScript)

### Installation

**Option 1: Using package.json (Recommended)**

```bash
# Install all dependencies (tsx, @types/node, typescript)
yarn install

# Run the browser-based script (recommended)
yarn download-wco-pdfs:browser

# Or run the HTTP-based script
yarn download-wco-pdfs
```

**Option 2: Global Installation**

```bash
# Install tsx globally for running TypeScript files directly
yarn global add tsx

# Install Node.js type definitions (if using TypeScript in project)
yarn add -D @types/node

# Then run directly
tsx scripts/download-wco-pdfs.ts
```

**Note:** The script uses Node.js built-in modules (fs, path, https, http). The package.json includes all necessary dependencies.

### Usage

**Browser-based Script (Recommended):**

```bash
# Download all PDFs for 2022 edition (default, headless mode)
yarn download-wco-pdfs:browser --headless

# Download with visible browser (for debugging)
yarn download-wco-pdfs:browser

# Download specific chapters
yarn download-wco-pdfs:browser --headless --chapters 1-10

# Download with custom delay (be respectful to server)
yarn download-wco-pdfs:browser --headless --delay 2000

# Download different edition
yarn download-wco-pdfs:browser --headless --edition 2017

# Custom output directory
yarn download-wco-pdfs:browser --headless --output ./custom/path

# See help
yarn download-wco-pdfs:browser:help
```

**HTTP-based Script:**

```bash
# Download all PDFs for 2022 edition (default)
yarn download-wco-pdfs

# Download specific chapters
yarn download-wco-pdfs --chapters 1-10

# Download with custom delay (be respectful to server)
yarn download-wco-pdfs --delay 2000

# Resume from last downloaded file
yarn download-wco-pdfs --resume

# Dry run (see what would be downloaded)
yarn download-wco-pdfs --dry-run

# Download different edition
yarn download-wco-pdfs --edition 2017

# Custom output directory
yarn download-wco-pdfs --output ./custom/path

# See help
yarn download-wco-pdfs:help
```

**Or run directly with tsx:**

```bash
# Browser-based (recommended)
tsx scripts/download-wco-pdfs-browser.ts [options]

# HTTP-based
tsx scripts/download-wco-pdfs.ts [options]
```

### Options

**Browser-based Script (`download-wco-pdfs-browser.ts`):**
- `--edition <year>` - WCO edition year (default: 2022)
- `--output <dir>` - Output directory (default: `./data/wco/{edition}/pdfs`)
- `--chapters <range>` - Chapter range, e.g., "1-97" or "1,2,3" (default: 1-97)
- `--delay <ms>` - Delay between downloads in milliseconds (default: 2000)
- `--headless` - Run browser in headless mode (default: false, shows browser)
- `--help, -h` - Show help message

**HTTP-based Script (`download-wco-pdfs.ts`):**
- `--edition <year>` - WCO edition year (default: 2022)
- `--output <dir>` - Output directory (default: `./data/wco/{edition}/pdfs`)
- `--chapters <range>` - Chapter range, e.g., "1-97" or "1,2,3" (default: 1-97)
- `--delay <ms>` - Base delay between downloads in milliseconds (default: 5000). Actual delay = base + random(0 to variation)
- `--delay-variation <ms>` - Random variation added to delay (default: 5000). Helps avoid being blocked by appearing more human-like
- `--retries <n>` - Number of retries for failed downloads (default: 3)
- `--resume` - Resume from last downloaded file
- `--dry-run` - Show what would be downloaded without downloading
- `--check-existing` - Check if files exist and skip if unchanged (default: enabled, uses HEAD request)
- `--skip-existing` - Skip files that already exist locally (faster, no HEAD request, doesn't check for updates)
- `--no-check-existing` / `--force` - Download all files without checking if they exist (re-downloads everything)
- `--config <file>` - Path to config file for additional PDFs (default: `scripts/download-wco-pdfs-config.ts`)
- `--help, -h` - Show help message

### Output

PDFs are saved to `./data/wco/{edition}/pdfs/` with filenames like:

**Additional PDFs (downloaded first - critical for LLM classification):**
- `introduction_2022e.pdf` - Introduction to HS Nomenclature
- `table-of-contents_2022e.pdf` - Table of Contents
- `general-rules_2022e.pdf` - General Rules for Interpretation
- `explanatory-notes_2022e.pdf` - Explanatory Notes
- `classification-rules_2022e.pdf` - Classification Rules
- `section-notes_2022e.pdf` - Section Notes
- `chapter-notes_2022e.pdf` - Chapter Notes
- `alphabetical-index_2022e.pdf` - Alphabetical Index
- `compendium-of-classification-opinions_2022e.pdf` - Compendium of Classification Opinions
- etc.

**Chapter/Heading PDFs:**
- `0101_2022e.pdf` (Chapter 1, Heading 01.01, Edition 2022)
- `0102_2022e.pdf` (Chapter 1, Heading 01.02, Edition 2022)
- etc.

### Notes

- **Downloads additional PDFs first**: Introduction, Table of Contents, General Rules, Explanatory Notes, etc. These are critical for LLM classification context and contain essential information about classification rules and interpretation guidelines.
- **Configurable PDF list**: Additional PDFs can be configured via `scripts/download-wco-pdfs-config.ts`. Simply add new PDF filenames to the `additionalPdfs` array to ensure they are downloaded automatically in the future. The script merges config file PDFs with defaults.
- The script then downloads all chapter/heading PDFs
- The script tries all possible heading combinations (01-99) for each chapter
- 404 errors are expected for non-existent headings and some additional PDFs (not all may exist), and are not counted as failures
- **Anti-blocking features:**
  - Uses realistic Chrome browser headers (User-Agent, Accept, Accept-Language, etc.) to appear like a regular browser
  - Random delay between requests (base delay + random variation) to avoid predictable patterns
  - Random User-Agent selection from a pool of Chrome user agents
  - Default: 2000ms base delay + 0-2000ms random variation (actual delay: 2000-4000ms)
- **Smart skip logic**: Before downloading, the script checks if the file already exists locally. If it exists, it makes an HTTP HEAD request to compare the remote file size with the local file size. If they match, the file is skipped (not downloaded again). This saves bandwidth and time when re-running the script.
- Use `--resume` to continue if the download is interrupted
- Files that already exist and haven't changed are automatically skipped

### Configuration File

The script supports a configuration file (`scripts/download-wco-pdfs-config.ts`) to specify additional PDFs to download. This allows you to add new PDFs in the future without modifying the script code.

**To add new PDFs in the future:**

1. Edit `scripts/download-wco-pdfs-config.ts`
2. Add new PDF filenames to the `additionalPdfs` array
3. Use `{EDITION}` placeholder which will be replaced with the edition year
4. Run the script - it will automatically download the new PDFs

**Example config file:**
```typescript
export const config: WCOPdfsConfig = {
  additionalPdfs: [
    "introduction_{EDITION}e.pdf",
    "table-of-contents_{EDITION}e.pdf",
    "new-document_{EDITION}e.pdf",  // Add new PDFs here
    "another-document_{EDITION}e.pdf"
  ],
  // ... other fields
};
```

**Note:** The script merges PDFs from the config file with the default list, so you don't need to include all defaults. If the config file doesn't exist, the script uses built-in defaults.

### Example Output

```
WCO PDF Download Script
========================
Edition: 2022
Output: ./data/wco-pdfs/2022
Chapters: 1-97
Delay: 1000ms
Retries: 3
Resume: false
Dry Run: false

Processing 97 chapters...

Chapter 1...
  ✓ 0101_2022e.pdf (45.23 KB)
  ✓ 0102_2022e.pdf (38.91 KB)
  ...
```

---

## PDF to Markdown Conversion

Converts WCO PDF files to Markdown format for better LLM processing and database population.

### Prerequisites

- Node.js 20+
- TypeScript support (tsx)
- **For marker/pdfplumber:** Python 3 and pip
- **For pdfjs:** No additional requirements (pure TypeScript)

### Installation

**Option 1: Using marker (Recommended for best quality)**

```bash
# Install marker (Python)
pip install marker-pdf

# Run conversion
yarn pdf-to-markdown --tool marker
```

**Option 2: Using pdfplumber (Good alternative)**

```bash
# Install pdfplumber (Python)
pip install pdfplumber

# Run conversion
yarn pdf-to-markdown --tool pdfplumber
```

**Option 3: Using pdfjs (Pure TypeScript)**

```bash
# Install pdfjs-dist (Node.js)
yarn add pdfjs-dist

# Run conversion
yarn pdf-to-markdown --tool pdfjs
```

### Usage

```bash
# Convert all PDFs using marker (recommended)
yarn pdf-to-markdown --tool marker

# Convert specific edition
yarn pdf-to-markdown --edition 2022 --tool marker

# Skip existing files (resume interrupted conversion)
yarn pdf-to-markdown --tool marker --skip-existing

# Custom input/output directories
yarn pdf-to-markdown --input ./custom/pdfs --output ./custom/markdown --tool marker

# See help
yarn pdf-to-markdown:help
```

### Options

- `--edition <year>` - WCO edition year (default: 2022)
- `--input <dir>` - Input directory with PDFs (default: `./data/wco/{edition}/pdfs`)
- `--output <dir>` - Output directory for Markdown files (default: `./data/wco/{edition}/md`)
- `--tool <tool>` - Conversion tool: `marker`, `pdfplumber`, or `pdfjs` (default: `marker`)
- `--skip-existing` - Skip files that already exist
- `--help, -h` - Show help message

### Tools Comparison

| Tool | Quality | Speed | Requirements | Best For |
|------|---------|-------|--------------|----------|
| **marker** | ⭐⭐⭐⭐⭐ | Slow | Python + GPU (optional) | Best structure preservation |
| **pdfplumber** | ⭐⭐⭐⭐ | Medium | Python | Good balance, no GPU |
| **pdfjs** | ⭐⭐⭐ | Fast | Node.js only | Quick conversion, may lose structure |

### Output

Markdown files are saved to `./data/wco/{edition}/md/` with filenames like:

- `0101_2022e.md` (from `0101_2022e.pdf`)
- `introduction_2022e.md` (from `introduction_2022e.pdf`)
- `0001_2022e-gir.md` (from `0001_2022e-gir.pdf`)
- etc.

### Notes

- **marker** is recommended for best quality, especially for preserving tables and complex formatting
- The script automatically detects which tool is available
- Use `--skip-existing` to resume interrupted conversions
- Large PDFs may take time to convert
- See `scripts/pdf-to-markdown-setup.md` for detailed setup instructions

### Example Output

```
PDF to Markdown Conversion Script
==================================
Edition: 2022
Input: ./data/wco/2022/pdfs
Output: ./data/wco/2022/md
Tool: marker
Skip Existing: false

Found 111 PDF files

  [1/111] Converting: 0001_2022e-gir.pdf
  ✓ 0001_2022e-gir.md
  [2/111] Converting: 0100_2022e.pdf
  ✓ 0100_2022e.md
  ...

========================================
Conversion Summary
========================================
Total PDFs: 111
Converted: 111
Failed: 0
Skipped: 0

Markdown files saved to: ./data/wco/2022/md
```

