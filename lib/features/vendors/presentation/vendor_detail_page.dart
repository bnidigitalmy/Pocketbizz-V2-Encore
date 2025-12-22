import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/vendors_repository_supabase.dart';
import '../../../data/repositories/vendor_commission_price_ranges_repository_supabase.dart';
import '../../../data/models/vendor.dart';
import '../../../data/models/vendor_commission_price_range.dart';
import 'assign_products_page.dart';

/// Vendor Detail Page - View vendor info, claims, payments
class VendorDetailPage extends StatefulWidget {
  final String vendorId;

  const VendorDetailPage({super.key, required this.vendorId});

  @override
  State<VendorDetailPage> createState() => _VendorDetailPageState();
}

class _VendorDetailPageState extends State<VendorDetailPage> {
  final _vendorsRepo = VendorsRepositorySupabase();
  final _priceRangesRepo = VendorCommissionPriceRangesRepository();
  Vendor? _vendor;
  Map<String, dynamic>? _summary;
  List<VendorCommissionPriceRange> _priceRanges = [];
  bool _isLoading = true;

  final _currencyFormat = NumberFormat.currency(
    locale: 'ms_MY',
    symbol: 'RM ',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final vendor = await _vendorsRepo.getVendorById(widget.vendorId);
      
      if (vendor == null) {
        setState(() {
          _vendor = null;
          _summary = null;
          _priceRanges = [];
          _isLoading = false;
        });
        return;
      }

      // Load summary and price ranges in parallel
      final summaryFuture = _vendorsRepo.getVendorSummary(widget.vendorId);
      
      // Load price ranges if commission type is price_range
      List<VendorCommissionPriceRange> priceRanges = [];
      if (vendor.commissionType == 'price_range') {
        try {
          priceRanges = await _priceRangesRepo.getPriceRanges(widget.vendorId);
        } catch (e) {
          debugPrint('Error loading price ranges: $e');
          // Continue even if price ranges fail to load
        }
      }

      final summary = await summaryFuture;

      if (mounted) {
        setState(() {
          _vendor = vendor;
          _summary = summary;
          _priceRanges = priceRanges;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading vendor data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat memuatkan data vendor: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _vendor = null;
          _summary = null;
          _priceRanges = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_vendor?.name ?? 'Vendor Details'),
        backgroundColor: AppColors.primary,
        actions: [
          if (_vendor != null)
            IconButton(
              icon: Icon(_vendor!.isActive ? Icons.block : Icons.check_circle),
              tooltip: _vendor!.isActive ? 'Deactivate' : 'Activate',
              onPressed: () async {
                await _vendorsRepo.toggleVendorStatus(widget.vendorId, !_vendor!.isActive);
                _loadData();
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _vendor == null
              ? const Center(child: Text('Vendor not found'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Summary Cards
                      _buildSummaryCards(),
                      
                      const SizedBox(height: 20),
                      
                      // Contact Info
                      _buildInfoCard(),
                      
                      const SizedBox(height: 20),
                      
                      // Quick Actions
                      _buildQuickActions(),
                      
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCards() {
    if (_summary == null) return const SizedBox();

    final totalGross = (_summary!['total_gross_amount'] as num?)?.toDouble() ?? 0.0;
    final totalCommission = (_summary!['total_commission'] as num?)?.toDouble() ?? 0.0;
    final totalPaid = (_summary!['total_paid_amount'] as num?)?.toDouble() ?? 0.0;
    final outstanding = (_summary!['outstanding_balance'] as num?)?.toDouble() ?? 0.0;
    final pendingClaims = _summary!['pending_claims'] ?? 0;
    final settledClaims = _summary!['settled_claims'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tuntutan & Bayaran',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Jumlah Jualan',
                _currencyFormat.format(totalGross),
                Icons.point_of_sale,
                AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Komisyen',
                _currencyFormat.format(totalCommission),
                Icons.percent,
                AppColors.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Sudah Dibayar',
                _currencyFormat.format(totalPaid),
                Icons.check_circle,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Baki Tertunggak',
                _currencyFormat.format(outstanding),
                Icons.pending,
                outstanding > 0 ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMiniStatCard(
                'Menunggu',
                pendingClaims.toString(),
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMiniStatCard(
                'Selesai',
                settledClaims.toString(),
                Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contact Information',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            if (_vendor!.vendorNumber != null && _vendor!.vendorNumber!.isNotEmpty)
              _buildInfoRow(Icons.numbers, 'NV: ${_vendor!.vendorNumber}'),
            if (_vendor!.phone != null)
              _buildInfoRow(Icons.phone, _vendor!.phone!),
            if (_vendor!.email != null)
              _buildInfoRow(Icons.email, _vendor!.email!),
            if (_vendor!.address != null)
              _buildInfoRow(Icons.location_on, _vendor!.address!),
            
            const SizedBox(height: 12),
            const Text(
              'Komisyen & Maklumat Bank',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            // Display commission based on type
            if (_vendor!.commissionType == 'percentage')
              _buildInfoRow(Icons.percent, 'Komisyen: ${_vendor!.defaultCommissionRate.toStringAsFixed(2)}%')
            else if (_vendor!.commissionType == 'price_range') ...[
              _buildInfoRow(Icons.settings, 'Jenis: Price Range'),
              if (_priceRanges.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._priceRanges.map((range) => _buildPriceRangeRow(range)),
              ] else
                Padding(
                  padding: const EdgeInsets.only(left: 30, top: 4),
                  child: Text(
                    'Tiada price range ditetapkan',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                  ),
                ),
            ],
            if (_vendor!.bankName != null)
              _buildInfoRow(Icons.account_balance, _vendor!.bankName!),
            if (_vendor!.bankAccountNumber != null)
              _buildInfoRow(Icons.credit_card, _vendor!.bankAccountNumber!),
            if (_vendor!.bankAccountHolder != null)
              _buildInfoRow(Icons.person, _vendor!.bankAccountHolder!),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRangeRow(VendorCommissionPriceRange range) {
    final maxPriceText = range.maxPrice == null 
        ? 'dan ke atas' 
        : 'hingga ${_currencyFormat.format(range.maxPrice!)}';
    
    return Padding(
      padding: const EdgeInsets.only(left: 30, top: 4, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_currencyFormat.format(range.minPrice)} $maxPriceText → Komisyen: ${_currencyFormat.format(range.commissionAmount)}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tindakan Pantas',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          'Lihat Penghantaran',
          'Lihat senarai penghantaran ke vendor ini',
          Icons.local_shipping,
          AppColors.primary,
          () {
            // Navigate to deliveries page with vendor filter
            Navigator.pushNamed(context, '/deliveries', arguments: {'vendorId': widget.vendorId});
          },
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          'Lihat Tuntutan',
          'Lihat tuntutan bayaran dari vendor ini',
          Icons.receipt_long,
          Colors.teal,
          () {
            // Navigate to claims page with vendor filter
            Navigator.pushNamed(context, '/claims', arguments: {'vendorId': widget.vendorId});
          },
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          'Cipta Tuntutan Baru',
          'Buat tuntutan bayaran baru',
          Icons.add_circle,
          Colors.green,
          () {
            Navigator.pushNamed(context, '/claims/create', arguments: {'vendorId': widget.vendorId});
          },
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          'Assign Produk',
          'Tentukan produk untuk vendor ini',
          Icons.inventory,
          AppColors.accent,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AssignProductsPage(vendorId: widget.vendorId),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionButton(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

