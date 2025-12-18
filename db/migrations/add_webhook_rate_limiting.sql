-- Webhook Rate Limiting Table
-- Tracks webhook requests to prevent spam/DoS attacks
-- Uses sliding window approach for rate limiting

CREATE TABLE IF NOT EXISTS webhook_rate_limits (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Identifier (IP address or order_number)
  identifier TEXT NOT NULL,
  
  -- Type: 'ip' or 'order_number'
  identifier_type TEXT NOT NULL CHECK (identifier_type IN ('ip', 'order_number')),
  
  -- Request count in current window
  request_count INTEGER NOT NULL DEFAULT 1,
  
  -- Window start time (for sliding window)
  window_start TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Last request time
  last_request_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Created at
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Unique constraint: one record per identifier
  UNIQUE(identifier, identifier_type)
);

-- Indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_webhook_rate_limits_identifier 
  ON webhook_rate_limits(identifier, identifier_type);

CREATE INDEX IF NOT EXISTS idx_webhook_rate_limits_window_start 
  ON webhook_rate_limits(window_start);

-- Index for cleanup of old records
CREATE INDEX IF NOT EXISTS idx_webhook_rate_limits_last_request 
  ON webhook_rate_limits(last_request_at);

-- Function to check and update rate limit
-- Returns true if request is allowed, false if rate limited
CREATE OR REPLACE FUNCTION check_webhook_rate_limit(
  p_identifier TEXT,
  p_identifier_type TEXT,
  p_max_requests INTEGER DEFAULT 10,
  p_window_minutes INTEGER DEFAULT 1
)
RETURNS BOOLEAN AS $$
DECLARE
  v_current_count INTEGER;
  v_window_start TIMESTAMPTZ;
  v_now TIMESTAMPTZ := NOW();
  v_window_duration INTERVAL := (p_window_minutes || ' minutes')::INTERVAL;
BEGIN
  -- Find or create rate limit record
  INSERT INTO webhook_rate_limits (identifier, identifier_type, request_count, window_start, last_request_at)
  VALUES (p_identifier, p_identifier_type, 1, v_now, v_now)
  ON CONFLICT (identifier, identifier_type) 
  DO UPDATE SET
    last_request_at = v_now,
    -- Reset window if expired
    window_start = CASE 
      WHEN webhook_rate_limits.window_start + v_window_duration < v_now 
      THEN v_now 
      ELSE webhook_rate_limits.window_start 
    END,
    -- Reset count if window expired, otherwise increment
    request_count = CASE 
      WHEN webhook_rate_limits.window_start + v_window_duration < v_now 
      THEN 1 
      ELSE webhook_rate_limits.request_count + 1 
    END
  RETURNING request_count, window_start INTO v_current_count, v_window_start;
  
  -- Check if within limit
  IF v_current_count <= p_max_requests THEN
    RETURN TRUE; -- Allowed
  ELSE
    RETURN FALSE; -- Rate limited
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to clean up old rate limit records (older than 1 hour)
-- Can be called by cron job
CREATE OR REPLACE FUNCTION cleanup_old_webhook_rate_limits()
RETURNS INTEGER AS $$
DECLARE
  v_deleted_count INTEGER;
BEGIN
  DELETE FROM webhook_rate_limits
  WHERE last_request_at < NOW() - INTERVAL '1 hour';
  
  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
  RETURN v_deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION check_webhook_rate_limit(TEXT, TEXT, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION check_webhook_rate_limit(TEXT, TEXT, INTEGER, INTEGER) TO anon;
GRANT EXECUTE ON FUNCTION cleanup_old_webhook_rate_limits() TO authenticated;

-- RLS Policies (allow service role to manage rate limits)
ALTER TABLE webhook_rate_limits ENABLE ROW LEVEL SECURITY;

-- Service role can do everything (for Edge Functions)
DROP POLICY IF EXISTS "Service role can manage rate limits" ON webhook_rate_limits;
CREATE POLICY "Service role can manage rate limits"
  ON webhook_rate_limits
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Note: This policy allows service role (used by Edge Functions) to manage rate limits
-- Regular users cannot access this table (no policy for authenticated/anon)
