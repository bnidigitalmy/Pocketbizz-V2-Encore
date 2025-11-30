# Sistem Penggunaan Stok Siap (Finished Products Stock Consumption)

## Overview
Sistem untuk auto-deduct quantity dari finished products (production batches) apabila:
1. **Penghantaran ke Vendor** (Deliveries)
2. **Jualan** (Sales)

## Prinsip Sistem

### 1. FIFO (First In First Out)
- Batch yang paling lama (oldest batch_date) akan digunakan dahulu
- Memastikan produk tidak expired sebelum digunakan
- Mengurangkan risiko produk rosak/expired

### 2. Auto-Deduction
- Automatic deduct dari `production_batches.remaining_qty`
- Tidak perlu manual update
- Real-time stock tracking

### 3. Tracking & Visibility
- Clear visibility dalam "Stok Siap" page
- Batch details menunjukkan remaining quantity
- Progress bar untuk visual tracking

## Flow Sistem

### Flow 1: Penghantaran ke Vendor (Deliveries)

```
User Create Delivery
    ↓
Select Products & Quantities
    ↓
System Auto-Check Stock Availability
    ↓
System Auto-Deduct from Production Batches (FIFO)
    ↓
Update remaining_qty in production_batches
    ↓
Create Delivery Record
    ↓
Stok Siap Page Auto-Update (Real-time)
```

**Implementation:**
- Dalam `createDelivery()` method
- Sebelum create delivery, deduct stock dari production batches
- Use FIFO: deduct dari oldest batch first
- Update `remaining_qty` untuk setiap batch yang digunakan

### Flow 2: Jualan (Sales)

```
User Create Sale
    ↓
Select Products & Quantities
    ↓
System Auto-Check Stock Availability
    ↓
System Auto-Deduct from Production Batches (FIFO)
    ↓
Update remaining_qty in production_batches
    ↓
Create Sale Record
    ↓
Stok Siap Page Auto-Update (Real-time)
```

**Implementation:**
- Dalam `createSale()` method
- Sebelum create sale, deduct stock dari production batches
- Use FIFO: deduct dari oldest batch first
- Update `remaining_qty` untuk setiap batch yang digunakan

## Database Structure

### Table: `production_batches`
```sql
- id
- product_id
- quantity (total produced)
- remaining_qty (remaining after deductions)
- batch_date (for FIFO ordering)
- expiry_date (for expiry tracking)
```

### Key Fields:
- `remaining_qty`: Quantity yang masih ada (auto-updated)
- `batch_date`: Untuk FIFO ordering (oldest first)
- `expiry_date`: Untuk expiry tracking

## FIFO Deduction Logic

### Algorithm:
1. Get all batches untuk product (ordered by batch_date ASC - oldest first)
2. Filter batches dengan `remaining_qty > 0`
3. Loop through batches:
   - Deduct dari batch pertama (oldest)
   - Jika batch habis, continue ke batch seterusnya
   - Continue sehingga semua quantity deducted
4. Update `remaining_qty` untuk setiap batch yang affected

### Example:
```
Product: Kek Batik
Quantity needed: 15 units

Batches available:
- Batch #1 (oldest): remaining_qty = 10
- Batch #2: remaining_qty = 8
- Batch #3: remaining_qty = 5

Deduction:
1. Deduct 10 dari Batch #1 → remaining_qty = 0
2. Deduct 5 dari Batch #2 → remaining_qty = 3
3. Batch #3 tidak digunakan

Result:
- Batch #1: remaining_qty = 0 (fully consumed)
- Batch #2: remaining_qty = 3
- Batch #3: remaining_qty = 5 (unchanged)
```

## User Visibility

### Stok Siap Page
- Shows total remaining untuk setiap product
- Shows batch count
- Shows nearest expiry date
- Click product → See all batches dengan:
  - FIFO order (#1, #2, #3)
  - Remaining quantity per batch
  - Progress bar
  - Expiry status

### Real-time Updates
- Apabila delivery/sale dibuat, stok auto-update
- User boleh refresh untuk lihat latest stock
- Progress bars update automatically

## Error Handling

### Insufficient Stock
- Check stock availability sebelum create delivery/sale
- Show clear error message: "Stok tidak mencukupi. Stok sedia ada: X unit"
- Prevent creation jika stock tidak cukup

### Validation
- Validate quantity > 0
- Validate stock availability
- Validate batch exists dan ada remaining_qty

## Implementation Status

### ✅ Completed

#### 1. Deliveries Repository
- ✅ Added `getAvailableStock()` method
- ✅ Added `validateStockAvailability()` method
- ✅ Auto-deduct stock dalam `createDelivery()` menggunakan FIFO
- ✅ Deduct hanya untuk **accepted quantity** (quantity - rejected_qty)
- ✅ Rollback delivery jika stock deduction fails

#### 2. Sales Repository
- ✅ Already has auto-deduct stock (FIFO)
- ✅ Deduct stock untuk semua items dalam sale

#### 3. UI Enhancements
- ✅ Stock availability display dalam delivery form
- ✅ Real-time stock validation
- ✅ Visual warnings (red background jika stock tidak cukup)
- ✅ Helper text showing available stock
- ✅ Error messages untuk insufficient stock

#### 4. User Visibility
- ✅ "Stok Siap" page shows total remaining
- ✅ Batch details dengan FIFO order
- ✅ Progress bars untuk visual tracking
- ✅ Expiry status indicators

## User Experience Flow

### Scenario 1: Create Delivery dengan Stock Cukup

```
1. User buka Delivery Form
2. Pilih Vendor
3. Pilih Produk → System auto-load stock availability
4. Helper text shows: "Stok: 50.0 unit"
5. User masukkan quantity (cth: 20)
6. System validate: 20 < 50 ✅
7. User submit → System auto-deduct 20 dari oldest batch
8. Delivery created → Stok Siap page auto-update
```

### Scenario 2: Create Delivery dengan Stock Tidak Cukup

```
1. User buka Delivery Form
2. Pilih Vendor
3. Pilih Produk → System auto-load stock availability
4. Helper text shows: "Stok: 10.0 unit"
5. User masukkan quantity (cth: 20)
6. System validate: 20 > 10 ❌
7. Error message: "Stok tidak cukup!"
8. Card background turns red
9. User tidak boleh submit sehingga stock cukup
```

### Scenario 3: Create Sale

```
1. User create Sale
2. Add products & quantities
3. System auto-validate stock
4. System auto-deduct stock (FIFO)
5. Sale created → Stok Siap page auto-update
```

## Key Features untuk User Understanding

### 1. **Auto Stock Deduction**
- User tidak perlu manual update stock
- System auto-deduct apabila delivery/sale dibuat
- Real-time stock tracking

### 2. **FIFO System**
- Oldest batch digunakan dahulu
- Mengurangkan risiko expired products
- Clear FIFO numbering (#1, #2, #3) dalam batch details

### 3. **Stock Validation**
- Check stock sebelum create delivery/sale
- Clear error messages
- Visual warnings (red background)
- Helper text showing available stock

### 4. **Transparency**
- "Stok Siap" page shows total remaining
- Batch details dengan progress bars
- Clear visibility untuk setiap batch

### 5. **Accepted Quantity Only**
- Stock hanya deduct untuk accepted quantity
- Rejected items tidak deduct stock
- Accurate stock tracking

## Visual Indicators

### Delivery Form
- **Green**: Stock cukup
- **Red background**: Stock tidak cukup
- **Helper text**: "Stok: X unit"
- **Error message**: "Stok tidak cukup!" jika quantity > available stock

### Stok Siap Page
- **Total remaining**: Large number display
- **Batch count**: Badge showing number of batches
- **Expiry status**: Color-coded badges
- **Progress bars**: Visual representation dalam batch details

## Benefits untuk User

1. **No Manual Work**: Stock auto-update, tidak perlu manual entry
2. **Error Prevention**: System prevent delivery/sale jika stock tidak cukup
3. **Clear Visibility**: User boleh lihat stock availability dalam real-time
4. **FIFO Protection**: System ensure oldest stock digunakan dahulu
5. **Accurate Tracking**: Stock selalu accurate kerana auto-deduction

## Benefits

1. **Automatic**: User tidak perlu manual update stock
2. **Accurate**: Real-time stock tracking
3. **FIFO**: Mengurangkan risiko expired products
4. **Transparent**: Clear visibility dalam Stok Siap page
5. **Error Prevention**: Validate stock sebelum create delivery/sale

