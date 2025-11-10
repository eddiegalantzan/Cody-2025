/**
 * Configuration file for additional WCO PDFs to download.
 * 
 * Add new PDF filenames here to ensure they are downloaded automatically.
 * Use the {EDITION} placeholder which will be replaced with the edition year (e.g., 2022).
 * 
 * If a PDF returns 404, the script will stop and report it as a bug (files should exist).
 * To add new PDFs in the future, simply add them to the additionalPdfs array below.
 * The script will automatically merge these with the default list.
 */

export interface WCOPdfsConfig {
  description: string;
  additionalPdfs: string[];
  notes: string[];
}

export const config: WCOPdfsConfig = {
  description: "Configuration file for additional WCO PDFs to download. Add new PDF filenames here to ensure they are downloaded automatically.",
  additionalPdfs: [
    "introduction_{EDITION}e.pdf",
    "table-of-contents_{EDITION}e_rev.pdf" // Note: actual filename has _rev suffix (discovered via browser)
    // TODO: Add other PDFs once we verify they exist on the WCO server
    // The following files return 404 and need to be fixed:
    // "table-of-contents_{EDITION}e.pdf", // Wrong - should be _rev.pdf
    // "general-rules_{EDITION}e.pdf",
    // "general-rules-for-interpretation_{EDITION}e.pdf",
    // "explanatory-notes_{EDITION}e.pdf",
    // "classification-rules_{EDITION}e.pdf",
    // "section-notes_{EDITION}e.pdf",
    // "chapter-notes_{EDITION}e.pdf",
    // "alphabetical-index_{EDITION}e.pdf",
    // "compendium_{EDITION}e.pdf",
    // "compendium-of-classification-opinions_{EDITION}e.pdf"
  ],
  notes: [
    "Use {EDITION} placeholder which will be replaced with the edition year (e.g., 2022)",
    "If a PDF returns 404, it will be skipped (not all PDFs may exist for all editions)",
    "To add new PDFs in the future, simply add them to the additionalPdfs array above",
    "The script will automatically merge these with the default list"
  ]
};

