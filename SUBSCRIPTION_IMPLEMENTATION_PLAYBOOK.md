# 🧭 SUBSCRIPTION IMPLEMENTATION PLAYBOOK (POCKETBIZZ)

## 🎯 GOAL

Bukan "cantik atas kertas", tapi:

* ❌ tak bocor revenue
* ❌ tak marahkan user
* ❌ tak rosakkan core bisnes logic
* ✅ senang maintain
* ✅ senang scale

---

## ✅ PROGRESS TRACKING

### PHASE 0 — TETAPKAN "LAW OF THE LAND" (WAJIB)
- [x] **COMPLETED**: Single Source of Truth established
  - DB is source of truth
  - Backend validates all status
  - App reads from DB only

### PHASE 1 — BETULKAN ACCESS CONTROL (CRITICAL 🔥)
- [x] **COMPLETED**: SubscriptionGuard uses `isActive` (includes grace period)
  - ✅ Already correct: `subscription.isActive` includes trial + active + grace
  - ✅ Grace period users have access

### PHASE 2 — SOFT BLOCK, BUKAN HARD BLOCK
- [x] **COMPLETED**: Universal `requirePro()` wrapper created
  - ✅ Shows upgrade modal instead of hard blocking
  - ✅ Location: `lib/features/subscription/widgets/subscription_guard.dart`
  - ⚠️ **TODO**: Apply to all create/edit/delete operations

### PHASE 3 — ENFORCE USAGE LIMIT (REVENUE LEAK STOPPER)
- [x] **COMPLETED**: Enforcement checks added
  - [x] Product creation ✅
  - [x] Stock creation ✅
  - [x] Sales creation ✅
  - [x] `SubscriptionLimitException` class created ✅
  - [x] UI upgrade prompts added to all creation pages ✅

### PHASE 4 — FIX TIME & DATE (SENYAP TAPI BAHAYA)
- [x] **COMPLETED**: Calendar months calculation
  - ✅ `_addCalendarMonths()` method already implemented correctly
  - ✅ Used in all subscription creation/extend operations
  - ✅ Handles end-of-month edge cases (Jan 31 + 1 month = Feb 28/29)

### PHASE 5 — TRIAL RULE = SEKALI SEUMUR HIDUP
- [x] **COMPLETED**: Trial reuse prevention implemented
  - [x] Database migration exists (`2025-12-17_fix_subscription_critical_issues.sql`) ✅
  - [x] `startTrial()` logic checks `has_ever_had_trial` flag ✅
  - [x] Prevents trial reuse correctly ✅

### PHASE 6 — GRACE & EXPIRY JANGAN DALAM READ
- [x] **COMPLETED**: Moved to cron job
  - [x] Edge Function created (`subscription-transitions`) ✅
  - [x] Removed from `getUserSubscription()` ✅
  - [x] `_applyGraceTransitions()` method deprecated ✅
  - ⚠️ **TODO**: Schedule cron job (manual setup required in Supabase Dashboard)

### PHASE 7 — PAYMENT = STRICT & PARANOID
- [x] **COMPLETED**: Strict webhook validation added
  - [x] Currency validation (MYR only) ✅
  - [x] Amount validation (strict with 50 sen tolerance) ✅
  - [x] Idempotency checks (reject duplicate completed payments) ✅
  - [x] Prorated payment detection for amount validation ✅

### PHASE 8 — AUTO RENEW (BILA READY)
- [x] **COMPLETED**: Auto-renewal implementation
  - [x] Edge Function created (`subscription-auto-renew`) ✅
  - [x] Auto-renewal enabled by default for all paid subscriptions ✅
  - [x] Webhook preserves `auto_renew` flag when extending ✅
  - [x] Creates pending payment 3 days before expiry ✅
  - ⚠️ **TODO**: Schedule cron job (daily) and integrate BCL.my payment link creation

### PHASE 9 — FILE & CODE HYGIENE
- [ ] **PENDING**: Split large files
  - [ ] Split `subscription_repository_supabase.dart` (2284 lines)
  - [ ] Split `subscription_page.dart` (2131 lines)

### PHASE 10 — DEPLOYMENT CHECKLIST
- [ ] **PENDING**: All tests before production

---

## 📋 IMPLEMENTATION DETAILS

### Phase 2: Universal Wrapper

**Location:** `lib/features/subscription/widgets/subscription_guard.dart`

**Usage:**
```dart
await requirePro(context, 'Tambah Produk', () async {
  // Your create/edit/delete logic here
  await productRepository.createProduct(...);
});
```

**Features:**
- Shows upgrade modal instead of hard blocking
- Supports expired users (read-only mode)
- Clear action name in modal

**Next Steps:**
- Apply to all create/edit/delete operations:
  - Product creation
  - Stock creation
  - Sales creation
  - Vendor creation
  - Supplier creation
  - Delivery creation
  - Claim creation

### Phase 3: Usage Limit Enforcement

**Pattern:**
```dart
// Before creating product
final limits = await subscriptionService.getPlanLimits();

if (!limits.products.isUnlimited &&
    limits.products.current >= limits.products.max) {
  throw SubscriptionLimitException(
    'Had produk telah dicapai. Upgrade untuk teruskan.'
  );
}
```

**Enforcement Points:**
1. **Product Creation** - `lib/features/products/presentation/add_product_page.dart`
2. **Stock Creation** - `lib/features/stock/presentation/stock_page.dart`
3. **Sales Creation** - `lib/features/sales/presentation/create_sale_page_enhanced.dart`

**Exception Class:**
```dart
class SubscriptionLimitException implements Exception {
  final String message;
  SubscriptionLimitException(this.message);
  
  @override
  String toString() => message;
}
```

### Phase 4: Calendar Months ✅

**Status:** Already implemented correctly

**Method:** `_addCalendarMonths(DateTime date, int months)`
- Handles end-of-month edge cases
- Used in all subscription operations
- No fixed 30-day calculations found

### Phase 5: Trial Reuse Prevention

**Database Migration:**
```sql
ALTER TABLE subscriptions
ADD COLUMN IF NOT EXISTS has_ever_had_trial BOOLEAN DEFAULT FALSE;
```

**Logic Update:**
```dart
// In startTrial()
if (user.hasEverHadTrial) {
  throw Exception('Trial hanya sekali sahaja. Sila langgan untuk teruskan.');
}
```

### Phase 6: Grace/Expiry Transitions

**Current Issue:**
- `_applyGraceTransitions()` called on every `getUserSubscription()` read
- Updates DB on read (write operation)
- Performance concern

**Solution:**
- Create Edge Function: `subscription-transitions`
- Schedule cron job (every hour)
- Remove from `getUserSubscription()`

### Phase 7: Webhook Validation

**Required Checks:**
```typescript
// In webhook handler
if (paid_amount !== subscription.total_amount) {
  reject('Amount mismatch');
}

if (currency !== 'MYR') {
  reject('Invalid currency');
}

if (payment.status === 'completed' && already_processed) {
  return 200; // Idempotent
}
```

---

## 🚀 NEXT ACTIONS

### Immediate (This Week)
1. ✅ Verify Phase 1 (SubscriptionGuard) - DONE
2. ✅ Create Phase 2 wrapper - DONE
3. ⏳ Apply Phase 2 wrapper to all create/edit/delete operations
4. ⏳ Implement Phase 3 (usage limit enforcement)
5. ⏳ Add Phase 5 (trial reuse prevention)

### Short-term (Next Week)
6. ⏳ Phase 6 (move transitions to cron)
7. ⏳ Phase 7 (webhook validation)
8. ⏳ Phase 9 (split large files)

### Long-term
9. ⏳ Phase 8 (auto-renewal)
10. ⏳ Phase 10 (comprehensive testing)

---

**Last Updated:** 2025-01-16  
**Status:** Phase 1-2 Complete, Phase 3-10 Pending

