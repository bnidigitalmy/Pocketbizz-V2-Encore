import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SubscriptionStats extends StatelessWidget {
  final int totalSubscriptions;
  final int activeSubscriptions;
  final double totalRevenue;
  final double monthlyRevenue;
  final int totalPayments;
  final double successRate;

  const SubscriptionStats({
    super.key,
    required this.totalSubscriptions,
    required this.activeSubscriptions,
    required this.totalRevenue,
    required this.monthlyRevenue,
    required this.totalPayments,
    required this.successRate,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'RM ', decimalDigits: 2);
    
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _StatCard(
          title: 'Total Subscriptions',
          value: totalSubscriptions.toString(),
          icon: Icons.subscriptions,
          color: Colors.blue,
        ),
        _StatCard(
          title: 'Active Subscriptions',
          value: activeSubscriptions.toString(),
          icon: Icons.check_circle,
          color: Colors.green,
        ),
        _StatCard(
          title: 'Total Revenue',
          value: currencyFormat.format(totalRevenue),
          icon: Icons.attach_money,
          color: Colors.orange,
        ),
        _StatCard(
          title: 'Monthly Revenue',
          value: currencyFormat.format(monthlyRevenue),
          icon: Icons.calendar_month,
          color: Colors.purple,
        ),
        _StatCard(
          title: 'Total Payments',
          value: totalPayments.toString(),
          icon: Icons.payment,
          color: Colors.teal,
        ),
        _StatCard(
          title: 'Success Rate',
          value: '${successRate.toStringAsFixed(1)}%',
          icon: Icons.trending_up,
          color: Colors.indigo,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
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

