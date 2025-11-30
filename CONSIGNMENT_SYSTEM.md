# Consignment System - PocketBizz

## Overview

PocketBizz menggunakan **Consignment System** untuk jualan produk melalui kedai-kedai.

## Terminology

### Consignor (User)
- **Siapa:** Pengguna app PocketBizz (pengeluar/owner produk)
- **Role:** Owner produk yang hantar produk ke kedai untuk dijual
- **Database:** `users` table dengan `business_owner_id`

### Consignee (Vendor)
- **Siapa:** Kedai yang jual produk untuk user
- **Role:** Jual produk user dan bayar kepada user selepas tolak commission
- **Database:** `vendors` table
- **Features:**
  - Commission rate setup
  - Update sales dan balance (unsold/expired/rosak) kepada user
  - Bayar kepada user berdasarkan sold products sahaja

## System Flow

```
1. User (Consignor) buat produk
   ↓
2. User hantar produk ke Vendor (Consignee) - Deliveries
   ↓
3. Vendor jual produk kepada customer
   ↓
4. Vendor update sales dan balance unsold/expired/rosak kepada user
   ↓
5. User buat tuntutan bayaran based on product sold only
   (perlu update unsold/return/expired product qty)
   ↓
6. Vendor buat payment kepada user (consignor) 
   based on sold product only dengan jumlah selepas tolak %/rate komisyen
```

### Payment Calculation

**Formula:**
```
1. Gross = quantity * retailPrice
2. Rejected = rejected_qty * retailPrice (unsold + expired + rosak)
3. Net (Sold) = Gross - Rejected = (quantity - rejected_qty) * retailPrice
4. Commission = Net * (commissionRate / 100)
5. Payment to User = Net - Commission
```

**Example:**
- Quantity delivered: 100 units
- Retail price: RM 10/unit
- Gross: RM 1,000
- Rejected (unsold + expired + rosak): 20 units = RM 200
- Net (Sold): 80 units = RM 800
- Commission rate: 15%
- Commission: RM 120
- **Payment to User: RM 680**

**Notes:**
- `rejected_qty` = unsold + expired + rosak (all non-sold items)
- `quantity - rejected_qty` = sold quantity
- Only sold products = included dalam payment calculation
- Unsold/expired/rosak = excluded via rejected_qty

## Modules

### 1. Vendors Module
- **Purpose:** Manage Consignees (kedai yang jual produk)
- **Features:**
  - Add/Edit/Delete vendors
  - Setup commission rates
  - Bank details untuk payment
- **File:** `lib/features/vendors/`

### 2. Deliveries Module
- **Purpose:** Record penghantaran produk ke vendors
- **Features:**
  - Create delivery dengan items
  - Track delivery status
  - Generate invoices
- **File:** `lib/features/deliveries/`

### 3. Claims Module
- **Purpose:** User (Consignor) buat tuntutan bayaran dari Vendor (Consignee)
- **Features:**
  - View vendor sales dan balance
  - Update unsold/expired/rosak product quantities
  - Calculate payment based on sold products only
  - Track vendor payments (vendor bayar kepada user)
  - Generate payment statements
- **File:** `lib/features/claims/`
- **Note:** Vendor yang bayar kepada User, bukan sebaliknya!

### 4. Suppliers Module (Berbeza!)
- **Purpose:** Manage pembekal bahan/ingredients
- **Note:** Ini BUKAN consignment - ini untuk beli bahan
- **Use Case:** User beli bahan dari supplier untuk buat produk
- **File:** `lib/features/suppliers/`

## Database Structure

### vendors table
- Stores Consignee information
- Commission rates
- Bank details untuk payment
- Related to: vendor_claims, vendor_payments, vendor_deliveries

### vendor_claims table
- Claims submitted by vendors untuk sales
- Status: pending, approved, rejected, paid
- Commission calculations

### vendor_payments table
- Payments made to vendors
- Links to claims
- Payment methods and references

### vendor_deliveries table
- Deliveries dari user ke vendor
- Items delivered
- Invoice numbers

## Key Differences

| Aspect | Vendors (Consignee) | Suppliers |
|--------|---------------------|-----------|
| **Purpose** | Jual produk user | Bekal bahan untuk user |
| **Relationship** | Consignment | Purchase |
| **Payment** | Commission (after sale) | Direct payment (before/on delivery) |
| **Flow** | User → Vendor → Customer | Supplier → User |
| **Ownership** | User owns until sold | User owns immediately |

## Best Practices

1. **Vendors (Consignees):**
   - Setup commission rates sebelum hantar produk
   - Track semua deliveries
   - Review claims sebelum approve
   - Keep payment records

2. **Suppliers:**
   - Manage untuk Purchase Orders
   - Track bahan untuk production
   - Different dari Vendors!

