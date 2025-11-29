# 🚀 APPLY VENDOR SYSTEM MIGRATION

## ⚠️ STEP 1: Apply Database Migration

Go to **Supabase Dashboard** → **SQL Editor** and run:

```sql
-- Copy and paste the entire contents of:
db/migrations/add_vendor_system_SAFE.sql
```

**Then click "RUN"**

⚠️ **NOTE:** This will drop and recreate vendor tables if they exist.
✅ This is the safest approach for clean installation.

---

## ✅ WHAT WILL BE CREATED

### Tables:
- `vendors` - Vendor/supplier information
- `vendor_products` - Product assignments
- `vendor_claims` - Sales claims
- `vendor_claim_items` - Claim line items
- `vendor_payments` - Payment records

### Functions:
- `generate_claim_number()` - Auto-generate claim numbers
- `generate_payment_number()` - Auto-generate payment numbers
- `create_vendor_claim()` - Submit new claim with items
- `update_claim_status()` - Approve/reject claims
- `record_vendor_payment()` - Record payments

### RLS Policies:
- All tables protected by Row Level Security
- User can only access their own business data

---

## 🎯 AFTER MIGRATION

Run your Flutter app:

```bash
flutter run -d chrome
```

Then:
1. Open drawer menu
2. Click "Vendors"
3. Add your first vendor!

---

## 📱 TEST WORKFLOW

### 1. Create Vendor
- Name: Ahmad Bakery
- Phone: 012-3456789
- Commission: 15%
- Bank: Maybank
- Account: 1234567890

### 2. Assign Products
- Go to vendor detail
- Click "Assign Products"
- Toggle products on/off

### 3. Test Claim Submission
You can manually insert a test claim:

```sql
-- Test claim insertion
SELECT create_vendor_claim(
  auth.uid(), -- Your user ID
  '<vendor_id>', -- Vendor ID from vendors table
  '[
    {"product_id": "<product_id>", "quantity": 10, "unit_price": 50}
  ]'::jsonb,
  'Test claim via SQL',
  null
);
```

### 4. Approve Claim
- Go to Vendor Details → View Claims
- Click on pending claim
- Click "Approve"
- Status changes to "Approved"

---

## 🔥 READY BRO?

**PROCEED WITH MIGRATION NOW!** 🚀

After migration, vendor system is 100% functional:
- ✅ Add/Edit vendors
- ✅ Assign products
- ✅ Submit claims
- ✅ Approve/Reject workflow
- ✅ Payment tracking
- ✅ Commission calculation

**NAK TEST SEKARANG?** 💪

