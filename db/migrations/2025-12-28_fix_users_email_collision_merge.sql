-- ============================================================================
-- Fix: Merge public.users rows by email when auth.users.id differs
-- ============================================================================
-- Symptom:
--   - auth.users has user with email E and id = NEW_ID
--   - public.users already has email E but id = OLD_ID (created without auth id)
--   - Because users.email is UNIQUE, handle_new_user/backfill cannot insert NEW_ID row.
--   - Result: profile missing for NEW_ID → FK failures (stock_items_business_owner_id_fkey)
--
-- Fix strategy:
--   1) Re-key ALL foreign key references that point to public.users(id):
--      update any FK column referencing users(id) from OLD_ID → NEW_ID.
--   2) Delete OLD_ID row from public.users.
--   3) Upsert NEW_ID row into public.users with same email/name/phone.
--   4) Update handle_new_user profile creation to auto-merge on unique(email) conflicts.
--
-- Safe assumptions:
--   - Supabase Auth enforces unique email in auth.users, so (email) identifies the person.
--   - Any existing business data attached to OLD_ID should be owned by that email owner.
--
-- IMPORTANT:
--   Run this in Supabase SQL Editor (Role: postgres).
-- ============================================================================

BEGIN;

-- 1) Helper: re-key all FK references to public.users(id)
CREATE OR REPLACE FUNCTION public.rekey_users_fks(old_id UUID, new_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  r RECORD;
BEGIN
  IF old_id IS NULL OR new_id IS NULL OR old_id = new_id THEN
    RETURN;
  END IF;

  FOR r IN
    SELECT
      c.conrelid::regclass AS tbl,
      a.attname AS col
    FROM pg_constraint c
    JOIN pg_class cl ON cl.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = cl.relnamespace
    JOIN unnest(c.conkey) WITH ORDINALITY AS ck(attnum, ord) ON TRUE
    JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ck.attnum
    WHERE c.contype = 'f'
      AND c.confrelid = 'public.users'::regclass
      AND n.nspname = 'public'
  LOOP
    EXECUTE format('UPDATE %s SET %I = $1 WHERE %I = $2', r.tbl, r.col, r.col)
    USING new_id, old_id;
  END LOOP;
END;
$$;

-- 2) Merge a single email collision (public.users.email is unique)
CREATE OR REPLACE FUNCTION public.merge_users_by_email(auth_user_id UUID, user_email TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  old_id UUID;
  v_full_name TEXT;
  v_phone TEXT;
BEGIN
  IF auth_user_id IS NULL OR user_email IS NULL OR user_email = '' THEN
    RETURN;
  END IF;

  -- If already aligned, nothing to do.
  IF EXISTS (SELECT 1 FROM public.users WHERE id = auth_user_id AND email = user_email) THEN
    RETURN;
  END IF;

  -- Find the conflicting row (same email, different id)
  SELECT id, full_name, phone
  INTO old_id, v_full_name, v_phone
  FROM public.users
  WHERE email = user_email
  ORDER BY created_at ASC
  LIMIT 1;

  IF old_id IS NULL THEN
    RETURN;
  END IF;

  -- Re-key all FKs: OLD_ID → auth_user_id
  PERFORM public.rekey_users_fks(old_id, auth_user_id);

  -- Remove old user row and upsert correct one (preserve name/phone if present)
  DELETE FROM public.users WHERE id = old_id;

  INSERT INTO public.users (id, email, full_name, phone, created_at, updated_at)
  VALUES (
    auth_user_id,
    user_email,
    v_full_name,
    v_phone,
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = COALESCE(EXCLUDED.full_name, users.full_name),
    phone = COALESCE(EXCLUDED.phone, users.phone),
    updated_at = NOW();
END;
$$;

-- 3) Patch ensure_user_profile_for_user to auto-merge on unique(email) conflicts
--    (defined in 2025-12-28_fix_users_profile_trigger_and_backfill.sql)
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
  cols TEXT := 'id,email';
  vals TEXT := '$1,$2';
  updates TEXT := 'email = EXCLUDED.email';
  v_full_name TEXT;
BEGIN
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

  v_full_name := COALESCE(NULLIF(user_full_name, ''), user_email);

  IF has_full_name THEN
    cols := cols || ',full_name';
    vals := vals || ',$3';
    updates := updates || ', full_name = COALESCE(EXCLUDED.full_name, users.full_name)';
  ELSIF has_name THEN
    cols := cols || ',name';
    vals := vals || ',$3';
    updates := updates || ', name = COALESCE(EXCLUDED.name, users.name)';
  END IF;

  IF has_phone THEN
    cols := cols || ',phone';
    vals := vals || ',$4';
    updates := updates || ', phone = COALESCE(EXCLUDED.phone, users.phone)';
  END IF;

  IF has_created_at THEN
    cols := cols || ',created_at';
    vals := vals || ',NOW()';
  END IF;

  IF has_updated_at THEN
    cols := cols || ',updated_at';
    vals := vals || ',NOW()';
    updates := updates || ', updated_at = NOW()';
  END IF;

  BEGIN
    EXECUTE 'INSERT INTO public.users (' || cols || ') VALUES (' || vals || ')
             ON CONFLICT (id) DO UPDATE SET ' || updates
    USING user_uuid, user_email, v_full_name, user_phone;
  EXCEPTION
    WHEN unique_violation THEN
      -- Most common: unique(email) collision with an orphaned public.users row.
      PERFORM public.merge_users_by_email(user_uuid, user_email);
      -- Retry insert now that collision should be resolved.
      EXECUTE 'INSERT INTO public.users (' || cols || ') VALUES (' || vals || ')
               ON CONFLICT (id) DO UPDATE SET ' || updates
      USING user_uuid, user_email, v_full_name, user_phone;
  END;
END;
$$;

-- 4) Backfill: merge any existing email collisions between auth.users and public.users
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT au.id AS auth_id, au.email
    FROM auth.users au
    JOIN public.users pu ON pu.email = au.email
    WHERE pu.id <> au.id
  LOOP
    BEGIN
      PERFORM public.merge_users_by_email(r.auth_id, r.email);
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Email-merge failed for % (%): %', r.email, r.auth_id, SQLERRM;
    END;
  END LOOP;
END;
$$;

COMMIT;


