# 🏪 VENDOR/SUPPLIER SYSTEM - COMPLETE GUIDE

## ✅ WHAT'S BEEN CREATED

### 1️⃣ Database Schema (`add_vendor_system.sql`)
- **vendors** - Vendor information & commission settings
- **vendor_products** - Product assignments to vendors
- **vendor_claims** - Sales claims submitted by vendors
- **vendor_claim_items** - Individual products in claims
- **vendor_payments** - Payment tracking

### 2️⃣ Flutter Models
- `Vendor` - Vendor/supplier entity
- `VendorClaim` - Sales claim entity
- `VendorClaimItem` - Claim line items
- `VendorPayment` - Payment records

### 3️⃣ Repository (`VendorsRepositorySupabase`)
- Complete CRUD for vendors
- Product assignment logic
- Claim submission & approval
- Payment recording
- Summary calculations

### 4️⃣ UI Pages
- `VendorsPage` - List all vendors
- `AddVendorPage` - Create new vendor
- `VendorDetailPage` - View vendor details & summary
- `VendorClaimsPage` - Manage claims (approve/reject)
- `AssignProductsPage` - Link products to vendors

---

## 🚀 QUICK START

### Step 1: Apply Database Migration

```bash
# In Supabase SQL Editor, run:
db/migrations/add_vendor_system.sql
```

### Step 2: Add to Navigation

Update `lib/features/dashboard/presentation/home_page.dart`:

```dart
import '../../../features/vendors/presentation/vendors_page.dart';

// In drawer or quick actions:
ListTile(
  leading: Icon(Icons.store, color: AppColors.primary),
  title: const Text('Vendors'),
  onTap: () {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VendorsPage()),
    );
  },
),
```

---

## 📋 USER FLOW

### For Business Owner (Admin):

1. **Add Vendor**
   - Go to Vendors page
   - Tap + button
   - Fill in details (name, contact, commission rate, bank info)
   - Save

2. **Assign Products**
   - Open vendor details
   - Tap "Assign Products"
   - Toggle products on/off

3. **Review Claims**
   - Vendor submits claim
   - Admin receives notification (pending claims count)
   - Review claim details
   - Approve or Reject
   - Record payment when paying vendor

### For Vendor (Consignment Seller):

1. **Submit Sales Claim**
   - Log sales made
   - Attach proof (receipt/invoice photo)
   - Submit for review

2. **Track Status**
   - View claim status (Pending → Approved → Paid)
   - Check outstanding balance
   - View payment history

---

## 🎯 KEY FEATURES

### ✅ Commission Management
- Set default commission % per vendor
- Override commission % per product
- Auto-calculate commission on claims

### ✅ Claim Workflow
```
[Vendor Submits] → [Pending Review] → [Admin Approves/Rejects]
                                            ↓
                                      [Approved] → [Payment Recorded] → [Paid]
```

### ✅ Payment Tracking
- Record payments to vendors
- Link payment to multiple claims
- Track outstanding balance
- Bank details stored for reference

### ✅ Summary Dashboard
- Total sales by vendor
- Total commission earned
- Pending vs approved vs paid amounts
- Outstanding balance calculation

---

## 🔥 WHAT'S NEXT

### 📱 Vendor Mobile App (Optional)
Create separate vendor portal where vendors can:
- Submit claims
- View their products
- Check payment status
- View sales history

### 📊 Reports & Analytics
- Top performing vendors
- Commission trends
- Payment history reports
- Export to PDF/Excel

### 🔔 Notifications
- Alert admin when new claim submitted
- Notify vendor when claim approved/rejected
- Payment confirmation notifications

### 🤝 Integration
- Auto-create claims from POS sales
- Link to inventory (auto-deduct stock)
- Payment gateway integration

---

## 🎨 UI PREVIEW

### Vendors List
```
┌────────────────────────────────┐
│  🏪  Ahmad Bakery              │
│      📞 012-3456789            │
│      Commission: 15%           │
└────────────────────────────────┘
```

### Vendor Detail
```
┌──────────┐  ┌──────────┐
│ RM 5,000 │  │ RM 750   │
│ Sales    │  │ Comm.    │
└──────────┘  └──────────┘

┌──────────┐  ┌──────────┐
│ RM 500   │  │ RM 250   │
│ Paid     │  │ Due      │
└──────────┘  └──────────┘
```

### Claim Card
```
┌────────────────────────────────┐
│  CLAIM-20250129-0001  [Pending]│
│  Date: 29/1/2025               │
│  ──────────────────────────    │
│  Sales: RM 1,500               │
│  Commission: RM 225 (15%)      │
│  [Reject]  [Approve]           │
└────────────────────────────────┘
```

---

## 💡 BUSINESS LOGIC

### Commission Calculation
```typescript
commission = total_sales * (commission_rate / 100)

// Example:
// Sales: RM 1,000
// Rate: 15%
// Commission: RM 1,000 * 0.15 = RM 150
```

### Outstanding Balance
```typescript
outstanding = approved_commission - paid_amount

// Example:
// Approved: RM 750
// Paid: RM 500
// Outstanding: RM 250
```

---

## 🛡️ SECURITY

- **RLS Policies**: All tables protected by Row Level Security
- **Business Owner ID**: All records tied to authenticated user
- **No Cross-Business Access**: Vendors can only see their own business data

---

## 📱 INTEGRATION WITH OTHER MODULES

### With Products
- Assign specific products to vendors
- Track which products generate most commission

### With Sales
- Auto-create claims from POS sales (future)
- Link sales to vendor for commission tracking

### With Inventory
- Track vendor consignment stock
- Auto-deduct on sales

---

## 🚀 READY TO TEST!

**BRO NAK TEST SEKARANG?** 

1. Apply migration first
2. Run `flutter run -d chrome`
3. Add vendors
4. Assign products
5. Create test claims
6. Approve/reject workflow

**STATUS: 80% COMPLETE** ✅
- ✅ Database schema
- ✅ Models & repository
- ✅ Basic UI (admin side)
- ⏳ Vendor portal (future)
- ⏳ Reports (future)

**SIAP NAK PROCEED?** 🚀

