#!/usr/bin/env tsx
/// <reference types="node" />

/**
 * PDF to Markdown Conversion Script
 * 
 * Converts WCO PDF files to Markdown format for better LLM processing.
 * Uses marker (Python) for best structure preservation.
 * 
 * Usage:
 *   tsx scripts/pdf-to-markdown.ts [options]
 * 
 * Options:
 *   --edition <year>    WCO edition year (default: 2022)
 *   --input <dir>       Input directory with PDFs (default: ./data/wco-pdfs/{edition})
 *   --output <dir>      Output directory for Markdown files (default: ./data/wco-pdfs/{edition}/markdown)
 *   --tool <tool>       Conversion tool: marker, pdfplumber, or pdfjs (default: marker)
 *   --skip-existing     Skip files that already exist
 *   --help, -h          Show help message
 */

import { promises as fs } from 'fs';
import * as path from 'path';
import { existsSync } from 'fs';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

// Configuration
const DEFAULT_EDITION = '2022';
const DEFAULT_INPUT_DIR = './data/wco-pdfs';
const DEFAULT_OUTPUT_DIR = './data/wco-pdfs';
const DEFAULT_TOOL = 'marker';

interface Config {
  edition: string;
  inputDir: string;
  outputDir: string;
  tool: 'marker' | 'pdfplumber' | 'pdfjs';
  skipExisting: boolean;
}

// Parse command line arguments
function parseArgs(): Config {
  const args = process.argv.slice(2);
  const config: Config = {
    edition: DEFAULT_EDITION,
    inputDir: DEFAULT_INPUT_DIR,
    outputDir: DEFAULT_OUTPUT_DIR,
    tool: DEFAULT_TOOL,
    skipExisting: false
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    switch (arg) {
      case '--edition':
        config.edition = args[++i] || DEFAULT_EDITION;
        break;
      case '--input':
        config.inputDir = args[++i] || DEFAULT_INPUT_DIR;
        break;
      case '--output':
        config.outputDir = args[++i] || DEFAULT_OUTPUT_DIR;
        break;
      case '--tool':
        const tool = (args[++i] || DEFAULT_TOOL).toLowerCase();
        if (tool === 'marker' || tool === 'pdfplumber' || tool === 'pdfjs') {
          config.tool = tool;
        } else {
          console.error(`Invalid tool: ${tool}. Must be marker, pdfplumber, or pdfjs`);
          process.exit(1);
        }
        break;
      case '--skip-existing':
        config.skipExisting = true;
        break;
      case '--help':
      case '-h':
        console.log(`
PDF to Markdown Conversion Script

Usage:
  tsx scripts/pdf-to-markdown.ts [options]

Options:
  --edition <year>      WCO edition year (default: ${DEFAULT_EDITION})
  --input <dir>         Input directory with PDFs (default: ${DEFAULT_INPUT_DIR}/{edition})
  --output <dir>        Output directory for Markdown files (default: ${DEFAULT_OUTPUT_DIR}/{edition}/markdown)
  --tool <tool>         Conversion tool: marker, pdfplumber, or pdfjs (default: ${DEFAULT_TOOL})
  --skip-existing        Skip files that already exist
  --help, -h            Show this help message

Tools:
  marker       - AI-powered, best structure preservation (requires Python, GPU recommended)
  pdfplumber   - Python-based, good structure preservation (requires Python, no GPU)
  pdfjs        - Node.js-based, basic conversion (no Python needed, may lose structure)

Examples:
  # Convert all PDFs using marker (recommended)
  tsx scripts/pdf-to-markdown.ts --tool marker

  # Convert specific edition
  tsx scripts/pdf-to-markdown.ts --edition 2022 --tool marker

  # Skip existing files
  tsx scripts/pdf-to-markdown.ts --skip-existing
        `);
        process.exit(0);
      default:
        console.error(`Unknown option: ${arg}`);
        console.error('Use --help for usage information');
        process.exit(1);
    }
  }

  return config;
}

// Check if Python is available
async function checkPython(): Promise<boolean> {
  try {
    await execAsync('python3 --version');
    return true;
  } catch {
    return false;
  }
}

// Check if marker is installed
async function checkMarker(): Promise<boolean> {
  try {
    await execAsync('python3 -c "import marker"');
    return true;
  } catch {
    return false;
  }
}

// Check if pdfplumber is installed
async function checkPdfplumber(): Promise<boolean> {
  try {
    await execAsync('python3 -c "import pdfplumber"');
    return true;
  } catch {
    return false;
  }
}

// Convert PDF to Markdown using marker
async function convertWithMarker(pdfPath: string, outputPath: string): Promise<boolean> {
  try {
    // marker converts PDF to markdown
    // marker can be used via CLI: marker_single <input_pdf> <output_dir>
    // Or via Python API
    const outputDir = path.dirname(outputPath);
    const baseName = path.basename(pdfPath, '.pdf');
    
    // Create a Python script to use marker API
    const pythonScript = `
import sys
from pathlib import Path
from marker.convert import convert_single_pdf
from marker.models import load_all_models

pdf_path = "${pdfPath}"
output_dir = "${outputDir}"

try:
    # Load models (first time will download)
    model_lst = load_all_models()
    
    # Convert PDF to markdown
    full_text, images, out_meta = convert_single_pdf(pdf_path, model_lst)
    
    # Save markdown
    output_path = Path("${outputPath}")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(full_text, encoding='utf-8')
    
    print("SUCCESS")
except Exception as e:
    print(f"ERROR: {e}")
    sys.exit(1)
    `;
    
    const tempScript = path.join(__dirname, 'temp_marker_convert.py');
    await fs.writeFile(tempScript, pythonScript);
    
    try {
      const { stdout } = await execAsync(`python3 "${tempScript}"`);
      if (stdout.includes('SUCCESS')) {
        return true;
      }
      return false;
    } finally {
      // Clean up temp script
      if (existsSync(tempScript)) {
        await fs.unlink(tempScript);
      }
    }
  } catch (error) {
    console.error(`  ✗ Error converting with marker: ${error instanceof Error ? error.message : String(error)}`);
    return false;
  }
}

// Convert PDF to Markdown using pdfplumber
async function convertWithPdfplumber(pdfPath: string, outputPath: string): Promise<boolean> {
  try {
    // Create a Python script to convert PDF to Markdown
    const pythonScript = `
import pdfplumber
import sys
import json

pdf_path = "${pdfPath}"
output_path = "${outputPath}"

try:
    with pdfplumber.open(pdf_path) as pdf:
        markdown_content = []
        
        for page_num, page in enumerate(pdf.pages, 1):
            text = page.extract_text()
            if text:
                markdown_content.append(f"## Page {page_num}\\n\\n{text}\\n")
            
            # Extract tables
            tables = page.extract_tables()
            for table in tables:
                if table:
                    markdown_content.append("\\n### Table\\n\\n")
                    # Convert table to markdown
                    for row in table:
                        if row:
                            markdown_content.append("| " + " | ".join(str(cell) if cell else "" for cell in row) + " |\\n")
                    markdown_content.append("\\n")
        
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write("\\n".join(markdown_content))
        
        print("SUCCESS")
except Exception as e:
    print(f"ERROR: {e}")
    sys.exit(1)
    `;
    
    const tempScript = path.join(__dirname, 'temp_pdfplumber_convert.py');
    await fs.writeFile(tempScript, pythonScript);
    
    try {
      const { stdout } = await execAsync(`python3 "${tempScript}"`);
      if (stdout.includes('SUCCESS')) {
        return true;
      }
      return false;
    } finally {
      // Clean up temp script
      if (existsSync(tempScript)) {
        await fs.unlink(tempScript);
      }
    }
  } catch (error) {
    console.error(`  ✗ Error converting with pdfplumber: ${error instanceof Error ? error.message : String(error)}`);
    return false;
  }
}

// Convert PDF to Markdown using pdfjs (Node.js)
async function convertWithPdfjs(pdfPath: string, outputPath: string): Promise<boolean> {
  try {
    // Dynamic import of pdfjs-dist
    const pdfjsLib = await import('pdfjs-dist/legacy/build/pdf.mjs');
    
    const data = await fs.readFile(pdfPath);
    // Convert Buffer to Uint8Array for pdfjs
    const uint8Array = new Uint8Array(data);
    const pdf = await pdfjsLib.getDocument({ data: uint8Array }).promise;
    
    const markdownContent: string[] = [];
    
    for (let pageNum = 1; pageNum <= pdf.numPages; pageNum++) {
      const page = await pdf.getPage(pageNum);
      const textContent = await page.getTextContent();
      
      markdownContent.push(`## Page ${pageNum}\n\n`);
      
      let lastY = 0;
      for (const item of textContent.items) {
        if ('str' in item) {
          const y = item.transform[5] || 0;
          if (Math.abs(y - lastY) > 5) {
            markdownContent.push('\n');
          }
          markdownContent.push(item.str);
          lastY = y;
        }
      }
      markdownContent.push('\n\n');
    }
    
    await fs.writeFile(outputPath, markdownContent.join(''), 'utf-8');
    return true;
  } catch (error) {
    console.error(`  ✗ Error converting with pdfjs: ${error instanceof Error ? error.message : String(error)}`);
    return false;
  }
}

// Main function
async function main(): Promise<void> {
  const config = parseArgs();
  
  const inputDir = path.join(config.inputDir, config.edition);
  const outputDir = path.join(config.outputDir, config.edition, 'markdown');
  
  console.log('PDF to Markdown Conversion Script');
  console.log('==================================');
  console.log(`Edition: ${config.edition}`);
  console.log(`Input: ${inputDir}`);
  console.log(`Output: ${outputDir}`);
  console.log(`Tool: ${config.tool}`);
  console.log(`Skip Existing: ${config.skipExisting}`);
  console.log('');
  
  // Check input directory exists
  if (!existsSync(inputDir)) {
    console.error(`❌ Input directory does not exist: ${inputDir}`);
    process.exit(1);
  }
  
  // Create output directory
  await fs.mkdir(outputDir, { recursive: true });
  
  // Check tool requirements
  if (config.tool === 'marker' || config.tool === 'pdfplumber') {
    if (!(await checkPython())) {
      console.error('❌ Python 3 is required for marker/pdfplumber but not found.');
      console.error('   Please install Python 3: https://www.python.org/downloads/');
      process.exit(1);
    }
    
    if (config.tool === 'marker' && !(await checkMarker())) {
      console.error('❌ marker is not installed.');
      console.error('   Install with: pip install marker-pdf');
      process.exit(1);
    }
    
    if (config.tool === 'pdfplumber' && !(await checkPdfplumber())) {
      console.error('❌ pdfplumber is not installed.');
      console.error('   Install with: pip install pdfplumber');
      process.exit(1);
    }
  }
  
  if (config.tool === 'pdfjs') {
    // Check if pdfjs-dist is installed
    try {
      await import('pdfjs-dist/legacy/build/pdf.mjs');
    } catch {
      console.error('❌ pdfjs-dist is not installed.');
      console.error('   Install with: yarn add pdfjs-dist');
      process.exit(1);
    }
  }
  
  // Find all PDF files
  const files = await fs.readdir(inputDir);
  const pdfFiles = files.filter(f => f.toLowerCase().endsWith('.pdf'));
  
  if (pdfFiles.length === 0) {
    console.error(`❌ No PDF files found in ${inputDir}`);
    process.exit(1);
  }
  
  console.log(`Found ${pdfFiles.length} PDF files\n`);
  
  let converted = 0;
  let failed = 0;
  let skipped = 0;
  
  for (let i = 0; i < pdfFiles.length; i++) {
    const pdfFile = pdfFiles[i]!;
    const pdfPath = path.join(inputDir, pdfFile);
    const mdFile = pdfFile.replace(/\.pdf$/i, '.md');
    const mdPath = path.join(outputDir, mdFile);
    
    // Skip if exists
    if (config.skipExisting && existsSync(mdPath)) {
      console.log(`  ⊘ ${pdfFile} - already exists, skipping`);
      skipped++;
      continue;
    }
    
    console.log(`  [${i + 1}/${pdfFiles.length}] Converting: ${pdfFile}`);
    
    let success = false;
    switch (config.tool) {
      case 'marker':
        success = await convertWithMarker(pdfPath, mdPath);
        break;
      case 'pdfplumber':
        success = await convertWithPdfplumber(pdfPath, mdPath);
        break;
      case 'pdfjs':
        success = await convertWithPdfjs(pdfPath, mdPath);
        break;
    }
    
    if (success) {
      console.log(`  ✓ ${mdFile}`);
      converted++;
    } else {
      console.log(`  ✗ Failed: ${pdfFile}`);
      failed++;
    }
  }
  
  // Summary
  console.log('\n========================================');
  console.log('Conversion Summary');
  console.log('========================================');
  console.log(`Total PDFs: ${pdfFiles.length}`);
  console.log(`Converted: ${converted}`);
  console.log(`Failed: ${failed}`);
  console.log(`Skipped: ${skipped}`);
  console.log(`\nMarkdown files saved to: ${outputDir}`);
}

// Run main function
main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});

