-- Fix consignment claim_number uniqueness + generation to be per business_owner_id
-- ============================================================================
-- Why:
-- - Current schema: consignment_claims.claim_number is globally UNIQUE.
-- - Desired: claim_number should be unique per business_owner_id (multi-tenant).
-- - Also fix race-condition when multiple claims created concurrently.
--
-- This migration:
-- 1) Drops global UNIQUE constraint/index on claim_number (if exists)
-- 2) Adds composite UNIQUE (business_owner_id, claim_number)
-- 3) Replaces generate_claim_number() with generate_claim_number(p_owner_id UUID)
--    using advisory lock keyed by owner + YYYYMM.
-- 4) Updates trigger set_claim_number() to call the new function using NEW.business_owner_id.
-- ============================================================================

BEGIN;

-- 1) Drop global unique constraint/index (names vary depending on how it was created)
DO $$
BEGIN
  -- Drop constraint if it exists
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.consignment_claims'::regclass
      AND contype = 'u'
      AND conname IN ('consignment_claims_claim_number_key', 'consignment_claims_claim_number_unique')
  ) THEN
    ALTER TABLE public.consignment_claims
      DROP CONSTRAINT IF EXISTS consignment_claims_claim_number_key;
    ALTER TABLE public.consignment_claims
      DROP CONSTRAINT IF EXISTS consignment_claims_claim_number_unique;
  END IF;

  -- Drop any unique index on claim_number (safe if it doesn't exist)
  IF EXISTS (
    SELECT 1
    FROM pg_indexes
    WHERE schemaname = 'public'
      AND tablename = 'consignment_claims'
      AND indexname IN ('idx_claims_number', 'consignment_claims_claim_number_idx', 'consignment_claims_claim_number_key')
  ) THEN
    DROP INDEX IF EXISTS public.idx_claims_number;
    DROP INDEX IF EXISTS public.consignment_claims_claim_number_idx;
    DROP INDEX IF EXISTS public.consignment_claims_claim_number_key;
  END IF;
END $$;

-- 2) Add composite uniqueness (per owner)
CREATE UNIQUE INDEX IF NOT EXISTS idx_claims_owner_number
  ON public.consignment_claims (business_owner_id, claim_number);

-- 3) Replace generator: per owner + month + advisory lock
DROP FUNCTION IF EXISTS public.generate_claim_number();
DROP FUNCTION IF EXISTS public.generate_claim_number(UUID);

CREATE OR REPLACE FUNCTION public.generate_claim_number(p_owner_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_prefix TEXT := 'CLM';
  v_year TEXT := TO_CHAR(NOW(), 'YY');
  v_month TEXT := TO_CHAR(NOW(), 'MM');
  v_seq_num INTEGER;
  v_claim_number TEXT;
  v_lock_key BIGINT;
BEGIN
  -- Advisory lock key: hash(owner) + YYYYMM to avoid cross-tenant contention
  v_lock_key := (
    (ABS(hashtextextended(p_owner_id::text, 0))::bigint << 16)
    + (TO_CHAR(NOW(), 'YYYYMM')::bigint)
  );
  PERFORM pg_advisory_xact_lock(v_lock_key);

  SELECT COALESCE(MAX(CAST(SUBSTRING(claim_number FROM '[0-9]+$') AS INTEGER)), 0) + 1
    INTO v_seq_num
    FROM public.consignment_claims
   WHERE business_owner_id = p_owner_id
     AND claim_number LIKE (v_prefix || '-' || v_year || v_month || '-%');

  v_claim_number := v_prefix || '-' || v_year || v_month || '-' || LPAD(v_seq_num::TEXT, 4, '0');
  RETURN v_claim_number;
END;
$$ LANGUAGE plpgsql;

-- 4) Update trigger function to use new generator
CREATE OR REPLACE FUNCTION public.set_claim_number()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.claim_number IS NULL OR NEW.claim_number = '' THEN
    NEW.claim_number := public.generate_claim_number(NEW.business_owner_id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Ensure trigger exists (create if missing)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'trigger_set_claim_number'
  ) THEN
    CREATE TRIGGER trigger_set_claim_number
      BEFORE INSERT ON public.consignment_claims
      FOR EACH ROW
      EXECUTE FUNCTION public.set_claim_number();
  END IF;
END $$;

COMMIT;


