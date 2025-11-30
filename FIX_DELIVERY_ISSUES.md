# Fix Delivery Issues

## Masalah yang Dikenalpasti

### 1. Invoice Number Duplicate Error
**Error:** `duplicate key value violates unique constraint "vendor_deliveries_invoice_number_key"`

**Punca:**
- Race condition dalam invoice number generation
- Jika 2 delivery dibuat serentak, mereka boleh dapat same sequence number

**Penyelesaian:**
- Added advisory lock (`pg_advisory_xact_lock`) untuk prevent concurrent generation
- Added microseconds suffix untuk additional uniqueness
- Format baru: `DEL-YYMM-XXXX-UUUUUU` (where UUUUUU is microseconds)
- Double-check uniqueness dengan WHILE loop

### 2. Harga Produk Menunjukkan "0"
**Punca:**
- Product mungkin tidak ada `salePrice` atau `salePrice = 0`
- Commission calculation tidak trigger dengan betul
- No validation untuk ensure product ada valid price

**Penyelesaian:**
- Added validation untuk check jika product ada valid `salePrice`
- Show warning message jika product tidak ada harga
- Added validation sebelum submit untuk ensure semua items ada valid price
- Improved error handling dalam price calculation

## Files Changed

### Database Migration
- `db/migrations/fix_delivery_invoice_number.sql` - Fix invoice number generation

### UI Updates
- `lib/features/deliveries/presentation/delivery_form_dialog.dart`:
  - Added validation untuk product price
  - Added warning messages
  - Improved error handling
  - Added validation sebelum submit

## Migration Instructions

1. Apply database migration:
```sql
-- Run: db/migrations/fix_delivery_invoice_number.sql
```

2. Existing invoice numbers akan kekal, hanya new deliveries akan use new format

## Testing

1. **Test Invoice Number:**
   - Create multiple deliveries serentak
   - Verify no duplicate invoice numbers
   - Check format: `DEL-YYMM-XXXX-UUUUUU`

2. **Test Price Calculation:**
   - Create delivery dengan product yang ada valid salePrice
   - Verify harga auto-calculated dengan betul
   - Try dengan product yang tidak ada salePrice
   - Verify warning message muncul

3. **Test Validation:**
   - Try submit delivery dengan product yang harga = 0
   - Verify validation prevent submission
   - Verify error message jelas

