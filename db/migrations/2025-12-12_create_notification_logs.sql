-- Notification logs for email/SMS/in-app audit
CREATE TABLE IF NOT EXISTS notification_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    channel TEXT NOT NULL, -- 'email' | 'sms' | 'in_app'
    type TEXT NOT NULL,    -- e.g., 'payment_success', 'payment_failed', 'grace_reminder'
    status TEXT NOT NULL DEFAULT 'sent', -- 'sent' | 'failed'
    subject TEXT,
    payload JSONB,
    error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notification_logs_user_id ON notification_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_notification_logs_type ON notification_logs(type);

