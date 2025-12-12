import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/repositories/subscription_repository_supabase.dart';
import '../../services/subscription_service.dart';
import 'widgets/revenue_chart.dart';
import 'widgets/subscription_stats.dart';
import 'widgets/payment_analytics.dart';
import 'subscription_list_page.dart';

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
  DateTime _selectedStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _selectedEndDate = DateTime.now();
  
  // Stats
  int _totalSubscriptions = 0;
  int _activeSubscriptions = 0;
  double _totalRevenue = 0.0;
  double _monthlyRevenue = 0.0;
  int _totalPayments = 0;
  double _successRate = 0.0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadSubscriptionStats(),
        _loadRevenueStats(),
        _loadPaymentStats(),
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

  Future<void> _loadSubscriptionStats() async {
    final stats = await _subscriptionRepo.getAdminSubscriptionStats(
      startDate: _selectedStartDate,
      endDate: _selectedEndDate,
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
      startDate: _selectedStartDate,
      endDate: _selectedEndDate,
    );
    if (mounted) {
      setState(() {
        _totalRevenue = (revenue['total'] as num).toDouble();
        _monthlyRevenue = (revenue['monthly'] as num).toDouble();
      });
    }
  }

  Future<void> _loadPaymentStats() async {
    final stats = await _subscriptionRepo.getAdminPaymentStats(
      startDate: _selectedStartDate,
      endDate: _selectedEndDate,
    );
    if (mounted) {
      setState(() {
        _totalPayments = stats['total'] as int;
        _successRate = (stats['success_rate'] as num).toDouble();
      });
    }
  }

  Future<void> _selectDateRange() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _selectedStartDate,
        end: _selectedEndDate,
      ),
    );
    if (result != null) {
      setState(() {
        _selectedStartDate = result.start;
        _selectedEndDate = result.end;
      });
      _loadDashboardData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard - Subscriptions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Range Display
                  _buildDateRangeDisplay(),
                  const SizedBox(height: 16),
                  
                  // Stats Cards
                  SubscriptionStats(
                    totalSubscriptions: _totalSubscriptions,
                    activeSubscriptions: _activeSubscriptions,
                    totalRevenue: _totalRevenue,
                    monthlyRevenue: _monthlyRevenue,
                    totalPayments: _totalPayments,
                    successRate: _successRate,
                  ),
                  const SizedBox(height: 24),
                  
                  // Revenue Chart
                  RevenueChart(
                    startDate: _selectedStartDate,
                    endDate: _selectedEndDate,
                  ),
                  const SizedBox(height: 24),
                  
                  // Payment Analytics
                  PaymentAnalytics(
                    startDate: _selectedStartDate,
                    endDate: _selectedEndDate,
                  ),
                  const SizedBox(height: 24),
                  
                  // Quick Actions
                  _buildQuickActions(),
                ],
              ),
            ),
    );
  }

  Widget _buildDateRangeDisplay() {
    final format = DateFormat('dd MMM yyyy', 'ms');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 18),
            const SizedBox(width: 8),
            Text(
              '${format.format(_selectedStartDate)} - ${format.format(_selectedEndDate)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            TextButton(
              onPressed: _selectDateRange,
              child: const Text('Change'),
            ),
          ],
        ),
      ),
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminSubscriptionListPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.list),
                  label: const Text('View All Subscriptions'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Export to CSV
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Export feature coming soon')),
                    );
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Export Data'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

