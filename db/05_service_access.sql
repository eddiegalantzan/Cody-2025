-- ============================================
-- SERVICE ACCESS
-- ============================================
-- API keys, webhooks, job queue

-- API keys and authentication tokens
CREATE TABLE api_keys (
    api_key_id SERIAL PRIMARY KEY,
    api_key_organization_fk INTEGER NOT NULL REFERENCES organizations(organization_id) ON DELETE RESTRICT,
    api_key_user_fk INTEGER REFERENCES users(user_id) ON DELETE RESTRICT,
    api_key_key_name VARCHAR(255) NOT NULL,
    api_key_api_key VARCHAR(255) NOT NULL UNIQUE,
    api_key_key_hash VARCHAR(255) NOT NULL, -- Hashed version for verification
    api_key_permissions JSONB DEFAULT '{}', -- API permissions
    api_key_rate_limit_per_minute INTEGER DEFAULT 60,
    api_key_rate_limit_per_hour INTEGER DEFAULT 1000,
    api_key_last_used_at TIMESTAMPTZ,
    api_key_expires_at TIMESTAMPTZ,
    api_key_is_active BOOLEAN DEFAULT true,
    api_key_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    api_key_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    api_key_revoked_at TIMESTAMPTZ
);

CREATE INDEX idx_api_key_org_id ON api_keys(api_key_organization_fk);
CREATE INDEX idx_api_key_api_key ON api_keys(api_key_api_key);
CREATE INDEX idx_api_key_key_hash ON api_keys(api_key_key_hash);
CREATE INDEX idx_api_key_is_active ON api_keys(api_key_is_active) WHERE api_key_is_active = true;

-- Webhook configurations (client webhook URLs)
CREATE TABLE webhook_configurations (
    webhook_configuration_id SERIAL PRIMARY KEY,
    webhook_configuration_organization_fk INTEGER NOT NULL REFERENCES organizations(organization_id) ON DELETE RESTRICT,
    webhook_configuration_name VARCHAR(255) NOT NULL,
    webhook_configuration_webhook_url TEXT NOT NULL,
    webhook_configuration_webhook_secret VARCHAR(255), -- For signature verification
    webhook_configuration_events JSONB NOT NULL DEFAULT '[]', -- Array of event types to subscribe to
    webhook_configuration_is_active BOOLEAN DEFAULT true,
    webhook_configuration_last_triggered_at TIMESTAMPTZ,
    webhook_configuration_failure_count INTEGER DEFAULT 0,
    webhook_configuration_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    webhook_configuration_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_webhook_configs_org_id ON webhook_configurations(webhook_configuration_organization_fk);
CREATE INDEX idx_webhook_configs_is_active ON webhook_configurations(webhook_configuration_is_active) WHERE webhook_configuration_is_active = true;

-- Webhook delivery attempts (track individual webhook delivery attempts for async API)
CREATE TABLE webhook_deliveries (
    webhook_delivery_id SERIAL PRIMARY KEY,
    webhook_delivery_webhook_configuration_fk INTEGER NOT NULL REFERENCES webhook_configurations(webhook_configuration_id) ON DELETE RESTRICT,
    webhook_delivery_job_fk VARCHAR(255) REFERENCES job_queue(job_queue_job_id) ON DELETE RESTRICT,
    webhook_delivery_url TEXT NOT NULL,
    webhook_delivery_payload JSONB NOT NULL,
    webhook_delivery_status VARCHAR(50) NOT NULL DEFAULT 'pending', -- pending, sent, delivered, failed
    webhook_delivery_http_status_code INTEGER,
    webhook_delivery_response_body TEXT,
    webhook_delivery_error_message TEXT,
    webhook_delivery_retry_count INTEGER DEFAULT 0,
    webhook_delivery_max_retries INTEGER DEFAULT 3,
    webhook_delivery_sent_at TIMESTAMPTZ,
    webhook_delivery_delivered_at TIMESTAMPTZ,
    webhook_delivery_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    webhook_delivery_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_webhook_deliveries_config_id ON webhook_deliveries(webhook_delivery_webhook_configuration_fk);
CREATE INDEX idx_webhook_deliveries_job_id ON webhook_deliveries(webhook_delivery_job_fk) WHERE webhook_delivery_job_fk IS NOT NULL;
CREATE INDEX idx_webhook_deliveries_status ON webhook_deliveries(webhook_delivery_status);
CREATE INDEX idx_webhook_deliveries_created_at ON webhook_deliveries(webhook_delivery_created_at);

-- Job queue table (async API processing)
CREATE TABLE job_queue (
    job_queue_id SERIAL PRIMARY KEY,
    job_queue_job_id VARCHAR(255) NOT NULL UNIQUE,
    job_queue_organization_fk INTEGER REFERENCES organizations(organization_id) ON DELETE RESTRICT,
    job_queue_user_fk INTEGER REFERENCES users(user_id) ON DELETE RESTRICT,
    job_queue_job_type VARCHAR(50) NOT NULL, -- classification, webhook_delivery, email_send, etc.
    job_queue_status VARCHAR(50) NOT NULL DEFAULT 'pending', -- pending, processing, completed, failed, retrying
    job_queue_priority INTEGER DEFAULT 0, -- Higher number = higher priority
    job_queue_payload JSONB NOT NULL DEFAULT '{}', -- Job data
    job_queue_result JSONB, -- Job result
    job_queue_error_message TEXT,
    job_queue_retry_count INTEGER DEFAULT 0,
    job_queue_max_retries INTEGER DEFAULT 3,
    job_queue_scheduled_at TIMESTAMPTZ,
    job_queue_started_at TIMESTAMPTZ,
    job_queue_completed_at TIMESTAMPTZ,
    job_queue_created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    job_queue_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_job_queue_job_id ON job_queue(job_queue_job_id);
CREATE INDEX idx_job_queue_status ON job_queue(job_queue_status);
CREATE INDEX idx_job_queue_scheduled_at ON job_queue(job_queue_scheduled_at) WHERE job_queue_scheduled_at IS NOT NULL;
CREATE INDEX idx_job_queue_priority ON job_queue(job_queue_priority DESC, job_queue_created_at);
CREATE INDEX idx_job_queue_org_id ON job_queue(job_queue_organization_fk) WHERE job_queue_organization_fk IS NOT NULL;

COMMENT ON TABLE api_keys IS 'API keys for service access';
COMMENT ON TABLE webhook_configurations IS 'Client webhook URLs for async API';
COMMENT ON TABLE job_queue IS 'Async job processing queue';

