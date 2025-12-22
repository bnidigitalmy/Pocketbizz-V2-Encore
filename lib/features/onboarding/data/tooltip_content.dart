/// Tooltip content untuk setiap module
class TooltipContent {
  // Dashboard Module
  static const dashboard = TooltipData(
    moduleKey: 'dashboard',
    title: 'Selamat Datang ke Dashboard!',
    message: 'Di sini anda boleh lihat ringkasan perniagaan hari ini. '
        'Jualan, stok rendah, dan tindakan segera semua ada di sini. '
        'Scroll untuk lihat lebih banyak.',
    triggerCondition: TriggerCondition.firstVisit,
  );

  // Sales Module
  static const sales = TooltipData(
    moduleKey: 'sales',
    title: 'Sistem Jualan (POS)',
    message: 'Guna sistem ni untuk rekod jualan harian. '
        'Pilih produk, tambah ke cart, dan buat invois. '
        'Semua jualan akan disimpan automatik.',
    triggerCondition: TriggerCondition.firstVisit,
  );

  static const salesEmpty = TooltipData(
    moduleKey: 'sales_empty',
    title: 'Belum Ada Jualan Lagi',
    message: 'Bila anda buat jualan pertama, semua rekod akan muncul di sini. '
        'Klik butang "Jualan Baru" untuk mula.',
    triggerCondition: TriggerCondition.emptyState,
  );

  // Expenses Module
  static const expenses = TooltipData(
    moduleKey: 'expenses',
    title: 'Rekod Perbelanjaan',
    message: 'Simpan semua resit perbelanjaan di sini. '
        'Scan resit dengan mudah atau masukkan manual. '
        'Semua perbelanjaan akan dikategorikan untuk laporan.',
    triggerCondition: TriggerCondition.firstVisit,
  );

  static const expensesEmpty = TooltipData(
    moduleKey: 'expenses_empty',
    title: 'Mula Rekod Perbelanjaan',
    message: 'Simpan resit perbelanjaan anda di sini untuk track kos perniagaan. '
        'Klik "Tambah Perbelanjaan" untuk mula.',
    triggerCondition: TriggerCondition.emptyState,
  );

  // Inventory Module
  static const inventory = TooltipData(
    moduleKey: 'inventory',
    title: 'Urus Stok Anda',
    message: 'Lihat semua stok dalam satu tempat. '
        'Dapat alert bila stok nak habis. '
        'Tambahkan stok baru atau adjust stok sedia ada.',
    triggerCondition: TriggerCondition.firstVisit,
  );

  static const inventoryEmpty = TooltipData(
    moduleKey: 'inventory_empty',
    title: 'Tambah Stok Pertama',
    message: 'Mula dengan tambah produk dan stok anda. '
        'Selepas itu, sistem akan track stok automatik setiap kali jualan dibuat.',
    triggerCondition: TriggerCondition.emptyState,
  );

  // Reports Module
  static const reports = TooltipData(
    moduleKey: 'reports',
    title: 'Laporan Perniagaan',
    message: 'Lihat untung rugi, jualan mengikut bulan, dan analisis perniagaan. '
        'Pilih tempoh masa untuk lihat laporan yang anda nak.',
    triggerCondition: TriggerCondition.firstVisit,
  );

  static const reportsEmpty = TooltipData(
    moduleKey: 'reports_empty',
    title: 'Laporan Akan Muncul Di Sini',
    message: 'Selepas anda mula rekod jualan dan perbelanjaan, '
        'laporan automatik akan dihasilkan. '
        'Pilih tarikh untuk lihat laporan.',
    triggerCondition: TriggerCondition.emptyState,
  );

  // Products Module
  static const products = TooltipData(
    moduleKey: 'products',
    title: 'Senarai Produk Anda',
    message: 'Tambah dan urus semua produk di sini. '
        'Setiap produk boleh ada harga, gambar, dan kategori. '
        'Produk ni akan muncul dalam sistem jualan.',
    triggerCondition: TriggerCondition.firstVisit,
  );

  static const productsEmpty = TooltipData(
    moduleKey: 'products_empty',
    title: 'Tambah Produk Pertama',
    message: 'Mula dengan tambah produk anda. '
        'Selepas tambah produk, anda boleh guna dalam sistem jualan dan stok.',
    triggerCondition: TriggerCondition.emptyState,
  );

  // Bookings Module
  static const bookings = TooltipData(
    moduleKey: 'bookings',
    title: 'Sistem Tempahan',
    message: 'Urus semua tempahan pelanggan di sini. '
        'Buat tempahan baru, track status, dan generate invois. '
        'Perfect untuk pre-order dan event planning.',
    triggerCondition: TriggerCondition.firstVisit,
  );

  static const bookingsEmpty = TooltipData(
    moduleKey: 'bookings_empty',
    title: 'Belum Ada Tempahan',
    message: 'Bila pelanggan buat tempahan, semua akan muncul di sini. '
        'Klik "Tempahan Baru" untuk mula.',
    triggerCondition: TriggerCondition.emptyState,
  );

  // Vendors Module
  static const vendors = TooltipData(
    moduleKey: 'vendors',
    title: 'Urus Vendor & Reseller',
    message: 'Tambah vendor yang jual produk anda. '
        'Set setiap vendor dengan commission dan produk yang boleh jual. '
        'Sistem akan track jualan dan bayaran automatik.',
    triggerCondition: TriggerCondition.firstVisit,
  );

  static const vendorsEmpty = TooltipData(
    moduleKey: 'vendors_empty',
    title: 'Tambah Vendor Pertama',
    message: 'Kalau anda jual melalui kedai lain atau reseller, '
        'tambah mereka sebagai vendor di sini. '
        'Sistem akan track commission dan bayaran.',
    triggerCondition: TriggerCondition.emptyState,
  );

  // Claims Module
  static const claims = TooltipData(
    moduleKey: 'claims',
    title: 'Urus Tuntutan Vendor',
    message: 'Bila vendor jual produk anda, buat tuntutan di sini. '
        'Sistem akan kira commission dan bayaran. '
        'Track semua tuntutan dan status bayaran.',
    triggerCondition: TriggerCondition.firstVisit,
  );

  static const claimsEmpty = TooltipData(
    moduleKey: 'claims_empty',
    title: 'Belum Ada Tuntutan',
    message: 'Bila vendor jual produk anda, buat tuntutan baru di sini. '
        'Sistem akan kira commission automatik.',
    triggerCondition: TriggerCondition.emptyState,
  );

  // Suppliers Module
  static const suppliers = TooltipData(
    moduleKey: 'suppliers',
    title: 'Senarai Pembekal',
    message: 'Simpan maklumat semua pembekal anda di sini. '
        'Senang untuk contact dan buat purchase order. '
        'Link pembekal dengan produk untuk track kos.',
    triggerCondition: TriggerCondition.firstVisit,
  );

  static const suppliersEmpty = TooltipData(
    moduleKey: 'suppliers_empty',
    title: 'Tambah Pembekal Pertama',
    message: 'Tambah pembekal yang supply bahan atau produk kepada anda. '
        'Selepas tambah, anda boleh buat purchase order dengan mudah.',
    triggerCondition: TriggerCondition.emptyState,
  );

  // Purchase Orders Module
  static const purchaseOrders = TooltipData(
    moduleKey: 'purchase_orders',
    title: 'Purchase Order (PO)',
    message: 'Buat order kepada pembekal di sini. '
        'Track status PO dari pending sampai delivered. '
        'PO akan update stok automatik bila delivered.',
    triggerCondition: TriggerCondition.firstVisit,
  );

  static const purchaseOrdersEmpty = TooltipData(
    moduleKey: 'purchase_orders_empty',
    title: 'Belum Ada Purchase Order',
    message: 'Bila anda order dari pembekal, buat PO di sini. '
        'Klik "PO Baru" untuk mula. PO akan update stok automatik.',
    triggerCondition: TriggerCondition.emptyState,
  );

  // Shopping List Module
  static const shoppingList = TooltipData(
    moduleKey: 'shopping_list',
    title: 'Shopping List',
    message: 'Sistem akan suggest barang yang perlu dibeli bila stok rendah. '
        'Anda boleh tambah manual atau guna suggestion. '
        'Convert shopping list ke purchase order dengan mudah.',
    triggerCondition: TriggerCondition.firstVisit,
  );

  static const shoppingListEmpty = TooltipData(
    moduleKey: 'shopping_list_empty',
    title: 'Shopping List Kosong',
    message: 'Bila stok rendah, sistem akan suggest barang untuk dibeli. '
        'Anda juga boleh tambah manual. '
        'Convert ke purchase order bila dah siap.',
    triggerCondition: TriggerCondition.emptyState,
  );

  // Production Module
  static const production = TooltipData(
    moduleKey: 'production',
    title: 'Planning Production',
    message: 'Plan production berdasarkan recipe dan demand. '
        'Track bahan yang digunakan dan hasil production. '
        'Sistem akan update stok automatik selepas production.',
    triggerCondition: TriggerCondition.firstVisit,
  );

  static const productionEmpty = TooltipData(
    moduleKey: 'production_empty',
    title: 'Mula Planning Production',
    message: 'Plan production anda di sini. '
        'Buat production plan, rekod production, dan track hasil. '
        'Sistem akan update stok finished products automatik.',
    triggerCondition: TriggerCondition.emptyState,
  );

  // Recipes Module
  static const recipes = TooltipData(
    moduleKey: 'recipes',
    title: 'Recipe & Bahan',
    message: 'Simpan semua recipe produk anda di sini. '
        'Set bahan dan kuantiti untuk setiap recipe. '
        'Sistem akan kira kos production automatik.',
    triggerCondition: TriggerCondition.firstVisit,
  );

  static const recipesEmpty = TooltipData(
    moduleKey: 'recipes_empty',
    title: 'Tambah Recipe Pertama',
    message: 'Tambah recipe untuk produk anda. '
        'Set bahan dan kuantiti, sistem akan kira kos automatik. '
        'Recipe ni akan digunakan dalam production planning.',
    triggerCondition: TriggerCondition.emptyState,
  );

  // Planner Module
  static const planner = TooltipData(
    moduleKey: 'planner',
    title: 'Task & Planner',
    message: 'Urus semua task dan planning perniagaan di sini. '
        'Buat task, set deadline, dan track progress. '
        'Perfect untuk organize kerja harian.',
    triggerCondition: TriggerCondition.firstVisit,
  );

  static const plannerEmpty = TooltipData(
    moduleKey: 'planner_empty',
    title: 'Mula Planning',
    message: 'Tambah task pertama anda. '
        'Set deadline, priority, dan track progress. '
        'Senang untuk organize kerja harian.',
    triggerCondition: TriggerCondition.emptyState,
  );
}

/// Tooltip data model
class TooltipData {
  final String moduleKey;
  final String title;
  final String message;
  final TriggerCondition triggerCondition;

  const TooltipData({
    required this.moduleKey,
    required this.title,
    required this.message,
    required this.triggerCondition,
  });
}

/// Trigger conditions untuk tooltip
enum TriggerCondition {
  firstVisit, // Show sekali je, first time masuk module
  emptyState, // Show bila tak ada data
  firstAction, // Show sebelum first action
}
