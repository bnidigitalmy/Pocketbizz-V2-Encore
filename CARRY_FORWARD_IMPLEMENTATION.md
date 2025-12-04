# 🚀 CARRY FORWARD - QUICK IMPLEMENTATION GUIDE

## What Users Need to Do

### Week 1: First Claim
```
Step 3: Input Quantities

Beras 5kg
├─ Delivered: 100
├─ Expired: 10
├─ Damaged: 5
└─ ⏳ What about 85 unsold?

   User sees 3 options:
   🟢 TERJUAL - I sold more (adjust quantity)
   🔴 RUGI - It's a loss/waste (don't C/F)
   🔵 BAWA KE MINGGU DEPAN - Carry forward (mark as C/F)

User clicks: 🔵 BAWA KE MINGGU DEPAN
System saves: carry_forward_status = 'carry_forward'
Result: Auto-creates carry_forward_item with qty = 85
```

### Week 2: Next Claim
```
Step 2: Select Deliveries

📦 PENGHANTARAN BELUM DITUNTUT (1)
├─ INV-20251202: 100 Beras 5kg

🔄 ITEM BAWA KE MINGGU INI (1)  ← NEW!
└─ Beras 5kg: 85 units (dari CLM-2512-0001)

User: Selects both ✅
System: Shows 185 total units (100 new + 85 C/F)

Step 3: Input Quantities
├─ Sold: 150
├─ Unsold: 35
└─ What to do with 35?
   → Mark as C/F again for Week 3
   → System auto-updates old C/F as 'used'
   → Creates new C/F: 35 units
```

---

## Code Changes Required

### 1. Database Migration

**File:** `db/migrations/add_carry_forward_status.sql`

```sql
-- Add carry_forward_status field to track user's choice
ALTER TABLE consignment_claim_items
ADD COLUMN IF NOT EXISTS carry_forward_status TEXT DEFAULT 'none'
CHECK (carry_forward_status IN ('none', 'carry_forward', 'loss'));

-- Index for fast lookup
CREATE INDEX idx_claim_items_cf_status 
ON consignment_claim_items(claim_id, carry_forward_status);

-- Update existing trigger to use new field
DROP TRIGGER IF EXISTS trigger_create_carry_forward_items 
ON consignment_claim_items;

CREATE TRIGGER trigger_create_carry_forward_items
    AFTER INSERT ON consignment_claim_items
    FOR EACH ROW
    WHEN (NEW.quantity_unsold > 0 
          AND NEW.carry_forward_status = 'carry_forward')
EXECUTE FUNCTION create_carry_forward_items();
```

### 2. Dart Model Updates

**File:** `lib/data/models/delivery.dart`

```dart
// No changes needed - already has quantity_unsold
```

**File:** `lib/data/models/consignment_claim.dart`

```dart
class ConsignmentClaimItem {
  // ... existing fields ...
  final String carryForwardStatus;  // ADD THIS
  // 'none', 'carry_forward', or 'loss'

  ConsignmentClaimItem({
    // ... existing params ...
    required this.carryForwardStatus,  // ADD THIS
  });

  // Update fromJson/toJson
  factory ConsignmentClaimItem.fromJson(Map<String, dynamic> json) {
    return ConsignmentClaimItem(
      // ... existing fields ...
      carryForwardStatus: json['carry_forward_status'] as String? ?? 'none',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // ... existing fields ...
      'carry_forward_status': carryForwardStatus,
    };
  }
}
```

### 3. Repository Update

**File:** `lib/data/repositories/consignment_claims_repository_supabase.dart`

**Update `createClaim()` method:**

```dart
// When inserting claim items, include carry_forward_status

final claimItems = <Map<String, dynamic>>[];
for (var item in claimItemsData) {
  claimItems.add({
    'claim_id': claim['id'],
    'delivery_id': item['delivery_id'],
    'delivery_item_id': item['delivery_item_id'],
    'quantity_delivered': item['quantity_delivered'],
    'quantity_sold': item['quantity_sold'],
    'quantity_unsold': item['quantity_unsold'],
    'quantity_expired': item['quantity_expired'],
    'quantity_damaged': item['quantity_damaged'],
    'unit_price': item['unit_price'],
    'gross_amount': item['quantity_sold'] * item['unit_price'],
    'commission_rate': commissionRate,
    'commission_amount': (item['quantity_sold'] * item['unit_price'] * commissionRate) / 100,
    'net_amount': ((item['quantity_sold'] * item['unit_price']) * (100 - commissionRate)) / 100,
    'carry_forward_status': item['carry_forward_status'] ?? 'none',  // ADD THIS!
  });
}

await supabase.from('consignment_claim_items').insert(claimItems);
```

### 4. UI Changes

**File:** `lib/features/claims/presentation/create_claim_simplified_page.dart`

**In State:**

```dart
// Add to _CreateClaimSimplifiedPageState
Map<int, String> _cfStatus = {};  // Track user's choice per item
// 'none', 'carry_forward', 'loss'
```

**In `_buildStep3QuantityEntry()` method:**

```dart
// For each delivery item with unsold quantity

if (unsoldQty > 0) {
  children.add(
    Card(
      margin: const EdgeInsets.only(top: 12),
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, 
                  color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Unsold: ${unsoldQty.toStringAsFixed(1)} units',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Option 1: Mark as Loss
            RadioListTile(
              title: Text('🔴 Rugi (Loss/Waste - Don\'t C/F)'),
              subtitle: Text(
                'Item ini tidak akan dibawa ke minggu depan',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              value: 'loss',
              groupValue: _cfStatus[itemIndex] ?? 'none',
              onChanged: (v) => setState(() => _cfStatus[itemIndex] = v ?? 'none'),
            ),
            
            // Option 2: Carry Forward
            RadioListTile(
              title: Text('🔵 Bawa ke Minggu Depan (C/F)'),
              subtitle: Text(
                'Item ini akan tersedia untuk tuntutan minggu depan',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              value: 'carry_forward',
              groupValue: _cfStatus[itemIndex] ?? 'none',
              onChanged: (v) => setState(() => _cfStatus[itemIndex] = v ?? 'none'),
            ),
            
            const SizedBox(height: 12),
            
            // Show selected choice
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _cfStatus[itemIndex] == 'carry_forward' 
                  ? Colors.blue[100] 
                  : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getCfStatusText(_cfStatus[itemIndex] ?? 'none'),
                style: TextStyle(
                  fontSize: 12,
                  color: _cfStatus[itemIndex] == 'carry_forward' 
                    ? Colors.blue[700] 
                    : Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// Helper method
String _getCfStatusText(String status) {
  switch (status) {
    case 'carry_forward':
      return '✅ Akan dibawa ke minggu depan (C/F)';
    case 'loss':
      return '✅ Ditandai sebagai kerugian';
    default:
      return '⚠️ Pilih status untuk item yang belum terjual';
  }
}
```

**When saving claim items, pass the status:**

```dart
// In _validateAndCreateClaim()

final itemsToCreate = _deliveryItems.map((item) {
  return {
    'delivery_id': item['deliveryId'],
    'delivery_item_id': item['itemId'],
    'quantity_delivered': item['quantity'],
    'quantity_sold': item['quantitySold'],
    'quantity_unsold': item['quantityUnsold'],
    'quantity_expired': item['quantityExpired'],
    'quantity_damaged': item['quantityDamaged'],
    'unit_price': item['unitPrice'],
    'carry_forward_status': 
      item['isCarryForward'] 
        ? (_cfStatus[_deliveryItems.indexOf(item)] ?? 'none')
        : 'none',  // Regular items: 'none'
  };
}).toList();
```

---

## Testing Checklist

### ✅ Test 1: First Claim with C/F
- [ ] Create delivery (10 units)
- [ ] Create claim (8 sold, 2 unsold)
- [ ] In Step 3, see "Unsold: 2 units"
- [ ] Select "Bawa ke Minggu Depan"
- [ ] Submit claim
- [ ] Check DB: `carry_forward_items` has 1 row with qty = 2, status = 'available'

### ✅ Test 2: Second Claim Sees C/F
- [ ] Create new delivery (5 units)
- [ ] Create claim
- [ ] In Step 2, see "Item C/F (1)" section
- [ ] Shows "2 units from CLM-xxxxx"
- [ ] Select it (checkbox becomes checked)
- [ ] In Step 3, total shows 7 units (5 new + 2 C/F)

### ✅ Test 3: Multiple C/F
- [ ] Create third delivery (10 units)
- [ ] Create claim with: 5 new + 2 C/F from Week 2
- [ ] Total: 7 units shown
- [ ] Sell 6 units, mark 1 as C/F
- [ ] Check: Previous C/F marked as 'used', new C/F created

### ✅ Test 4: Mark as Loss
- [ ] Create delivery (10 units)
- [ ] Create claim (8 sold, 2 unsold)
- [ ] Mark 2 unsold as "Rugi"
- [ ] Submit
- [ ] Check: NO carry_forward_item created
- [ ] Next claim: Don't see those 2 units

### ✅ Test 5: C/F Item Details
- [ ] Verify C/F shows:
  - [ ] Product name
  - [ ] Available quantity
  - [ ] Unit price
  - [ ] Original claim number
  - [ ] "Dari CLM-xxxxx" text

---

## Files to Modify

1. **Database:**
   - `db/migrations/add_carry_forward_status.sql` (CREATE)

2. **Models:**
   - `lib/data/models/consignment_claim.dart` (UPDATE)

3. **Repository:**
   - `lib/data/repositories/consignment_claims_repository_supabase.dart` (UPDATE createClaim)

4. **UI:**
   - `lib/features/claims/presentation/create_claim_simplified_page.dart` (UPDATE Step 3)

5. **Optional - Already Done:**
   - Carry forward repository ✅
   - Carry forward model ✅
   - Database table ✅
   - Trigger ✅

---

## Timeline

- **Database:** 30 min
- **Models:** 30 min
- **Repository:** 1 hour
- **UI (Step 3):** 2 hours
- **Testing:** 1-2 hours
- **Total:** ~5 hours

---

**Ready to proceed?** 🚀

