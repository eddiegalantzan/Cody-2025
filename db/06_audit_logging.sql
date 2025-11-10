-- ============================================
-- AUDIT & LOGGING
-- ============================================

-- Audit logs table (user actions, classification history)
CREATE TABLE audit_logs (
    audit_log_id SERIAL PRIMARY KEY,
    audit_log_organization_fk INTEGER REFERENCES organizations(organization_id) ON DELETE RESTRICT,
    audit_log_user_fk INTEGER REFERENCES users(user_id) ON DELETE RESTRICT,
    audit_log_action_type VARCHAR(100) NOT NULL, -- classification_request, payment_created, user_login, etc.
    audit_log_resource_type VARCHAR(100), -- classification, payment, user, etc.
    audit_log_resource_id INTEGER,
    audit_log_details JSONB DEFAULT '{}', -- Action details
    audit_log_ip_address INET,
    audit_log_user_agent TEXT,
    audit_log_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    audit_log_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_log_org_id ON audit_logs(audit_log_organization_fk);
CREATE INDEX idx_audit_log_user_id ON audit_logs(audit_log_user_fk);
CREATE INDEX idx_audit_log_action_type ON audit_logs(audit_log_action_type);
CREATE INDEX idx_audit_log_resource ON audit_logs(audit_log_resource_type, audit_log_resource_id);
CREATE INDEX idx_audit_log_created_at ON audit_logs(audit_log_created_at);

-- Error logs table
CREATE TABLE error_logs (
    error_log_id SERIAL PRIMARY KEY,
    error_log_organization_fk INTEGER REFERENCES organizations(organization_id) ON DELETE RESTRICT,
    error_log_user_fk INTEGER REFERENCES users(user_id) ON DELETE RESTRICT,
    error_log_error_type VARCHAR(100) NOT NULL,
    error_log_error_message TEXT NOT NULL,
    error_log_stack_trace TEXT,
    error_log_context JSONB DEFAULT '{}', -- Additional context
    error_log_severity VARCHAR(20) DEFAULT 'error', -- info, warning, error, critical
    error_log_resolved BOOLEAN DEFAULT false,
    error_log_resolved_at TIMESTAMPTZ,
    error_log_resolved_by_user_fk INTEGER REFERENCES users(user_id) ON DELETE RESTRICT,
    error_log_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    error_log_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_error_log_org_id ON error_logs(error_log_organization_fk);
CREATE INDEX idx_error_log_user_id ON error_logs(error_log_user_fk);
CREATE INDEX idx_error_log_error_type ON error_logs(error_log_error_type);
CREATE INDEX idx_error_log_severity ON error_logs(error_log_severity);
CREATE INDEX idx_error_log_resolved ON error_logs(error_log_resolved) WHERE error_log_resolved = false;
CREATE INDEX idx_error_log_created_at ON error_logs(error_log_created_at);

COMMENT ON TABLE audit_logs IS 'Audit trail of user actions';
COMMENT ON TABLE error_logs IS 'Application error logging';

