-- ============================================
-- WEBHOOK RATE LIMITING MONITORING QUERIES
-- ============================================

-- 1. View current rate limits (all types)
SELECT 
  identifier,
  identifier_type,
  request_count,
  window_start,
  last_request_at,
  NOW() - last_request_at as time_since_last_request
FROM webhook_rate_limits
ORDER BY last_request_at DESC
LIMIT 20;

-- 2. Summary by type
SELECT 
  identifier_type,
  COUNT(*) as total_records,
  SUM(request_count) as total_requests,
  MAX(request_count) as max_requests_in_window,
  MAX(last_request_at) as latest_request
FROM webhook_rate_limits
GROUP BY identifier_type;

-- 3. IPs approaching rate limit (IP-based)
SELECT 
  identifier as ip_address,
  request_count,
  window_start,
  last_request_at,
  CASE 
    WHEN request_count >= 8 THEN '⚠️ Near limit (8-9 requests)'
    WHEN request_count >= 10 THEN '🚨 At limit (10 requests)'
    ELSE '✅ Normal'
  END as status
FROM webhook_rate_limits
WHERE identifier_type = 'ip'
ORDER BY request_count DESC, last_request_at DESC;

-- 4. Orders approaching rate limit (Order-number-based)
SELECT 
  identifier as order_number,
  request_count,
  window_start,
  last_request_at,
  CASE 
    WHEN request_count >= 4 THEN '⚠️ Near limit (4 requests)'
    WHEN request_count >= 5 THEN '🚨 At limit (5 requests)'
    ELSE '✅ Normal'
  END as status
FROM webhook_rate_limits
WHERE identifier_type = 'order_number'
ORDER BY request_count DESC, last_request_at DESC;

-- 5. Recent activity (last hour)
SELECT 
  identifier,
  identifier_type,
  request_count,
  window_start,
  last_request_at
FROM webhook_rate_limits
WHERE last_request_at > NOW() - INTERVAL '1 hour'
ORDER BY last_request_at DESC;

-- 6. Check for expired windows (should auto-reset on next request)
SELECT 
  identifier,
  identifier_type,
  request_count,
  window_start,
  last_request_at,
  window_start + INTERVAL '1 minute' as window_expires_at,
  CASE 
    WHEN identifier_type = 'ip' THEN window_start + INTERVAL '1 minute'
    WHEN identifier_type = 'order_number' THEN window_start + INTERVAL '60 minutes'
  END as calculated_expiry,
  CASE 
    WHEN identifier_type = 'ip' AND window_start + INTERVAL '1 minute' < NOW() THEN '✅ Expired (will reset)'
    WHEN identifier_type = 'order_number' AND window_start + INTERVAL '60 minutes' < NOW() THEN '✅ Expired (will reset)'
    ELSE '⏳ Active'
  END as window_status
FROM webhook_rate_limits
ORDER BY last_request_at DESC;

-- 7. Count records by type (for cleanup planning)
SELECT 
  identifier_type,
  COUNT(*) as total_records,
  COUNT(*) FILTER (WHERE last_request_at < NOW() - INTERVAL '1 hour') as old_records,
  COUNT(*) FILTER (WHERE last_request_at >= NOW() - INTERVAL '1 hour') as recent_records
FROM webhook_rate_limits
GROUP BY identifier_type;

-- 8. Top IPs by request count
SELECT 
  identifier as ip_address,
  request_count,
  window_start,
  last_request_at
FROM webhook_rate_limits
WHERE identifier_type = 'ip'
ORDER BY request_count DESC, last_request_at DESC
LIMIT 10;

-- 9. Top orders by request count
SELECT 
  identifier as order_number,
  request_count,
  window_start,
  last_request_at
FROM webhook_rate_limits
WHERE identifier_type = 'order_number'
ORDER BY request_count DESC, last_request_at DESC
LIMIT 10;

-- 10. Cleanup old records (older than 1 hour)
-- SELECT cleanup_old_webhook_rate_limits();
