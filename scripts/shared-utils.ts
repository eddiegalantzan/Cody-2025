#!/usr/bin/env tsx
/// <reference types="node" />
'use strict';

/**
 * Shared utility functions for WCO download scripts
 * 
 * These functions are used by both download-wco-pdfs.ts and download-wco-pdfs-browser.ts
 * to avoid code duplication (DRY principle).
 */

/**
 * Sleep/delay function
 */
export const sleep = (ms: number): Promise<void> => {
  return new Promise(resolve => setTimeout(resolve, ms));
};

/**
 * Process and normalize URLs
 * Handles URL decoding, query parameter removal, and absolute URL conversion
 */
export const processUrl = (href: string, baseUrl: string): string | null => {
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
      decodedHref = decodedHref.split('?')[0]!;
    }
    
    // Convert relative URLs to absolute
    return decodedHref.startsWith('http') 
      ? decodedHref 
      : new URL(decodedHref, baseUrl).href;
  } catch (e) {
    // If processing fails, try simpler approach
    try {
      let cleanHref = href;
      // Remove query parameters
      if (cleanHref.includes('?')) {
        cleanHref = cleanHref.split('?')[0]!;
      }
      return cleanHref.startsWith('http') ? cleanHref : new URL(cleanHref, baseUrl).href;
    } catch (e2) {
      // Skip invalid URLs
      return null;
    }
  }
};

/**
 * Convert relative URL to absolute (simpler version)
 */
export const toAbsoluteUrl = (href: string, baseUrl: string): string | null => {
  try {
    return href.startsWith('http') ? href : new URL(href, baseUrl).href;
  } catch (e) {
    return null;
  }
};

/**
 * Get browser-like headers for HTTP requests
 * Used to avoid detection as a bot
 * 
 * @param referer - Optional referer URL
 * @param cookies - Optional cookie string to include
 * @param userAgent - Optional custom user agent (defaults to Chrome on macOS)
 */
export const getBrowserHeaders = (referer?: string, cookies?: string, userAgent?: string): Record<string, string> => {
  const headers: Record<string, string> = {
    'User-Agent': userAgent || 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept-Encoding': 'gzip, deflate, br',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': referer ? 'same-origin' : 'none',
    'Cache-Control': 'max-age=0',
  };
  
  if (referer) {
    headers['Referer'] = referer;
  }
  
  if (cookies) {
    headers['Cookie'] = cookies;
  }
  
  return headers;
};

/**
 * Get random delay with variation
 * Used to make requests appear more human-like
 * 
 * @param baseDelay - Base delay in milliseconds
 * @param variation - Maximum variation to add/subtract (default: 5000ms)
 * @param allowNegative - Whether to allow negative variation (default: true)
 */
export const getRandomDelay = (baseDelay: number, variation: number = 5000, allowNegative: boolean = true): number => {
  const randomVariation = Math.floor(Math.random() * variation);
  if (allowNegative) {
    const isPositive = Math.random() > 0.5;
    return baseDelay + (isPositive ? randomVariation : -randomVariation);
  }
  return baseDelay + randomVariation;
};

