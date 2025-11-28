import 'package:flutter/material.dart';

import '../../../../core/widgets/section_header.dart';
import '../../../../data/api/models/sales_models.dart';

class RecentSalesList extends StatelessWidget {
  const RecentSalesList({
    super.key,
    required this.sales,
  });

  final List<Sale> sales;

  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: const [
              SectionHeader(title: 'Recent Sales'),
              SizedBox(height: 12),
              Text('No sales recorded yet.'),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SectionHeader(
              title: 'Recent Sales',
            ),
            const SizedBox(height: 12),
            Column(
              children: sales
                  .map(
                    (sale) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(sale.channel),
                      subtitle: Text(
                        sale.createdAt.toLocal().toString(),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('RM ${sale.total.toStringAsFixed(2)}'),
                          Text(
                            'Profit RM ${(sale.profit ?? 0).toStringAsFixed(2)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

