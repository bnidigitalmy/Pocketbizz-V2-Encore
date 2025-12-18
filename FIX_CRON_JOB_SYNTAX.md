# 🔧 FIX CRON JOB SYNTAX ERROR

**Error:** `ERROR: 42601: syntax error at or near "SELECT" LINE 9: SELECT net.http_post(^`

---

## 📋 MASALAH

Dalam `cron.schedule()`, command yang diberikan tidak boleh guna `SELECT` untuk side-effect operations seperti `net.http_post()`.

**❌ WRONG:**
```sql
SELECT cron.schedule(
  'subscription-transitions-hourly',
  '0 * * * *',
  $$
  SELECT net.http_post(...) AS request_id;  -- ❌ ERROR!
  $$
);
```

**✅ CORRECT:**
```sql
SELECT cron.schedule(
  'subscription-transitions-hourly',
  '0 * * * *',
  $$
  PERFORM net.http_post(...);  -- ✅ CORRECT!
  $$
);
```

---

## ✅ SOLUTION: GUNA PERFORM

Dalam PostgreSQL, untuk call function yang ada side-effect (seperti HTTP request), kita perlu guna `PERFORM` bukan `SELECT`.

### Fixed SQL Code:

```sql
-- Enable pg_cron extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule hourly subscription transitions
SELECT cron.schedule(
  'subscription-transitions-hourly',
  '0 * * * *', -- Every hour at minute 0
  $$
  PERFORM net.http_post(
    url := 'https://<your-project-ref>.supabase.co/functions/v1/subscription-transitions',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer <service-role-key>'
    )
  );
  $$
);
```

**Changes:**
- `SELECT net.http_post(...) AS request_id;` → `PERFORM net.http_post(...);`
- Remove `AS request_id` (not needed with PERFORM)

---

## 🚀 STEP-BY-STEP: CREATE CRON JOB DI SUPABASE

### Option 1: Via Supabase Dashboard (Recommended)

**⚠️ IMPORTANT:** Dalam Supabase Dashboard "SQL Snippet" type, **JANGAN paste `SELECT cron.schedule(...)`**. Dashboard akan handle itu automatically. Hanya paste SQL yang akan di-execute oleh cron job!

1. **Buka Supabase Dashboard**
   - Go to: https://app.supabase.com
   - Select project anda
   - Go to **Database** → **Cron Jobs** (atau **Extensions** → **pg_cron**)

2. **Create New Cron Job**
   - Click **"Create a new cron job"**
   - **Type:** Select **"SQL Snippet"**
   - **Schedule:** Set to `0 * * * *` (every hour at minute 0) - use the schedule picker UI
   - **SQL Snippet:** Paste **HANYA** code di bawah (tanpa `SELECT cron.schedule`)

3. **SQL Code untuk Paste (HANYA ini sahaja!):**
   ```sql
   PERFORM net.http_post(
     url := 'https://<your-project-ref>.supabase.co/functions/v1/subscription-transitions',
     headers := jsonb_build_object(
       'Content-Type', 'application/json',
       'Authorization', 'Bearer <service-role-key>'
     )
   );
   ```

4. **Replace Placeholders:**
   - `<your-project-ref>` → Your Supabase project reference (e.g., `gxllowlurizrkvpdircw`)
   - `<service-role-key>` → Your service role key (dari Settings → API)

5. **Click "Create cron job"**

**❌ JANGAN paste ini (Dashboard akan handle automatically):**
```sql
SELECT cron.schedule(...);  -- ❌ JANGAN paste ini!
```

**✅ Hanya paste ini:**
```sql
PERFORM net.http_post(...);  -- ✅ Ini sahaja!
```

### Option 2: Via SQL Editor

1. **Buka SQL Editor** dalam Supabase Dashboard
2. **Paste SQL code** (dengan `PERFORM`):
   ```sql
   -- Enable pg_cron (if not enabled)
   CREATE EXTENSION IF NOT EXISTS pg_cron;
   
   -- Schedule cron job
   SELECT cron.schedule(
     'subscription-transitions-hourly',
     '0 * * * *',
     $$
     PERFORM net.http_post(
       url := 'https://<your-project-ref>.supabase.co/functions/v1/subscription-transitions',
       headers := jsonb_build_object(
         'Content-Type', 'application/json',
         'Authorization', 'Bearer <service-role-key>'
       )
     );
     $$
   );
   ```
3. **Replace placeholders** dan **Run**

---

## ⚠️ IMPORTANT NOTES

### 1. PERFORM vs SELECT
- **PERFORM:** Untuk side-effect operations (HTTP calls, inserts, etc.)
- **SELECT:** Untuk queries yang return data
- Dalam cron job, kita guna `PERFORM` kerana kita hanya nak trigger HTTP call, bukan return data

### 2. Service Role Key
- **JANGAN** expose service role key dalam public code
- Guna environment variable atau secure storage
- Service role key boleh dapat dari: **Settings → API → service_role key**

### 3. Project Reference
- Boleh dapat dari Supabase Dashboard URL
- Atau dari Settings → API → Project URL
- Format: `https://<project-ref>.supabase.co`

---

## 🧪 VERIFY CRON JOB

1. **Check Cron Job Created:**
   ```sql
   SELECT * FROM cron.job WHERE jobname = 'subscription-transitions-hourly';
   ```

2. **Check Cron Job Runs:**
   ```sql
   SELECT * FROM cron.job_run_details 
   WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'subscription-transitions-hourly')
   ORDER BY start_time DESC 
   LIMIT 10;
   ```

3. **Manual Test:**
   - Trigger function manually via HTTP:
   ```bash
   curl -X POST https://<project-ref>.supabase.co/functions/v1/subscription-transitions \
     -H "Authorization: Bearer <anon-key>"
   ```

---

## 🔄 ALTERNATIVE: EXTERNAL CRON SERVICE

Jika `pg_cron` tidak available atau ada issues, boleh guna external cron service:

### cron-job.org atau EasyCron:
1. **URL:** `https://<project-ref>.supabase.co/functions/v1/subscription-transitions`
2. **Method:** POST
3. **Headers:**
   - `Authorization: Bearer <anon-key>`
   - `Content-Type: application/json`
4. **Schedule:** `0 * * * *` (every hour)

---

**Status:** Syntax fixed ✅ - Use `PERFORM` instead of `SELECT`
