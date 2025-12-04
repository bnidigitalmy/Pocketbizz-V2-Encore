# 🎯 CLAIMS MODULE - SIMPLIFIED ARCHITECTURE & FLOW

## 📋 OVERVIEW

**Tujuan:** Membolehkan user (pemilik bisnes) menuntut bayaran dari vendor untuk produk yang telah dijual melalui sistem consignment.

**Prinsip Reka Bentuk:**
- ✅ **Mudah difahami** - Non-techy users boleh guna tanpa training
- ✅ **Step-by-step guidance** - Clear instructions pada setiap langkah
- ✅ **Visual feedback** - User tahu apa yang berlaku
- ✅ **Auto-calculate** - System handle calculations automatically
- ✅ **Error prevention** - Validate sebelum submit

---

## 🔄 SIMPLIFIED USER FLOW

### **Flow 1: Cipta Tuntutan (Create Claim)**

```
┌─────────────────────────────────────────────────────────┐
│  STEP 1: Pilih Vendor                                   │
│  ─────────────────────────────────────────────────────  │
│  • Dropdown dengan semua vendors                       │
│  • Auto-filter deliveries untuk vendor tersebut        │
│  • Show: "Pilih vendor untuk lihat penghantaran"       │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│  STEP 2: Pilih Penghantaran                            │
│  ─────────────────────────────────────────────────────  │
│  • List semua deliveries untuk vendor (status: delivered)│
│  • Checkbox untuk pilih multiple deliveries             │
│  • Show: Date, Total Amount, Status                     │
│  • Auto-highlight deliveries yang belum dituntut       │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│  STEP 3: Semak & Edit Kuantiti (Optional)              │
│  ─────────────────────────────────────────────────────  │
│  • Show summary: Total items, Total value               │
│  • Button: "Edit Kuantiti" (jika perlu)                │
│  • Auto-calculate: Terjual, Tidak Terjual, Luput, Rosak│
│  • Validation: Jumlah mesti sama dengan dihantar       │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│  STEP 4: Review & Submit                                │
│  ─────────────────────────────────────────────────────  │
│  • Show summary card:                                   │
│    - Jumlah Terjual: RM XXX                            │
│    - Komisyen (X%): RM XXX                             │
│    - Jumlah Tuntutan: RM XXX                           │
│  • Notes field (optional)                               │
│  • Button: "Cipta Tuntutan"                            │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│  SUCCESS: Tuntutan Dicipta                              │
│  ─────────────────────────────────────────────────────  │
│  • Show success message                                 │
│  • Auto-navigate to claims list                         │
│  • Highlight new claim                                  │
└─────────────────────────────────────────────────────────┘
```

---

## 🏗️ ARCHITECTURE REDESIGN

### **Layer 1: Presentation (UI)**
```
lib/features/claims/
├── presentation/
│   ├── claims_list_page.dart          # Main list page
│   ├── create_claim_flow/             # NEW: Step-by-step flow
│   │   ├── step1_vendor_selection.dart
│   │   ├── step2_delivery_selection.dart
│   │   ├── step3_quantity_review.dart
│   │   └── step4_claim_summary.dart
│   ├── claim_detail_page.dart         # View claim details
│   └── widgets/
│       ├── claim_summary_card.dart    # Show totals
│       ├── delivery_selection_card.dart
│       └── quantity_editor.dart      # Visual quantity editor
```

### **Layer 2: Business Logic (Repository)**
```
lib/data/repositories/
└── consignment_claims_repository_supabase.dart
    ├── createClaim()                  # Simplified - auto-handle everything
    ├── validateClaimData()            # NEW: Pre-validation
    ├── calculateClaimAmounts()        # NEW: Extract calculation logic
    └── getAvailableDeliveries()       # NEW: Get deliveries for claim
```

### **Layer 3: Data Models**
```
lib/data/models/
├── consignment_claim.dart             # Main claim model
├── claim_summary.dart                 # NEW: Summary for UI
└── claim_validation_result.dart       # NEW: Validation feedback
```

---

## 🎨 UX IMPROVEMENTS

### **1. Simplified Language**
- ❌ "Vendor Delivery Items" → ✅ "Produk yang Dihantar"
- ❌ "Quantity Sold/Unsold" → ✅ "Terjual / Belum Terjual"
- ❌ "Consignment Claim" → ✅ "Tuntutan Bayaran"
- ❌ "Commission Rate" → ✅ "Komisyen (%)"

### **2. Visual Indicators**
- ✅ Color coding: Green (success), Orange (pending), Red (error)
- ✅ Icons untuk setiap status
- ✅ Progress indicator untuk multi-step flow
- ✅ Summary cards dengan big numbers

### **3. Smart Defaults**
- ✅ Auto-select current month deliveries
- ✅ Auto-calculate quantities (assume all unsold if not set)
- ✅ Auto-apply vendor commission rate
- ✅ Default claim date = today

### **4. Help Text & Tooltips**
- ✅ Info icons dengan explanations
- ✅ Placeholder text dengan examples
- ✅ Error messages dengan suggestions
- ✅ "What is this?" links untuk complex concepts

---

## 🔧 TECHNICAL IMPROVEMENTS

### **1. Simplified Repository Logic**

**Before (Complex):**
```dart
// Too many steps, hard to understand
- Validate deliveries
- Get delivery items
- Auto-balance quantities
- Update database
- Get vendor commission
- Calculate amounts
- Create claim with retry logic
- Create claim items
```

**After (Simplified):**
```dart
// Clear, single responsibility
Future<ConsignmentClaim> createClaim(ClaimRequest request) async {
  // 1. Validate (return clear errors)
  final validation = await validateClaimRequest(request);
  if (!validation.isValid) throw ClaimValidationException(validation.errors);
  
  // 2. Prepare data (auto-calculate everything)
  final claimData = await prepareClaimData(request);
  
  // 3. Create (with retry for race conditions)
  return await _createClaimWithRetry(claimData);
}
```

### **2. Better Error Handling**

**Before:**
```dart
throw Exception('Some deliveries not found');
```

**After:**
```dart
throw ClaimValidationException(
  message: 'Penghantaran tidak dijumpai',
  details: [
    'Penghantaran #123 tidak wujud atau sudah dituntut',
    'Sila pilih penghantaran lain atau semak senarai penghantaran'
  ],
  suggestions: ['Lihat semua penghantaran', 'Hubungi vendor']
);
```

### **3. Validation Layer**

```dart
class ClaimValidator {
  static Future<ValidationResult> validate(ClaimRequest request) async {
    final errors = <String>[];
    final warnings = <String>[];
    
    // Check vendor exists
    if (request.vendorId == null) {
      errors.add('Sila pilih vendor');
    }
    
    // Check deliveries selected
    if (request.deliveryIds.isEmpty) {
      errors.add('Sila pilih sekurang-kurangnya satu penghantaran');
    }
    
    // Check deliveries not already claimed
    final claimedDeliveries = await _getClaimedDeliveries(request.deliveryIds);
    if (claimedDeliveries.isNotEmpty) {
      errors.add('Beberapa penghantaran sudah dituntut: ${claimedDeliveries.join(", ")}');
    }
    
    // Check quantities valid
    final quantityErrors = await _validateQuantities(request);
    errors.addAll(quantityErrors);
    
    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }
}
```

---

## 📊 DATA FLOW (SIMPLIFIED)

```
User Action
    ↓
UI Validation (Client-side)
    ↓
Business Logic Validation (Repository)
    ↓
Auto-Calculate Amounts
    ↓
Database Transaction
    ↓
Success Response
    ↓
UI Update
```

---

## 🎯 KEY PRINCIPLES

1. **Progressive Disclosure** - Show only what user needs at each step
2. **Auto-Calculate** - System handle math, user just review
3. **Clear Feedback** - User always know what's happening
4. **Error Prevention** - Validate before submit, show clear errors
5. **Visual Hierarchy** - Important info big and clear
6. **Consistent Language** - Use business terms, not technical terms

---

## 📝 IMPLEMENTATION PLAN

### Phase 1: Core Simplification
- [ ] Refactor repository to simpler methods
- [ ] Add validation layer
- [ ] Improve error messages
- [ ] Add summary calculations

### Phase 2: UI Improvements
- [ ] Create step-by-step flow
- [ ] Add visual indicators
- [ ] Improve quantity editor
- [ ] Add help text

### Phase 3: User Experience
- [ ] Add tooltips and explanations
- [ ] Improve error messages with suggestions
- [ ] Add confirmation dialogs
- [ ] Add success animations

---

**Goal:** User boleh create claim dalam 3 clicks tanpa perlu faham technical details! 🚀

