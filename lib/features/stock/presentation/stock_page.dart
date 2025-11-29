import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_client.dart' show supabase;
import '../../../data/repositories/stock_repository_supabase.dart';
import '../../../data/models/stock_item.dart';
import '../../../core/utils/unit_conversion.dart';
import 'add_edit_stock_item_page.dart';
import 'stock_detail_page.dart';

/// Stock Management Page - List all stock items
class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  late final StockRepository _stockRepository;
  List<StockItem> _stockItems = [];
  List<StockItem> _filteredItems = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _showOnlyLowStock = false;

  @override
  void initState() {
    super.initState();
    _stockRepository = StockRepository(supabase);
    _loadStockItems();
  }

  Future<void> _loadStockItems() async {
    setState(() => _isLoading = true);

    try {
      final items = await _stockRepository.getAllStockItems();
      setState(() {
        _stockItems = items;
        _filteredItems = items;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredItems = _stockItems.where((item) {
        // Search filter
        final matchesSearch = _searchQuery.isEmpty ||
            item.name.toLowerCase().contains(_searchQuery.toLowerCase());

        // Low stock filter
        final matchesLowStock = !_showOnlyLowStock || item.isLowStock;

        return matchesSearch && matchesLowStock;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Stock Management'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _showOnlyLowStock ? Icons.filter_alt : Icons.filter_alt_outlined,
            ),
            onPressed: () {
              setState(() => _showOnlyLowStock = !_showOnlyLowStock);
              _applyFilters();
            },
            tooltip: 'Show only low stock',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _applyFilters();
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search stock items...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          // Stock Stats
          _buildStockStats(),

          // Stock List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredItems.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadStockItems,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) {
                            return _buildStockItemCard(_filteredItems[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEditStockItemPage(),
            ),
          );
          if (result == true) _loadStockItems();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Stock Item'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildStockStats() {
    final lowStockCount = _stockItems.where((item) => item.isLowStock).length;
    final outOfStockCount =
        _stockItems.where((item) => item.currentQuantity <= 0).length;
    final totalValue = _stockItems.fold<double>(
      0.0,
      (sum, item) => sum + (item.currentQuantity * item.costPerUnit),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Items',
              '${_stockItems.length}',
              Icons.inventory_2,
              AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Low Stock',
              '$lowStockCount',
              Icons.warning_amber_rounded,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Out of Stock',
              '$outOfStockCount',
              Icons.error_outline,
              Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStockItemCard(StockItem item) {
    final isLowStock = item.isLowStock;
    final isOutOfStock = item.currentQuantity <= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StockDetailPage(stockItem: item),
            ),
          );
          if (result == true) _loadStockItems();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Status indicator
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isOutOfStock
                          ? Colors.red
                          : isLowStock
                              ? Colors.orange
                              : Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Item name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (item.notes != null)
                          Text(
                            item.notes!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),

                  // Edit button
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AddEditStockItemPage(stockItem: item),
                        ),
                      );
                      if (result == true) _loadStockItems();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Stock info
              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(
                      'Current Stock',
                      UnitConversion.formatQuantity(
                        item.currentQuantity,
                        item.unit,
                      ),
                      Icons.inventory,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInfoChip(
                      'Cost/Unit',
                      'RM ${item.costPerUnit.toStringAsFixed(4)}',
                      Icons.attach_money,
                    ),
                  ),
                ],
              ),

              if (isLowStock) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isOutOfStock
                        ? Colors.red.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isOutOfStock ? Icons.error : Icons.warning_amber_rounded,
                        size: 16,
                        color: isOutOfStock ? Colors.red : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isOutOfStock
                            ? 'OUT OF STOCK!'
                            : 'Low stock (${item.stockLevelPercentage.toStringAsFixed(0)}%)',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOutOfStock ? Colors.red : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 100,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'No stock items yet'
                : 'No items found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Add your first stock item to get started'
                : 'Try a different search term',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

