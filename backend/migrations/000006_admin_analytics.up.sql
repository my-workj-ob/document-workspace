CREATE TABLE IF NOT EXISTS admin_users (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(32) NOT NULL DEFAULT 'admin'
        CHECK (role IN ('admin', 'analyst', 'read_only')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS admin_audit_logs (
    id BIGSERIAL PRIMARY KEY,
    admin_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    resource VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_created_at
    ON admin_audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_user_created
    ON admin_audit_logs(admin_user_id, created_at DESC);

ALTER TABLE usage_ledger
    ADD COLUMN IF NOT EXISTS cache_read_tokens INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS cache_write_tokens INT NOT NULL DEFAULT 0;
