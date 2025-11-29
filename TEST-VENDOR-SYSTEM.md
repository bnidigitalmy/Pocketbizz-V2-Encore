# 🧪 TEST VENDOR SYSTEM - QUICK GUIDE

## ✅ MIGRATION DONE! NOW TEST:

### 🔥 **Step 1: Open Vendor Page**
1. App should be loading...
2. Click **☰ Drawer Menu** (top-left)
3. Click **"Vendors"** (with 🏪 icon)

---

### 🔥 **Step 2: Add First Vendor**
1. Click **+ Add Vendor** button (bottom-right)
2. Fill in details:

**Basic Info:**
- Name: `Ahmad Bakery`
- Email: `ahmad@bakery.com`
- Phone: `012-3456789`
- Address: `Jalan Merdeka, KL`

**Commission:**
- Rate: `15` (15%)

**Bank Details:**
- Bank Name: `Maybank`
- Account Number: `1234567890`
- Account Holder: `Ahmad bin Ali`

3. Click **"Save Vendor"**
4. Should see success message! ✅

---

### 🔥 **Step 3: Assign Products to Vendor**
1. Click on **Ahmad Bakery** from vendor list
2. You should see:
   - Summary cards (Total Sales: RM 0, Commission: RM 0)
   - Contact info
   - Quick actions
3. Click **"Assign Products"**
4. Toggle ON some products (e.g., your existing products)
5. Should see "Product assigned!" message ✅

---

### 🔥 **Step 4: View Vendor Summary**
Go back to vendor detail page and you should see:
- Total Sales: RM 0.00
- Total Commission: RM 0.00
- Paid: RM 0.00
- Outstanding: RM 0.00

---

### 🔥 **Step 5: Test Claim Submission (Manual)**

Since vendor portal doesn't exist yet, let's test with SQL:

Go to **Supabase Dashboard → SQL Editor** and run:

```sql
-- Get your user ID first
SELECT id FROM auth.users WHERE email = 'admin@pocketbizz.my';
-- Copy the UUID

-- Get vendor ID
SELECT id FROM vendors WHERE name = 'Ahmad Bakery';
-- Copy the UUID

-- Get a product ID
SELECT id FROM products LIMIT 1;
-- Copy the UUID

-- Now create a test claim:
SELECT create_vendor_claim(
  '<YOUR_USER_ID>'::UUID,  -- Replace with your user ID
  '<VENDOR_ID>'::UUID,      -- Replace with Ahmad Bakery's ID
  '[
    {"product_id": "<PRODUCT_ID>", "quantity": 10, "unit_price": 50}
  ]'::jsonb,
  'Test claim - Week 1 sales',
  null
);
```

---

### 🔥 **Step 6: View & Approve Claim**

Back in the app:
1. Go to **Vendor Detail** → **Ahmad Bakery**
2. Click **"View Claims"**
3. You should see the test claim:
   - Status: **Pending**
   - Sales: RM 500
   - Commission: RM 75 (15%)
4. Click **"Approve"** button
5. Confirm approval
6. Status should change to **"Approved"** ✅

---

### 🔥 **Step 7: Check Summary Again**

Go back to **Vendor Detail**:
- Total Sales: RM 500.00
- Total Commission: RM 75.00
- Paid: RM 0.00
- Outstanding: RM 75.00 ✅

---

## 🎯 **EXPECTED RESULTS:**

✅ Vendor created successfully  
✅ Products assigned to vendor  
✅ Claim submitted (via SQL)  
✅ Claim visible in app  
✅ Approve/reject buttons work  
✅ Summary calculations correct  
✅ Status changes reflected  

---

## 🐛 **IF YOU SEE ERRORS:**

### Error: "Table vendors does not exist"
- Migration didn't run properly
- Re-run: `db/migrations/add_vendor_system_SAFE.sql`

### Error: "Navigation error"
- Restart the app: `Ctrl+C` then `flutter run -d chrome`

### Error: "RLS policy violation"
- Make sure you're logged in as admin@pocketbizz.my

---

## 🎨 **WHAT YOU SHOULD SEE:**

### Vendors List:
```
┌────────────────────────────────────┐
│ 🏪  Ahmad Bakery                   │
│     📞 012-3456789                 │
│     ✉️  ahmad@bakery.com           │
│     💰 Commission: 15.0%           │
└────────────────────────────────────┘
```

### Vendor Detail - Summary:
```
┌──────────┬──────────┐
│ RM 500   │ RM 75    │
│ Sales    │ Comm.    │
└──────────┴──────────┘
┌──────────┬──────────┐
│ RM 0     │ RM 75    │
│ Paid     │ Due      │
└──────────┴──────────┘
```

### Claims List:
```
┌────────────────────────────────────┐
│ CLAIM-20250129-0001    [Approved]  │
│ Date: 29/1/2025                    │
│ ────────────────────────           │
│ Sales: RM 500.00                   │
│ Commission: RM 75.00 (15%)         │
└────────────────────────────────────┘
```

---

## 🚀 **READY TO TEST BRO?**

**FOLLOW THE STEPS ABOVE!** 💪

When done testing, tell me:
1. ✅ All working?
2. 🐛 Any errors?
3. 💡 What feature next?

**LET'S GO!** 🔥

