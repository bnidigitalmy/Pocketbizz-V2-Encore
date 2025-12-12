import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../data/models/subscription.dart';
import '../../data/repositories/subscription_repository_supabase.dart';
import '../../services/subscription_service.dart';
import 'subscription_list_page.dart';
import 'user_management_page.dart';

/// Admin Dashboard for Subscription Management
/// Shows overview, revenue, analytics, and subscription management
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _subscriptionService = SubscriptionService();
  final _subscriptionRepo = SubscriptionRepositorySupabase();
  
  bool _isLoading = true;
  
  // User Stats
  int _totalUsers = 0;
  int _paidUsers = 0;
  int _activeTrial = 0;
  int _expiredTrial = 0;
  
  // Subscription Stats
  int _totalSubscriptions = 0;
  int _activeSubscriptions = 0;
  
  // Revenue Stats
  double _mrr = 0.0; // Monthly Recurring Revenue
  
  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadUserStats(),
        _loadSubscriptionStats(),
        _loadRevenueStats(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dashboard: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadUserStats() async {
    try {
      // Get all users from auth.users (via Supabase Admin API)
      // For now, we'll count from subscriptions table
      final allSubs = await _subscriptionRepo.getAdminSubscriptions(
        limit: 1000,
      );
      
      // Get unique user IDs
      final userIds = allSubs.map((s) => s.userId).toSet();
      _totalUsers = userIds.length;
      
      // Count paid users (have active subscription)
      final paidUserIds = allSubs
          .where((s) => s.status.toString().contains('active'))
          .map((s) => s.userId)
          .toSet();
      _paidUsers = paidUserIds.length;
      
      // Count trial users
      final trialSubs = allSubs.where((s) => s.status.toString().contains('trial'));
      _activeTrial = trialSubs.where((s) => s.status != SubscriptionStatus.expired && s.expiresAt.isAfter(DateTime.now())).length;
      _expiredTrial = trialSubs.where((s) => s.status == SubscriptionStatus.expired || s.expiresAt.isBefore(DateTime.now())).length;
    } catch (e) {
      debugPrint('Error loading user stats: $e');
    }
  }

  Future<void> _loadSubscriptionStats() async {
    final stats = await _subscriptionRepo.getAdminSubscriptionStats(
      startDate: DateTime.now().subtract(const Duration(days: 365)),
      endDate: DateTime.now(),
    );
    if (mounted) {
      setState(() {
        _totalSubscriptions = stats['total'] as int;
        _activeSubscriptions = stats['active'] as int;
      });
    }
  }

  Future<void> _loadRevenueStats() async {
    final revenue = await _subscriptionRepo.getAdminRevenueStats(
      startDate: DateTime.now().subtract(const Duration(days: 365)),
      endDate: DateTime.now(),
    );
    if (mounted) {
      setState(() {
        _mrr = (revenue['monthly'] as num).toDouble();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 24),
            
            // Stats Cards
            _buildStatsCards(isMobile),
            const SizedBox(height: 24),
            
            // Additional Info Cards
            _buildInfoCards(isMobile),
            const SizedBox(height: 24),
            
            // Quick Actions
            _buildQuickActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Admin Dashboard',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Pantau prestasi sistem dan pengguna PocketBizz',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCards(bool isMobile) {
    final statCards = [
      _StatCard(
        title: 'Jumlah Pengguna',
        value: '$_totalUsers',
        description: '$_paidUsers pengguna berbayar',
        icon: Icons.people,
        color: Colors.blue,
      ),
      _StatCard(
        title: 'Trial Aktif',
        value: '$_activeTrial',
        description: '$_expiredTrial trial tamat tempoh',
        icon: Icons.verified_user,
        color: Colors.green,
      ),
      _StatCard(
        title: 'Subscription Aktif',
        value: '$_activeSubscriptions',
        description: '$_totalSubscriptions jumlah subscription',
        icon: Icons.trending_up,
        color: Colors.purple,
      ),
      _StatCard(
        title: 'MRR (Bulanan)',
        value: 'RM ${_mrr.toStringAsFixed(2)}',
        description: 'Pendapatan berulang bulanan',
        icon: Icons.attach_money,
        color: Colors.amber,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : 4,
        childAspectRatio: isMobile ? 1.3 : 1.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: statCards.length,
      itemBuilder: (context, index) => statCards[index],
    );
  }

  Widget _buildInfoCards(bool isMobile) {
    if (isMobile) {
      return Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Status Pengguna',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pecahan status pengguna semasa',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Pengguna Berbayar', '$_paidUsers', Colors.green),
                  const SizedBox(height: 12),
                  _buildInfoRow('Trial Aktif', '$_activeTrial', Colors.blue),
                  const SizedBox(height: 12),
                  _buildInfoRow('Trial Tamat Tempoh', '$_expiredTrial', Colors.orange),
                  const Divider(height: 24),
                  _buildInfoRow('Jumlah', '$_totalUsers', null, isBold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Subscription',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Statistik langganan pengguna',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Subscription Aktif', '$_activeSubscriptions', Colors.green),
                  const SizedBox(height: 12),
                  _buildInfoRow('Jumlah Subscription', '$_totalSubscriptions', null),
                  const Divider(height: 24),
                  _buildInfoRow('MRR', 'RM ${_mrr.toStringAsFixed(2)}', AppColors.primary, isBold: true),
                ],
              ),
            ),
          ),
        ],
      );
    }
    
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Status Pengguna',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pecahan status pengguna semasa',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Pengguna Berbayar', '$_paidUsers', Colors.green),
                  const SizedBox(height: 12),
                  _buildInfoRow('Trial Aktif', '$_activeTrial', Colors.blue),
                  const SizedBox(height: 12),
                  _buildInfoRow('Trial Tamat Tempoh', '$_expiredTrial', Colors.orange),
                  const Divider(height: 24),
                  _buildInfoRow('Jumlah', '$_totalUsers', null, isBold: true),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Subscription',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Statistik langganan pengguna',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Subscription Aktif', '$_activeSubscriptions', Colors.green),
                  const SizedBox(height: 12),
                  _buildInfoRow('Jumlah Subscription', '$_totalSubscriptions', null),
                  const Divider(height: 24),
                  _buildInfoRow('MRR', 'RM ${_mrr.toStringAsFixed(2)}', AppColors.primary, isBold: true),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, Color? color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? Colors.black87,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    // Navigation handled by AdminLayout
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Use sidebar navigation to switch pages')),
                    );
                  },
                  icon: const Icon(Icons.people, color: Colors.white),
                  label: const Text('Manage Users', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // Navigation handled by AdminLayout
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Use sidebar navigation to switch pages')),
                    );
                  },
                  icon: const Icon(Icons.credit_card, color: Colors.white),
                  label: const Text('Subscriptions', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Export feature coming soon')),
                    );
                  },
                  icon: Icon(Icons.download, color: AppColors.primary),
                  label: Text('Export Data', style: TextStyle(color: AppColors.primary)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String description;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.description,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
