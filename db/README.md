# Database Schema

This directory contains the database schema definition for Cody-2025.

## Files

- **`init.sql`** - Master file that sources all domain-specific schema files
  - Uses `\i` to include domain files in order
  - Can be run directly: `psql "$DATABASE_URL" < db/init.sql`

**Domain-Specific Schema Files:**
- **`01_schema_versioning.sql`** - Schema versioning table
- **`02_customs_data.sql`** - WCO tables, customs_books, countries (Customs Data)
- **`03_user_data.sql`** - Users, organizations, and related tables (User Data)
- **`04_transaction_data.sql`** - Classifications, payments, transactions (Transaction Data)
- **`05_service_access.sql`** - API keys, webhooks, job queue
- **`06_audit_logging.sql`** - Audit and error logs
- **`07_functions_triggers.sql`** - Functions and triggers
- **`08_initial_data.sql`** - Initial data inserts

## Schema Overview

### User Management
- `users` - Users linked to Clerk user IDs
- `user_profiles` - User profiles and preferences

### B2B/Organization Management
- `organizations` - Organizations linked to Clerk organization IDs
- `organization_members` - Users in organizations with roles
- `organization_groups` - Groups/teams within organizations
- `organization_group_members` - Group membership

### HS Code Classifier
- `countries` - Country reference data
- `wco_editions` - WCO HS Nomenclature editions (2022, 2017, etc.)
- `wco_sections` - WCO Sections (I-XXI)
- `wco_chapters` - WCO Chapters (1-97)
- `wco_headings` - WCO Headings (4-digit codes, e.g., 01.01, 01.02)
- `wco_hs_codes` - WCO 6-digit HS codes (international standard)
- `customs_books` - Country-specific customs books (Israel: 3 books) with sync tracking fields
- `customs_book_hs_codes` - HS codes in customs books (extends WCO codes to 8-10 digits) with classification rules JSONB field
- `classifications` - Classification requests and results with LLM usage tracking fields
- `interactive_sessions` - Interactive Q&A sessions
- `questions` - Questions asked during interactive classification
- `company_item_lists` - Uploaded company item code lists
- `company_item_mappings` - Item code to HS code mappings
- `transactions` - Transaction pricing (X, X/D, M×X)

### Payments (Payoneer Integration)
- `payment_accounts` - Payoneer payment accounts
- `payment_transactions` - Payment transactions (incoming/outgoing)
- `invoices` - B2B invoices with payment terms
- `invoice_line_items` - Invoice line items
- `scheduled_payments` - Custom recurring payment schedules

### Service Access
- `api_keys` - API keys and authentication tokens
- `webhook_configurations` - Client webhook URLs
- `job_queue` - Async job processing queue

### Audit & Logging
- `audit_logs` - User actions and classification history
- `error_logs` - Application error logging

### Versioning
- `schema_versions` - Database schema version tracking

## Applying the Schema

### Option 1: Using Master File (Recommended)

```bash
# Load secrets
source .secrets

# Apply complete schema using master file
psql "$DATABASE_URL_REMOTE" < db/init.sql
```

**Note:** The master file uses `\i` to include domain files. When running from the project root (as shown above), the paths work correctly. If running from a different directory, adjust the paths in `init.sql` or use Option 2.

### Option 2: Run Domain Files Individually

```bash
# Load secrets
source .secrets

# Run files in order
cd db
psql "$DATABASE_URL_REMOTE" -f 01_schema_versioning.sql
psql "$DATABASE_URL_REMOTE" -f 02_customs_data.sql
psql "$DATABASE_URL_REMOTE" -f 03_user_data.sql
psql "$DATABASE_URL_REMOTE" -f 04_transaction_data.sql
psql "$DATABASE_URL_REMOTE" -f 05_service_access.sql
psql "$DATABASE_URL_REMOTE" -f 06_audit_logging.sql
psql "$DATABASE_URL_REMOTE" -f 07_functions_triggers.sql
psql "$DATABASE_URL_REMOTE" -f 08_initial_data.sql
```

### Option 3: From Server (Local Connection)

```bash
# SSH into server
ssh root@165.22.65.197

# Apply schema using master file
psql -U app_user -d cody2025 -h localhost < /path/to/db/init.sql
```

## Features

- **Auto-Increment Primary Keys** - All tables use SERIAL for IDs
- **Naming Convention** - All fields follow `table_name_field_name` pattern (singular)
- **Timestamps** - `created_at`, `updated_at` with automatic updates
- **Soft Deletes** - `deleted_at` columns for soft deletion
- **Indexes** - Optimized indexes for common queries
- **Full-Text Search** - GIN indexes on text fields for search
- **Triggers** - Automatic `updated_at` updates
- **Multi-Tenancy** - Organization-level data isolation
- **International Support** - Currency codes, timezones, country codes
- **Schema Versioning** - Track migrations with backup-based rollback strategy

## Initial Data

The schema includes initial country data (Israel, US, EU countries, etc.) for immediate use.

## Versioning

The database includes schema version tracking:

### Schema Versioning (`schema_versions` table)
- Tracks database schema versions
- Stores version information and descriptions
- Current version marked with `is_current = true`
- Version history and audit trail

**Important:** Migrations are **NOT needed** until we have production running. During planning and initial development, all schema changes go directly into the appropriate domain file (e.g., `02_customs_data.sql` for customs-related changes, `03_user_data.sql` for user-related changes, etc.). Migration procedures will only be needed after the database is deployed to production and we need to modify the schema without losing data.

## Next Steps

After applying the schema:
1. Verify tables were created: `\dt` in psql
2. Check indexes: `\di` in psql
3. Verify versioning: `SELECT * FROM schema_versions;`
4. Test organization creation
5. Test classification workflow

## Related Documentation

- [5.0_PLAN.md](../documents/5.0_PLAN.md) - Phase 2: Database Schema
- [7.0_SECRETS_MANAGEMENT.md](../documents/7.0_SECRETS_MANAGEMENT.md) - Database connection secrets
- [6.0_STEP_1_TERRAFORM_POSTGRES.md](../documents/6.0_STEP_1_TERRAFORM_POSTGRES.md) - Infrastructure setup

