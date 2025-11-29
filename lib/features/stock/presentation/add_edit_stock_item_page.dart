import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_client.dart' show supabase;
import '../../../data/repositories/stock_repository_supabase.dart';
import '../../../data/models/stock_item.dart';
import '../../../data/models/stock_movement.dart';
import '../../../core/utils/unit_conversion.dart';

/// Add/Edit Stock Item Page
class AddEditStockItemPage extends StatefulWidget {
  final StockItem? stockItem;

  const AddEditStockItemPage({super.key, this.stockItem});

  bool get isEditing => stockItem != null;

  @override
  State<AddEditStockItemPage> createState() => _AddEditStockItemPageState();
}

class _AddEditStockItemPageState extends State<AddEditStockItemPage> {
  late final StockRepository _stockRepository;
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  late final TextEditingController _nameController;
  late final TextEditingController _packageSizeController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _lowStockThresholdController;
  late final TextEditingController _notesController;
  late final TextEditingController _initialQuantityController;
  late final TextEditingController _reasonController;

  String _selectedUnit = Units.gram;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _stockRepository = StockRepository(supabase);

    // Initialize controllers
    _nameController = TextEditingController(text: widget.stockItem?.name ?? '');
    _packageSizeController = TextEditingController(
      text: widget.stockItem?.packageSize.toString() ?? '',
    );
    _purchasePriceController = TextEditingController(
      text: widget.stockItem?.purchasePrice.toString() ?? '',
    );
    _lowStockThresholdController = TextEditingController(
      text: widget.stockItem?.lowStockThreshold.toString() ?? '5',
    );
    _notesController = TextEditingController(text: widget.stockItem?.notes ?? '');
    _initialQuantityController = TextEditingController();
    _reasonController = TextEditingController();

    if (widget.stockItem != null) {
      _selectedUnit = widget.stockItem!.unit;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _packageSizeController.dispose();
    _purchasePriceController.dispose();
    _lowStockThresholdController.dispose();
    _notesController.dispose();
    _initialQuantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _saveStockItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final input = StockItemInput(
        name: _nameController.text.trim(),
        unit: _selectedUnit,
        packageSize: double.parse(_packageSizeController.text),
        purchasePrice: double.parse(_purchasePriceController.text),
        lowStockThreshold: double.parse(_lowStockThresholdController.text),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (widget.isEditing) {
        // Update existing item
        await _stockRepository.updateStockItem(widget.stockItem!.id, input);
      } else {
        // Create new item
        final newItem = await _stockRepository.createStockItem(input);

        // If initial quantity provided, add it
        final initialQty = _initialQuantityController.text.trim();
        if (initialQty.isNotEmpty && double.parse(initialQty) > 0) {
          await _stockRepository.recordStockMovement(
            StockMovementInput(
              stockItemId: newItem.id,
              movementType: StockMovementType.purchase,
              quantityChange: double.parse(initialQty),
              reason: _reasonController.text.trim().isEmpty
                  ? 'Initial stock'
                  : _reasonController.text.trim(),
            ),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditing
                  ? 'Stock item updated!'
                  : 'Stock item added!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Stock Item' : 'Add Stock Item'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Item Name
            _buildTextField(
              controller: _nameController,
              label: 'Item Name',
              hint: 'e.g., Tepung Gandum, Gula Pasir',
              icon: Icons.inventory_2,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter item name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Unit Selection
            _buildUnitDropdown(),
            const SizedBox(height: 16),

            // Package Size & Purchase Price
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _packageSizeController,
                    label: 'Package Size',
                    hint: 'e.g., 500',
                    icon: Icons.scale,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Invalid number';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _purchasePriceController,
                    label: 'Purchase Price (RM)',
                    hint: 'e.g., 21.90',
                    icon: Icons.attach_money,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Invalid number';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Cost per unit calculation
            if (_packageSizeController.text.isNotEmpty &&
                _purchasePriceController.text.isNotEmpty)
              _buildCostPerUnitInfo(),

            const SizedBox(height: 16),

            // Low Stock Threshold
            _buildTextField(
              controller: _lowStockThresholdController,
              label: 'Low Stock Alert Threshold',
              hint: 'e.g., 5',
              icon: Icons.warning_amber_rounded,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Required';
                }
                if (double.tryParse(value) == null) {
                  return 'Invalid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Notes
            _buildTextField(
              controller: _notesController,
              label: 'Notes (Optional)',
              hint: 'Additional information...',
              icon: Icons.notes,
              maxLines: 3,
            ),

            // Initial Quantity (only for new items)
            if (!widget.isEditing) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Initial Stock (Optional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add initial quantity if you already have this item in stock',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _initialQuantityController,
                label: 'Initial Quantity',
                hint: 'e.g., 2000 (for 2000 gram)',
                icon: Icons.add_box,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _reasonController,
                label: 'Reason (Optional)',
                hint: 'e.g., Initial stock from inventory',
                icon: Icons.comment,
                maxLines: 2,
              ),
            ],

            const SizedBox(height: 32),

            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveStockItem,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.isEditing ? 'Update Item' : 'Add Item',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
      ),
    );
  }

  Widget _buildUnitDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonFormField<String>(
        value: _selectedUnit,
        decoration: InputDecoration(
          labelText: 'Unit of Measurement',
          prefixIcon: Icon(Icons.straighten, color: AppColors.primary),
          border: InputBorder.none,
        ),
        items: Units.flatList.map((unit) {
          final category = UnitConversion.getUnitCategory(unit) ?? 'Other';
          return DropdownMenuItem(
            value: unit,
            child: Text('$unit ($category)'),
          );
        }).toList(),
        onChanged: (value) {
          setState(() => _selectedUnit = value!);
        },
      ),
    );
  }

  Widget _buildCostPerUnitInfo() {
    final packageSize = double.tryParse(_packageSizeController.text);
    final purchasePrice = double.tryParse(_purchasePriceController.text);

    if (packageSize != null && purchasePrice != null && packageSize > 0) {
      final costPerUnit = purchasePrice / packageSize;

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.calculate, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Cost per $_selectedUnit: RM ${costPerUnit.toStringAsFixed(4)}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

