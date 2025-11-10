# PDF to Markdown Conversion Setup

> **See:** `scripts/README.md` for complete documentation. This file provides quick setup instructions only.

## Quick Setup

1. **Install a conversion tool** (choose one):
   ```bash
   # Option 1: marker (recommended for best quality)
   pip install marker-pdf
   
   # Option 2: pdfplumber (good alternative, no GPU)
   pip install pdfplumber
   
   # Option 3: pdfjs (pure TypeScript, no Python)
   yarn add pdfjs-dist
   ```

2. **Convert PDFs:**
   ```bash
   yarn pdf-to-markdown --tool marker
   ```

3. **Output:** Markdown files saved to `./data/wco-pdfs/{edition}/markdown/`

## Tool Comparison

| Tool | Quality | Speed | Requirements | Best For |
|------|---------|-------|--------------|----------|
| **marker** | ⭐⭐⭐⭐⭐ | Slow | Python + GPU (optional) | Best structure preservation |
| **pdfplumber** | ⭐⭐⭐⭐ | Medium | Python | Good balance, no GPU |
| **pdfjs** | ⭐⭐⭐ | Fast | Node.js only | Quick conversion, may lose structure |

## Troubleshooting

### marker Installation Issues
```bash
pip install torch torchvision torchaudio
pip install marker-pdf
```

### Python Not Found
```bash
python3 --version  # Check if installed
# macOS: brew install python3
# Linux: sudo apt-get install python3
```

### Conversion Errors
1. Check error message in script output
2. Try a different tool (e.g., pdfplumber instead of marker)
3. Verify PDF files: `file data/wco-pdfs/2022/*.pdf | head -5`

## Full Documentation

- **Complete guide:** `scripts/README.md` - PDF to Markdown Conversion section
- **Script help:** `yarn pdf-to-markdown:help`
- **Workflow:** `documents/WORKFLOW_PDF_TO_DATABASE.md`

