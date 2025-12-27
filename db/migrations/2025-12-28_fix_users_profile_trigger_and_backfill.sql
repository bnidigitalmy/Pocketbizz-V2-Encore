-- ============================================================================
-- Fix: public.users profile auto-creation + backfill missing profiles
-- ============================================================================
-- Symptom:
--   INSERT into stock_items fails:
--     violates foreign key stock_items_business_owner_id_fkey
--     Key is not present in table "users"
--
-- Root cause:
--   Some new auth users do not get a matching row in public.users.
--   Most commonly: trigger function `public.handle_new_user()` fails due to
--   schema mismatch (e.g., users table doesn't have expected columns like
--   full_name/phone/updated_at), and error is swallowed.
--
-- Fix:
--   1) Add resilient SECURITY DEFINER function to upsert into public.users
--      using only columns that actually exist.
--   2) Update `public.handle_new_user()` to call it (and keep trial creation).
--   3) Ensure trigger exists.
--   4) Backfill missing public.users rows for existing auth.users.
-- ============================================================================

BEGIN;

-- Resilient profile upsert that adapts to public.users schema
CREATE OR REPLACE FUNCTION public.ensure_user_profile_for_user(
  user_uuid UUID,
  user_email TEXT,
  user_full_name TEXT,
  user_phone TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  has_full_name BOOLEAN;
  has_name BOOLEAN;
  has_phone BOOLEAN;
  has_created_at BOOLEAN;
  has_updated_at BOOLEAN;
  full_name_required BOOLEAN := FALSE;
  name_required BOOLEAN := FALSE;
  cols TEXT := 'id,email';
  vals TEXT := '$1,$2';
  updates TEXT := 'email = EXCLUDED.email';
  v_full_name TEXT;
BEGIN
  -- Detect columns on public.users
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'full_name'
  ) INTO has_full_name;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'name'
  ) INTO has_name;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'phone'
  ) INTO has_phone;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'created_at'
  ) INTO has_created_at;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'updated_at'
  ) INTO has_updated_at;

  -- Determine if full_name/name is required (NOT NULL)
  IF has_full_name THEN
    SELECT (is_nullable = 'NO')
    INTO full_name_required
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'full_name'
    LIMIT 1;
  END IF;

  IF has_name THEN
    SELECT (is_nullable = 'NO')
    INTO name_required
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'name'
    LIMIT 1;
  END IF;

  v_full_name := COALESCE(NULLIF(user_full_name, ''), user_email);

  -- Prefer full_name if available, otherwise name.
  IF has_full_name THEN
    cols := cols || ',full_name';
    vals := vals || ',$3';
    updates := updates || ', full_name = COALESCE(EXCLUDED.full_name, users.full_name)';
  ELSIF has_name THEN
    cols := cols || ',name';
    vals := vals || ',$3';
    updates := updates || ', name = COALESCE(EXCLUDED.name, users.name)';
  ELSE
    -- If schema requires full_name/name but column missing, we cannot satisfy it.
    -- (This should not happen; kept for safety.)
    IF full_name_required OR name_required THEN
      RAISE EXCEPTION 'public.users schema requires name/full_name but column is missing';
    END IF;
  END IF;

  IF has_phone THEN
    cols := cols || ',phone';
    vals := vals || ',$4';
    updates := updates || ', phone = COALESCE(EXCLUDED.phone, users.phone)';
  END IF;

  IF has_created_at THEN
    cols := cols || ',created_at';
    vals := vals || ',NOW()';
    -- no update for created_at
  END IF;

  IF has_updated_at THEN
    cols := cols || ',updated_at';
    vals := vals || ',NOW()';
    updates := updates || ', updated_at = NOW()';
  END IF;

  EXECUTE 'INSERT INTO public.users (' || cols || ') VALUES (' || vals || ')
           ON CONFLICT (id) DO UPDATE SET ' || updates
  USING user_uuid, user_email, v_full_name, user_phone;
END;
$$;

-- Ensure handle_new_user() calls resilient profile upsert + trial ensure
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  user_phone TEXT;
BEGIN
  user_phone := NEW.raw_user_meta_data->>'phone';

  -- 1) Ensure profile row exists (never block signup)
  BEGIN
    PERFORM public.ensure_user_profile_for_user(
      NEW.id,
      NEW.email,
      COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
      user_phone
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Failed to ensure user profile for user %: %', NEW.id, SQLERRM;
  END;

  -- 2) Ensure trial subscription exists (never block signup)
  BEGIN
    -- This function is created in earlier migration (2025-12-27_auto_create_trial_on_new_user.sql)
    PERFORM public.ensure_trial_subscription_for_user(NEW.id);
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Failed to create trial subscription for user %: %', NEW.id, SQLERRM;
  END;

  -- 3) Optional: sync phone to auth.users (best-effort)
  IF user_phone IS NOT NULL AND user_phone != '' THEN
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM auth.users
        WHERE phone = user_phone
          AND id != NEW.id
      ) THEN
        UPDATE auth.users
        SET phone = user_phone,
            updated_at = NOW()
        WHERE id = NEW.id;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Failed to update auth.users.phone for user %: %', NEW.id, SQLERRM;
    END;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensure trigger exists and points to latest handle_new_user()
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Backfill missing public.users rows for any existing auth.users
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT au.id, au.email, au.raw_user_meta_data->>'full_name' AS full_name, au.raw_user_meta_data->>'phone' AS phone
    FROM auth.users au
    LEFT JOIN public.users pu ON pu.id = au.id
    WHERE pu.id IS NULL
  LOOP
    BEGIN
      PERFORM public.ensure_user_profile_for_user(
        r.id,
        r.email,
        COALESCE(r.full_name, r.email),
        r.phone
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Backfill failed for user %: %', r.id, SQLERRM;
    END;
  END LOOP;
END;
$$;

COMMIT;


