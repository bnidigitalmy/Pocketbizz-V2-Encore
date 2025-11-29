import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/vendors_repository_supabase.dart';
import '../../../data/models/vendor.dart';
import 'vendor_claims_page.dart';
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
  Vendor? _vendor;
  Map<String, dynamic>? _summary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final vendor = await _vendorsRepo.getVendorById(widget.vendorId);
      final summary = await _vendorsRepo.getVendorSummary(widget.vendorId);

      setState(() {
        _vendor = vendor;
        _summary = summary;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isLoading = false);
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

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Sales',
                'RM ${_summary!['total_sales'].toStringAsFixed(2)}',
                Icons.attach_money,
                AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Total Commission',
                'RM ${_summary!['total_commission'].toStringAsFixed(2)}',
                Icons.payments,
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
                'Paid',
                'RM ${_summary!['paid_amount'].toStringAsFixed(2)}',
                Icons.check_circle,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Outstanding',
                'RM ${_summary!['outstanding_balance'].toStringAsFixed(2)}',
                Icons.pending,
                Colors.orange,
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
            if (_vendor!.phone != null)
              _buildInfoRow(Icons.phone, _vendor!.phone!),
            if (_vendor!.email != null)
              _buildInfoRow(Icons.email, _vendor!.email!),
            if (_vendor!.address != null)
              _buildInfoRow(Icons.location_on, _vendor!.address!),
            
            const SizedBox(height: 12),
            const Text(
              'Commission & Bank Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildInfoRow(Icons.percent, 'Commission: ${_vendor!.defaultCommissionRate}%'),
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

  Widget _buildQuickActions() {
    return Column(
      children: [
        _buildActionButton(
          'View Claims',
          Icons.receipt_long,
          AppColors.primary,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VendorClaimsPage(vendorId: widget.vendorId),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          'Assign Products',
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

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
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
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

