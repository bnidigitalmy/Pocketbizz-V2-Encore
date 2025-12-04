# Consignment System Implementation - Complete ✅

## Overview

Sistem Tuntutan & Bayaran untuk consignment business telah diimplementasikan menggunakan **Supabase sepenuhnya** (tanpa Encore backend).

## ✅ Yang Telah Diimplementasikan

### 1. Database Schema
- ✅ Migration file: `db/migrations/add_consignment_claims_and_payments.sql`
- ✅ Tables:
  - `consignment_claims` - Tuntutan dari user kepada vendor
  - `consignment_claim_items` - Items dalam setiap tuntutan
  - `consignment_payments` - Bayaran dari vendor kepada user
  - `consignment_payment_allocations` - Alokasi bayaran kepada tuntutan
- ✅ Enhanced `vendor_delivery_items` dengan quantity tracking (sold, unsold, expired, damaged)
- ✅ RLS Policies untuk security
- ✅ Triggers untuk auto-update balances

### 2. Flutter Models
- ✅ `ConsignmentClaim` & `ConsignmentClaimItem` - Model untuk claims
- ✅ `ConsignmentPayment` & `ConsignmentPaymentAllocation` - Model untuk payments
- ✅ `OutstandingBalance` - Model untuk baki tertunggak
- ✅ Updated `DeliveryItem` dengan quantity fields

### 3. Repositories (Supabase Direct)
- ✅ `ConsignmentClaimsRepositorySupabase` - CRUD operations untuk claims
  - `createClaim()` - Cipta tuntutan dari deliveries
  - `submitClaim()` - Submit tuntutan
  - `approveClaim()` - Approve tuntutan
  - `rejectClaim()` - Reject tuntutan
  - `listClaims()` - List dengan filters
  - `getClaimById()` - Get detail dengan items
  - `updateClaimItemQuantities()` - Update kuantiti items

- ✅ `ConsignmentPaymentsRepositorySupabase` - CRUD operations untuk payments
  - `createPayment()` - Cipta bayaran dengan auto-allocation
  - `allocatePayment()` - Manual allocation
  - `listPayments()` - List dengan filters
  - `getPaymentById()` - Get detail dengan allocations
  - `getOutstandingBalance()` - Get baki tertunggak per vendor

### 4. UI Screens
- ✅ `CreateConsignmentClaimPage` - Halaman cipta tuntutan
  - Pilih vendor
  - Pilih deliveries
  - Edit kuantiti (sold, unsold, expired, damaged)
  - Set tarikh tuntutan
  - Tambah nota

- ✅ `CreateConsignmentPaymentPage` - Halaman rekod bayaran
  - Pilih vendor
  - Pilih kaedah bayaran (bill-to-bill, per-claim, partial, carry-forward)
  - Pilih tuntutan (jika perlu)
  - Set jumlah bayaran
  - Tambah rujukan & nota
  - Auto-show outstanding balance

### 5. Routing
- ✅ Routes ditambah di `main.dart`:
  - `/claims/create` → `CreateConsignmentClaimPage`
  - `/payments/create` → `CreateConsignmentPaymentPage`
- ✅ Navigation buttons ditambah di `ClaimsPage` AppBar

## 📋 Flow Sistem

### Flow Tuntutan (Claims)
1. **User hantar produk ke vendor** → Delivery dibuat
2. **Vendor update kuantiti** → Update `quantity_sold`, `quantity_unsold`, `quantity_expired`, `quantity_damaged` dalam `vendor_delivery_items`
3. **User buat tuntutan** → Pilih deliveries, system auto-calculate:
   - Gross Amount = sum(quantity_sold × unit_price)
   - Commission = gross × commission_rate%
   - Net Amount = gross - commission
4. **Submit & Approve** → Status berubah dari draft → submitted → approved
5. **Vendor buat bayaran** → Payment dibuat dan allocated kepada claims

### Flow Bayaran (Payments)
1. **Pilih Vendor** → System show outstanding balance
2. **Pilih Kaedah Bayaran**:
   - **Bill to Bill**: Bayaran untuk beberapa tuntutan (proportional allocation)
   - **Per Claim**: Bayaran penuh untuk satu tuntutan
   - **Partial**: Bayaran separa untuk satu tuntutan
   - **Carry Forward**: Mark items untuk dibawa ke tuntutan seterusnya
3. **Auto-Allocation** → System auto-allocate berdasarkan kaedah
4. **Update Balances** → Triggers auto-update `paid_amount` dan `balance_amount` dalam claims

## 🔧 Technical Details

### Database Triggers
- **Auto-generate claim_number**: Format `CLM-YYYYMMDD-XXXX`
- **Auto-generate payment_number**: Format `PAY-YYYYMMDD-XXXX`
- **Auto-update balances**: Setiap kali payment allocation dibuat, claim balances auto-update
- **Quantity validation**: Constraint ensure quantities balance

### Business Logic
- **Commission Calculation**: 
  - Commission rate dari vendor table
  - Commission = gross_amount × (commission_rate / 100)
  - Net = gross - commission
- **Payment Allocation**:
  - Bill-to-bill: Proportional berdasarkan balance
  - Per-claim: Full amount to one claim
  - Partial: Amount to one claim (must not exceed balance)
  - Carry-forward: No allocation yet (for future claims)

## 📝 Next Steps (Optional Enhancements)

1. **List Pages**:
   - List claims dengan filters (status, vendor, date range)
   - List payments dengan filters
   - Claim details page dengan items breakdown
   - Payment details page dengan allocations

2. **Integration dengan Delivery System**:
   - Update delivery items quantities dari delivery page
   - Show claim status dalam delivery list

3. **Reports**:
   - Outstanding balance report
   - Payment history report
   - Commission report

4. **Notifications**:
   - Notify user when claim approved
   - Notify vendor when payment received

5. **PDF Generation**:
   - Generate claim invoice PDF
   - Generate payment receipt PDF

## 🚀 Cara Guna

### Cipta Tuntutan
1. Pergi ke **Claims** page
2. Click **+** button di AppBar
3. Pilih vendor
4. Pilih deliveries yang nak claim
5. Edit kuantiti jika perlu (click "Edit Kuantiti" button)
6. Set tarikh tuntutan
7. Click "Cipta Tuntutan"

### Rekod Bayaran
1. Pergi ke **Claims** page
2. Click **💳** button di AppBar
3. Pilih vendor (outstanding balance akan show)
4. Pilih kaedah bayaran
5. Pilih tuntutan (jika perlu)
6. Masukkan jumlah bayaran
7. Masukkan rujukan & nota (optional)
8. Click "Rekod Bayaran"

## ✅ Status: READY TO USE

Semua core functionality dah siap dan boleh digunakan. Database migration perlu di-run di Supabase sebelum guna.



