# 🔍 OLD POCKETBIZZ REPO - FEATURE FLOW ANALYSIS

Based on: https://github.com/bnidigitalmy/pocketbizz

---

## 📂 **REPOSITORY STRUCTURE**

```
pocketbizz/
├── client/           # React frontend
├── server/           # Express.js backend
├── packages/core/    # Shared code
├── migrations/       # Drizzle ORM migrations
├── shared/          # Common utilities
├── scripts/         # Helper scripts
└── tests/           # Test files
```

### **Tech Stack (OLD):**
- Frontend: React
- Backend: Express.js + Node.js
- Database: PostgreSQL (Drizzle ORM)
- Payment: Stripe (mentioned in docs)
- Cache: Redis (likely)
- Email: Nodemailer
- WhatsApp: Twilio/similar

---

## 🎯 **KEY FEATURES TO PORT**

Based on the documentation files I found:

### **1. VENDOR/SUPPLIER SYSTEM** 🏪

From `VENDOR_CLAIM_SYSTEM.md` and `VENDOR_SYSTEM_BUGFIX_REPORT.md`:

**Core Flow:**
```
1. Admin creates Vendor account
2. Vendor gets login credentials
3. Vendor can:
   ✅ View their assigned products
   ✅ Submit claims (sales report)
   ✅ Upload proof of sales
   ✅ Track commission/payments
   ✅ View claim history
   
4. Admin can:
   ✅ Approve/reject claims
   ✅ View vendor performance
   ✅ Manage commission rates
   ✅ Process payments
```

**Key Tables:**
```sql
- vendors (id, name, contact, commission_rate)
- vendor_products (vendor_id, product_id)
- vendor_claims (vendor_id, amount, status, proof_url)
- vendor_payments (vendor_id, amount, paid_date)
```

**Business Logic:**
- Vendor submits claim → Admin reviews → Approve → Payment
- Commission calculated automatically
- SMS/Email notifications on status change

---

### **2. PAYMENT SYSTEM** 💳

From `TOYYIBPAY_SETUP.md` and `USER_PAYMENT_FLOW.md`:

**Flow:**
```
1. User selects subscription plan
2. Redirects to ToyyibPay gateway
3. User pays via:
   ✅ FPX (Online banking)
   ✅ Credit/Debit card
   ✅ eWallet
   
4. Callback to PocketBizz
5. Verify payment
6. Activate subscription
7. Send confirmation email
```

**Key Features:**
- Recurring billing (monthly/yearly)
- Payment status tracking
- Invoice generation
- Auto-renewal
- Grace period on failure

**ToyyibPay Integration:**
```typescript
// Create bill
POST https://toyyibpay.com/index.php/api/createBill

// Check status
POST https://toyyibpay.com/index.php/api/getBillTransactions

// Callback endpoint
POST /api/payments/toyyibpay/callback
```

---

### **3. ADMIN PANEL** 👑

From `ADMIN_UI_CONSISTENCY_UPDATE.md`:

**Admin Features:**
```
✅ User Management
   - View all users
   - Activate/deactivate accounts
   - Assign subscriptions
   - Reset passwords

✅ Business Management
   - View all businesses
   - Moderate content
   - Support tickets
   - Analytics

✅ Vendor Management
   - Approve vendors
   - Set commission rates
   - Process claims
   - Payment reports

✅ System Settings
   - App configuration
   - Email templates
   - Payment gateway settings
   - Feature flags
```

**Access Control:**
```sql
users (
  role: 'admin' | 'business_owner' | 'vendor'
)

RLS Policies:
- Admin can see ALL data
- Business owner can see ONLY their data
- Vendor can see ONLY assigned products
```

---

### **4. REPORTS & ANALYTICS** 📊

**Key Metrics:**
```
Dashboard Stats:
✅ Daily/Monthly sales
✅ Top products
✅ Low stock alerts
✅ Pending bookings
✅ Revenue trends

Vendor Reports:
✅ Sales by vendor
✅ Commission owed
✅ Payment history

Product Reports:
✅ Best sellers
✅ Profit margins
✅ Stock turnover
✅ Cost analysis

Financial Reports:
✅ Income statement
✅ Expense tracking
✅ Profit/Loss
✅ Cash flow
```

---

### **5. SUBSCRIPTION PLANS** 💎

**Tiers:**
```
FREE:
- Max 50 products
- Basic reports
- 1 user
- Email support

PREMIUM (RM99/month):
- Unlimited products
- Advanced reports
- Multiple users
- Vendor management
- Priority support
- WhatsApp notifications

ENTERPRISE (Custom):
- All Premium features
- Custom integrations
- Dedicated support
- White-label option
```

---

## 🔄 **KEY BUSINESS FLOWS**

### **VENDOR CLAIM FLOW:**
```
1. Vendor sells products (offline/consignment)
2. Vendor logs in to PocketBizz
3. Submits claim:
   - Product sold
   - Quantity
   - Sale price
   - Upload receipt/proof
4. Admin receives notification
5. Admin reviews claim
6. Admin approves/rejects
7. If approved → Add to payment queue
8. Vendor receives notification
9. Payment processed (manual or auto)
10. Both parties see updated records
```

### **STOCK DEDUCTION FLOW:**
```
1. Sale recorded
2. Check if product has recipe
3. If YES:
   a. For each ingredient in recipe
   b. Calculate quantity needed
   c. Deduct from stock (FIFO)
   d. Record stock movement
4. If stock < reorder level:
   a. Send alert to user
   b. Suggest purchase order
```

### **PRODUCTION TO SALE FLOW:**
```
1. Record production batch
2. Deduct raw materials (via recipe)
3. Add finished goods to inventory
4. Available for sale
5. When sold:
   a. Deduct from inventory
   b. Calculate COGS
   c. Update profit tracking
```

---

## 🎯 **TECHNICAL PATTERNS FROM OLD REPO**

### **Multi-Tenancy:**
```typescript
// Every query filtered by business_owner_id
await db.select()
  .from(products)
  .where(eq(products.businessOwnerId, userId))
```

### **Role-Based Access:**
```typescript
middleware checkRole(['admin', 'business_owner'])

// Different views based on role
if (user.role === 'admin') {
  // See all businesses
} else {
  // See only own data
}
```

### **Notifications:**
```typescript
// Email
await sendEmail({
  to: vendor.email,
  subject: 'Claim Approved',
  template: 'claim-approved'
})

// WhatsApp (Premium users)
await sendWhatsApp({
  to: vendor.phone,
  message: 'Your claim has been approved!'
})
```

---

## 🚀 **RECOMMENDED PORTING ORDER**

### **PHASE 1: CORE BUSINESS FEATURES** ✅ **DONE!**
- ✅ Products (CRUD)
- ✅ Stock Management
- ✅ Recipes
- ✅ Production Batches
- ✅ Sales
- ✅ Bookings

### **PHASE 2: VENDOR SYSTEM** 🏪 **NEXT!**
```
1. Vendor registration & management
2. Product assignment
3. Claim submission
4. Claim approval workflow
5. Payment tracking
```

### **PHASE 3: PAYMENT INTEGRATION** 💳
```
1. ToyyibPay setup
2. Subscription plans
3. Payment callback handling
4. Invoice generation
```

### **PHASE 4: ADMIN PANEL** 👑
```
1. User management
2. Business overview
3. Vendor approval
4. System settings
```

### **PHASE 5: ANALYTICS & REPORTS** 📊
```
1. Dashboard charts
2. Sales reports
3. Inventory reports
4. Financial reports
```

---

## 💡 **KEY INSIGHTS FOR FLUTTER PORT**

### **1. Vendor System is CRITICAL**
- Many users are consignment/dropship businesses
- Need vendor portal (separate login)
- Need claim/payment tracking

### **2. ToyyibPay is ESSENTIAL**
- Malaysian payment gateway
- Supports FPX, cards, eWallet
- Recurring billing needed

### **3. Multi-Tenancy is WORKING**
- Current RLS policies good
- Just need proper role management

### **4. Notifications are IMPORTANT**
- Email for all users
- WhatsApp for premium (competitive advantage)

---

## 🎯 **NEXT FEATURE TO BUILD:**

**VENDOR/SUPPLIER SYSTEM** (Estimated: 3-4 hours)

**Why This First:**
- Core differentiator
- Highest business value
- Foundation for commission/payment features
- Referenced in old repo as critical feature

---

**READY TO START VENDOR SYSTEM BRO?** 🏪

Or pilih feature lain dulu?

