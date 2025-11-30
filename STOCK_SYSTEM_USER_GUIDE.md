# Panduan Sistem Stok Siap untuk User

## 🎯 Konsep Asas

Sistem **Stok Siap** adalah inventori produk yang sudah siap untuk dijual. Apabila anda:
- **Hantar produk ke vendor** (Deliveries)
- **Buat jualan** (Sales)

System akan **automatik tolak quantity** dari stok siap menggunakan sistem **FIFO** (First In First Out).

## 📊 Bagaimana Sistem Bekerja?

### Flow Ringkas:

```
1. Buat Produksi → Stok Siap Bertambah
   ↓
2. Hantar ke Vendor / Buat Jualan → Stok Siap Auto-Tolak
   ↓
3. Stok Siap Page Auto-Update (Real-time)
```

### Sistem FIFO (First In First Out)

**Prinsip:** Batch yang paling lama (oldest) akan digunakan dahulu.

**Kenapa?**
- ✅ Mengurangkan risiko produk expired
- ✅ Memastikan produk fresh digunakan dahulu
- ✅ Mengurangkan kerugian akibat expired products

**Contoh:**
```
Batch #1 (01 Jan 2025): 50 unit
Batch #2 (15 Jan 2025): 30 unit
Batch #3 (01 Feb 2025): 20 unit

Jika hantar 60 unit:
→ Batch #1: 50 unit (habis)
→ Batch #2: 10 unit (tinggal 20 unit)
→ Batch #3: Tidak digunakan
```

## 🚀 Cara Guna

### 1. Lihat Stok Siap

**Langkah:**
1. Buka drawer menu → Click "Stok Siap"
2. Lihat product cards dengan:
   - Total remaining quantity
   - Batch count
   - Expiry status (Fresh/Warning/Expired)
3. Click product card → Lihat batch details

**Apa yang anda lihat:**
- **Total Remaining**: Jumlah unit yang masih ada
- **Batch Count**: Berapa banyak batch yang ada
- **Expiry Status**: 
  - 🟢 Fresh (>7 hari)
  - 🔵 Soon (4-7 hari)
  - 🟠 Warning (1-3 hari)
  - 🔴 Expired

### 2. Hantar ke Vendor (Deliveries)

**Langkah:**
1. Buka Deliveries → Click "Tambah Penghantaran"
2. Pilih vendor
3. Pilih produk → **System auto-show stock availability**
4. Masukkan quantity
5. **System auto-validate stock**
6. Submit → **System auto-deduct stock**

**Visual Indicators:**
- ✅ **Helper text**: "Stok: 50.0 unit" (hijau)
- ⚠️ **Warning**: Jika stock < 10 unit (orange)
- ❌ **Error**: Jika quantity > available stock (red background)

**Important:**
- Stock hanya deduct untuk **accepted quantity** (quantity - rejected_qty)
- Jika ada rejected items, stock tidak deduct untuk rejected quantity
- System prevent delivery jika stock tidak cukup

### 3. Buat Jualan (Sales)

**Langkah:**
1. Buka Sales → Create Sale
2. Add products & quantities
3. **System auto-validate stock**
4. Submit → **System auto-deduct stock (FIFO)**

**Important:**
- Stock auto-deduct untuk semua items
- System prevent sale jika stock tidak cukup
- FIFO: Oldest batch digunakan dahulu

## 🔍 Memahami Batch Details

### FIFO Order
- **FIFO #1**: Batch paling lama (akan digunakan dahulu)
- **FIFO #2**: Batch kedua
- **FIFO #3**: Batch ketiga
- Dan seterusnya...

### Progress Bar
- **Hijau**: >50% remaining
- **Orange**: 25-50% remaining
- **Merah**: <25% remaining

### Expiry Status
- **Fresh**: >7 hari sebelum expiry
- **Soon**: 4-7 hari sebelum expiry
- **Warning**: 1-3 hari sebelum expiry
- **Expired**: Sudah expired

## ⚠️ Error Messages

### "Stok tidak mencukupi"
**Maksud:** Quantity yang diminta lebih besar dari available stock

**Penyelesaian:**
1. Check "Stok Siap" page untuk lihat available stock
2. Kurangkan quantity
3. Atau buat produksi baru untuk tambah stock

### "Stok tidak cukup!"
**Maksud:** Quantity dalam form lebih besar dari available stock

**Penyelesaian:**
1. Lihat helper text: "Stok: X unit"
2. Kurangkan quantity kepada X atau kurang
3. Card akan kembali normal (tidak merah)

## 💡 Tips untuk User

### 1. Check Stock Sebelum Delivery
- Selalu check "Stok Siap" page sebelum create delivery
- Lihat expiry status untuk plan delivery

### 2. Monitor Low Stock
- Jika stock < 10 unit, system akan show warning
- Buat produksi baru untuk tambah stock

### 3. Understand FIFO
- Batch #1 akan digunakan dahulu
- Ini memastikan produk tidak expired
- Check batch details untuk lihat FIFO order

### 4. Rejected Items
- Rejected items **TIDAK deduct stock**
- Hanya accepted quantity deduct stock
- Ini memastikan stock tracking accurate

## 📈 Real-time Updates

- Apabila delivery/sale dibuat, "Stok Siap" page auto-update
- Refresh page untuk lihat latest stock
- Progress bars update automatically

## 🎨 Visual Guide

### Delivery Form - Stock Indicators

**Normal (Stock Cukup):**
```
[Produk Dropdown] [Qty: 20] [Harga: RM2.32]
                  Helper: "Stok: 50.0 unit" ✅
```

**Warning (Stock Rendah):**
```
[Produk Dropdown] [Qty: 5] [Harga: RM2.32]
                  Helper: "Stok: 8.0 unit" ⚠️
                  Snackbar: "Stok rendah"
```

**Error (Stock Tidak Cukup):**
```
[Produk Dropdown] [Qty: 20] [Harga: RM2.32]
                  Helper: "Stok: 10.0 unit" ❌
                  Error: "Stok tidak cukup!"
                  Card background: Red
```

### Stok Siap Page

**Product Card:**
```
┌─────────────────────────┐
│ Kek Batik          →    │
│ 50 unit                 │
│ [3 batch] [🟢 Fresh]    │
└─────────────────────────┘
```

**Batch Details:**
```
┌─────────────────────────┐
│ [FIFO #1] [🟢 Fresh]    │
│ Produksi: 01 Jan 2025   │
│ Expiry: 15 Jan 2025     │
│ Baki: 30/50 unit        │
│ [████████░░] 60%        │
└─────────────────────────┘
```

## ✅ Checklist untuk User

Sebelum create delivery:
- [ ] Check "Stok Siap" page
- [ ] Verify stock availability
- [ ] Check expiry status
- [ ] Plan delivery quantities

Semasa create delivery:
- [ ] Lihat helper text untuk stock availability
- [ ] Masukkan quantity yang tidak melebihi available stock
- [ ] Jika ada rejected items, faham bahawa rejected tidak deduct stock

Selepas delivery:
- [ ] Check "Stok Siap" page untuk verify stock updated
- [ ] Monitor low stock warnings
- [ ] Plan produksi jika stock rendah

## 🔄 System Flow Diagram

```
┌─────────────────┐
│   Production    │
│   (Buat Stok)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Stok Siap     │
│   (Inventory)   │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌────────┐ ┌────────┐
│Delivery│ │ Sales  │
│(Vendor)│ │(Jualan)│
└───┬────┘ └───┬────┘
    │          │
    └────┬─────┘
         │
         ▼
┌─────────────────┐
│ Auto-Deduct     │
│ (FIFO)          │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Update Stock    │
│ (Real-time)     │
└─────────────────┘
```

## 📝 Summary

**Key Points:**
1. ✅ Stock **auto-deduct** apabila delivery/sale dibuat
2. ✅ System menggunakan **FIFO** (oldest batch first)
3. ✅ Stock hanya deduct untuk **accepted quantity**
4. ✅ System **prevent delivery/sale** jika stock tidak cukup
5. ✅ **Real-time updates** dalam "Stok Siap" page
6. ✅ **Visual indicators** untuk stock availability
7. ✅ **Clear error messages** untuk user guidance

**User tidak perlu:**
- ❌ Manual update stock
- ❌ Calculate stock manually
- ❌ Worry tentang expired products (FIFO handles this)

**System handle:**
- ✅ Auto-deduct stock
- ✅ FIFO ordering
- ✅ Stock validation
- ✅ Error prevention
- ✅ Real-time tracking

