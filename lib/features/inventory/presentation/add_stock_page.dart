import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/api/models/inventory_models.dart';
import 'inventory_controller.dart';

class AddStockPage extends ConsumerStatefulWidget {
  const AddStockPage({super.key});

  @override
  ConsumerState<AddStockPage> createState() => _AddStockPageState();
}

class _AddStockPageState extends ConsumerState<AddStockPage> {
  final _formKey = GlobalKey<FormState>();

  final _productIdController = TextEditingController();
  final _quantityController = TextEditingController();
  final _costController = TextEditingController();
  final _batchCodeController = TextEditingController();
  final _warehouseController = TextEditingController();

  DateTime? _expiryDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _productIdController.dispose();
    _quantityController.dispose();
    _costController.dispose();
    _batchCodeController.dispose();
    _warehouseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Stock')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _productIdController,
                decoration: const InputDecoration(labelText: 'Product ID'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
                validator: (value) =>
                    double.tryParse(value ?? '') == null ? 'Invalid number' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _costController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cost per Unit'),
                validator: (value) =>
                    double.tryParse(value ?? '') == null ? 'Invalid number' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _batchCodeController,
                decoration: const InputDecoration(labelText: 'Batch Code'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _warehouseController,
                decoration: const InputDecoration(labelText: 'Warehouse'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Expiry Date'),
                subtitle: Text(
                  _expiryDate != null
                      ? _expiryDate!.toLocal().toString().split(' ').first
                      : 'Not set',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (picked != null) {
                      setState(() => _expiryDate = picked);
                    }
                  },
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving
                    ? null
                    : () async {
                        if (_formKey.currentState?.validate() ?? false) {
                          setState(() => _isSaving = true);
                          final request = BatchCreateRequest(
                            productId: _productIdController.text.trim(),
                            quantity: double.parse(_quantityController.text),
                            costPerUnit: double.parse(_costController.text),
                            batchCode: _batchCodeController.text.trim().isEmpty
                                ? null
                                : _batchCodeController.text.trim(),
                            warehouse: _warehouseController.text.trim().isEmpty
                                ? null
                                : _warehouseController.text.trim(),
                            expiryDate: _expiryDate,
                          );
                          await ref
                              .read(inventoryListControllerProvider.notifier)
                              .addBatch(request);
                          if (!mounted) return;
                          Navigator.of(context).pop(true);
                        }
                      },
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Batch'),
              )
            ],
          ),
        ),
      ),
    );
  }
}

