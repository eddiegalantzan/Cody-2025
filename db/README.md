# Database Schema

This directory contains the database schema definition for Cody-2025.

## Files

- **`init.sql`** - Complete database schema (single source of truth)
  - All tables, indexes, triggers, and initial data
  - ~940+ lines defining the initial database structure
- **`MIGRATION_GUIDE.md`** - Safe migration process documentation
  - Step-by-step migration procedures
  - Safety best practices
  - Rollback procedures

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
- `customs_books` - Country-specific customs books (Israel: 3 books)
- `customs_book_hs_codes` - HS codes in customs books (extends WCO codes to 8-10 digits)
- `classifications` - Classification requests and results
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

### Versioning & Rollback
- `schema_versions` - Database schema version tracking (for schema rollback)
- Migration strategy: Database backup-based rollback (see [MIGRATION_GUIDE.md](./MIGRATION_GUIDE.md))

## Applying the Schema

### Option 1: From Local Machine (Remote Connection)

```bash
# Get database connection details
cd infra/terraform
terraform output database_url

# Apply schema
psql "$(terraform output -raw database_url)" < db/init.sql
```

### Option 2: From Server (Local Connection)

```bash
# SSH into server
ssh root@165.22.65.197

# Connect to database
psql -U app_user -d cody2025 -h localhost

# Or apply schema file
psql -U app_user -d cody2025 -h localhost < /path/to/init.sql
```

### Option 3: Using Database URL from Secrets

```bash
# Load secrets
source .secrets

# Apply schema
psql "$DATABASE_URL_REMOTE" < db/init.sql
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

## Versioning & Rollback

The database uses a backup-based migration strategy:

### Schema Versioning (`schema_versions` table)
- Tracks all database schema migrations
- Stores `up_sql` (SQL to apply migration) for each version
- Current version marked with `is_current = true`
- Migration history and audit trail

### Migration Strategy
- **Before migration:** Create database backup
- **If migration fails:** Restore from backup
- **If migration succeeds:** Verify and delete backup after safety period

**📖 For detailed migration procedures, see [MIGRATION_GUIDE.md](./MIGRATION_GUIDE.md)**

## Next Steps

After applying the schema:
1. Verify tables were created: `\dt` in psql
2. Check indexes: `\di` in psql
3. Verify versioning: `SELECT * FROM schema_versions;`
4. Test organization creation
5. Test classification workflow
6. Review [MIGRATION_GUIDE.md](./MIGRATION_GUIDE.md) before making schema changes

## Related Documentation

- [MIGRATION_GUIDE.md](./MIGRATION_GUIDE.md) - **Safe migration procedures and best practices**
- [5.0_PLAN.md](../documents/5.0_PLAN.md) - Phase 2: Database Schema
- [7.0_SECRETS_MANAGEMENT.md](../documents/7.0_SECRETS_MANAGEMENT.md) - Database connection secrets
- [6.0_STEP_1_TERRAFORM_POSTGRES.md](../documents/6.0_STEP_1_TERRAFORM_POSTGRES.md) - Infrastructure setup

