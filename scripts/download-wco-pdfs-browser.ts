#!/usr/bin/env tsx
/// <reference types="node" />

/**
 * WCO PDF Download Script (Browser-based)
 * 
 * Uses Puppeteer to navigate the WCO website, discover available PDFs, and download them.
 * This approach:
 * - Discovers which PDFs actually exist on the website
 * - Handles authentication and sessions automatically
 * - Finds all PDF links on the page
 * - Downloads PDFs directly from the browser
 * 
 * Usage:
 *   tsx scripts/download-wco-pdfs-browser.ts [options]
 * 
 * Options:
 *   --edition <year>    WCO edition year (default: 2022)
 *   --output <dir>      Output directory (default: ./data/wco-pdfs/{edition})
 *   --chapters <range>  Chapter range, e.g., "1-97" or "1,2,3" (default: 1-97)
 *   --delay <ms>        Delay between downloads in milliseconds (default: 2000)
 *   --headless          Run browser in headless mode (default: false, shows browser)
 *   --help, -h          Show help message
 */

import puppeteer, { Browser, Page } from 'puppeteer';
import { promises as fs, readFileSync } from 'fs';
import * as path from 'path';
import { existsSync } from 'fs';

// Configuration
const DEFAULT_EDITION = '2022';
const DEFAULT_OUTPUT_DIR = './data/wco-pdfs';
const DEFAULT_DELAY_MS = 2000;

// WCO website URLs
const WCO_BASE_URL = 'https://www.wcoomd.org';
const WCO_NOMENCLATURE_PAGE = (edition: string) => 
  `${WCO_BASE_URL}/en/topics/nomenclature/instrument-and-tools/hs-nomenclature-${edition}-edition/hs-nomenclature-${edition}-edition.aspx`;

interface Config {
  edition: string;
  outputDir: string;
  chapters: string;
  delay: number;
  headless: boolean;
}

// Parse command line arguments
function parseArgs(): Config {
  const args = process.argv.slice(2);
  const config: Config = {
    edition: DEFAULT_EDITION,
    outputDir: '',
    chapters: '1-97',
    delay: DEFAULT_DELAY_MS,
    headless: false
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    switch (arg) {
      case '--edition':
        config.edition = args[++i] || DEFAULT_EDITION;
        break;
      case '--output':
        config.outputDir = args[++i] || '';
        break;
      case '--chapters':
        config.chapters = args[++i] || '1-97';
        break;
      case '--delay':
        config.delay = parseInt(args[++i] || String(DEFAULT_DELAY_MS), 10);
        break;
      case '--headless':
        config.headless = true;
        break;
      case '--help':
      case '-h':
        console.log(`
WCO PDF Download Script (Browser-based)

Usage: tsx scripts/download-wco-pdfs-browser.ts [options]

Options:
  --edition <year>    WCO edition year (default: 2022)
  --output <dir>      Output directory (default: ./data/wco-pdfs/{edition})
  --chapters <range>  Chapter range, e.g., "1-97" or "1,2,3" (default: 1-97)
  --delay <ms>        Delay between downloads in milliseconds (default: 2000)
  --headless          Run browser in headless mode (default: false)
  --help, -h          Show this help message

Features:
  - Uses Puppeteer to control a real browser
  - Discovers PDF links automatically from the WCO website
  - Handles authentication and sessions automatically
  - Downloads PDFs directly from the browser
        `);
        process.exit(0);
        break;
    }
  }

  // Set default output directory if not provided
  if (!config.outputDir) {
    config.outputDir = path.join(DEFAULT_OUTPUT_DIR, config.edition);
  }

  return config;
}

// Load WCO credentials from .secrets file
function loadWCOCredentials(): { username: string; password: string } | null {
  try {
    const secretsPath = path.join(process.cwd(), '.secrets');
    const secretsContent = readFileSync(secretsPath, 'utf-8');
    const lines = secretsContent.split('\n');
    
    let username = '';
    let password = '';
    
    for (const line of lines) {
      if (line.startsWith('WCO_USERNAME=')) {
        username = line.substring('WCO_USERNAME='.length).trim();
      } else if (line.startsWith('WCO_PASSWORD=')) {
        password = line.substring('WCO_PASSWORD='.length).trim();
      }
    }
    
    if (username && password) {
      return { username, password };
    }
  } catch (error) {
    // .secrets file not found or error reading
  }
  
  return null;
}

// Sleep/delay function
function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// Find all PDF links on the page
async function findPDFLinks(page: Page, baseUrl: string): Promise<string[]> {
  const pdfLinks = await page.evaluate((base) => {
    const links: string[] = [];
    
    // Find all links that point to PDFs
    const anchors = document.querySelectorAll('a[href]');
    anchors.forEach((anchor) => {
      const href = anchor.getAttribute('href');
      if (href && (href.endsWith('.pdf') || href.includes('.pdf'))) {
        // Convert relative URLs to absolute
        try {
          const absoluteUrl = href.startsWith('http') ? href : new URL(href, base).href;
          links.push(absoluteUrl);
        } catch (e) {
          // Skip invalid URLs
        }
      }
    });
    
    // Also check for PDF links in iframes or other embedded content
    const iframes = document.querySelectorAll('iframe');
    iframes.forEach((iframe) => {
      try {
        const src = iframe.getAttribute('src');
        if (src && src.includes('.pdf')) {
          const absoluteUrl = src.startsWith('http') ? src : new URL(src, base).href;
          links.push(absoluteUrl);
        }
      } catch (e) {
        // Skip invalid URLs
      }
    });
    
    return [...new Set(links)]; // Remove duplicates
  }, baseUrl);
  
  return pdfLinks;
}

// Navigate through chapters and find PDF links
async function discoverChapterPDFs(page: Page, edition: string, chapters: number[]): Promise<string[]> {
  const allPdfLinks: string[] = [];
  
  for (const chapter of chapters) {
    console.log(`\nDiscovering PDFs for Chapter ${chapter}...`);
    
    // Try to navigate to chapter page or find chapter-specific PDFs
    // This is a placeholder - we need to understand the WCO website structure
    // For now, we'll try to find PDFs on the main page that match the chapter pattern
    
    const chapterPdfs = await page.evaluate((chapterNum, editionYear) => {
      const links: string[] = [];
      const pattern = new RegExp(`${String(chapterNum).padStart(2, '0')}\\d{2}_${editionYear}e\\.pdf`, 'i');
      
      document.querySelectorAll('a[href]').forEach((anchor) => {
        const href = anchor.getAttribute('href');
        if (href && pattern.test(href)) {
          links.push(href);
        }
      });
      
      return links;
    }, chapter, edition);
    
    allPdfLinks.push(...chapterPdfs);
    console.log(`  Found ${chapterPdfs.length} PDFs for Chapter ${chapter}`);
  }
  
  return [...new Set(allPdfLinks)];
}

// Download PDF using direct HTTP request with browser cookies
async function downloadPDF(page: Page, url: string, outputPath: string): Promise<boolean> {
  try {
    // Get cookies from browser
    const cookies = await page.cookies();
    const cookieString = cookies.map(c => `${c.name}=${c.value}`).join('; ');
    
    // Use direct HTTP request to get PDF content (not rendered HTML)
    const https = await import('https');
    const http = await import('http');
    const { URL } = await import('url');
    
    const urlObj = new URL(url);
    const protocol = urlObj.protocol === 'https:' ? https : http;
    
    const content = await new Promise<Buffer>((resolveHttp, rejectHttp) => {
      const options = {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/pdf,*/*',
          'Cookie': cookieString,
          'Referer': page.url()
        }
      };
      
      protocol.get(url, options, (res) => {
        if (res.statusCode === 404) {
          console.error(`\n❌ ERROR: File not found (404): ${url}`);
          console.error(`   This is a bug - the file should exist!`);
          console.error(`   Stopping download to fix the bug.\n`);
          process.exit(1);
        }
        if (res.statusCode !== 200) {
          rejectHttp(new Error(`HTTP ${res.statusCode}`));
          return;
        }
        
        const chunks: Buffer[] = [];
        res.on('data', (chunk) => chunks.push(chunk));
        res.on('end', () => resolveHttp(Buffer.concat(chunks)));
        res.on('error', rejectHttp);
      }).on('error', rejectHttp);
    });
    
    // Verify it's actually a PDF (starts with %PDF)
    if (content.length < 4 || content.toString('utf8', 0, 4) !== '%PDF') {
      console.error(`  ✗ Invalid PDF content: ${url} (does not start with %PDF)`);
      console.error(`     First 100 bytes: ${content.toString('utf8', 0, 100)}`);
      return false;
    }
    
    // Save to file
    await fs.writeFile(outputPath, content);
    return true;
  } catch (error) {
    console.error(`  ✗ Error downloading ${url}: ${error instanceof Error ? error.message : String(error)}`);
    return false;
  }
}

// Main function
async function main(): Promise<void> {
  const config = parseArgs();
  
  console.log('WCO PDF Download Script (Browser-based)');
  console.log('========================================');
  console.log(`Edition: ${config.edition}`);
  console.log(`Output: ${config.outputDir}`);
  console.log(`Chapters: ${config.chapters}`);
  console.log(`Delay: ${config.delay}ms`);
  console.log(`Headless: ${config.headless}`);
  console.log('');

  // Create output directory
  await fs.mkdir(config.outputDir, { recursive: true });

  // Load credentials
  const credentials = loadWCOCredentials();
  if (!credentials) {
    console.error('❌ ERROR: WCO credentials not found in .secrets file');
    console.error('   Please add WCO_USERNAME and WCO_PASSWORD to .secrets file');
    process.exit(1);
  }

  // Launch browser
  console.log('Launching browser...');
  const browser = await puppeteer.launch({
    headless: config.headless,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  try {
    const page = await browser.newPage();
    
    // Set viewport
    await page.setViewport({ width: 1920, height: 1080 });
    
    // Navigate to WCO nomenclature page
    const nomenclatureUrl = WCO_NOMENCLATURE_PAGE(config.edition);
    console.log(`Navigating to: ${nomenclatureUrl}`);
    await page.goto(nomenclatureUrl, { waitUntil: 'networkidle0', timeout: 30000 });
    
    // Wait a bit for page to fully load
    await sleep(2000);
    
    // Find all PDF links on the page
    console.log('\nDiscovering PDF links on the page...');
    let pdfLinks = await findPDFLinks(page, WCO_BASE_URL);
    console.log(`Found ${pdfLinks.length} PDF links on main page`);
    
    // Parse chapters
    const chapterRanges = config.chapters.split(',').map(range => {
      if (range.includes('-')) {
        const [start, end] = range.split('-').map(Number);
        return Array.from({ length: end - start + 1 }, (_, i) => start + i);
      }
      return [Number(range)];
    }).flat();
    
    // Try to discover chapter-specific PDFs
    if (chapterRanges.length > 0) {
      const chapterPdfs = await discoverChapterPDFs(page, config.edition, chapterRanges);
      pdfLinks = [...new Set([...pdfLinks, ...chapterPdfs])];
      console.log(`Total PDF links found: ${pdfLinks.length}`);
    }
    
    if (pdfLinks.length === 0) {
      console.log('\n⚠️  WARNING: No PDF links found on the page.');
      console.log('   The page structure might have changed, or PDFs might be behind authentication.');
      console.log('   Try running with --headless=false to see what the browser sees.');
      console.log('   You may need to manually navigate and authenticate first.');
    }
    
    // Download each PDF
    console.log(`\nDownloading ${pdfLinks.length} PDFs...\n`);
    let downloaded = 0;
    let failed = 0;
    let skipped = 0;
    
    // Log progress every 10 files
    const logProgress = () => {
      const total = downloaded + failed + skipped;
      if (total > 0 && total % 10 === 0) {
        console.log(`\n[Progress] Downloaded: ${downloaded}, Failed: ${failed}, Skipped: ${skipped}, Total: ${total}/${pdfLinks.length}\n`);
      }
    };
    
    for (let i = 0; i < pdfLinks.length; i++) {
      const pdfUrl = pdfLinks[i]!;
      const urlObj = new URL(pdfUrl);
      const filename = path.basename(urlObj.pathname);
      const outputPath = path.join(config.outputDir, filename);
      
      // Skip if file already exists
      if (existsSync(outputPath)) {
        console.log(`  ⊘ ${filename} - already exists, skipping`);
        skipped++;
        logProgress();
        continue;
      }
      
      console.log(`  [${i + 1}/${pdfLinks.length}] Downloading: ${filename}`);
      
      const success = await downloadPDF(page, pdfUrl, outputPath);
      if (success) {
        downloaded++;
        console.log(`  ✓ ${filename}`);
        logProgress();
      } else {
        failed++;
        logProgress();
      }
      
      // Delay between downloads
      if (i < pdfLinks.length - 1 && config.delay > 0) {
        await sleep(config.delay);
      }
    }
    
    // Summary
    console.log('\n========================================');
    console.log('Download Summary');
    console.log('========================================');
    console.log(`Total PDFs found: ${pdfLinks.length}`);
    console.log(`Downloaded: ${downloaded}`);
    console.log(`Failed: ${failed}`);
    console.log(`Skipped: ${skipped}`);
    
  } finally {
    await browser.close();
  }
}

// Run main function
main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});

