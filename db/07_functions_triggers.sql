-- ============================================
-- FUNCTIONS & TRIGGERS
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    -- Dynamically update the updated_at column based on table name
    -- Note: schema_versions doesn't have updated_at, so skip it
    IF TG_TABLE_NAME = 'users' THEN
        NEW.user_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'user_profiles' THEN
        NEW.user_profile_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'organizations' THEN
        NEW.organization_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'organization_members' THEN
        NEW.organization_member_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'organization_groups' THEN
        NEW.organization_group_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'organization_group_members' THEN
        NEW.organization_group_member_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'countries' THEN
        NEW.country_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'wco_editions' THEN
        NEW.wco_edition_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'wco_sections' THEN
        NEW.wco_section_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'wco_chapters' THEN
        NEW.wco_chapter_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'wco_headings' THEN
        NEW.wco_heading_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'wco_hs_codes' THEN
        NEW.wco_hs_code_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'customs_books' THEN
        NEW.customs_book_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'customs_book_hs_codes' THEN
        NEW.customs_book_hs_code_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'classifications' THEN
        NEW.classification_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'interactive_sessions' THEN
        NEW.interactive_session_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'questions' THEN
        NEW.question_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'company_item_lists' THEN
        NEW.company_item_list_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'company_item_mappings' THEN
        NEW.company_item_mapping_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'transactions' THEN
        NEW.transaction_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'payment_accounts' THEN
        NEW.payment_account_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'payment_transactions' THEN
        NEW.payment_transaction_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'invoices' THEN
        NEW.invoice_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'invoice_line_items' THEN
        NEW.invoice_line_item_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'scheduled_payments' THEN
        NEW.scheduled_payment_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'api_keys' THEN
        NEW.api_key_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'webhook_configurations' THEN
        NEW.webhook_configuration_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'webhook_deliveries' THEN
        NEW.webhook_delivery_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'job_queue' THEN
        NEW.job_queue_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'audit_logs' THEN
        NEW.audit_log_updated_at = NOW();
    ELSIF TG_TABLE_NAME = 'error_logs' THEN
        NEW.error_log_updated_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply updated_at trigger to all tables
-- Note: schema_versions doesn't have updated_at, so no trigger needed

CREATE TRIGGER update_user_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_profile_updated_at BEFORE UPDATE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_organization_updated_at BEFORE UPDATE ON organizations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_organization_member_updated_at BEFORE UPDATE ON organization_members
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_organization_group_updated_at BEFORE UPDATE ON organization_groups
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_organization_group_member_updated_at BEFORE UPDATE ON organization_group_members
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_country_updated_at BEFORE UPDATE ON countries
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_wco_edition_updated_at BEFORE UPDATE ON wco_editions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_wco_section_updated_at BEFORE UPDATE ON wco_sections
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_wco_chapter_updated_at BEFORE UPDATE ON wco_chapters
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_wco_heading_updated_at BEFORE UPDATE ON wco_headings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_wco_hs_code_updated_at BEFORE UPDATE ON wco_hs_codes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_customs_book_updated_at BEFORE UPDATE ON customs_books
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_customs_book_hs_code_updated_at BEFORE UPDATE ON customs_book_hs_codes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_classification_updated_at BEFORE UPDATE ON classifications
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_interactive_session_updated_at BEFORE UPDATE ON interactive_sessions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_question_updated_at BEFORE UPDATE ON questions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_company_item_list_updated_at BEFORE UPDATE ON company_item_lists
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_company_item_mapping_updated_at BEFORE UPDATE ON company_item_mappings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_transaction_updated_at BEFORE UPDATE ON transactions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_payment_account_updated_at BEFORE UPDATE ON payment_accounts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_payment_transaction_updated_at BEFORE UPDATE ON payment_transactions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_invoice_updated_at BEFORE UPDATE ON invoices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_invoice_line_item_updated_at BEFORE UPDATE ON invoice_line_items
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_scheduled_payment_updated_at BEFORE UPDATE ON scheduled_payments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_api_key_updated_at BEFORE UPDATE ON api_keys
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_webhook_configuration_updated_at BEFORE UPDATE ON webhook_configurations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_webhook_delivery_updated_at BEFORE UPDATE ON webhook_deliveries
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_job_queue_updated_at BEFORE UPDATE ON job_queue
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_audit_log_updated_at BEFORE UPDATE ON audit_logs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_error_log_updated_at BEFORE UPDATE ON error_logs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to update company_item_lists.item_count
CREATE OR REPLACE FUNCTION update_item_list_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE company_item_lists
        SET company_item_list_item_count = company_item_list_item_count + 1
        WHERE company_item_list_id = NEW.company_item_mapping_company_item_list_fk;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE company_item_lists
        SET company_item_list_item_count = GREATEST(0, company_item_list_item_count - 1)
        WHERE company_item_list_id = OLD.company_item_mapping_company_item_list_fk;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_item_list_count_trigger
    AFTER INSERT OR DELETE ON company_item_mappings
    FOR EACH ROW EXECUTE FUNCTION update_item_list_count();

