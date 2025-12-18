# 🎯 CRON JOB SETUP: SUPABASE DASHBOARD GUIDE

**Quick Guide:** Cara betul untuk create cron job dalam Supabase Dashboard

---

## ⚠️ COMMON MISTAKE

**❌ WRONG - Jangan paste ini dalam "SQL Snippet" field:**
```sql
SELECT cron.schedule(
  'subscription-transitions-hourly',
  '0 * * * *',
  $$
  PERFORM net.http_post(...);
  $$
);
```

**✅ CORRECT - Hanya paste ini:**
```sql
PERFORM net.http_post(
  url := 'https://gxllowlurizrkvpdircw.supabase.co/functions/v1/subscription-transitions',
  headers := jsonb_build_object(
    'Content-Type', 'application/json',
    'Authorization', 'Bearer <service-role-key>'
  )
);
```

**Kenapa?** Supabase Dashboard akan automatically wrap SQL snippet anda dengan `cron.schedule()`. Anda hanya perlu provide SQL yang akan di-execute.

---

## 🚀 STEP-BY-STEP: CREATE CRON JOB

### Step 1: Buka Cron Jobs Page
1. Go to **Supabase Dashboard** → **Database** → **Cron Jobs**
2. Click **"Create a new cron job"** button

### Step 2: Configure Cron Job
1. **Type:** Select **"SQL Snippet"** (bukan "Database function" atau "HTTP Request")
2. **Schedule:** Use the schedule picker atau type `0 * * * *` (every hour)
   - Format: `minute hour day month weekday`
   - `0 * * * *` = Every hour at minute 0

### Step 3: Paste SQL Snippet
**HANYA paste ini (tanpa `SELECT cron.schedule`):**

```sql
PERFORM net.http_post(
  url := 'https://gxllowlurizrkvpdircw.supabase.co/functions/v1/subscription-transitions',
  headers := jsonb_build_object(
    'Content-Type', 'application/json',
    'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd4bGxvd2x1cml6cmt2cGRpcmN3Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NDIxMDIwOSwiZXhwIjoyMDc5Nzg2MjA5fQ.eYq5NUBt04hCD0Y0VQQErTURvb2HHBU5t7pZbu3SVg0'
  )
);
```

**Replace:**
- `gxllowlurizrkvpdircw` → Your project reference (if different)
- `Bearer eyJ...` → Your service role key (from Settings → API)

### Step 4: Create
Click **"Create cron job"** button (green button at bottom)

---

## 🔍 VERIFY CRON JOB CREATED

### Check in Dashboard:
1. Go to **Database** → **Cron Jobs**
2. Should see your cron job listed
3. Click on it to see details and run history

### Check via SQL:
```sql
-- List all cron jobs
SELECT * FROM cron.job;

-- Check specific job
SELECT * FROM cron.job WHERE jobname = 'subscription-transitions-hourly';

-- Check job runs
SELECT * FROM cron.job_run_details 
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'subscription-transitions-hourly')
ORDER BY start_time DESC 
LIMIT 10;
```

---

## 🆚 DASHBOARD vs SQL EDITOR

### Via Dashboard (Recommended):
- ✅ Easy UI untuk schedule
- ✅ Visual cron job management
- ✅ Run history dalam dashboard
- ⚠️ **Hanya paste SQL snippet** (tanpa `SELECT cron.schedule`)

### Via SQL Editor:
- ✅ Full control
- ✅ Can use full `SELECT cron.schedule(...)` syntax
- ⚠️ Need to manually manage schedule

**Untuk Dashboard:** Hanya paste `PERFORM net.http_post(...);`  
**Untuk SQL Editor:** Boleh paste full `SELECT cron.schedule(...)` command

---

## 🐛 TROUBLESHOOTING

### Error: "syntax error at or near PERFORM"
**Cause:** Pasted `SELECT cron.schedule(...)` dalam SQL Snippet field  
**Fix:** Hanya paste `PERFORM net.http_post(...);` (tanpa `SELECT cron.schedule`)

### Error: "function net.http_post does not exist"
**Cause:** `pg_net` extension belum enabled  
**Fix:** Run ini dalam SQL Editor:
```sql
CREATE EXTENSION IF NOT EXISTS pg_net;
```

### Cron job tidak run
**Check:**
1. Verify cron job exists: `SELECT * FROM cron.job;`
2. Check run history: `SELECT * FROM cron.job_run_details;`
3. Verify Edge Function deployed dan accessible
4. Check Edge Function logs untuk errors

---

## 📝 COMPLETE EXAMPLE

**Untuk Supabase Dashboard "SQL Snippet":**
```sql
PERFORM net.http_post(
  url := 'https://gxllowlurizrkvpdircw.supabase.co/functions/v1/subscription-transitions',
  headers := jsonb_build_object(
    'Content-Type', 'application/json',
    'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY_HERE'
  )
);
```

**Untuk SQL Editor (full command):**
```sql
SELECT cron.schedule(
  'subscription-transitions-hourly',
  '0 * * * *',
  $$
  PERFORM net.http_post(
    url := 'https://gxllowlurizrkvpdircw.supabase.co/functions/v1/subscription-transitions',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY_HERE'
    )
  );
  $$
);
```

---

**Status:** Dashboard guide updated ✅
