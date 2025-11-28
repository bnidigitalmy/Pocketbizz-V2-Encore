import 'package:flutter/material.dart';
import '../../../data/repositories/sales_repository_supabase.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final _repo = SalesRepositorySupabase();
  List<Sale> _sales = [];
  bool _loading = false;
  String? _selectedChannel;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() => _loading = true);

    try {
      final sales = await _repo.listSales(channel: _selectedChannel);
      setState(() {
        _sales = sales;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (channel) {
              setState(() => _selectedChannel = channel == 'all' ? null : channel);
              _loadSales();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All')),
              const PopupMenuItem(value: 'walk-in', child: Text('Walk-in')),
              const PopupMenuItem(value: 'online', child: Text('Online')),
              const PopupMenuItem(value: 'delivery', child: Text('Delivery')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSales,
              child: _sales.isEmpty
                  ? const Center(
                      child: Text('No sales yet. Create your first sale!'),
                    )
                  : ListView.builder(
                      itemCount: _sales.length,
                      itemBuilder: (context, index) {
                        final sale = _sales[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            title: Text(
                              sale.customerName ?? 'Anonymous Customer',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_getChannelIcon(sale.channel) + sale.channel.toUpperCase()),
                                Text(
                                  _formatDateTime(sale.createdAt),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'RM${sale.finalAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.green,
                                  ),
                                ),
                                if (sale.items != null)
                                  Text(
                                    '${sale.items!.length} item(s)',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                              ],
                            ),
                            onTap: () => _showSaleDetails(sale),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).pushNamed('/sales/create');
          if (result == true && mounted) {
            _loadSales();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  String _getChannelIcon(String channel) {
    switch (channel) {
      case 'walk-in':
        return '🏪 ';
      case 'online':
        return '🛒 ';
      case 'delivery':
        return '🚚 ';
      default:
        return '📦 ';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (date == today) {
      return 'Today ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _showSaleDetails(Sale sale) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sale #${sale.id.substring(0, 8).toUpperCase()}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Customer', sale.customerName ?? 'Anonymous'),
              _buildDetailRow('Channel', sale.channel.toUpperCase()),
              _buildDetailRow('Date', _formatDateTime(sale.createdAt)),
              if (sale.notes != null && sale.notes!.isNotEmpty)
                _buildDetailRow('Notes', sale.notes!),
              const Divider(),
              _buildDetailRow(
                'Total Amount',
                'RM${sale.totalAmount.toStringAsFixed(2)}',
              ),
              if (sale.discountAmount != null && sale.discountAmount! > 0)
                _buildDetailRow(
                  'Discount',
                  '-RM${sale.discountAmount!.toStringAsFixed(2)}',
                ),
              _buildDetailRow(
                'Final Amount',
                'RM${sale.finalAmount.toStringAsFixed(2)}',
                bold: true,
              ),
              const SizedBox(height: 16),
              if (sale.items != null && sale.items!.isNotEmpty) ...[
                const Text(
                  'Items:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: sale.items!.length,
                    itemBuilder: (context, index) {
                      final item = sale.items![index];
                      return ListTile(
                        title: Text(item.productName),
                        subtitle: Text('Qty: ${item.quantity} × RM${item.unitPrice.toStringAsFixed(2)}'),
                        trailing: Text(
                          'RM${item.subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Print receipt
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Print - Coming soon!')),
                        );
                      },
                      child: const Text('Print'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

