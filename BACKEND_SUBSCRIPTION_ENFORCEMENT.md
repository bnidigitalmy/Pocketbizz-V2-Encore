# 🔐 BACKEND SUBSCRIPTION ENFORCEMENT

**Date:** 2025-01-16  
**Status:** ✅ Migration Created | ⚠️ Needs Deployment

---

## 📋 OVERVIEW

Backend enforcement untuk subscription checks di database level. Ini adalah **CRITICAL** untuk security kerana:

- ✅ UI protection sudah ada (requirePro())
- ❌ Backend enforcement belum ada
- ⚠️ **Risk:** Users boleh bypass UI dengan direct API calls

---

## 🎯 IMPLEMENTATION

### 1. Database Functions

**File:** `db/migrations/2025-01-16_backend_subscription_enforcement.sql`

#### Function: `check_subscription_active(user_uuid UUID)`
- Checks if user has active subscription (active, trial, grace)
- Returns `BOOLEAN`
- Uses `SECURITY DEFINER` untuk bypass RLS

#### Function: `enforce_subscription_on_insert()`
- Trigger function untuk INSERT operations
- Checks subscription before allowing insert
- Raises exception if subscription not active

#### Function: `enforce_subscription_on_update()`
- Trigger function untuk UPDATE operations
- Checks subscription before allowing update
- Raises exception if subscription not active

---

### 2. Database Triggers

Triggers applied to critical tables:

1. **products** - INSERT, UPDATE
2. **stock_items** - INSERT, UPDATE
3. **sales** - INSERT
4. **production_batches** - INSERT
5. **expenses** - INSERT
6. **bookings** - INSERT
7. **deliveries** - INSERT
8. **consignment_claims** - INSERT
9. **stock_movements** - INSERT (for bulk operations)
10. **shopping_cart_items** - INSERT (for bulk add)

---

### 3. Edge Functions (Supabase)

**Status:** ⚠️ **PENDING** - Need to add subscription checks

#### Files to Update:
- `supabase/functions/OCR-Cloud-Vision/index.ts`
- `supabase/functions/bcl-webhook/index.ts` (already has checks)
- Any other Edge Functions that create/update data

#### Example Pattern:

```typescript
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

async function checkSubscription(supabase: any, userId: string): Promise<boolean> {
  const { data, error } = await supabase
    .from("subscriptions")
    .select("status, expires_at")
    .eq("user_id", userId)
    .in("status", ["active", "trial", "grace"])
    .gt("expires_at", new Date().toISOString())
    .order("created_at", { ascending: false })
    .limit(1)
    .single();

  return data !== null && !error;
}

// Use in function
serve(async (req) => {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  );

  const token = authHeader.replace("Bearer ", "");
  const { data: { user }, error: authError } = await supabase.auth.getUser(token);
  
  if (authError || !user) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
  }

  // Check subscription
  const hasActiveSubscription = await checkSubscription(supabase, user.id);
  if (!hasActiveSubscription) {
    return new Response(
      JSON.stringify({ 
        error: "Subscription required",
        message: "User does not have active subscription. Please renew your subscription to continue."
      }),
      { status: 403 }
    );
  }

  // Continue with function logic...
});
```

---

## 🚀 DEPLOYMENT STEPS

### Step 1: Apply Database Migration

```bash
# Run in Supabase SQL Editor
psql -f db/migrations/2025-01-16_backend_subscription_enforcement.sql
```

Or via Supabase Dashboard:
1. Go to SQL Editor
2. Copy contents of `db/migrations/2025-01-16_backend_subscription_enforcement.sql`
3. Run migration

### Step 2: Test Backend Enforcement

```sql
-- Test 1: Try to insert product as expired user
-- Should fail with: "Subscription required: User does not have active subscription"

-- Test 2: Try to update product as expired user
-- Should fail with: "Subscription required: User does not have active subscription"

-- Test 3: Try to insert sale as expired user
-- Should fail with: "Subscription required: User does not have active subscription"
```

### Step 3: Update Edge Functions

1. Add subscription check to `OCR-Cloud-Vision` function
2. Verify `bcl-webhook` already has checks
3. Test Edge Functions with expired user

---

## ⚠️ IMPORTANT NOTES

### What is Blocked:
- ✅ INSERT operations (create new data)
- ✅ UPDATE operations (modify existing data)

### What is NOT Blocked:
- ✅ SELECT operations (read-only mode for expired users)
- ✅ DELETE operations (users can still delete their own data)

### Exceptions:
- If you need to allow certain operations for expired users, modify the trigger function
- Add conditions to check specific tables/operations

---

## 🔒 SECURITY BENEFITS

1. **Prevents API Bypass:** Users cannot bypass UI checks with direct API calls
2. **Database-Level Enforcement:** Even if frontend is modified, backend enforces subscription
3. **Consistent Behavior:** Same rules apply across all access methods
4. **Audit Trail:** All blocked attempts are logged in database

---

## 📝 TESTING CHECKLIST

- [ ] Test INSERT with expired user → Should fail
- [ ] Test UPDATE with expired user → Should fail
- [ ] Test SELECT with expired user → Should succeed (read-only)
- [ ] Test DELETE with expired user → Should succeed (can delete own data)
- [ ] Test with active user → Should succeed
- [ ] Test with trial user → Should succeed
- [ ] Test with grace user → Should succeed
- [ ] Test Edge Functions with expired user → Should return 403

---

**Status:** ✅ Migration Ready | ⚠️ Needs Deployment & Testing  
**Priority:** 🔴 **CRITICAL** - Must deploy before production



