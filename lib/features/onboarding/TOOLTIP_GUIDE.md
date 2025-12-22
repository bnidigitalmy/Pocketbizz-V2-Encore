# 🎯 Contextual Tooltip Guide - PocketBizz

## 📋 Overview

Tooltip-style onboarding untuk guide users dalam setiap module. Friendly, non-technical, dan explain WHAT to do, bukan HOW technically.

---

## 🎨 Design Principles

### **Copy Guidelines:**
- ✅ **Very short** - 1-2 sentences max
- ✅ **Friendly tone** - Casual Bahasa Malaysia
- ✅ **Non-technical** - No jargon
- ✅ **Action-oriented** - Explain WHAT to do
- ✅ **Skip option** - User boleh skip anytime

### **Trigger Conditions:**
- **First Visit** - Show sekali je, first time masuk module
- **Empty State** - Show bila tak ada data
- **First Action** - Show sebelum first action (optional)

---

## 📝 Tooltip Content by Module

### **1. Dashboard Module**

#### **First Visit:**
**Title:** `Selamat Datang ke Dashboard!`

**Message:**
```
Di sini anda boleh lihat ringkasan perniagaan hari ini. 
Jualan, stok rendah, dan tindakan segera semua ada di sini. 
Scroll untuk lihat lebih banyak.
```

**Trigger:** First visit to dashboard  
**Skip:** Available

**UX Notes:**
- Welcome message
- Explain what dashboard shows
- Encourage exploration

---

### **2. Sales Module**

#### **First Visit:**
**Title:** `Sistem Jualan (POS)`

**Message:**
```
Guna sistem ni untuk rekod jualan harian. 
Pilih produk, tambah ke cart, dan buat invois. 
Semua jualan akan disimpan automatik.
```

**Trigger:** First visit to sales page  
**Skip:** Available

**UX Notes:**
- Explain POS workflow
- Simple steps
- Auto-save reassurance

---

#### **Empty State:**
**Title:** `Belum Ada Jualan Lagi`

**Message:**
```
Bila anda buat jualan pertama, semua rekod akan muncul di sini. 
Klik butang "Jualan Baru" untuk mula.
```

**Trigger:** Empty state (no sales yet)  
**Skip:** Available

**UX Notes:**
- Reassure user
- Clear CTA
- Explain what will appear

---

### **3. Expenses Module**

#### **First Visit:**
**Title:** `Rekod Perbelanjaan`

**Message:**
```
Simpan semua resit perbelanjaan di sini. 
Scan resit dengan mudah atau masukkan manual. 
Semua perbelanjaan akan dikategorikan untuk laporan.
```

**Trigger:** First visit to expenses page  
**Skip:** Available

**UX Notes:**
- Explain purpose
- Multiple input methods
- Link to reports benefit

---

#### **Empty State:**
**Title:** `Mula Rekod Perbelanjaan`

**Message:**
```
Simpan resit perbelanjaan anda di sini untuk track kos perniagaan. 
Klik "Tambah Perbelanjaan" untuk mula.
```

**Trigger:** Empty state (no expenses yet)  
**Skip:** Available

**UX Notes:**
- Explain value
- Clear CTA
- Business benefit

---

### **4. Inventory Module**

#### **First Visit:**
**Title:** `Urus Stok Anda`

**Message:**
```
Lihat semua stok dalam satu tempat. 
Dapat alert bila stok nak habis. 
Tambahkan stok baru atau adjust stok sedia ada.
```

**Trigger:** First visit to inventory page  
**Skip:** Available

**UX Notes:**
- Overview of features
- Alert benefit
- Action options

---

#### **Empty State:**
**Title:** `Tambah Stok Pertama`

**Message:**
```
Mula dengan tambah produk dan stok anda. 
Selepas itu, sistem akan track stok automatik setiap kali jualan dibuat.
```

**Trigger:** Empty state (no inventory yet)  
**Skip:** Available

**UX Notes:**
- First step guidance
- Auto-tracking benefit
- Reassure automation

---

### **5. Reports Module**

#### **First Visit:**
**Title:** `Laporan Perniagaan`

**Message:**
```
Lihat untung rugi, jualan mengikut bulan, dan analisis perniagaan. 
Pilih tempoh masa untuk lihat laporan yang anda nak.
```

**Trigger:** First visit to reports page  
**Skip:** Available

**UX Notes:**
- Explain available reports
- Time period selection
- Business insights

---

#### **Empty State:**
**Title:** `Laporan Akan Muncul Di Sini`

**Message:**
```
Selepas anda mula rekod jualan dan perbelanjaan, 
laporan automatik akan dihasilkan. 
Pilih tarikh untuk lihat laporan.
```

**Trigger:** Empty state (no data yet)  
**Skip:** Available

**UX Notes:**
- Explain when reports appear
- Link to other modules
- Reassure automation

---

## 🔧 Technical Implementation

### **Files Structure:**
```
lib/features/onboarding/
├── services/
│   └── tooltip_service.dart          # Track tooltip status
├── data/
│   └── tooltip_content.dart          # All tooltip content
├── presentation/
│   └── widgets/
│       └── contextual_tooltip.dart    # Tooltip widget
└── TOOLTIP_GUIDE.md                   # This file
```

### **Usage Example:**

```dart
// In your module page (e.g., DashboardPage)
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _checkAndShowTooltip();
  });
}

Future<void> _checkAndShowTooltip() async {
  final shouldShow = await TooltipHelper.shouldShowTooltip(
    context,
    TooltipKeys.dashboard,
  );
  
  if (shouldShow && mounted) {
    final content = TooltipContent.dashboard;
    await TooltipHelper.showTooltip(
      context,
      content.moduleKey,
      content.title,
      content.message,
    );
  }
}
```

### **Empty State Check:**

```dart
Future<void> _checkAndShowTooltip() async {
  final hasData = salesList.isNotEmpty; // Your data check
  
  final shouldShow = await TooltipHelper.shouldShowTooltip(
    context,
    TooltipKeys.sales,
    checkEmptyState: true,
    emptyStateChecker: () => !hasData, // Show if empty
  );
  
  if (shouldShow && mounted) {
    final content = hasData 
        ? TooltipContent.sales 
        : TooltipContent.salesEmpty;
    
    await TooltipHelper.showTooltip(
      context,
      content.moduleKey,
      content.title,
      content.message,
    );
  }
}
```

---

### **6. Products Module**

#### **First Visit:**
**Title:** `Senarai Produk Anda`

**Message:**
```
Tambah dan urus semua produk di sini. 
Setiap produk boleh ada harga, gambar, dan kategori. 
Produk ni akan muncul dalam sistem jualan.
```

**Trigger:** First visit to products page  
**Skip:** Available

---

#### **Empty State:**
**Title:** `Tambah Produk Pertama`

**Message:**
```
Mula dengan tambah produk anda. 
Selepas tambah produk, anda boleh guna dalam sistem jualan dan stok.
```

**Trigger:** Empty state (no products yet)  
**Skip:** Available

---

### **7. Bookings Module**

#### **First Visit:**
**Title:** `Sistem Tempahan`

**Message:**
```
Urus semua tempahan pelanggan di sini. 
Buat tempahan baru, track status, dan generate invois. 
Perfect untuk pre-order dan event planning.
```

**Trigger:** First visit to bookings page  
**Skip:** Available

---

#### **Empty State:**
**Title:** `Belum Ada Tempahan`

**Message:**
```
Bila pelanggan buat tempahan, semua akan muncul di sini. 
Klik "Tempahan Baru" untuk mula.
```

**Trigger:** Empty state (no bookings yet)  
**Skip:** Available

---

### **8. Vendors Module**

#### **First Visit:**
**Title:** `Urus Vendor & Reseller`

**Message:**
```
Tambah vendor yang jual produk anda. 
Set setiap vendor dengan commission dan produk yang boleh jual. 
Sistem akan track jualan dan bayaran automatik.
```

**Trigger:** First visit to vendors page  
**Skip:** Available

---

#### **Empty State:**
**Title:** `Tambah Vendor Pertama`

**Message:**
```
Kalau anda jual melalui kedai lain atau reseller, 
tambah mereka sebagai vendor di sini. 
Sistem akan track commission dan bayaran.
```

**Trigger:** Empty state (no vendors yet)  
**Skip:** Available

---

### **9. Claims Module**

#### **First Visit:**
**Title:** `Urus Tuntutan Vendor`

**Message:**
```
Bila vendor jual produk anda, buat tuntutan di sini. 
Sistem akan kira commission dan bayaran. 
Track semua tuntutan dan status bayaran.
```

**Trigger:** First visit to claims page  
**Skip:** Available

---

#### **Empty State:**
**Title:** `Belum Ada Tuntutan`

**Message:**
```
Bila vendor jual produk anda, buat tuntutan baru di sini. 
Sistem akan kira commission automatik.
```

**Trigger:** Empty state (no claims yet)  
**Skip:** Available

---

### **10. Suppliers Module**

#### **First Visit:**
**Title:** `Senarai Pembekal`

**Message:**
```
Simpan maklumat semua pembekal anda di sini. 
Senang untuk contact dan buat purchase order. 
Link pembekal dengan produk untuk track kos.
```

**Trigger:** First visit to suppliers page  
**Skip:** Available

---

#### **Empty State:**
**Title:** `Tambah Pembekal Pertama`

**Message:**
```
Tambah pembekal yang supply bahan atau produk kepada anda. 
Selepas tambah, anda boleh buat purchase order dengan mudah.
```

**Trigger:** Empty state (no suppliers yet)  
**Skip:** Available

---

### **11. Purchase Orders Module**

#### **First Visit:**
**Title:** `Purchase Order (PO)`

**Message:**
```
Buat order kepada pembekal di sini. 
Track status PO dari pending sampai delivered. 
PO akan update stok automatik bila delivered.
```

**Trigger:** First visit to purchase orders page  
**Skip:** Available

---

#### **Empty State:**
**Title:** `Belum Ada Purchase Order`

**Message:**
```
Bila anda order dari pembekal, buat PO di sini. 
Klik "PO Baru" untuk mula. PO akan update stok automatik.
```

**Trigger:** Empty state (no POs yet)  
**Skip:** Available

---

### **12. Shopping List Module**

#### **First Visit:**
**Title:** `Shopping List`

**Message:**
```
Sistem akan suggest barang yang perlu dibeli bila stok rendah. 
Anda boleh tambah manual atau guna suggestion. 
Convert shopping list ke purchase order dengan mudah.
```

**Trigger:** First visit to shopping list page  
**Skip:** Available

---

#### **Empty State:**
**Title:** `Shopping List Kosong`

**Message:**
```
Bila stok rendah, sistem akan suggest barang untuk dibeli. 
Anda juga boleh tambah manual. 
Convert ke purchase order bila dah siap.
```

**Trigger:** Empty state (no items yet)  
**Skip:** Available

---

### **13. Production Module**

#### **First Visit:**
**Title:** `Planning Production`

**Message:**
```
Plan production berdasarkan recipe dan demand. 
Track bahan yang digunakan dan hasil production. 
Sistem akan update stok automatik selepas production.
```

**Trigger:** First visit to production page  
**Skip:** Available

---

#### **Empty State:**
**Title:** `Mula Planning Production`

**Message:**
```
Plan production anda di sini. 
Buat production plan, rekod production, dan track hasil. 
Sistem akan update stok finished products automatik.
```

**Trigger:** Empty state (no production yet)  
**Skip:** Available

---

### **14. Recipes Module**

#### **First Visit:**
**Title:** `Recipe & Bahan`

**Message:**
```
Simpan semua recipe produk anda di sini. 
Set bahan dan kuantiti untuk setiap recipe. 
Sistem akan kira kos production automatik.
```

**Trigger:** First visit to recipes page  
**Skip:** Available

---

#### **Empty State:**
**Title:** `Tambah Recipe Pertama`

**Message:**
```
Tambah recipe untuk produk anda. 
Set bahan dan kuantiti, sistem akan kira kos automatik. 
Recipe ni akan digunakan dalam production planning.
```

**Trigger:** Empty state (no recipes yet)  
**Skip:** Available

---

### **15. Planner Module**

#### **First Visit:**
**Title:** `Task & Planner`

**Message:**
```
Urus semua task dan planning perniagaan di sini. 
Buat task, set deadline, dan track progress. 
Perfect untuk organize kerja harian.
```

**Trigger:** First visit to planner page  
**Skip:** Available

---

#### **Empty State:**
**Title:** `Mula Planning`

**Message:**
```
Tambah task pertama anda. 
Set deadline, priority, dan track progress. 
Senang untuk organize kerja harian.
```

**Trigger:** Empty state (no tasks yet)  
**Skip:** Available

---

## 📊 Trigger Conditions Summary

| Module | First Visit | Empty State | Notes |
|--------|------------|-------------|-------|
| **Dashboard** | ✅ | ❌ | Always show on first visit |
| **Sales** | ✅ | ✅ | Show both conditions |
| **Expenses** | ✅ | ✅ | Show both conditions |
| **Inventory** | ✅ | ✅ | Show both conditions |
| **Reports** | ✅ | ✅ | Show both conditions |
| **Products** | ✅ | ✅ | Show both conditions |
| **Bookings** | ✅ | ✅ | Show both conditions |
| **Vendors** | ✅ | ✅ | Show both conditions |
| **Claims** | ✅ | ✅ | Show both conditions |
| **Suppliers** | ✅ | ✅ | Show both conditions |
| **Purchase Orders** | ✅ | ✅ | Show both conditions |
| **Shopping List** | ✅ | ✅ | Show both conditions |
| **Production** | ✅ | ✅ | Show both conditions |
| **Recipes** | ✅ | ✅ | Show both conditions |
| **Planner** | ✅ | ✅ | Show both conditions |

---

## ✅ Copy Checklist

- [x] All messages are 1-2 sentences
- [x] Friendly, casual Bahasa Malaysia
- [x] No technical jargon
- [x] Explain WHAT to do
- [x] Clear CTAs where needed
- [x] Skip option available
- [x] Mobile-friendly (short lines)

---

## 🎯 Key Messages Summary

| Module | Core Message | Value Proposition |
|--------|-------------|-------------------|
| **Dashboard** | Overview of business today | Quick business health check |
| **Sales** | Record daily sales easily | Simple POS workflow |
| **Expenses** | Track all receipts | Organized expense tracking |
| **Inventory** | Manage stock in one place | Smart stock alerts |
| **Reports** | View business insights | Automatic report generation |
| **Products** | Manage product catalog | Centralized product management |
| **Bookings** | Handle customer orders | Pre-order management |
| **Vendors** | Manage reseller network | Commission tracking |
| **Claims** | Track vendor sales | Automated commission calculation |
| **Suppliers** | Manage suppliers | Easy purchase ordering |
| **Purchase Orders** | Order from suppliers | Automated stock updates |
| **Shopping List** | Smart buying suggestions | Low stock alerts |
| **Production** | Plan and track production | Recipe-based production |
| **Recipes** | Manage product recipes | Automatic cost calculation |
| **Planner** | Organize business tasks | Task management |

---

## 🧪 Testing

### **Reset Tooltips (for testing):**
```dart
final tooltipService = TooltipService();
await tooltipService.resetAllTooltips();
```

### **Reset Specific Tooltip:**
```dart
await tooltipService.resetTooltip(TooltipKeys.dashboard);
```

### **Check Status:**
```dart
final hasSeen = await tooltipService.hasSeenTooltip(TooltipKeys.sales);
print('Has seen sales tooltip: $hasSeen');
```

---

## 🚀 Integration Steps

1. **Add tooltip check in module pages:**
   - Dashboard page
   - Sales page
   - Expenses page
   - Inventory page
   - Reports page

2. **Check trigger conditions:**
   - First visit: Check `hasSeenTooltip()`
   - Empty state: Check data availability

3. **Show tooltip:**
   - Use `TooltipHelper.showTooltip()`
   - Pass appropriate content from `TooltipContent`

4. **Handle dismissal:**
   - Tooltip auto-marks as seen
   - User can skip anytime

---

**Selamat Guide Users!** 🚀
