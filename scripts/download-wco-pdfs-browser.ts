#!/usr/bin/env tsx
/// <reference types="node" />
'use strict';

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
 *   --output <dir>      Output directory (default: ./data/wco/{edition}/pdfs)
 *   --chapters <range>  Chapter range, e.g., "1-97" or "1,2,3" (default: 1-97)
 *   --delay <ms>        Delay between downloads in milliseconds (default: 5000)
 *   --headless          Run browser in headless mode (default: false, shows browser)
 *   --dry-run           Show what would be downloaded without downloading
 *   --help, -h          Show help message
 * 
 * Code Style Guidelines:
 * - Prefer arrow functions for consistency and modern JavaScript style
 * - Use function declarations only when necessary (e.g., inside page.evaluate() browser context
 *   where arrow functions may cause serialization issues)
 * - Keep helper functions DRY (Don't Repeat Yourself) - extract common patterns
 * - Shared utilities are in `shared-utils.ts` to avoid duplication between scripts
 */

import puppeteer, { Browser, Page } from 'puppeteer';
import { promises as fs } from 'fs';
import * as path from 'path';
import { existsSync } from 'fs';
import { sleep, processUrl as processUrlShared, toAbsoluteUrl as toAbsoluteUrlShared } from './shared-utils.js';

// Configuration
const DEFAULT_EDITION = '2022';
const DEFAULT_OUTPUT_DIR = './data/wco';
const DEFAULT_DELAY_MS = 5000; // Increased to 5 seconds to avoid rate limiting

// WCO website URLs
const WCO_BASE_URL = 'https://www.wcoomd.org';
const WCO_NOMENCLATURE_PAGE = (edition: string) => {
  // Older editions (2012, 2007, etc.) use a different URL structure
  const year = parseInt(edition, 10);
  if (year < 2017) {
    return `${WCO_BASE_URL}/en/topics/nomenclature/instrument-and-tools/hs_nomenclature_previous_editions/hs_nomenclature_table_${edition}.aspx`;
  }
  // Current editions (2017, 2022) use the standard URL
  return `${WCO_BASE_URL}/en/topics/nomenclature/instrument-and-tools/hs-nomenclature-${edition}-edition/hs-nomenclature-${edition}-edition.aspx`;
};

interface Config {
  edition: string;
  outputDir: string;
  chapters: string;
  delay: number;
  headless: boolean;
  dryRun: boolean;
}

// Parse command line arguments
// Note: Prefer arrow functions, but using function declaration here for hoisting
const parseArgs = (): Config => {
  const args = process.argv.slice(2);
  const config: Config = {
    edition: DEFAULT_EDITION,
    outputDir: '',
    chapters: '1-97',
    delay: DEFAULT_DELAY_MS,
    headless: false,
    dryRun: false
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
      case '--dry-run':
        config.dryRun = true;
        break;
      case '--help':
      case '-h':
        console.log(`
WCO PDF Download Script (Browser-based)

Usage: tsx scripts/download-wco-pdfs-browser.ts [options]

Options:
  --edition <year>    WCO edition year (default: 2022)
  --output <dir>      Output directory (default: ./data/wco/{edition}/pdfs)
  --chapters <range>  Chapter range, e.g., "1-97" or "1,2,3" (default: 1-97)
  --delay <ms>        Delay between downloads in milliseconds (default: 5000)
  --headless          Run browser in headless mode (default: false)
  --dry-run           Show what would be downloaded without downloading
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
    config.outputDir = path.join(DEFAULT_OUTPUT_DIR, config.edition, 'pdfs');
  }

  return config;
};

// Note: loadWCOCredentials removed - PDFs are publicly accessible, no login needed

// Note: sleep, processUrl, and toAbsoluteUrl are imported from shared-utils.ts
// The browser context versions (inside page.evaluate()) must remain duplicated
// because they run in a different JavaScript context and cannot import Node.js modules

// Find all PDF links on the page
async function findPDFLinks(page: Page, baseUrl: string, edition?: string): Promise<string[]> {
  try {
    const pdfLinks = await page.evaluate((base, editionYear) => {
      // Completely isolate from page's JavaScript context
      // Wrap in IIFE to prevent access to page globals like __name
      // Note: 'use strict' is inside the IIFE - browser context doesn't inherit file-level strict mode
      try {
        return (function() {
          'use strict';
          try {
            const links: string[] = [];
          
          // Helper function to process URLs (runs in browser context)
          // Note: Using function declaration here because arrow functions can cause
          // serialization issues in page.evaluate() browser context
          function processUrl(href: string): string | null {
        try {
          // Decode URL-encoded characters (e.g., %5F becomes _, %5E becomes ^)
          // Handle both single and double encoding
          let decodedHref = href;
          try {
            decodedHref = decodeURIComponent(href);
            // Try decoding again in case of double encoding
            if (decodedHref.includes('%')) {
              decodedHref = decodeURIComponent(decodedHref);
            }
          } catch (e) {
            // If decoding fails, use original
            decodedHref = href;
          }
          
          // Remove query parameters (?la=en) for cleaner URLs
          if (decodedHref.includes('?')) {
            decodedHref = decodedHref.split('?')[0];
          }
          
          // Convert relative URLs to absolute
          try {
            return decodedHref.startsWith('http') 
              ? decodedHref 
              : new URL(decodedHref, base).href;
          } catch (e) {
            // If URL construction fails, try simpler approach
            try {
              let cleanHref = href;
              if (cleanHref.includes('?')) {
                cleanHref = cleanHref.split('?')[0];
              }
              return cleanHref.startsWith('http') ? cleanHref : new URL(cleanHref, base).href;
            } catch (e2) {
              return null;
            }
          }
        } catch (e) {
            return null;
          }
        }
        
        // For older editions, PDFs are in a table - look for table cells with PDF links
        const tables = document.querySelectorAll('table');
        tables.forEach((table) => {
          const rows = table.querySelectorAll('tr');
          rows.forEach((row) => {
            const cells = row.querySelectorAll('td, th');
            cells.forEach((cell) => {
              const anchors = cell.querySelectorAll('a[href]');
              anchors.forEach((anchor) => {
                const href = anchor.getAttribute('href');
                if (href && (href.includes('.pdf') || href.includes('pdf') || href.includes('PDF'))) {
                  const absoluteUrl = processUrl(href);
                  if (absoluteUrl) {
                    links.push(absoluteUrl);
                  }
                }
              });
            });
          });
        });
        
        // Helper function to convert URL to absolute (simpler version)
        // Note: Using function declaration here because arrow functions can cause
        // serialization issues in page.evaluate() browser context
        function toAbsoluteUrl(href: string): string | null {
          try {
            return href.startsWith('http') ? href : new URL(href, base).href;
          } catch (e) {
            return null;
          }
        }
        
        // Also find all regular PDF links (for newer editions)
        const anchors = document.querySelectorAll('a[href]');
        anchors.forEach((anchor) => {
          const href = anchor.getAttribute('href');
          if (href && (href.endsWith('.pdf') || href.includes('.pdf'))) {
            const absoluteUrl = processUrl(href);
            // Only add if not already in links (avoid duplicates)
            if (absoluteUrl && !links.includes(absoluteUrl)) {
              links.push(absoluteUrl);
            }
          }
        });
        
        // Also check for PDF links in iframes or other embedded content
        const iframes = document.querySelectorAll('iframe');
        iframes.forEach((iframe) => {
          const src = iframe.getAttribute('src');
          if (src && src.includes('.pdf')) {
            const absoluteUrl = toAbsoluteUrl(src);
            if (absoluteUrl && !links.includes(absoluteUrl)) {
              links.push(absoluteUrl);
            }
          }
        });
    
            return [...new Set(links)]; // Remove duplicates
          } catch (e) {
            return [];
          }
        })();
      } catch (e) {
        // If IIFE fails, return empty array - will trigger fallback
        return [];
      }
    }, baseUrl, edition);
    
    // If we got an empty array, it might mean the IIFE caught an error
    // Try the fallback method
    if (pdfLinks.length === 0) {
      console.log('  Main method returned 0 links, trying fallback method...');
      try {
        const simpleLinks = await page.evaluate((base) => {
          // Browser context - strict mode needed here
          'use strict';
          const links: string[] = [];
          const anchors = document.querySelectorAll('a[href]');
          anchors.forEach((anchor) => {
            const href = anchor.getAttribute('href');
            if (href && href.includes('.pdf')) {
              try {
                const absoluteUrl = href.startsWith('http') ? href : new URL(href, base).href;
                if (absoluteUrl && !links.includes(absoluteUrl)) {
                  links.push(absoluteUrl);
                }
              } catch (e) {
                // Skip invalid URLs
              }
            }
          });
          return [...new Set(links)];
        }, baseUrl);
        if (simpleLinks.length > 0) {
          console.log(`  Fallback method found ${simpleLinks.length} PDF links`);
          return simpleLinks;
        }
      } catch (simpleError) {
        console.error(`  Fallback method also failed: ${simpleError instanceof Error ? simpleError.message : String(simpleError)}`);
      }
    }
    
    return pdfLinks;
  } catch (error) {
    console.error(`Error finding PDF links: ${error instanceof Error ? error.message : String(error)}`);
    // Try a simpler approach - just find all links with .pdf
    try {
      const simpleLinks = await page.evaluate((base) => {
        // Browser context - strict mode needed here
        'use strict';
        const links: string[] = [];
        const anchors = document.querySelectorAll('a[href]');
        anchors.forEach((anchor) => {
          const href = anchor.getAttribute('href');
          if (href && href.includes('.pdf')) {
            try {
              const absoluteUrl = href.startsWith('http') ? href : new URL(href, base).href;
              if (absoluteUrl && !links.includes(absoluteUrl)) {
                links.push(absoluteUrl);
              }
            } catch (e) {
              // Skip invalid URLs
            }
          }
        });
        return [...new Set(links)];
      }, baseUrl);
      return simpleLinks;
    } catch (simpleError) {
      console.error(`Simple PDF link discovery also failed: ${simpleError instanceof Error ? simpleError.message : String(simpleError)}`);
      return [];
    }
  }
}

// Navigate through chapters and find PDF links
async function discoverChapterPDFs(page: Page, edition: string, chapters: number[]): Promise<string[]> {
  const allPdfLinks: string[] = [];
  const baseUrl = WCO_BASE_URL;
  const currentUrl = page.url();
  
  // First, try to find and click on expandable sections/accordions that might contain chapter links
  console.log('\nLooking for expandable sections or navigation menus...');
  try {
    await page.evaluate(() => {
      // Completely isolate from page's JavaScript context
      // Wrap in IIFE to prevent access to page globals
      return (function() {
        'use strict';
        try {
          // Try to find and click common expandable elements
          const expandButtons = document.querySelectorAll('[class*="expand"], [class*="accordion"], [class*="toggle"], [class*="collapse"], [aria-expanded="false"]');
          expandButtons.forEach((btn: Element) => {
            try {
              (btn as HTMLElement).click();
            } catch (e) {
              // Ignore click errors
            }
          });
          return true;
        } catch (e) {
          return false;
        }
      })();
    });
  } catch (error) {
    console.log(`  Note: Could not expand sections (${error instanceof Error ? error.message : String(error)})`);
  }
  
  // Wait for any dynamic content to load
  await sleep(2000);
  
  // Try to find chapter links and navigate to them
  let chapterLinks: Array<{ chapter: number; url: string; text: string }> = [];
  try {
    chapterLinks = await page.evaluate((chapterNums: number[], base: string) => {
      // Completely isolate from page's JavaScript context
      // Wrap in IIFE to prevent access to page globals like __name
      return (function() {
        'use strict';
        try {
          const links: Array<{ chapter: number; url: string; text: string }> = [];
          
          // Helper function to convert URL to absolute
          function toAbsoluteUrl(href: string): string | null {
            try {
              return href.startsWith('http') ? href : new URL(href, base).href;
            } catch (e) {
              return null;
            }
          }
        
          // Look for links that mention chapters
          document.querySelectorAll('a[href]').forEach((anchor) => {
            const href = anchor.getAttribute('href');
            const text = anchor.textContent?.toLowerCase() || '';
            
            if (href) {
              chapterNums.forEach((chapterNum) => {
                // Check if link text or href contains chapter number
                if (text.includes(`chapter ${chapterNum}`) || 
                    text.includes(`ch ${chapterNum}`) ||
                    href.includes(`chapter-${chapterNum}`) ||
                    href.includes(`ch${chapterNum}`) ||
                    href.includes(`chapter${chapterNum}`)) {
                  const absoluteUrl = toAbsoluteUrl(href);
                  if (absoluteUrl) {
                    links.push({ chapter: chapterNum, url: absoluteUrl, text: text });
                  }
                }
              });
            }
          });
          
          return links;
        } catch (e) {
          return [];
        }
      })();
    }, chapters, baseUrl);
  } catch (error) {
    console.log(`  Note: Could not find chapter links (${error instanceof Error ? error.message : String(error)})`);
    chapterLinks = [];
  }
  
  console.log(`Found ${chapterLinks.length} chapter navigation links`);
  
  // For each chapter, try to navigate and find PDFs
  for (const chapter of chapters) {
    console.log(`\nDiscovering PDFs for Chapter ${chapter}...`);
    const chapterPdfs: string[] = [];
    
    // First, check current page for chapter PDFs
    let currentPagePdfs: string[] = [];
    try {
      currentPagePdfs = await page.evaluate((chapterNum, editionYear, base) => {
        // Completely isolate from page's JavaScript context
        // Wrap in IIFE to prevent access to page globals like __name
        return (function() {
          'use strict';
          try {
            const links: string[] = [];
            const pattern = new RegExp(`${String(chapterNum).padStart(2, '0')}\\d{2}_${editionYear}e\\.pdf`, 'i');
            
            // Helper function to convert URL to absolute
            function toAbsolute(href: string): string | null {
              try {
                return href.startsWith('http') ? href : new URL(href, base).href;
              } catch (e) {
                return null;
              }
            }
            
            document.querySelectorAll('a[href]').forEach((anchor) => {
              const href = anchor.getAttribute('href');
              if (href && pattern.test(href)) {
                const absoluteUrl = toAbsolute(href);
                if (absoluteUrl) {
                  links.push(absoluteUrl);
                }
              }
            });
            
            return links;
          } catch (e) {
            return [];
          }
        })();
      }, chapter, edition, baseUrl);
    } catch (error) {
      console.log(`  Note: Could not find PDFs for chapter ${chapter} on current page (${error instanceof Error ? error.message : String(error)})`);
      currentPagePdfs = [];
    }
    
    chapterPdfs.push(...currentPagePdfs);
    
    // Try to navigate to chapter-specific page if link found
    const chapterLink = chapterLinks.find(link => link.chapter === chapter);
    if (chapterLink && chapterPdfs.length === 0) {
      try {
        console.log(`  Navigating to chapter page: ${chapterLink.url}`);
        await page.goto(chapterLink.url, { waitUntil: 'networkidle0', timeout: 15000 });
        await sleep(2000);
        
        // Find PDFs on chapter page
        const chapterPagePdfs = await findPDFLinks(page, baseUrl);
        const chapterPattern = new RegExp(`${String(chapter).padStart(2, '0')}\\d{2}_${edition}e\\.pdf`, 'i');
        const filteredPdfs = chapterPagePdfs.filter(url => chapterPattern.test(url));
        chapterPdfs.push(...filteredPdfs);
        
        // Navigate back to main page
        await page.goto(currentUrl, { waitUntil: 'networkidle0', timeout: 15000 });
        await sleep(1000);
      } catch (error) {
        console.log(`  ⚠️  Could not navigate to chapter page: ${error instanceof Error ? error.message : String(error)}`);
        // Try to go back to main page if navigation failed
        try {
          await page.goto(currentUrl, { waitUntil: 'networkidle0', timeout: 15000 });
        } catch (e) {
          // Ignore navigation errors
        }
      }
    }
    
    // Also try to expand any sections that might contain this chapter's PDFs
    if (chapterPdfs.length === 0) {
      try {
        // Look for elements that might expand to show chapter content
        await page.evaluate((chapterNum) => {
          // Browser context - strict mode needed here
          'use strict';
          const chapterStr = String(chapterNum).padStart(2, '0');
          // Look for elements containing chapter number
          const elements = Array.from(document.querySelectorAll('*')).filter(el => {
            const text = el.textContent || '';
            return text.includes(`Chapter ${chapterNum}`) || 
                   text.includes(`Ch ${chapterNum}`) ||
                   text.includes(`Chapter ${chapterStr}`);
          });
          
          // Try to click on parent elements that might be expandable
          elements.forEach((el) => {
            let parent = el.parentElement;
            for (let i = 0; i < 3 && parent; i++) {
              if (parent.getAttribute('aria-expanded') === 'false' ||
                  parent.classList.toString().includes('collapse') ||
                  parent.classList.toString().includes('expand')) {
                try {
                  (parent as HTMLElement).click();
                } catch (e) {
                  // Ignore
                }
              }
              parent = parent.parentElement;
            }
          });
        }, chapter);
        
        await sleep(2000);
        
        // Check again for PDFs after expanding
        const expandedPdfs = await page.evaluate((chapterNum, editionYear, base) => {
          // Browser context - strict mode needed here
          'use strict';
          const links: string[] = [];
          const pattern = new RegExp(`${String(chapterNum).padStart(2, '0')}\\d{2}_${editionYear}e\\.pdf`, 'i');
          
          // Helper function to convert URL to absolute
          const toAbsolute = (href: string): string | null => {
            try {
              return href.startsWith('http') ? href : new URL(href, base).href;
            } catch (e) {
              return null;
            }
          };
          
          document.querySelectorAll('a[href]').forEach((anchor) => {
            const href = anchor.getAttribute('href');
            if (href && pattern.test(href)) {
              const absoluteUrl = toAbsolute(href);
              if (absoluteUrl) {
                links.push(absoluteUrl);
              }
            }
          });
          
          return links;
        }, chapter, edition, baseUrl);
        
        chapterPdfs.push(...expandedPdfs);
      } catch (error) {
        // Ignore errors during expansion attempts
      }
    }
    
    allPdfLinks.push(...chapterPdfs);
    console.log(`  Found ${chapterPdfs.length} PDFs for Chapter ${chapter}`);
  }
  
  return [...new Set(allPdfLinks)];
};

// Download PDF using direct HTTP request with browser cookies
// Note: Prefer arrow functions for consistency
const downloadPDF = async (page: Page, url: string, outputPath: string): Promise<boolean> => {
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
          // 404 is expected for headings that don't exist
          resolveHttp(Buffer.from(''));
          return;
        }
        
        // Check for blocking/rate limiting
        if (res.statusCode === 403 || res.statusCode === 429) {
          const errorMsg = res.statusCode === 403 
            ? 'Access forbidden (403) - may be blocked'
            : 'Rate limited (429) - too many requests';
          rejectHttp(new Error(errorMsg));
          return;
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
    
    // Handle empty content (404)
    if (content.length === 0) {
      return false; // Silently skip 404s
    }
    
    // Verify it's actually a PDF (starts with %PDF)
    if (content.length < 4 || content.toString('utf8', 0, 4) !== '%PDF') {
      const preview = content.toString('utf8', 0, 200);
      // Check if it's an HTML error page
      if (preview.includes('<html') || preview.includes('<!DOCTYPE')) {
        if (preview.toLowerCase().includes('blocked') || preview.toLowerCase().includes('access denied')) {
          console.error(`  ✗ Blocked/Forbidden: ${url}`);
          console.error(`     The server may be blocking automated access`);
        } else {
          console.error(`  ✗ Invalid PDF content: ${url} (received HTML instead of PDF)`);
        }
      } else {
        console.error(`  ✗ Invalid PDF content: ${url} (does not start with %PDF)`);
        console.error(`     First 100 bytes: ${preview.substring(0, 100)}`);
      }
      return false;
    }
    
    // Save to file
    await fs.writeFile(outputPath, content);
    return true;
  } catch (error) {
    console.error(`  ✗ Error downloading ${url}: ${error instanceof Error ? error.message : String(error)}`);
    return false;
  }
};

// Main function
// Note: Prefer arrow functions, but async function declarations are acceptable for clarity
const main = async (): Promise<void> => {
  const config = parseArgs();
  
  console.log('WCO PDF Download Script (Browser-based)');
  console.log('========================================');
  console.log(`Edition: ${config.edition}`);
  console.log(`Output: ${config.outputDir}`);
  console.log(`Chapters: ${config.chapters}`);
  console.log(`Delay: ${config.delay}ms`);
  console.log(`Headless: ${config.headless}`);
  console.log(`Dry Run: ${config.dryRun}`);
  console.log('');

  // Create output directory
  await fs.mkdir(config.outputDir, { recursive: true });

  // Note: Credentials are not required for PDF downloads - they are publicly accessible
  // The credentials check is removed since login is not needed

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
    
    // Set realistic browser behavior to avoid detection
    await page.setUserAgent('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
    await page.setExtraHTTPHeaders({
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8'
    });
    
    const response = await page.goto(nomenclatureUrl, { waitUntil: 'networkidle0', timeout: 30000 });
    
    // Check if we're being blocked or redirected to login
    const currentUrl = page.url();
    const statusCode = response?.status();
    
    console.log(`  Status: ${statusCode}`);
    console.log(`  Current URL: ${currentUrl}`);
    
    // Check for blocking indicators (but don't try to login - PDFs are publicly accessible)
    const blockingCheck = await page.evaluate(() => {
      // Browser context - strict mode needed here
      'use strict';
      const bodyText = document.body.textContent?.toLowerCase() || '';
      const title = document.title.toLowerCase();
      
      return {
        hasBlockedMessage: bodyText.includes('blocked') || 
                          bodyText.includes('access denied') ||
                          bodyText.includes('forbidden') ||
                          bodyText.includes('rate limit') ||
                          title.includes('blocked') ||
                          title.includes('access denied'),
        hasCaptcha: bodyText.includes('captcha') ||
                   document.querySelector('[class*="captcha"]') !== null ||
                   document.querySelector('iframe[src*="recaptcha"]') !== null,
        pageText: bodyText.substring(0, 500)
      };
    });
    
    if (blockingCheck.hasBlockedMessage) {
      console.error('\n⚠️  WARNING: Page appears to be blocked or access denied!');
      console.error('   The website may have detected automated access.');
      console.error('   Suggestions:');
      console.error('   1. Wait a few minutes before trying again');
      console.error('   2. Try running with --headless=false to see what the browser sees');
      console.error('   3. Check if your IP has been rate-limited');
      console.error(`   Page content preview: ${blockingCheck.pageText.substring(0, 200)}`);
    }
    
    if (blockingCheck.hasCaptcha) {
      console.error('\n⚠️  WARNING: CAPTCHA detected!');
      console.error('   Manual intervention required. Please:');
      console.error('   1. Run with --headless=false');
      console.error('   2. Complete the CAPTCHA manually');
      console.error('   3. The script will continue after CAPTCHA is solved');
    }
    
    // Note: Login is not required - PDFs are publicly accessible
    // The login form on the page is for member-only content, not for PDF downloads
    
    // Wait a bit for page to fully load
    await sleep(2000);
    
    // First, inspect and analyze the page structure
    console.log('\n📖 Analyzing page structure...');
    const pageAnalysis = await page.evaluate(() => {
      // Browser context - strict mode needed here
      'use strict';
      const analysis: {
        title: string;
        url: string;
        totalLinks: number;
        pdfLinks: number;
        expandableElements: number;
        chapterLinks: number;
        structure: {
          hasAccordions: boolean;
          hasTabs: boolean;
          hasNavigation: boolean;
          mainContent: string;
        };
      } = {
        title: document.title,
        url: window.location.href,
        totalLinks: document.querySelectorAll('a[href]').length,
        pdfLinks: 0,
        expandableElements: 0,
        chapterLinks: 0,
        structure: {
          hasAccordions: false,
          hasTabs: false,
          hasNavigation: false,
          mainContent: ''
        }
      };
      
      // Count PDF links
      document.querySelectorAll('a[href]').forEach((anchor) => {
        const href = anchor.getAttribute('href') || '';
        if (href.includes('.pdf')) {
          analysis.pdfLinks++;
        }
        // Check for chapter links
        const text = anchor.textContent?.toLowerCase() || '';
        if (text.includes('chapter') || href.includes('chapter')) {
          analysis.chapterLinks++;
        }
      });
      
      // Check for expandable elements
      analysis.expandableElements = document.querySelectorAll(
        '[class*="accordion"], [class*="expand"], [class*="collapse"], [class*="toggle"], [aria-expanded]'
      ).length;
      
      // Check page structure
      analysis.structure.hasAccordions = analysis.expandableElements > 0;
      analysis.structure.hasTabs = document.querySelectorAll('[role="tab"], [class*="tab"]').length > 0;
      analysis.structure.hasNavigation = document.querySelectorAll('nav, [class*="nav"], [class*="menu"]').length > 0;
      
      // Get main content area text (first 500 chars)
      const mainContent = document.querySelector('main, [role="main"], .content, #content, .main-content');
      if (mainContent) {
        analysis.structure.mainContent = (mainContent.textContent || '').substring(0, 500);
      } else {
        // Fallback to body
        analysis.structure.mainContent = (document.body.textContent || '').substring(0, 500);
      }
      
      return analysis;
    });
    
    console.log(`  Page Title: ${pageAnalysis.title}`);
    console.log(`  Total Links: ${pageAnalysis.totalLinks}`);
    console.log(`  PDF Links Found: ${pageAnalysis.pdfLinks}`);
    console.log(`  Chapter Links: ${pageAnalysis.chapterLinks}`);
    console.log(`  Expandable Elements: ${pageAnalysis.expandableElements}`);
    console.log(`  Structure:`);
    console.log(`    - Has Accordions: ${pageAnalysis.structure.hasAccordions}`);
    console.log(`    - Has Tabs: ${pageAnalysis.structure.hasTabs}`);
    console.log(`    - Has Navigation: ${pageAnalysis.structure.hasNavigation}`);
    if (pageAnalysis.structure.mainContent) {
      console.log(`  Main Content Preview: ${pageAnalysis.structure.mainContent.substring(0, 200)}...`);
    }
    
    // Detailed inspection: Look for specific patterns and structures
    console.log('\n🔍 Detailed page inspection...');
    const detailedInspection = await page.evaluate((edition) => {
      // Browser context - strict mode needed here
      'use strict';
      const inspection: {
        allLinks: Array<{ href: string; text: string; visible: boolean }>;
        pdfLinks: Array<{ href: string; text: string }>;
        chapterSections: Array<{ text: string; element: string }>;
        clickableElements: Array<{ type: string; text: string; selector: string }>;
      } = {
        allLinks: [],
        pdfLinks: [],
        chapterSections: [],
        clickableElements: []
      };
      
      // Get all links with their text
      document.querySelectorAll('a[href]').forEach((anchor) => {
        const href = anchor.getAttribute('href') || '';
        const text = (anchor.textContent || '').trim();
        const isVisible = (anchor as HTMLElement).offsetParent !== null;
        
        inspection.allLinks.push({ href, text, visible: isVisible });
        
        if (href.includes('.pdf')) {
          inspection.pdfLinks.push({ href, text });
        }
      });
      
      // Look for chapter-related sections
      const chapterPattern = /chapter\s*\d+|ch\.?\s*\d+|section\s*\d+/i;
      document.querySelectorAll('*').forEach((el) => {
        const text = el.textContent || '';
        if (chapterPattern.test(text) && text.length < 200) {
          inspection.chapterSections.push({
            text: text.substring(0, 100),
            element: el.tagName.toLowerCase()
          });
        }
      });
      
      // Find clickable elements that might expand content
      const clickableSelectors = [
        'button',
        '[onclick]',
        '[role="button"]',
        '[class*="expand"]',
        '[class*="toggle"]',
        '[class*="accordion"]',
        '[aria-expanded]'
      ];
      
      clickableSelectors.forEach(selector => {
        try {
          document.querySelectorAll(selector).forEach((el) => {
            const text = (el.textContent || '').trim().substring(0, 50);
            if (text) {
              inspection.clickableElements.push({
                type: selector,
                text: text,
                selector: selector
              });
            }
          });
        } catch (e) {
          // Ignore selector errors
        }
      });
      
      return inspection;
    }, config.edition);
    
    console.log(`  Total Links: ${detailedInspection.allLinks.length}`);
    console.log(`  Visible Links: ${detailedInspection.allLinks.filter(l => l.visible).length}`);
    console.log(`  PDF Links: ${detailedInspection.pdfLinks.length}`);
    if (detailedInspection.pdfLinks.length > 0 && detailedInspection.pdfLinks.length <= 10) {
      console.log(`  PDF Link Examples:`);
      detailedInspection.pdfLinks.slice(0, 5).forEach(link => {
        console.log(`    - ${link.text.substring(0, 60)}: ${link.href.substring(0, 80)}`);
      });
    }
    console.log(`  Chapter Sections Found: ${detailedInspection.chapterSections.length}`);
    if (detailedInspection.chapterSections.length > 0 && detailedInspection.chapterSections.length <= 10) {
      console.log(`  Chapter Section Examples:`);
      detailedInspection.chapterSections.slice(0, 5).forEach(section => {
        console.log(`    - ${section.element}: ${section.text}`);
      });
    }
    console.log(`  Clickable Elements: ${detailedInspection.clickableElements.length}`);
    if (detailedInspection.clickableElements.length > 0 && detailedInspection.clickableElements.length <= 10) {
      console.log(`  Clickable Element Examples:`);
      detailedInspection.clickableElements.slice(0, 5).forEach(el => {
        console.log(`    - ${el.type}: ${el.text}`);
      });
    }
    
    // Find all PDF links on the page
    console.log('\nDiscovering PDF links on the page...');
    let pdfLinks = await findPDFLinks(page, WCO_BASE_URL, config.edition);
    console.log(`Found ${pdfLinks.length} PDF links on main page`);
    
    // For older editions (with table structure), we already have all PDFs from the table
    // No need to discover chapter-specific PDFs separately
    const year = parseInt(config.edition, 10);
    const isOlderEdition = year < 2017;
    
    // If we already found a good number of PDFs on the main page (100+), skip chapter-by-chapter discovery
    // This avoids the slow and confusing "Discovering PDFs for Chapter X... Found 0 PDFs" messages
    const hasEnoughPdfs = pdfLinks.length >= 100;
    
    if (!isOlderEdition && !hasEnoughPdfs) {
      // For newer editions, try to discover chapter-specific PDFs only if we don't have enough yet
      const chapterRanges = config.chapters.split(',').map(range => {
        if (range.includes('-')) {
          const [start, end] = range.split('-').map(Number);
          return Array.from({ length: end - start + 1 }, (_, i) => start + i);
        }
        return [Number(range)];
      }).flat();
      
      if (chapterRanges.length > 0) {
        const chapterPdfs = await discoverChapterPDFs(page, config.edition, chapterRanges);
        pdfLinks = [...new Set([...pdfLinks, ...chapterPdfs])];
        console.log(`Total PDF links found: ${pdfLinks.length}`);
      }
    } else {
      // Skip chapter-by-chapter discovery - we already have all PDFs
      if (isOlderEdition) {
        console.log(`Using all ${pdfLinks.length} PDFs found in table (older edition structure)`);
      } else {
        console.log(`Using all ${pdfLinks.length} PDFs found on main page (skipping chapter-by-chapter discovery)`);
      }
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
      let pdfUrl = pdfLinks[i]!;
      
      // Ensure URL is absolute and clean
      const processedUrl = processUrlShared(pdfUrl, WCO_BASE_URL);
      if (!processedUrl) {
        console.log(`  ⚠️  Skipping invalid URL: ${pdfUrl}`);
        failed++;
        continue;
      }
      pdfUrl = processedUrl;
      
      // Extract filename from URL
      const urlObj = new URL(pdfUrl);
      let filename = path.basename(urlObj.pathname);
      const outputPath = path.join(config.outputDir, filename);
      
      // Skip if file already exists
      if (existsSync(outputPath)) {
        console.log(`  ⊘ ${filename} - already exists, skipping`);
        skipped++;
        logProgress();
        continue;
      }
      
      if (config.dryRun) {
        console.log(`  [DRY RUN] Would download: ${filename}`);
        console.log(`           URL: ${pdfUrl}`);
        downloaded++; // Count as would-be downloaded for summary
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
      
      // Delay between downloads (with random variation to appear more human-like)
      if (i < pdfLinks.length - 1 && config.delay > 0) {
        const randomVariation = Math.floor(Math.random() * config.delay * 0.5); // 0-50% variation
        const delay = config.delay + randomVariation;
        await sleep(delay);
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
};

// Run main function
main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});

