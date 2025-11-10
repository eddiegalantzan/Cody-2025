-- ============================================
-- TRANSACTION DATA
-- ============================================
-- Classifications, payments, transactions, invoices

-- Classifications table (classification requests and results)
CREATE TABLE classifications (
    classification_id SERIAL PRIMARY KEY,
    classification_organization_fk INTEGER REFERENCES organizations(organization_id) ON DELETE RESTRICT,
    classification_user_fk INTEGER REFERENCES users(user_id) ON DELETE RESTRICT,
    classification_customs_book_fk INTEGER NOT NULL REFERENCES customs_books(customs_book_id) ON DELETE RESTRICT,
    classification_product_description TEXT NOT NULL,
    classification_hs_code VARCHAR(20), -- Result HS code (may include check digit, 7-11 digits)
    classification_confidence_score DECIMAL(5,4), -- 0.0000 to 1.0000 (99.99% = 0.9999)
    classification_status VARCHAR(50) NOT NULL DEFAULT 'pending', -- pending, completed, failed, rejected
    classification_rejection_reason TEXT, -- If status is 'rejected' (e.g., "abstract description")
    classification_classification_type VARCHAR(50) NOT NULL DEFAULT 'standard', -- standard, list_lookup, interactive
    classification_company_item_list_fk INTEGER, -- If classification_type is 'list_lookup'
    classification_session_fk INTEGER, -- If classification_type is 'interactive'
    classification_cost_multiplier DECIMAL(10,2) DEFAULT 1.0, -- X, X/D, or M×X
    classification_access_method VARCHAR(50), -- frontend, email, api_webhook, api_sync
    classification_job_id VARCHAR(255), -- For async API webhook method
    -- LLM usage tracking
    classification_llm_provider VARCHAR(50), -- openai, anthropic, google, xai, etc.
    classification_llm_model VARCHAR(100), -- gpt-4, gpt-3.5-turbo, claude-3-opus, etc.
    classification_llm_input_tokens INTEGER, -- Number of input tokens used
    classification_llm_output_tokens INTEGER, -- Number of output tokens used
    classification_llm_total_tokens INTEGER, -- Total tokens used
    classification_llm_cost DECIMAL(10,6), -- Cost in USD for LLM usage
    classification_llm_response_time_ms INTEGER, -- LLM response time in milliseconds
    classification_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    classification_completed_at TIMESTAMPTZ,
    classification_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_classification_org_id ON classifications(classification_organization_fk);
CREATE INDEX idx_classification_user_id ON classifications(classification_user_fk);
CREATE INDEX idx_classification_customs_book_id ON classifications(classification_customs_book_fk);
CREATE INDEX idx_classification_status ON classifications(classification_status);
CREATE INDEX idx_classification_created_at ON classifications(classification_created_at);
CREATE INDEX idx_classification_session_id ON classifications(classification_session_fk) WHERE classification_session_fk IS NOT NULL;
CREATE INDEX idx_classification_job_id ON classifications(classification_job_id) WHERE classification_job_id IS NOT NULL;
CREATE INDEX idx_classification_llm_provider ON classifications(classification_llm_provider) WHERE classification_llm_provider IS NOT NULL;
CREATE INDEX idx_classification_llm_model ON classifications(classification_llm_model) WHERE classification_llm_model IS NOT NULL;

-- Interactive workflow sessions (for Q&A when HS code unknown)
CREATE TABLE interactive_sessions (
    interactive_session_id SERIAL PRIMARY KEY,
    interactive_session_session_id VARCHAR(255) NOT NULL UNIQUE, -- External session ID for API
    interactive_session_classification_fk INTEGER REFERENCES classifications(classification_id) ON DELETE RESTRICT,
    interactive_session_organization_fk INTEGER REFERENCES organizations(organization_id) ON DELETE RESTRICT,
    interactive_session_user_fk INTEGER REFERENCES users(user_id) ON DELETE RESTRICT,
    interactive_session_customs_book_fk INTEGER NOT NULL REFERENCES customs_books(customs_book_id) ON DELETE RESTRICT,
    interactive_session_product_description TEXT NOT NULL,
    interactive_session_status VARCHAR(50) NOT NULL DEFAULT 'active', -- active, completed, expired, cancelled
    interactive_session_current_question_id INTEGER, -- Current question being asked
    interactive_session_question_asked JSONB DEFAULT '[]', -- Array of question IDs asked
    interactive_session_answers_received JSONB DEFAULT '{}', -- Map of question_id -> answer
    interactive_session_pending_questions JSONB DEFAULT '[]', -- Array of pending question IDs
    interactive_session_expires_at TIMESTAMPTZ NOT NULL,
    interactive_session_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    interactive_session_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    interactive_session_completed_at TIMESTAMPTZ
);

CREATE INDEX idx_interactive_session_session_id ON interactive_sessions(interactive_session_session_id);
CREATE INDEX idx_interactive_session_classification_id ON interactive_sessions(interactive_session_classification_fk);
CREATE INDEX idx_interactive_session_status ON interactive_sessions(interactive_session_status);
CREATE INDEX idx_interactive_session_expires_at ON interactive_sessions(interactive_session_expires_at);
CREATE INDEX idx_interactive_session_org_id ON interactive_sessions(interactive_session_organization_fk);

-- Questions table (interactive Q&A for classification)
CREATE TABLE questions (
    question_id SERIAL PRIMARY KEY,
    question_session_fk INTEGER NOT NULL REFERENCES interactive_sessions(interactive_session_id) ON DELETE RESTRICT,
    question_question_text TEXT NOT NULL,
    question_question_type VARCHAR(50) NOT NULL, -- multiple_choice, text, yes_no, etc.
    question_options JSONB, -- For multiple choice questions
    question_answer TEXT, -- User's answer
    question_answer_received_at TIMESTAMPTZ,
    question_order_index INTEGER NOT NULL, -- Order in which question was asked
    question_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    question_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_question_session_id ON questions(question_session_fk);
CREATE INDEX idx_question_order_index ON questions(question_session_fk, question_order_index);

-- Company item code lists (uploaded lists for lookup)
CREATE TABLE company_item_lists (
    company_item_list_id SERIAL PRIMARY KEY,
    company_item_list_organization_fk INTEGER NOT NULL REFERENCES organizations(organization_id) ON DELETE RESTRICT,
    company_item_list_name VARCHAR(255) NOT NULL,
    company_item_list_description TEXT,
    company_item_list_item_count INTEGER DEFAULT 0,
    company_item_list_uploaded_by_user_fk INTEGER REFERENCES users(user_id) ON DELETE RESTRICT,
    company_item_list_file_name VARCHAR(255),
    company_item_list_file_size_bytes INTEGER,
    company_item_list_upload_status VARCHAR(50) DEFAULT 'pending', -- pending, processing, completed, failed
    company_item_list_error_message TEXT,
    company_item_list_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    company_item_list_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    company_item_list_deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_company_item_list_org_id ON company_item_lists(company_item_list_organization_fk);
CREATE INDEX idx_company_item_list_deleted_at ON company_item_lists(company_item_list_deleted_at) WHERE company_item_list_deleted_at IS NULL;

-- Company item code mappings (items in uploaded lists)
CREATE TABLE company_item_mappings (
    company_item_mapping_id SERIAL PRIMARY KEY,
    company_item_mapping_company_item_list_fk INTEGER NOT NULL REFERENCES company_item_lists(company_item_list_id) ON DELETE RESTRICT,
    company_item_mapping_company_item_code VARCHAR(255) NOT NULL,
    company_item_mapping_product_description TEXT,
    company_item_mapping_hs_code VARCHAR(20) NOT NULL,
    company_item_mapping_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    company_item_mapping_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(company_item_mapping_company_item_list_fk, company_item_mapping_company_item_code)
);

CREATE INDEX idx_item_mappings_list_id ON company_item_mappings(company_item_mapping_company_item_list_fk);
CREATE INDEX idx_item_mappings_item_code ON company_item_mappings(company_item_mapping_company_item_code);
CREATE INDEX idx_item_mappings_hs_code ON company_item_mappings(company_item_mapping_hs_code);
CREATE INDEX idx_item_mappings_description ON company_item_mappings USING gin(to_tsvector('english', company_item_mapping_product_description));

-- Transactions/pricing table (track costs per transaction)
CREATE TABLE transactions (
    transaction_id SERIAL PRIMARY KEY,
    transaction_classification_fk INTEGER REFERENCES classifications(classification_id) ON DELETE RESTRICT,
    transaction_organization_fk INTEGER NOT NULL REFERENCES organizations(organization_id) ON DELETE RESTRICT,
    transaction_user_fk INTEGER REFERENCES users(user_id) ON DELETE RESTRICT,
    transaction_transaction_type VARCHAR(50) NOT NULL, -- standard, list_lookup, interactive, abstract
    transaction_base_cost DECIMAL(10,2) NOT NULL, -- Base cost X
    transaction_cost_multiplier DECIMAL(10,2) DEFAULT 1.0, -- Multiplier M or divisor D
    transaction_final_cost DECIMAL(10,2) NOT NULL, -- Final cost (X, X/D, or M×X)
    transaction_currency_code VARCHAR(3) DEFAULT 'USD',
    transaction_status VARCHAR(50) DEFAULT 'pending', -- pending, billed, paid, cancelled
    transaction_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    transaction_billed_at TIMESTAMPTZ,
    transaction_paid_at TIMESTAMPTZ,
    transaction_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_transaction_classification_id ON transactions(transaction_classification_fk);
CREATE INDEX idx_transaction_org_id ON transactions(transaction_organization_fk);
CREATE INDEX idx_transaction_user_id ON transactions(transaction_user_fk);
CREATE INDEX idx_transaction_status ON transactions(transaction_status);
CREATE INDEX idx_transaction_created_at ON transactions(transaction_created_at);

-- Payment accounts (link to Payoneer, organization linkage)
CREATE TABLE payment_accounts (
    payment_account_id SERIAL PRIMARY KEY,
    payment_account_organization_fk INTEGER NOT NULL REFERENCES organizations(organization_id) ON DELETE RESTRICT,
    payment_account_payoneer_account_id VARCHAR(255) NOT NULL,
    payment_account_account_type VARCHAR(50) NOT NULL, -- receiving, sending, both
    payment_account_currency_code VARCHAR(3) DEFAULT 'USD',
    payment_account_status VARCHAR(50) DEFAULT 'active', -- active, pending_approval, suspended, closed
    payment_account_metadata JSONB DEFAULT '{}', -- Additional Payoneer account metadata
    payment_account_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    payment_account_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_payment_account_org_id ON payment_accounts(payment_account_organization_fk);
CREATE INDEX idx_payment_account_payoneer_id ON payment_accounts(payment_account_payoneer_account_id);
CREATE INDEX idx_payment_account_status ON payment_accounts(payment_account_status);

-- Payment transactions (incoming/outgoing, status, currency)
CREATE TABLE payment_transactions (
    payment_transaction_id SERIAL PRIMARY KEY,
    payment_transaction_payment_account_fk INTEGER NOT NULL REFERENCES payment_accounts(payment_account_id) ON DELETE RESTRICT,
    payment_transaction_organization_fk INTEGER NOT NULL REFERENCES organizations(organization_id) ON DELETE RESTRICT,
    payment_transaction_payoneer_payment_id VARCHAR(255) UNIQUE,
    payment_transaction_transaction_type VARCHAR(50) NOT NULL, -- incoming, outgoing
    payment_transaction_amount DECIMAL(15,2) NOT NULL,
    payment_transaction_currency_code VARCHAR(3) NOT NULL,
    payment_transaction_status VARCHAR(50) NOT NULL DEFAULT 'pending', -- pending, processing, completed, failed, cancelled
    payment_transaction_payment_method VARCHAR(50), -- ACH, SEPA, BACS, BECS, card, PayPal
    payment_transaction_recipient_payee_id VARCHAR(255), -- For outgoing payments
    payment_transaction_description TEXT,
    payment_transaction_invoice_id INTEGER, -- Link to invoices table
    payment_transaction_webhook_received_at TIMESTAMPTZ,
    payment_transaction_metadata JSONB DEFAULT '{}', -- Additional transaction metadata
    payment_transaction_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    payment_transaction_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    payment_transaction_completed_at TIMESTAMPTZ
);

CREATE INDEX idx_payment_transaction_account_id ON payment_transactions(payment_transaction_payment_account_fk);
CREATE INDEX idx_payment_transaction_org_id ON payment_transactions(payment_transaction_organization_fk);
CREATE INDEX idx_payment_transaction_payoneer_id ON payment_transactions(payment_transaction_payoneer_payment_id);
CREATE INDEX idx_payment_transaction_status ON payment_transactions(payment_transaction_status);
CREATE INDEX idx_payment_transaction_created_at ON payment_transactions(payment_transaction_created_at);
CREATE INDEX idx_payment_transaction_invoice_id ON payment_transactions(payment_transaction_invoice_id) WHERE payment_transaction_invoice_id IS NOT NULL;

-- Invoices table (B2B invoice tracking, payment terms)
CREATE TABLE invoices (
    invoice_id SERIAL PRIMARY KEY,
    invoice_organization_fk INTEGER NOT NULL REFERENCES organizations(organization_id) ON DELETE RESTRICT,
    invoice_invoice_number VARCHAR(255) NOT NULL UNIQUE,
    invoice_invoice_date DATE NOT NULL,
    invoice_due_date DATE NOT NULL,
    invoice_payment_terms VARCHAR(50) DEFAULT 'net_30', -- net_30, net_60, due_on_receipt, etc.
    invoice_subtotal DECIMAL(15,2) NOT NULL,
    invoice_tax_amount DECIMAL(15,2) DEFAULT 0,
    invoice_total_amount DECIMAL(15,2) NOT NULL,
    invoice_currency_code VARCHAR(3) DEFAULT 'USD',
    invoice_status VARCHAR(50) DEFAULT 'draft', -- draft, sent, paid, overdue, cancelled
    invoice_payment_account_fk INTEGER REFERENCES payment_accounts(payment_account_id) ON DELETE RESTRICT,
    invoice_paid_at TIMESTAMPTZ,
    invoice_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    invoice_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_invoice_org_id ON invoices(invoice_organization_fk);
CREATE INDEX idx_invoice_invoice_number ON invoices(invoice_invoice_number);
CREATE INDEX idx_invoice_status ON invoices(invoice_status);
CREATE INDEX idx_invoice_due_date ON invoices(invoice_due_date);

-- Invoice line items
CREATE TABLE invoice_line_items (
    invoice_line_item_id SERIAL PRIMARY KEY,
    invoice_line_item_invoice_fk INTEGER NOT NULL REFERENCES invoices(invoice_id) ON DELETE RESTRICT,
    invoice_line_item_transaction_fk INTEGER REFERENCES transactions(transaction_id) ON DELETE RESTRICT,
    invoice_line_item_description TEXT NOT NULL,
    invoice_line_item_quantity INTEGER DEFAULT 1,
    invoice_line_item_unit_price DECIMAL(15,2) NOT NULL,
    invoice_line_item_total_price DECIMAL(15,2) NOT NULL,
    invoice_line_item_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    invoice_line_item_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_invoice_line_item_invoice_id ON invoice_line_items(invoice_line_item_invoice_fk);
CREATE INDEX idx_invoice_line_item_transaction_id ON invoice_line_items(invoice_line_item_transaction_fk) WHERE invoice_line_item_transaction_fk IS NOT NULL;

-- Scheduled payments table (custom recurring payment logic)
CREATE TABLE scheduled_payments (
    scheduled_payment_id SERIAL PRIMARY KEY,
    scheduled_payment_organization_fk INTEGER NOT NULL REFERENCES organizations(organization_id) ON DELETE RESTRICT,
    scheduled_payment_payment_account_fk INTEGER NOT NULL REFERENCES payment_accounts(payment_account_id) ON DELETE RESTRICT,
    scheduled_payment_recipient_payee_id VARCHAR(255) NOT NULL,
    scheduled_payment_amount DECIMAL(15,2) NOT NULL,
    scheduled_payment_currency_code VARCHAR(3) NOT NULL,
    scheduled_payment_frequency VARCHAR(50) NOT NULL, -- daily, weekly, monthly, yearly, custom
    scheduled_payment_next_payment_date DATE NOT NULL,
    scheduled_payment_timezone VARCHAR(50) DEFAULT 'UTC',
    scheduled_payment_status VARCHAR(50) DEFAULT 'active', -- active, paused, cancelled, completed
    scheduled_payment_metadata JSONB DEFAULT '{}', -- Custom schedule configuration
    scheduled_payment_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    scheduled_payment_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    scheduled_payment_cancelled_at TIMESTAMPTZ
);

CREATE INDEX idx_scheduled_payment_org_id ON scheduled_payments(scheduled_payment_organization_fk);
CREATE INDEX idx_scheduled_payment_account_id ON scheduled_payments(scheduled_payment_payment_account_fk);
CREATE INDEX idx_scheduled_payment_status ON scheduled_payments(scheduled_payment_status);
CREATE INDEX idx_scheduled_payment_next_date ON scheduled_payments(scheduled_payment_next_payment_date);

COMMENT ON TABLE classifications IS 'HS code classification requests and results';
COMMENT ON TABLE interactive_sessions IS 'Interactive Q&A sessions for classification when HS code is unknown';
COMMENT ON TABLE company_item_lists IS 'Uploaded company item code lists for lookup';
COMMENT ON TABLE transactions IS 'Transaction pricing tracking (X, X/D, M×X)';
COMMENT ON TABLE payment_accounts IS 'Payment accounts linked to Payoneer';
COMMENT ON TABLE payment_transactions IS 'Payment transactions (incoming/outgoing)';
COMMENT ON TABLE invoices IS 'B2B invoices with payment terms';
COMMENT ON TABLE scheduled_payments IS 'Custom recurring payment schedules';

