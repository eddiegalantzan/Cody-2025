# Database Migration Guide

Safe migration process for Cody-2025 database schema changes.

## ⚠️ Important Note

**Migrations are NOT needed until production is running.** During planning and development, all schema changes go directly into `init.sql`. This guide is for future use when the system is deployed to production.

## Overview

**Migration Strategy:** Database backup-based rollback
- Before migration: Create database backup
- If migration fails: Restore from backup
- If migration succeeds: Verify and delete backup

## Prerequisites

- PostgreSQL client tools (`psql`, `pg_dump`, `pg_restore`)
- Database connection credentials
- Access to stop/start application (if needed)

## Migration Process

### Step 1: Prepare Migration

1. **Create migration record in `schema_versions` table:**
   ```sql
   INSERT INTO schema_versions (
       schema_version_version,
       schema_version_description,
       schema_version_up_sql,
       schema_version_is_current,
       schema_version_applied_at,
       schema_version_applied_by
   ) VALUES (
       '1.1.0',
       'Add phone_number to users, remove old_address from organizations',
       'ALTER TABLE users ADD COLUMN user_phone_number VARCHAR(50);
        ALTER TABLE organizations DROP COLUMN organization_old_address;',
       false,
       NULL,
       'developer'
   );
   ```

2. **Review the migration SQL carefully:**
   - Check for typos
   - Verify table/column names match your naming convention
   - Ensure no data loss (e.g., dropping columns with data)

### Step 2: Create Backup (CRITICAL)

```bash
# Create backup with timestamp
BACKUP_FILE="backup_before_$(date +%Y%m%d_%H%M%S)_1.1.0.sql"
pg_dump -h localhost -U app_user -d cody2025 > "$BACKUP_FILE"

# Verify backup integrity (IMPORTANT!)
pg_restore --list "$BACKUP_FILE" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: Backup file is corrupted or invalid!"
    exit 1
fi

echo "Backup created: $BACKUP_FILE"
```

**Safety Check:**
- Verify backup file size is reasonable (not 0 bytes)
- Test restore on a test database if possible
- Keep backup in safe location

### Step 3: Stop Application (Recommended)

Prevent concurrent access during migration:

```bash
# Stop application to prevent conflicts
systemctl stop cody2025

# Or if using PM2
pm2 stop cody2025
```

**Why:** Prevents application errors and data corruption during schema changes.

### Step 4: Apply Migration

**Option A: Single Transaction (Safer - if DDL allows)**

```bash
psql -h localhost -U app_user -d cody2025 << EOF
BEGIN;
-- Your migration SQL here
ALTER TABLE users ADD COLUMN user_phone_number VARCHAR(50);
ALTER TABLE organizations DROP COLUMN organization_old_address;
COMMIT;
EOF

# Check exit code
if [ $? -ne 0 ]; then
    echo "ERROR: Migration failed!"
    # Proceed to Step 5a (Restore)
    exit 1
fi
```

**Option B: Direct Execution (If transaction not possible)**

```bash
# Some DDL operations can't be in transactions
psql -h localhost -U app_user -d cody2025 -f migration_1.1.0.sql

if [ $? -ne 0 ]; then
    echo "ERROR: Migration failed!"
    # Proceed to Step 5a (Restore)
    exit 1
fi
```

**Note:** Some PostgreSQL DDL operations (like `ALTER TABLE`, `DROP COLUMN`) cannot be rolled back in a transaction. In these cases, the backup restore is your only rollback option.

### Step 5a: If Migration Failed - Restore Backup

```bash
echo "Migration failed! Restoring from backup..."

# Drop and recreate database
psql -h localhost -U app_user -d postgres << EOF
DROP DATABASE cody2025;
CREATE DATABASE cody2025;
GRANT ALL PRIVILEGES ON DATABASE cody2025 TO app_user;
EOF

# Restore from backup
psql -h localhost -U app_user -d cody2025 < "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "Backup restored successfully!"
    echo "Review the migration SQL and fix issues before retrying."
else
    echo "ERROR: Backup restore failed! Contact database administrator immediately."
    exit 1
fi

# Don't delete backup - keep it for investigation
exit 1
```

### Step 5b: If Migration Succeeded - Verify and Cleanup

```bash
# Verify migration was applied correctly
psql -h localhost -U app_user -d cody2025 << EOF
-- Check that new column exists
SELECT column_name 
FROM information_schema.columns 
WHERE table_name='users' 
  AND column_name='user_phone_number';

-- Check that old column is removed
SELECT column_name 
FROM information_schema.columns 
WHERE table_name='organizations' 
  AND column_name='organization_old_address';
EOF

if [ $? -ne 0 ]; then
    echo "WARNING: Migration verification failed!"
    echo "Database may be in inconsistent state."
    echo "Keep backup file: $BACKUP_FILE"
    exit 1
fi

# Update schema_versions table
psql -h localhost -U app_user -d cody2025 << EOF
UPDATE schema_versions 
SET schema_version_is_current = false 
WHERE schema_version_is_current = true;

UPDATE schema_versions 
SET schema_version_is_current = true,
    schema_version_applied_at = NOW()
WHERE schema_version_version = '1.1.0';
EOF

# Wait 24-48 hours before deleting backup (safety net)
echo "Migration successful!"
echo "Backup file: $BACKUP_FILE"
echo "Keep this backup for 24-48 hours before deleting."
echo "To delete: rm $BACKUP_FILE"
```

### Step 6: Restart Application

```bash
# Start application
systemctl start cody2025

# Or if using PM2
pm2 start cody2025

# Verify application is running
systemctl status cody2025
```

## Complete Migration Script Example

```bash
#!/bin/bash
set -e  # Exit on any error

VERSION="1.1.0"
BACKUP_FILE="backup_before_$(date +%Y%m%d_%H%M%S)_${VERSION}.sql"
DB_NAME="cody2025"
DB_USER="app_user"
DB_HOST="localhost"

echo "=== Migration ${VERSION} ==="

# Step 1: Create backup
echo "Step 1: Creating backup..."
pg_dump -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" > "$BACKUP_FILE"

# Verify backup
if [ ! -s "$BACKUP_FILE" ]; then
    echo "ERROR: Backup file is empty!"
    exit 1
fi

echo "Backup created: $BACKUP_FILE"

# Step 2: Stop application
echo "Step 2: Stopping application..."
systemctl stop cody2025 || true

# Step 3: Apply migration
echo "Step 3: Applying migration..."
psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" << EOF
BEGIN;
-- Your migration SQL here
ALTER TABLE users ADD COLUMN user_phone_number VARCHAR(50);
COMMIT;
EOF

if [ $? -ne 0 ]; then
    echo "ERROR: Migration failed! Restoring backup..."
    psql -h "$DB_HOST" -U "$DB_USER" -d postgres << EOF
    DROP DATABASE $DB_NAME;
    CREATE DATABASE $DB_NAME;
    GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
EOF
    psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" < "$BACKUP_FILE"
    echo "Backup restored. Migration aborted."
    exit 1
fi

# Step 4: Verify migration
echo "Step 4: Verifying migration..."
psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "
SELECT column_name 
FROM information_schema.columns 
WHERE table_name='users' 
  AND column_name='user_phone_number';
" || {
    echo "ERROR: Verification failed!"
    exit 1
}

# Step 5: Update schema_versions
echo "Step 5: Updating schema_versions..."
psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" << EOF
UPDATE schema_versions 
SET schema_version_is_current = false 
WHERE schema_version_is_current = true;

UPDATE schema_versions 
SET schema_version_is_current = true,
    schema_version_applied_at = NOW()
WHERE schema_version_version = '${VERSION}';
EOF

# Step 6: Start application
echo "Step 6: Starting application..."
systemctl start cody2025

echo "=== Migration ${VERSION} completed successfully! ==="
echo "Backup file: $BACKUP_FILE"
echo "Keep backup for 24-48 hours before deleting."
```

## Safety Best Practices

### 1. Always Verify Backup
- Check backup file size (not 0 bytes)
- Test restore on a test database if possible
- Verify backup integrity before migration

### 2. Test on Staging First
- Always test migrations on staging environment first
- Verify application works after migration
- Check for any data inconsistencies

### 3. Backup Retention
- Keep backups for 24-48 hours after successful migration
- Store backups in safe location (not just local disk)
- Consider keeping monthly backups for longer-term recovery

### 4. Migration Timing
- Run migrations during low-traffic periods
- Schedule maintenance windows if possible
- Notify team members before migration

### 5. Rollback Plan
- Always have a rollback plan ready
- Document what could go wrong
- Know how long rollback will take

### 6. Verification Checklist
- [ ] Backup created and verified
- [ ] Application stopped (if needed)
- [ ] Migration SQL reviewed
- [ ] Migration applied successfully
- [ ] Schema changes verified
- [ ] Application restarted
- [ ] Application tested
- [ ] Backup kept for safety period

## Common Migration Patterns

### Adding a Column
```sql
ALTER TABLE users ADD COLUMN user_phone_number VARCHAR(50);
```

### Removing a Column
```sql
-- First, ensure column is not critical
-- Then remove
ALTER TABLE organizations DROP COLUMN organization_old_address;
```

### Adding an Index
```sql
CREATE INDEX idx_users_phone ON users(user_phone_number);
```

### Modifying Column Type
```sql
-- Be careful with this - may cause data loss
ALTER TABLE users ALTER COLUMN user_phone_number TYPE VARCHAR(100);
```

### Adding Foreign Key
```sql
ALTER TABLE user_profiles 
ADD CONSTRAINT fk_user_profiles_country 
FOREIGN KEY (user_profile_country_code) 
REFERENCES countries(country_code);
```

## Troubleshooting

### Migration Fails Midway

**Problem:** Migration partially applied, database in inconsistent state.

**Solution:**
1. Restore from backup immediately
2. Review error message
3. Fix migration SQL
4. Retry migration

### Backup Restore Fails

**Problem:** Cannot restore from backup.

**Solution:**
1. Check backup file integrity: `pg_restore --list backup.sql`
2. Verify database permissions
3. Check disk space
4. Try restoring to a new database first
5. Contact database administrator if issues persist

### Application Errors After Migration

**Problem:** Application works but shows errors.

**Solution:**
1. Check application logs
2. Verify schema changes match application expectations
3. Check for missing columns or changed data types
4. Rollback if necessary and fix migration

## Related Documentation

- [db/README.md](./README.md) - Database schema overview
- [documents/5.0_PLAN.md](../documents/5.0_PLAN.md) - Project plan
- [documents/7.0_SECRETS_MANAGEMENT.md](../documents/7.0_SECRETS_MANAGEMENT.md) - Database credentials

## Notes

- **DDL Transaction Limitations:** Some PostgreSQL DDL operations cannot be rolled back in a transaction. Always rely on backups for these operations.
- **Concurrent Access:** Always stop the application during migrations to prevent conflicts.
- **Backup Safety:** Never delete backups immediately after migration. Keep them for at least 24-48 hours.
- **Testing:** Always test migrations on staging environment before production.

