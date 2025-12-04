# 🔄 CARRY FORWARD (C/F) SYSTEM - COMPLETE DESIGN

## Current Problem

When a user marks items as "Belum Terjual" (unsold), they cannot control what happens:
- **Current:** All unsold items are auto-carried forward (if `carry_forward = TRUE` in DB)
- **User can't decide:** "This item should be C/F" or "This item is loss/waste/expired"

## Solution: User-Controlled C/F Flow

### Phase 1: Step 3 Enhancement - Mark C/F Items Explicitly

**What to Change:**
1. When editing quantities in Step 3, show three options per unsold item:
   - 🟢 **Terjual** (Sold)
   - 🔴 **Rugi** (Loss - don't carry forward)
   - 🔵 **Bawa ke Minggu Depan** (Carry Forward)

2. Let user choose: "What do I do with unsold items?"
   - Don't auto-carry everything
   - Only carry what user explicitly marks

### Phase 2: Automatic C/F Item Creation (Already Implemented)

**Database Trigger (Already in Place):**
```sql
-- When claim item is inserted with:
-- - quantity_unsold > 0
-- - carry_forward = TRUE
-- Then: CREATE carry_forward_items record automatically

INSERT INTO carry_forward_items (
  source_claim_id,
  source_claim_item_id,
  source_delivery_id,
  product_name,
  quantity_available,  -- The unsold qty
  unit_price,
  status = 'available'  -- Ready for next claim
)
```

### Phase 3: Step 2 (Next Claim) - Show C/F Items

**In Next Claim Creation:**
```
Step 2: Pilih Penghantaran

✅ Penghantaran Belum Dituntut (3)
├─ INV-12345 (Baru)
├─ INV-12346 (Baru)
└─ INV-12347 (Baru)

⏭️ Item Bawa ke Minggu Ini (C/F) (5)  ← NEW SECTION
├─ Beras 5kg dari CLM-2512-0001 (Qty: 2 bag)
├─ Gula 1kg dari CLM-2512-0002 (Qty: 1 pack)
├─ Minyak 2L dari CLM-2512-0001 (Qty: 3 botol)
├─ Keropok dari CLM-2512-0003 (Qty: 4 pack)
└─ Coklat dari CLM-2512-0002 (Qty: 2 pack)
```

### Phase 4: Final Claim - Show Both Sources

**In Claim Summary:**
```
Langkah 5: Ringkasan Tuntutan

📦 ITEMS DARI PENGHANTARAN BARU (3 items)
├─ Beras 5kg × 10 bag @ RM 25.00 = RM 250.00
├─ Gula 1kg × 5 pack @ RM 8.00 = RM 40.00
└─ Minyak 2L × 8 botol @ RM 12.00 = RM 96.00
                                    ___________
                            Subtotal: RM 386.00

🔄 ITEMS DIBAWA DARI MINGGU LALU (2 items)
├─ Keropok × 4 pack @ RM 15.00 = RM 60.00  (dari CLM-2512-0003)
└─ Coklat × 2 pack @ RM 20.00 = RM 40.00   (dari CLM-2512-0002)
                                    ___________
                            Subtotal: RM 100.00

───────────────────────────────────────────
JUMLAH TERJUAL (Baru + C/F):      RM 486.00
```

---

## Implementation Steps

### Step 1: Update `consignment_claim_items` Table

**Add Field:**
```sql
ALTER TABLE consignment_claim_items
ADD COLUMN IF NOT EXISTS carry_forward_status TEXT DEFAULT 'none'
CHECK (carry_forward_status IN ('none', 'carry_forward', 'loss'));
```

**Explanation:**
- `none`: Regular item, no C/F
- `carry_forward`: Mark to C/F to next claim
- `loss`: User decided not to C/F (treat as loss/waste)

### Step 2: UI Changes in create_claim_simplified_page.dart

#### Step 3: Quantity Input Section

**Show 3 Radio Buttons for Unsold:**

```dart
// For each item with unsold quantity
Column(
  children: [
    Text('Unsold: 5 units'),
    RadioListTile(
      title: Text('🟢 Terjual (Reduce claimed qty)'),
      value: 'sold_qty_adjustment',
      groupValue: _cfStatus[itemIndex],
      onChanged: (v) => setState(() => _cfStatus[itemIndex] = v),
    ),
    RadioListTile(
      title: Text('🔴 Rugi/Expired/Rosak (Loss)'),
      value: 'loss',
      groupValue: _cfStatus[itemIndex],
      onChanged: (v) => setState(() => _cfStatus[itemIndex] = v),
    ),
    RadioListTile(
      title: Text('🔵 Bawa ke Minggu Depan (C/F)'),
      value: 'carry_forward',
      groupValue: _cfStatus[itemIndex],
      onChanged: (v) => setState(() => _cfStatus[itemIndex] = v),
    ),
  ],
)
```

**User Flow:**
1. View unsold items
2. Choose: Sold more? / Loss? / Carry to next week?
3. System calculates claimed amount based on choice
4. Only `quantity_sold` items are claimed

#### Step 2: C/F Items Display

**Add New Section:**

```dart
// In Step 2 after "Penghantaran Sudah Dituntut" section

if (_availableCarryForwardItems.isNotEmpty) ...[
  const SizedBox(height: 24),
  const Divider(),
  const SizedBox(height: 24),
  
  Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(Icons.forward, color: Colors.blue[700], size: 24),
          const SizedBox(width: 8),
          Text(
            'Item Bawa ke Minggu Ini (${_availableCarryForwardItems.length})',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        'Item yang belum terjual dari tuntutan sebelumnya',
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      const SizedBox(height: 12),
      
      // List C/F items
      ..._availableCarryForwardItems.map((cfItem) {
        final isSelected = _selectedCarryForwardItems.any((i) => i.id == cfItem.id);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: isSelected ? Colors.blue[50] : null,
          child: CheckboxListTile(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    cfItem.productName,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'C/F',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Qty: ${cfItem.quantityAvailable.toStringAsFixed(1)} @ RM ${cfItem.unitPrice.toStringAsFixed(2)}',
                ),
                Text(
                  'Dari: ${cfItem.originalClaimNumber ?? "Unknown"}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            value: isSelected,
            onChanged: (value) => _toggleCarryForwardSelection(cfItem),
            secondary: Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? Colors.blue[600] : Colors.grey,
            ),
          ),
        );
      }),
    ],
  ),
],
```

---

## Database Changes Needed

### 1. Update vendor_delivery_items Table

```sql
-- Already has these fields:
quantity_sold NUMERIC(12,3)
quantity_unsold NUMERIC(12,3)
quantity_expired NUMERIC(12,3)
quantity_damaged NUMERIC(12,3)
```

### 2. Update consignment_claim_items Table

```sql
-- Add carry_forward_status field
ALTER TABLE consignment_claim_items
ADD COLUMN IF NOT EXISTS carry_forward_status TEXT DEFAULT 'none'
CHECK (carry_forward_status IN ('none', 'carry_forward', 'loss'));

-- This tracks: what did user decide for unsold items?
```

### 3. Trigger Logic Update

**Current Trigger:**
```sql
-- Current: Only creates C/F if carry_forward = TRUE
IF NEW.quantity_unsold > 0 AND NEW.carry_forward = TRUE THEN
    INSERT INTO carry_forward_items ...
END IF;
```

**New Trigger Logic:**
```sql
-- NEW: Only creates C/F if user explicitly marked it
IF NEW.quantity_unsold > 0 
   AND NEW.carry_forward_status = 'carry_forward' THEN
    INSERT INTO carry_forward_items ...
END IF;
```

---

## Data Flow Example

### Week 1: First Claim

**User receives:**
- 100 units Beras delivered

**User creates claim:**
- 70 units sold (claim RM 175)
- 20 units unsold (user marks: "Bawa ke Minggu Depan" → C/F)
- 10 units expired (user marks: "Rugi" → no C/F)

**Result:**
- consignment_claim created: gross = 70 × RM 2.50 = RM 175
- carry_forward_item created: qty = 20, status = 'available'

### Week 2: Next Claim

**User creates new claim:**
- Receive 50 new units Beras
- See carry_forward showing: 20 units from CLM-2512-0001

**User's choices:**
- Select 50 new + 20 C/F = 70 total units
- New claim: 65 sold + 5 unsold (C/F again) + 0 expired

**Result:**
- Previous C/F marked as 'used' (used_in_claim_id = CLM-2512-0002)
- New carry_forward_item created: qty = 5, status = 'available'
- Beras moves through: Week1 → Week2 → Week3 until all sold

---

## User Experience Timeline

```
Week 1:
├─ Mon: Receive 100 Beras
├─ Tue-Thu: Sell 70 units
├─ Fri: Create Claim
│  ├─ Input: 70 sold
│  ├─ See: 20 unsold
│  ├─ Decide: "Bawa ke Minggu Depan"
│  └─ Submit Claim (CLM-2512-0001)
│     └─ Auto-create C/F: 20 units, qty 20, status available
│
Week 2:
├─ Mon: Receive 50 new Beras
├─ Mon: Create Claim
│  ├─ Step 2: See "Penghantaran Belum Dituntut (1)"
│  ├─ Step 2: See "Item C/F (1)" → 20 units from CLM-2512-0001
│  ├─ Select: 1 delivery + 1 C/F
│  └─ Step 3: Total 70 units to claim
│
├─ Tue-Thu: Sell 65 more
├─ Fri: Create Claim (CLM-2512-0002)
│  ├─ Input: 65 sold
│  ├─ See: 5 unsold from new + C/F mixed
│  ├─ Decide: "Bawa ke Minggu Depan" again
│  └─ Submit
│     └─ Auto-mark previous C/F as 'used'
│     └─ Auto-create new C/F: 5 units
│
Week 3:
├─ Mon: Receive 75 Beras
├─ Mon: Create Claim
│  ├─ See C/F: 5 units from CLM-2512-0002
│  ├─ Select all (75 new + 5 C/F)
│  └─ All eventually sold
└─ Fri: Create Final Claim (CLM-2512-0003)
   └─ No C/F left (everything sold)
```

---

## Benefits of This Approach

1. **User Control**
   - Users decide what to C/F (not automatic)
   - Transparency: see reason for each unsold item

2. **Data Accuracy**
   - Track loss vs C/F separately
   - Know how many times item was carried
   - Audit trail: CLM-2512-0001 → CLM-2512-0002 → CLM-2512-0003

3. **Financial Clarity**
   - Only sold items generate payment
   - C/F items tracked separately
   - User can analyze "why always unsold?"

4. **Flexibility**
   - Items can be C/F multiple times
   - User can decide end-of-month: "No more C/F, mark as loss"
   - Support special cases (damaged, expired later)

---

## Implementation Priority

### Priority 1 (CRITICAL)
- [ ] Add UI in Step 3 to let user mark C/F status
- [ ] Update createClaim to save carry_forward_status

### Priority 2 (HIGH)
- [ ] Update DB trigger to use carry_forward_status instead of carry_forward boolean
- [ ] Test C/F creation logic

### Priority 3 (MEDIUM)
- [ ] Improve C/F display in Step 2
- [ ] Add C/F item count to summary
- [ ] Show C/F origin in final summary

### Priority 4 (ENHANCEMENT)
- [ ] Add C/F report: "Items carried X weeks"
- [ ] Alert if item carries too long: "Item X carried 8 weeks!"
- [ ] Allow bulk-mark items as "expired" at end-of-month

---

## Testing Scenarios

### Test 1: Simple C/F
1. Create delivery (10 units)
2. Create claim (8 sold, 2 unsold → mark C/F)
3. Create new claim
4. Verify: 2 C/F units appear in Step 2 ✅

### Test 2: Multiple C/F
1. Week 1: 100 units → 70 sold, 30 C/F
2. Week 2: 50 new + 30 C/F (80 total) → 60 sold, 20 C/F
3. Week 3: See 20 C/F still available ✅

### Test 3: C/F Mix
1. Create claim with: 5 delivered + 10 C/F from week 1
2. Verify: Both shown in summary ✅
3. User sells 12 out of 15 total
4. Mark 3 as C/F again for week 4 ✅

### Test 4: Multiple Products
1. Week 1: Product A (5C/F), Product B (8 C/F)
2. Week 2: See both in C/F list
3. Select only Product A to include
4. Verify: Product B C/F not included ✅

---

**Status:** Ready for Implementation  
**Target:** This week  
**Effort:** 6-8 hours development + 2-3 hours testing

