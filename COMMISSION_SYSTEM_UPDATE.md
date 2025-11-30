# Commission System Update

## Overview
Sistem commission telah dikemaskini untuk menyokong 2 jenis commission:
1. **Percentage-based** - Komisyen berdasarkan peratus (cth: 10%, 15%, 20%)
2. **Price Range-based** - Komisyen berdasarkan price range (cth: RM0.1-RM5=RM1, RM5.01-RM10=RM1.50)

## Changes

### 1. Database Migration
**File:** `db/migrations/add_vendor_commission_types.sql`

- Added `commission_type` column to `vendors` table (default: 'percentage')
- Created `vendor_commission_price_ranges` table untuk store price ranges
- Added RLS policies dan indexes

### 2. Models
**Files:**
- `lib/data/models/vendor.dart` - Added `commissionType` field
- `lib/data/models/vendor_commission_price_range.dart` - New model untuk price ranges

### 3. Repositories
**Files:**
- `lib/data/repositories/vendor_commission_price_ranges_repository_supabase.dart` - New repository untuk manage price ranges
- `lib/data/repositories/deliveries_repository_supabase.dart` - Updated `getVendorCommission()` untuk support kedua-dua types

### 4. Utilities
**File:** `lib/core/utils/vendor_price_calculator.dart`
- New utility class untuk calculate vendor price based on commission type
- Support untuk kedua-dua percentage dan price range calculations

### 5. UI Updates

#### Delivery Form Dialog
**File:** `lib/features/deliveries/presentation/delivery_form_dialog.dart`
- **Auto-calculate vendor price** - Harga kepada vendor sekarang auto-calculated berdasarkan commission
- **Read-only price field** - User tidak boleh edit harga secara manual
- Price field menunjukkan "Auto (tolak komisyen)" sebagai helper text
- Auto-recalculate prices apabila vendor atau product berubah

#### Commission Dialog
**File:** `lib/features/vendors/presentation/commission_dialog.dart`
- Added commission type selector (percentage vs price_range)
- Percentage input untuk percentage type
- Price ranges management untuk price_range type:
  - Add new price ranges
  - View existing ranges
  - Delete ranges
  - Each range defines: min_price, max_price (optional), commission_amount

## How It Works

### Percentage-based Commission
1. User setup commission rate (cth: 10%) dalam vendor settings
2. Semasa create delivery, system auto-calculate:
   - `vendorPrice = retailPrice - (retailPrice * commissionRate / 100)`
   - Contoh: Retail RM10, Commission 10% → Vendor Price = RM9.00

### Price Range-based Commission
1. User setup price ranges dalam vendor settings (cth: RM0.1-RM5=RM1, RM5.01-RM10=RM1.50)
2. Semasa create delivery, system:
   - Check retail price
   - Find matching price range
   - Calculate: `vendorPrice = retailPrice - commissionAmount`
   - Contoh: Retail RM3.50 → Match range RM0.1-RM5 → Commission RM1 → Vendor Price = RM2.50

## Usage

### Setup Commission (Vendor Settings)
1. Buka vendor page
2. Click "Setup Komisyen" button
3. Pilih jenis commission:
   - **Percentage**: Masukkan kadar (cth: 10.0)
   - **Price Range**: Tambah price ranges (min, max, commission amount)

### Create Delivery
1. Buka delivery form
2. Pilih vendor (commission auto-loaded)
3. Pilih produk
4. **Harga kepada vendor auto-calculated** - User tidak perlu keyin manual
5. Harga field adalah read-only dengan helper text "Auto (tolak komisyen)"

## Migration Instructions

1. Apply database migration:
```sql
-- Run: db/migrations/add_vendor_commission_types.sql
```

2. Existing vendors akan default kepada `commission_type = 'percentage'`
3. Existing commission rates akan kekal sebagai percentage-based

## Notes

- Harga kepada vendor adalah **auto-calculated** - user tidak boleh edit manual
- Price ranges mesti tidak overlap (system tidak check overlap, user perlu manage sendiri)
- Last range boleh have `max_price = NULL` untuk unlimited range
- Commission calculation berlaku secara real-time semasa user pilih produk

