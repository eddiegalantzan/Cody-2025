-- ============================================
-- Cody-2025 Database Schema
-- Master file that sources all domain-specific schema files
-- ============================================
-- 
-- This file defines the complete database schema for:
-- - User Management (Clerk integration)
-- - B2B/Organization Management
-- - HS Code Classifier
-- - Payments (Payoneer integration)
-- - Service Access (API keys, webhooks, job queue)
-- - Audit & Logging
--
-- Environment: Staging (cody2025staging)
-- Database: cody2025
-- Naming Convention: table_name_field_name
-- Primary Keys: SERIAL/BIGSERIAL (auto-increment)
-- ============================================

-- Enable timezone support
SET timezone = 'UTC';

-- ============================================
-- Schema files are split by domain:
-- ============================================
-- 01_schema_versioning.sql - Schema versioning table
-- 02_customs_data.sql - WCO tables, customs_books, countries
-- 03_user_data.sql - Users, organizations, and related tables
-- 04_transaction_data.sql - Classifications, payments, transactions
-- 05_service_access.sql - API keys, webhooks, job queue
-- 06_audit_logging.sql - Audit and error logs
-- 07_functions_triggers.sql - Functions and triggers
-- 08_initial_data.sql - Initial data inserts
-- ============================================
--
-- To apply schema:
-- Option 1: Use this master file (includes all domain files)
--   Run from project root:
--   psql "$DATABASE_URL" < db/init.sql
--
-- Option 2: Run domain files individually in order:
--   psql "$DATABASE_URL" -f db/01_schema_versioning.sql
--   psql "$DATABASE_URL" -f db/02_customs_data.sql
--   psql "$DATABASE_URL" -f db/03_user_data.sql
--   psql "$DATABASE_URL" -f db/04_transaction_data.sql
--   psql "$DATABASE_URL" -f db/05_service_access.sql
--   psql "$DATABASE_URL" -f db/06_audit_logging.sql
--   psql "$DATABASE_URL" -f db/07_functions_triggers.sql
--   psql "$DATABASE_URL" -f db/08_initial_data.sql
-- ============================================

\i db/01_schema_versioning.sql
\i db/02_customs_data.sql
\i db/03_user_data.sql
\i db/04_transaction_data.sql
\i db/05_service_access.sql
\i db/06_audit_logging.sql
\i db/07_functions_triggers.sql
\i db/08_initial_data.sql
