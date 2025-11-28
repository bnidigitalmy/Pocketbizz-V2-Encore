import 'package:flutter/material.dart';

import '../../../../data/api/models/inventory_models.dart';

class BatchCard extends StatelessWidget {
  const BatchCard({
    super.key,
    required this.batch,
    this.onTap,
  });

  final InventoryBatch batch;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('Batch ${batch.batchCode ?? batch.id.substring(0, 6)}'),
        subtitle: Text(
          'Available: ${batch.availableQuantity.toStringAsFixed(1)} ${batch.unitLabel}',
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Cost RM ${batch.costPerUnit?.toStringAsFixed(2) ?? '-'}'),
            if (batch.expiryDate != null)
              Text(
                'Expiry: ${batch.expiryDate!.toLocal().toString().split(' ').first}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

extension on InventoryBatch {
  String get unitLabel => warehouse ?? '';
}

