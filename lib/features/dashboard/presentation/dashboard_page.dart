import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/quick_action_button.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/theme/app_theme.dart';
import 'dashboard_controller.dart';
import 'widgets/low_stock_list.dart';
import 'widgets/recent_sales_list.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardControllerProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(child: Text(state.error!));
    }

    final metrics = state.metrics!;

    return RefreshIndicator(
      onRefresh: () => ref.read(dashboardControllerProvider.notifier).load(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Today\'s Profit',
                  value: 'RM ${metrics.todayProfit.toStringAsFixed(2)}',
                  icon: Icons.trending_up,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatCard(
                  title: 'Total Sales Today',
                  value: 'RM ${metrics.salesToday.toStringAsFixed(2)}',
                  icon: Icons.attach_money,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: metrics.quickActions.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.9,
                    ),
                    itemBuilder: (context, index) {
                      final action = metrics.quickActions[index];
                      return QuickActionButton(
                        icon: IconData(
                          action.icon.codePoint,
                          fontFamily: action.icon.fontFamily,
                        ),
                        label: action.label,
                        onTap: () {
                          // TODO: Navigate using router
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          LowStockList(items: metrics.lowStockItems),
          const SizedBox(height: 16),
          RecentSalesList(sales: metrics.recentSales),
        ],
      ),
    );
  }
}

