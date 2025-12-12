import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/subscription.dart';
import '../../data/repositories/subscription_repository_supabase.dart';

class AdminSubscriptionListPage extends StatefulWidget {
  const AdminSubscriptionListPage({super.key});

  @override
  State<AdminSubscriptionListPage> createState() => _AdminSubscriptionListPageState();
}

class _AdminSubscriptionListPageState extends State<AdminSubscriptionListPage> {
  final _repo = SubscriptionRepositorySupabase();
  bool _isLoading = true;
  List<Subscription> _subscriptions = [];
  String? _selectedStatus;
  String? _searchUserId;

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    setState(() => _isLoading = true);
    try {
      final subs = await _repo.getAdminSubscriptions(
        status: _selectedStatus,
        userId: _searchUserId,
        limit: 100,
      );
      if (mounted) {
        setState(() {
          _subscriptions = subs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
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
        title: const Text('All Subscriptions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilters,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSubscriptions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _subscriptions.isEmpty
              ? const Center(child: Text('No subscriptions found'))
              : ListView.builder(
                  itemCount: _subscriptions.length,
                  itemBuilder: (context, index) {
                    final sub = _subscriptions[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text('User: ${sub.userId.substring(0, 8)}...'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Plan: ${sub.planName}'),
                            Text('Status: ${sub.status.toString().split('.').last}'),
                            Text('Expires: ${DateFormat('dd MMM yyyy', 'ms').format(sub.expiresAt)}'),
                          ],
                        ),
                        trailing: Text('RM ${sub.totalAmount.toStringAsFixed(2)}'),
                        onTap: () {
                          // TODO: Show subscription details dialog
                        },
                      ),
                    );
                  },
                ),
    );
  }

  void _showFilters() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Subscriptions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                const DropdownMenuItem(value: 'active', child: Text('Active')),
                const DropdownMenuItem(value: 'trial', child: Text('Trial')),
                const DropdownMenuItem(value: 'expired', child: Text('Expired')),
                const DropdownMenuItem(value: 'paused', child: Text('Paused')),
              ],
              onChanged: (value) {
                setState(() => _selectedStatus = value);
              },
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'User ID'),
              onChanged: (value) {
                setState(() => _searchUserId = value.isEmpty ? null : value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedStatus = null;
                _searchUserId = null;
              });
              Navigator.pop(context);
              _loadSubscriptions();
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadSubscriptions();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

