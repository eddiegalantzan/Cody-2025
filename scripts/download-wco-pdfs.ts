#!/usr/bin/env tsx
/// <reference types="node" />

import { fileURLToPath } from 'url';
import { dirname } from 'path';

// Get __dirname for config file imports
// tsx handles both ES modules and CommonJS, so we support both
const getScriptDir = (): string => {
  try {
    // Try ES modules approach (when using import.meta.url)
    if (typeof import.meta !== 'undefined' && import.meta.url) {
      return dirname(fileURLToPath(import.meta.url));
    }
  } catch {
    // Fall through to CommonJS
  }
  // CommonJS fallback (tsx provides __dirname in CommonJS mode)
  // @ts-ignore - __dirname may not be defined in ES modules, but tsx provides it
  return typeof __dirname !== 'undefined' ? __dirname : process.cwd();
};

/**
 * WCO PDF Download Script
 * 
 * Downloads all WCO HS Nomenclature PDF files from the official WCO website.
 * 
 * Downloads:
 * - Additional PDFs: Introduction, Table of Contents, General Rules, Explanatory Notes, etc. (critical for LLM classification)
 * - Chapter/Heading PDFs: All chapters (1-97) and headings (01-99)
 * 
 * URL Patterns:
 * - Chapter/Heading: https://www.wcoomd.org/-/media/wco/public/global/pdf/topics/nomenclature/instruments-and-tools/hs-nomenclature-{EDITION}/{EDITION}/{CHAPTER}{HEADING}_{EDITION}e.pdf
 * - Additional PDFs: https://www.wcoomd.org/-/media/wco/public/global/pdf/topics/nomenclature/instruments-and-tools/hs-nomenclature-{EDITION}/{EDITION}/{FILENAME}
 * Example: https://www.wcoomd.org/-/media/wco/public/global/pdf/topics/nomenclature/instruments-and-tools/hs-nomenclature-2022/2022/0101_2022e.pdf
 * 
 * Usage:
 *   tsx scripts/download-wco-pdfs.ts [options]
 * 
 * Options:
 *   --edition <year>    WCO edition year (default: 2022)
 *   --output <dir>      Output directory (default: ./data/wco-pdfs/{edition})
 *   --chapters <range>  Chapter range, e.g., "1-97" or "1,2,3" (default: 1-97)
 *   --delay <ms>        Base delay between downloads in milliseconds (default: ${DEFAULT_DELAY_MS})
 *   --delay-variation <ms>  Random variation added to delay (default: ${DEFAULT_DELAY_VARIATION_MS})
 *   --retries <n>       Number of retries for failed downloads (default: 3)
 *   --resume             Resume from last downloaded file
 *   --dry-run            Show what would be downloaded without downloading
 *   --check-existing     Check if files exist and skip if unchanged (default: enabled, uses HEAD request)
 *   --skip-existing      Skip files that already exist locally (faster, no HEAD request, doesn't check for updates)
 *   --no-check-existing  Download all files without checking if they exist (re-downloads everything)
 *   --force              Alias for --no-check-existing
 * 
 * Features:
 *   - Uses realistic Chrome browser headers to avoid detection
 *   - Random delay variation to appear more human-like
 *   - Smart skip logic: checks if file exists and hasn't changed before downloading
 *   - Retry logic with exponential backoff
 *   - Resume capability for interrupted downloads
 *   - Configurable additional PDFs via config file (scripts/download-wco-pdfs-config.ts)
 *   - Automatically downloads new PDFs added to config file in the future
 */

import { promises as fs } from 'fs';
import * as path from 'path';
import * as https from 'https';
import * as http from 'http';
import { createWriteStream, existsSync, readFileSync, statSync, unlinkSync } from 'fs';
import { URL as NodeURL } from 'url';

// Configuration
const DEFAULT_EDITION = '2022';
const DEFAULT_OUTPUT_DIR = './data/wco-pdfs';
const DEFAULT_DELAY_MS = 5000; // Base delay between downloads (will be randomized)
const DEFAULT_DELAY_VARIATION_MS = 5000; // Random variation added to base delay
const DEFAULT_RETRIES = 3;

// Realistic Chrome browser headers
const CHROME_USER_AGENTS = [
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
];

// Get random Chrome User-Agent
function getRandomUserAgent(): string {
  return CHROME_USER_AGENTS[Math.floor(Math.random() * CHROME_USER_AGENTS.length)]!;
}

// Cookie storage
let cookieJar: string = '';

// Get realistic browser headers (with cookies and referer if available)
function getBrowserHeaders(referer?: string): Record<string, string> {
  const headers: Record<string, string> = {
    'User-Agent': getRandomUserAgent(),
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept-Encoding': 'gzip, deflate, br',
    'DNT': '1',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': referer ? 'same-origin' : 'none',
    'Sec-Fetch-User': '?1',
    'Cache-Control': 'max-age=0',
  };
  
  // Add referer if provided
  if (referer) {
    headers['Referer'] = referer;
  }
  
  // Add cookies if we have them
  if (cookieJar) {
    headers['Cookie'] = cookieJar;
  }
  
  return headers;
}

// Extract cookies from Set-Cookie headers
function extractCookies(response: http.IncomingMessage): void {
  const setCookieHeaders = response.headers['set-cookie'];
  if (setCookieHeaders) {
    const cookies: string[] = [];
    setCookieHeaders.forEach((cookieHeader: string) => {
      // Extract cookie name=value (before semicolon)
      const cookie = cookieHeader.split(';')[0]?.trim();
      if (cookie) {
        cookies.push(cookie);
      }
    });
    if (cookies.length > 0) {
      cookieJar = cookies.join('; ');
    }
  }
}

// Load WCO credentials from .secrets file
function loadWCOCredentials(): { username: string; password: string } | null {
  try {
    const secretsPath = path.join(process.cwd(), '.secrets');
    const secretsContent = readFileSync(secretsPath, 'utf-8');
    
    let username: string | null = null;
    let password: string | null = null;
    
    const lines = secretsContent.split('\n');
    for (const line of lines) {
      const trimmed = line.trim();
      if (trimmed.startsWith('WCO_USERNAME=')) {
        username = trimmed.substring('WCO_USERNAME='.length).trim();
      } else if (trimmed.startsWith('WCO_PASSWORD=')) {
        password = trimmed.substring('WCO_PASSWORD='.length).trim();
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

// Visit WCO main page to establish session (like a regular browser)
async function establishSession(edition: string, verbose: boolean = false): Promise<string> {
  // WCO main page URL for the edition
  const mainPageUrl = `https://www.wcoomd.org/en/topics/nomenclature/instrument-and-tools/hs-nomenclature-${edition}-edition/hs-nomenclature-${edition}-edition.aspx`;
  
  if (verbose) {
    console.log('[DEBUG] Establishing browser session...');
    console.log(`[DEBUG] Visiting main page: ${mainPageUrl}`);
  }
  
  return new Promise((resolve, reject) => {
    const protocol = https;
    // Clear any existing cookies for initial request
    const headers = getBrowserHeaders();
    delete headers['Cookie'];
    
    const options = {
      headers: headers,
      method: 'GET'
    };
    
    const req = protocol.request(mainPageUrl, options, (response) => {
      // Extract cookies from response
      extractCookies(response);
      
      // Consume response body
      response.resume();
      
      response.on('end', () => {
        if (verbose) {
          console.log(`[DEBUG] Session established: ${response.statusCode}`);
          console.log(`[DEBUG] Cookies received: ${cookieJar || 'none'}`);
        }
        
        // Return the main page URL to use as referer
        resolve(mainPageUrl);
      });
    });
    
    req.on('error', (error) => {
      if (verbose) {
        console.log(`[DEBUG] Session establishment error: ${error.message}`);
      }
      // Even if there's an error, continue with the main page URL as referer
      resolve(mainPageUrl);
    });
    
    req.setTimeout(10000, () => {
      req.destroy();
      if (verbose) {
        console.log('[DEBUG] Session establishment timeout');
      }
      resolve(mainPageUrl);
    });
    
    req.end();
  });
}

// Get random delay with variation
function getRandomDelay(baseDelay: number, variation: number = DEFAULT_DELAY_VARIATION_MS): number {
  const randomVariation = Math.floor(Math.random() * variation);
  return baseDelay + randomVariation;
}
// Base URL for chapter/heading PDFs
const BASE_URL = 'https://www.wcoomd.org/-/media/wco/public/global/pdf/topics/nomenclature/instruments-and-tools/hs-nomenclature-{EDITION}/{EDITION}/{CHAPTER}{HEADING}_{EDITION}e.pdf';

// Base URL for additional PDFs (Introduction, Table of Contents, etc.)
const BASE_URL_ADDITIONAL = 'https://www.wcoomd.org/-/media/wco/public/global/pdf/topics/nomenclature/instruments-and-tools/hs-nomenclature-{EDITION}/{EDITION}/{FILENAME}';

// Default additional PDFs for LLM classification context
// These contain critical information: introduction, general rules, explanatory notes, etc.
// Can be overridden/extended via config file: scripts/download-wco-pdfs-config.ts
// NOTE: Only include files that actually exist on the WCO server (404s are treated as bugs)
const DEFAULT_ADDITIONAL_PDFS = [
  'introduction_{EDITION}e.pdf'
  // TODO: Add other PDFs once we verify they exist on the WCO server
  // The following files return 404 and need to be fixed:
  // 'table-of-contents_{EDITION}e.pdf',
  // 'general-rules_{EDITION}e.pdf',
  // 'general-rules-for-interpretation_{EDITION}e.pdf',
  // 'explanatory-notes_{EDITION}e.pdf',
  // 'classification-rules_{EDITION}e.pdf',
  // 'section-notes_{EDITION}e.pdf',
  // 'chapter-notes_{EDITION}e.pdf',
  // 'alphabetical-index_{EDITION}e.pdf',
  // 'compendium_{EDITION}e.pdf',
  // 'compendium-of-classification-opinions_{EDITION}e.pdf',
];

// Load additional PDFs from config file if it exists
async function loadAdditionalPdfs(configPath?: string): Promise<string[]> {
  try {
    if (configPath) {
      // Custom config path provided
      if (configPath.endsWith('.ts')) {
        // TypeScript config file - try to import it
        try {
          // Use dynamic import for TypeScript config
          const configModule = await import(path.resolve(configPath));
          if (configModule.config && configModule.config.additionalPdfs && Array.isArray(configModule.config.additionalPdfs)) {
            const merged = [...new Set([...DEFAULT_ADDITIONAL_PDFS, ...configModule.config.additionalPdfs])];
            console.log(`Loaded ${configModule.config.additionalPdfs.length} additional PDFs from config file`);
            return merged;
          }
        } catch (importError) {
          console.warn(`Warning: Could not import TypeScript config file ${configPath}: ${importError instanceof Error ? importError.message : String(importError)}`);
        }
      } else {
        // JSON config file (backward compatibility)
        const configContent = await fs.readFile(configPath, 'utf-8');
        const config = JSON.parse(configContent);
        if (config.additionalPdfs && Array.isArray(config.additionalPdfs)) {
          const merged = [...new Set([...DEFAULT_ADDITIONAL_PDFS, ...config.additionalPdfs])];
          console.log(`Loaded ${config.additionalPdfs.length} additional PDFs from config file`);
          return merged;
        }
      }
    } else {
      // Try to import default TypeScript config
      try {
        // Use relative path from current file location (tsx handles TypeScript imports)
        const scriptDir = getScriptDir();
        const defaultConfigPath = path.join(scriptDir, 'download-wco-pdfs-config.ts');
        // For tsx, we can use file:// protocol or just the path
        const configModule = await import(defaultConfigPath);
        if (configModule.config && configModule.config.additionalPdfs && Array.isArray(configModule.config.additionalPdfs)) {
          const merged = [...new Set([...DEFAULT_ADDITIONAL_PDFS, ...configModule.config.additionalPdfs])];
          console.log(`Loaded ${configModule.config.additionalPdfs.length} additional PDFs from config file`);
          return merged;
        }
      } catch (importError) {
        // Config file doesn't exist or can't be imported - use defaults
        // This is expected if the file doesn't exist, so we don't warn
        // tsx should handle TypeScript imports, but if it fails, we fall back to defaults
      }
    }
  } catch (error) {
    // Config file doesn't exist or is invalid - use defaults
    if ((error as NodeJS.ErrnoException).code !== 'ENOENT') {
      console.warn(`Warning: Could not load config file: ${error instanceof Error ? error.message : String(error)}`);
    }
  }
  return DEFAULT_ADDITIONAL_PDFS;
}

interface Config {
  edition: string;
  outputDir: string;
  chapters: string;
  delay: number;
  delayVariation: number;
  retries: number;
  resume: boolean;
  dryRun: boolean;
  verbose: boolean;
  configFile?: string;
  checkExisting: boolean; // Check if files exist and skip if unchanged (uses HEAD request)
  skipExisting: boolean; // Skip files that already exist locally (no HEAD request, faster)
}

interface DownloadResult {
  success: boolean;
  status?: number;
  error?: string;
  size?: number;
}

interface FileStats {
  downloaded: Array<{ chapter: number; heading: string; filename: string }>;
  failed: Array<{ chapter: number; heading: string; filename: string; error: string }>;
  skipped: Array<{ chapter: number; heading: string; filename: string }>;
}

interface ResumePoint {
  chapter: number;
  heading: number;
}

// Parse command line arguments
function parseArgs(): Config {
  const args = process.argv.slice(2);
  const config: Config = {
    edition: DEFAULT_EDITION,
    outputDir: '',
    chapters: '1-97',
    delay: DEFAULT_DELAY_MS,
    delayVariation: DEFAULT_DELAY_VARIATION_MS,
    retries: DEFAULT_RETRIES,
    resume: false,
    dryRun: false,
    verbose: false,
    checkExisting: true, // Default: check for existing files and skip if unchanged
    skipExisting: false // Default: don't skip existing files (checkExisting handles this)
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
      case '--delay-variation':
        config.delayVariation = parseInt(args[++i] || String(DEFAULT_DELAY_VARIATION_MS), 10);
        break;
      case '--retries':
        config.retries = parseInt(args[++i] || '3', 10);
        break;
      case '--resume':
        config.resume = true;
        break;
      case '--dry-run':
        config.dryRun = true;
        break;
      case '--verbose':
      case '-v':
        config.verbose = true;
        break;
      case '--config':
        config.configFile = args[++i] || '';
        break;
      case '--check-existing':
        config.checkExisting = true;
        config.skipExisting = false; // checkExisting takes precedence
        break;
      case '--no-check-existing':
      case '--force':
        config.checkExisting = false;
        config.skipExisting = false;
        break;
      case '--skip-existing':
        config.skipExisting = true;
        config.checkExisting = false; // skipExisting takes precedence (faster, no HEAD request)
        break;
      case '--help':
      case '-h':
        console.log(`
WCO PDF Download Script

Usage: tsx scripts/download-wco-pdfs.ts [options]

Options:
  --edition <year>    WCO edition year (default: 2022)
  --output <dir>      Output directory (default: ./data/wco-pdfs/{edition})
  --chapters <range>  Chapter range, e.g., "1-97" or "1,2,3" (default: 1-97)
  --delay <ms>        Base delay between downloads in milliseconds (default: ${DEFAULT_DELAY_MS})
  --delay-variation <ms>  Random variation added to delay (default: ${DEFAULT_DELAY_VARIATION_MS})
                       Actual delay = base + random(0 to variation)
  --retries <n>       Number of retries for failed downloads (default: 3)
  --resume            Resume from last downloaded file
  --dry-run           Show what would be downloaded without downloading
  --check-existing    Check if files exist and skip if unchanged (default: enabled, uses HEAD request)
  --skip-existing     Skip files that already exist locally (faster, no HEAD request, doesn't check for updates)
  --no-check-existing  Download all files without checking if they exist (re-downloads everything)
  --force             Alias for --no-check-existing
  --verbose, -v       Show detailed request/response information for debugging
  --config <file>     Path to config file for additional PDFs (default: scripts/download-wco-pdfs-config.ts)
  --help, -h          Show this help message

Examples:
  tsx scripts/download-wco-pdfs.ts --edition 2022
  tsx scripts/download-wco-pdfs.ts --chapters 1-10 --delay ${DEFAULT_DELAY_MS}
  tsx scripts/download-wco-pdfs.ts --resume
        `);
        process.exit(0);
        break;
    }
  }

  // Set default output directory if not specified
  if (!config.outputDir) {
    config.outputDir = path.join(DEFAULT_OUTPUT_DIR, config.edition);
  }

  return config;
}

// Parse chapter range (e.g., "1-97" or "1,2,3")
function parseChapters(chapterStr: string): number[] {
  if (chapterStr.includes('-')) {
    const [start, end] = chapterStr.split('-').map(Number);
    return Array.from({ length: end - start + 1 }, (_, i) => start + i);
  } else if (chapterStr.includes(',')) {
    return chapterStr.split(',').map(Number);
  } else {
    return [Number(chapterStr)];
  }
}

// Generate heading codes for a chapter (e.g., 01, 02, ..., 99)
// Note: Most chapters have headings from 01 to around 50-60, but we'll try up to 99
// Returns just the 2-digit heading number (not chapter+heading)
function generateHeadings(chapter: number): string[] {
  const headings: string[] = [];
  
  // Try headings from 01 to 99
  for (let heading = 1; heading <= 99; heading++) {
    const headingStr = String(heading).padStart(2, '0');
    headings.push(headingStr);
  }
  
  return headings;
}

// Build URL for a specific chapter and heading
function buildUrl(edition: string, chapter: number, heading: string): string {
  return BASE_URL
    .replace(/{EDITION}/g, edition)
    .replace(/{CHAPTER}/g, String(chapter).padStart(2, '0'))
    .replace(/{HEADING}/g, heading);
}

// Build URL for additional PDFs (Introduction, Table of Contents, etc.)
function buildAdditionalUrl(edition: string, filename: string): string {
  return BASE_URL_ADDITIONAL
    .replace(/{EDITION}/g, edition)
    .replace(/{FILENAME}/g, filename);
}

// Download a file with redirect handling
function downloadFile(url: string, outputPath: string, refererUrl: string, retries: number = DEFAULT_RETRIES, maxRedirects: number = 5, verbose: boolean = false): Promise<DownloadResult> {
  return new Promise((resolve, reject) => {
    const protocol = url.startsWith('https:') ? https : http;
    
    const attemptDownload = (attempt: number = 1, currentUrl: string = url, redirectCount: number = 0, previousUrl?: string): void => {
      // Prevent infinite redirect loops
      if (redirectCount >= maxRedirects) {
        resolve({ success: false, status: 0, error: 'Too many redirects' });
        return;
      }
      
      // Use previous URL as referer if available (for redirects), otherwise use the main page referer
      const referer = previousUrl || refererUrl;
      const headers = getBrowserHeaders(referer);
      
      if (verbose) {
        console.log(`\n[DEBUG] Request #${attempt} (redirect: ${redirectCount}):`);
        console.log(`  URL: ${currentUrl}`);
        console.log(`  Referer: ${referer}`);
        console.log(`  Headers:`, JSON.stringify(headers, null, 2));
      }
      
      const file = createWriteStream(outputPath);
      
      const options = {
        headers: headers
      };
      
      protocol.get(currentUrl, options, (response) => {
        // Extract cookies from response
        extractCookies(response);
        
        if (verbose) {
          console.log(`\n[DEBUG] Response:`);
          console.log(`  Status: ${response.statusCode} ${response.statusMessage}`);
          console.log(`  Headers:`, JSON.stringify(response.headers, null, 2));
          if (cookieJar) {
            console.log(`  [DEBUG] Current cookies: ${cookieJar}`);
          }
        }
        
        // Handle redirects (301, 302, 303, 307, 308)
        if (response.statusCode === 301 || response.statusCode === 302 || response.statusCode === 303 || 
            response.statusCode === 307 || response.statusCode === 308) {
          // Consume response body to prevent hanging
          response.resume();
          
          const location = response.headers.location;
          if (!location) {
            file.close();
            if (existsSync(outputPath)) {
              unlinkSync(outputPath);
            }
            resolve({ success: false, status: response.statusCode || 302, error: `HTTP ${response.statusCode || 302} - No redirect location` });
            return;
          }
          
          // Check if redirect is to an error page - treat as 404 and delete empty file
          if (location.includes('/error') || location.includes('404')) {
            file.close();
            // Delete empty file created by this failed request
            if (existsSync(outputPath)) {
              try {
                const stats = statSync(outputPath);
                // Only delete if file is empty or very small (likely from this failed request)
                if (stats.size === 0 || stats.size < 100) {
                  unlinkSync(outputPath);
                }
              } catch {
                // Ignore stat errors
              }
            }
            if (verbose) {
              console.log(`  [DEBUG] Redirect to error page detected, treating as 404`);
            }
            resolve({ success: false, status: 404, error: 'Not Found (redirected to error page)' });
            return;
          }
          
          // Handle relative and absolute URLs
          let redirectUrl: string;
          if (location.startsWith('http://') || location.startsWith('https://')) {
            redirectUrl = location;
          } else if (location.startsWith('//')) {
            redirectUrl = `${currentUrl.split('://')[0]}://${location.substring(2)}`;
          } else if (location.startsWith('/')) {
            const urlObj = new URL(currentUrl);
            redirectUrl = `${urlObj.protocol}//${urlObj.host}${location}`;
          } else {
            const urlObj = new URL(currentUrl);
            const basePath = urlObj.pathname.substring(0, urlObj.pathname.lastIndexOf('/'));
            redirectUrl = `${urlObj.protocol}//${urlObj.host}${basePath}/${location}`;
          }
          
          if (verbose) {
            console.log(`  [DEBUG] Redirect detected: ${response.statusCode}`);
            console.log(`  [DEBUG] Location header: ${location}`);
            console.log(`  [DEBUG] Following redirect to: ${redirectUrl}`);
          }
          
          // Close file before following redirect (but don't delete - might be valid redirect)
          file.close();
          
          // Follow redirect
          attemptDownload(attempt, redirectUrl, redirectCount + 1, currentUrl);
          return;
        }
        
        if (response.statusCode === 404) {
          file.close();
          // Delete empty file created by this failed request
          if (existsSync(outputPath)) {
            try {
              const stats = statSync(outputPath);
              // Only delete if file is empty or very small (likely from this failed request)
              if (stats.size === 0 || stats.size < 100) {
                unlinkSync(outputPath);
              }
            } catch {
              // Ignore stat errors
            }
          }
          resolve({ success: false, status: 404, error: 'Not Found' });
          return;
        }
        
        if (response.statusCode !== 200) {
          file.close();
          // Only delete file if it's a server error and we're not retrying
          if (response.statusCode && response.statusCode >= 500 && attempt >= retries) {
            if (existsSync(outputPath)) {
              try {
                const stats = statSync(outputPath);
                // Only delete if file is empty or very small (likely incomplete)
                if (stats.size === 0 || stats.size < 100) {
                  unlinkSync(outputPath);
                }
              } catch {
                // Ignore stat errors
              }
            }
          }
          if (verbose) {
            console.log(`  [DEBUG] Non-200 status code: ${response.statusCode}`);
          }
          if (attempt < retries) {
            console.log(`  Retrying... (${attempt}/${retries})`);
            setTimeout(() => attemptDownload(attempt + 1, currentUrl, redirectCount, previousUrl), 1000 * attempt);
            return;
          }
          resolve({ success: false, status: response.statusCode, error: `HTTP ${response.statusCode}` });
          return;
        }
        
        response.pipe(file);
        
        file.on('finish', () => {
          file.close();
          const size = statSync(outputPath).size;
          resolve({ success: true, size });
        });
      }).on('error', (error: Error) => {
        file.close();
        // Only delete file on error if we're not retrying and file is likely incomplete
        if (attempt >= retries && existsSync(outputPath)) {
          try {
            const stats = statSync(outputPath);
            // Only delete if file is empty or very small (likely incomplete)
            if (stats.size === 0 || stats.size < 100) {
              unlinkSync(outputPath);
            }
          } catch {
            // Ignore stat errors
          }
        }
        if (verbose) {
          console.log(`  [DEBUG] Request error:`, error.message);
          console.log(`  [DEBUG] Error stack:`, error.stack);
        }
        if (attempt < retries) {
          console.log(`  Retrying... (${attempt}/${retries})`);
          setTimeout(() => attemptDownload(attempt + 1, currentUrl, redirectCount, previousUrl), 1000 * attempt);
          return;
        }
        reject(error);
      });
    };
    
    attemptDownload();
  });
}

// Sleep/delay function
function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// Check if file exists
async function fileExists(filePath: string): Promise<boolean> {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

// Get local file size
async function getLocalFileSize(filePath: string): Promise<number | null> {
  try {
    const stats = await fs.stat(filePath);
    return stats.size;
  } catch {
    return null;
  }
}

// Check if remote file has changed by comparing file size (with redirect handling)
async function checkFileChanged(url: string, localPath: string, maxRedirects: number = 5): Promise<boolean> {
  return new Promise((resolve) => {
    const protocol = url.startsWith('https:') ? https : http;
    
    const checkFile = (currentUrl: string, redirectCount: number = 0): void => {
      // Prevent infinite redirect loops
      if (redirectCount >= maxRedirects) {
        resolve(true); // Too many redirects, assume changed to force download
        return;
      }
      
      // Make HEAD request to get file size
      const baseReferer = 'https://www.wcoomd.org/en/topics/nomenclature/instrument-and-tools/hs-nomenclature-2022-edition/hs-nomenclature-2022-edition.aspx';
      const options = {
        method: 'HEAD',
        headers: getBrowserHeaders(baseReferer)
      };
      
      const req = protocol.request(currentUrl, options, async (response) => {
        // Handle redirects (301, 302, 303, 307, 308)
        if (response.statusCode === 301 || response.statusCode === 302 || response.statusCode === 303 || 
            response.statusCode === 307 || response.statusCode === 308) {
          const location = response.headers.location;
          if (!location) {
            resolve(true); // No redirect location, assume changed
            return;
          }
          
          // Handle relative and absolute URLs
          let redirectUrl: string;
          if (location.startsWith('http://') || location.startsWith('https://')) {
            redirectUrl = location;
          } else if (location.startsWith('//')) {
            redirectUrl = `${currentUrl.split('://')[0]}://${location.substring(2)}`;
          } else if (location.startsWith('/')) {
            const urlObj = new URL(currentUrl);
            redirectUrl = `${urlObj.protocol}//${urlObj.host}${location}`;
          } else {
            const urlObj = new URL(currentUrl);
            const basePath = urlObj.pathname.substring(0, urlObj.pathname.lastIndexOf('/'));
            redirectUrl = `${urlObj.protocol}//${urlObj.host}${basePath}/${location}`;
          }
          
          // Follow redirect
          checkFile(redirectUrl, redirectCount + 1);
          return;
        }
        
        if (response.statusCode === 404) {
          resolve(true); // File doesn't exist on server, consider it "changed" to skip
          return;
        }
        
        if (response.statusCode !== 200) {
          resolve(true); // Error, assume changed to force download
          return;
        }
        
        const remoteSize = parseInt(response.headers['content-length'] || '0', 10);
        const localSize = await getLocalFileSize(localPath);
        
        // If sizes don't match, file has changed
        if (localSize === null || localSize !== remoteSize) {
          resolve(true); // File has changed or doesn't exist locally
        } else {
          resolve(false); // File exists and size matches, no change
        }
      });
      
      req.on('error', () => {
        resolve(true); // On error, assume changed to force download
      });
      
      req.setTimeout(10000, () => {
        req.destroy();
        resolve(true); // On timeout, assume changed to force download
      });
      
      req.end();
    };
    
    checkFile(url);
  });
}

// Main download function
async function main(): Promise<void> {
  const config = parseArgs();
  
  console.log('WCO PDF Download Script');
  console.log('========================');
  console.log(`Edition: ${config.edition}`);
  console.log(`Output: ${config.outputDir}`);
  console.log(`Chapters: ${config.chapters}`);
  console.log(`Delay: ${config.delay}ms (with ±${config.delayVariation}ms random variation)`);
  console.log(`Retries: ${config.retries}`);
  console.log(`Resume: ${config.resume}`);
  if (config.skipExisting) {
    console.log(`Skip Existing: enabled (fast mode, no HEAD requests)`);
  } else {
    console.log(`Check Existing: ${config.checkExisting ? 'enabled' : 'disabled'}`);
  }
  console.log(`Dry Run: ${config.dryRun}`);
  console.log('');

  // Create output directory
  if (!config.dryRun) {
    await fs.mkdir(config.outputDir, { recursive: true });
  }

  // Establish browser session (visit main page first, like a regular browser)
  let refererUrl = `https://www.wcoomd.org/en/topics/nomenclature/instrument-and-tools/hs-nomenclature-${config.edition}-edition/hs-nomenclature-${config.edition}-edition.aspx`;
  if (!config.dryRun) {
    refererUrl = await establishSession(config.edition, config.verbose);
    if (config.verbose) {
      console.log(`[DEBUG] Using referer: ${refererUrl}`);
    }
  }

  // Initialize statistics
  let totalAttempted = 0;
  let totalDownloaded = 0;
  let totalFailed = 0;
  let totalSkipped = 0;
  const stats: FileStats = {
    downloaded: [],
    failed: [],
    skipped: []
  };

  // Load additional PDFs from config file or use defaults
  // Use path relative to project root (scripts directory)
  const additionalPdfs = await loadAdditionalPdfs(config.configFile);

  // Download additional important PDFs first (Introduction, Table of Contents, General Rules, etc.)
  // These are critical for LLM classification context
  console.log(`Downloading ${additionalPdfs.length} additional PDFs (Introduction, Table of Contents, General Rules, etc.)...\n`);
  for (const pdfTemplate of additionalPdfs) {
    const filename = pdfTemplate.replace(/{EDITION}/g, config.edition);
    const url = buildAdditionalUrl(config.edition, filename);
    const outputPath = path.join(config.outputDir, filename);

    totalAttempted++;

    // Skip if file exists (simple check, no HEAD request)
    if (config.skipExisting && !config.dryRun && await fileExists(outputPath)) {
      totalSkipped++;
      continue;
    }

    // Check if file already exists and hasn't changed (if enabled, uses HEAD request)
    if (config.checkExisting && !config.dryRun && await fileExists(outputPath)) {
      // Small random delay before HEAD request
      if (config.delay > 0) {
        const headDelay = getRandomDelay(config.delay / 2, config.delayVariation / 2);
        await sleep(headDelay);
      }
      const hasChanged = await checkFileChanged(url, outputPath);
      if (!hasChanged) {
        totalSkipped++;
        continue;
      }
    }

    if (config.dryRun) {
      console.log(`  [DRY RUN] Would download: ${filename}`);
      totalDownloaded++;
    } else {
      try {
        const result = await downloadFile(url, outputPath, refererUrl, config.retries, 5, config.verbose);
        
        if (result.success) {
          const sizeKB = result.size ? (result.size / 1024).toFixed(2) : '0';
          console.log(`  ✓ ${filename} (${sizeKB} KB)`);
          totalDownloaded++;
          stats.downloaded.push({ chapter: 0, heading: 'additional', filename });
        } else if (result.status === 404) {
          // 404 is a bug - file should exist, stop and fix
          console.error(`\n❌ ERROR: File not found (404): ${filename}`);
          console.error(`   URL: ${url}`);
          console.error(`\nThis is a bug - the file should exist. Please check:`);
          console.error(`   1. Is the filename correct?`);
          console.error(`   2. Is the URL pattern correct?`);
          console.error(`   3. Does the file exist on the WCO server?`);
          console.error(`\nStopping download to fix the bug.\n`);
          process.exit(1);
        } else {
          console.log(`  ✗ ${filename} - ${result.error || 'Unknown error'}`);
          totalFailed++;
          stats.failed.push({ chapter: 0, heading: 'additional', filename, error: result.error || 'Unknown error' });
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        console.log(`  ✗ ${filename} - ${errorMessage}`);
        totalFailed++;
        stats.failed.push({ chapter: 0, heading: 'additional', filename, error: errorMessage });
      }

      // Random delay between downloads
      if (config.delay > 0) {
        const randomDelay = getRandomDelay(config.delay, config.delayVariation);
        await sleep(randomDelay);
      }
    }
  }
  console.log('');

  // Parse chapters
  const chapters = parseChapters(config.chapters);
  console.log(`Processing ${chapters.length} chapters...\n`);

  // Find last downloaded file if resuming
  let resumeFrom: ResumePoint | null = null;
  if (config.resume && !config.dryRun) {
    const files = await fs.readdir(config.outputDir).catch(() => []);
    if (files.length > 0) {
      const pdfFiles = files.filter(f => f.endsWith('.pdf')).sort();
      if (pdfFiles.length > 0) {
        const lastFile = pdfFiles[pdfFiles.length - 1];
        const match = lastFile.match(/^(\d{2})(\d{2})_(\d{4})e\.pdf$/);
        if (match) {
          resumeFrom = {
            chapter: parseInt(match[1]!, 10),
            heading: parseInt(match[2]!, 10)
          };
          console.log(`Resuming from Chapter ${resumeFrom.chapter}, Heading ${String(resumeFrom.heading).padStart(2, '0')}\n`);
        }
      }
    }
  }

  // Process each chapter
  for (const chapter of chapters) {
    // Skip if resuming and we haven't reached the resume point
    if (resumeFrom && chapter < resumeFrom.chapter) {
      continue;
    }

    console.log(`Chapter ${chapter}...`);
    const headings = generateHeadings(chapter);
    let chapterDownloaded = 0;
    let chapterFailed = 0;
    let chapterSkipped = 0;

    for (const heading of headings) {
      // Skip if resuming and we haven't reached the resume point
      if (resumeFrom && chapter === resumeFrom.chapter) {
        const headingNum = parseInt(heading, 10);
        if (headingNum <= resumeFrom.heading) {
          continue;
        }
      }

      const url = buildUrl(config.edition, chapter, heading);
      const filename = `${String(chapter).padStart(2, '0')}${heading}_${config.edition}e.pdf`;
      const outputPath = path.join(config.outputDir, filename);

      totalAttempted++;

      // Skip if file exists (simple check, no HEAD request)
      if (config.skipExisting && !config.dryRun && await fileExists(outputPath)) {
        totalSkipped++;
        chapterSkipped++;
        continue;
      }

      // Check if file already exists and hasn't changed (if enabled, uses HEAD request)
      if (config.checkExisting && !config.dryRun && await fileExists(outputPath)) {
        // Small random delay before HEAD request (to avoid being blocked)
        if (config.delay > 0) {
          const headDelay = getRandomDelay(config.delay / 2, config.delayVariation / 2);
          await sleep(headDelay);
        }
        const hasChanged = await checkFileChanged(url, outputPath);
        if (!hasChanged) {
          // File exists and hasn't changed, skip download
          totalSkipped++;
          chapterSkipped++;
          continue;
        }
        // File exists but has changed, will re-download
      }

      if (config.dryRun) {
        console.log(`  [DRY RUN] Would download: ${filename}`);
        totalDownloaded++;
        chapterDownloaded++;
      } else {
        try {
          const result = await downloadFile(url, outputPath, refererUrl, config.retries, 5, config.verbose);
          
          if (result.success) {
            const sizeKB = result.size ? (result.size / 1024).toFixed(2) : '0';
            console.log(`  ✓ ${filename} (${sizeKB} KB)`);
            totalDownloaded++;
            chapterDownloaded++;
            stats.downloaded.push({ chapter, heading, filename });
          } else if (result.status === 404) {
            // 404 is a bug - file should exist, stop and fix
            console.error(`\n❌ ERROR: File not found (404): ${filename}`);
            console.error(`   URL: ${url}`);
            console.error(`   Chapter: ${chapter}, Heading: ${heading}`);
            console.error(`\nThis is a bug - the file should exist. Please check:`);
            console.error(`   1. Is the filename pattern correct?`);
            console.error(`   2. Is the URL pattern correct?`);
            console.error(`   3. Does the file exist on the WCO server?`);
            console.error(`\nStopping download to fix the bug.\n`);
            process.exit(1);
          } else {
            console.log(`  ✗ ${filename} - ${result.error || 'Unknown error'}`);
            totalFailed++;
            chapterFailed++;
            stats.failed.push({ chapter, heading, filename, error: result.error || 'Unknown error' });
          }
        } catch (error) {
          const errorMessage = error instanceof Error ? error.message : String(error);
          console.log(`  ✗ ${filename} - ${errorMessage}`);
          totalFailed++;
          chapterFailed++;
          stats.failed.push({ chapter, heading, filename, error: errorMessage });
        }

        // Random delay between downloads (to avoid being blocked)
        if (config.delay > 0) {
          const randomDelay = getRandomDelay(config.delay, config.delayVariation);
          await sleep(randomDelay);
        }
      }
    }

    console.log(`  Chapter ${chapter}: ${chapterDownloaded} downloaded, ${chapterFailed} failed, ${chapterSkipped} skipped\n`);
  }

  // Print summary
  console.log('========================');
  console.log('Download Summary');
  console.log('========================');
  console.log(`Total attempted: ${totalAttempted}`);
  console.log(`Downloaded: ${totalDownloaded}`);
  console.log(`Failed: ${totalFailed}`);
  console.log(`Skipped: ${totalSkipped} (already exists and unchanged, or 404)`);
  console.log('');

  if (stats.failed.length > 0) {
    console.log('Failed downloads:');
    stats.failed.forEach(({ filename, error }) => {
      console.log(`  - ${filename}: ${error}`);
    });
    console.log('');
  }

  if (!config.dryRun) {
    console.log(`PDFs saved to: ${config.outputDir}`);
  }
}

// Run the script
main().catch(error => {
  console.error('Error:', error);
  process.exit(1);
});

