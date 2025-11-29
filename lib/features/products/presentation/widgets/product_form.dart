import 'package:flutter/material.dart';

import '../../../../data/models/product.dart';

class ProductForm extends StatefulWidget {
  const ProductForm({
    super.key,
    this.initial,
    required this.onSubmit,
  });

  final Product? initial;
  final ValueChanged<Product> onSubmit;

  @override
  State<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _skuController;
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _unitController;
  late final TextEditingController _costController;
  late final TextEditingController _priceController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _skuController = TextEditingController(text: widget.initial?.sku ?? '');
    _nameController = TextEditingController(text: widget.initial?.name ?? '');
    _categoryController =
        TextEditingController(text: widget.initial?.category ?? '');
    _unitController = TextEditingController(text: widget.initial?.unit ?? '');
    _costController = TextEditingController(
      text: widget.initial?.costPrice.toString() ?? '',
    );
    _priceController = TextEditingController(
      text: widget.initial?.salePrice.toString() ?? '',
    );
    _descriptionController =
        TextEditingController(text: widget.initial?.description ?? '');
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _categoryController.dispose();
    _unitController.dispose();
    _costController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildTextField(_skuController, 'SKU')),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField(_nameController, 'Name')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  _categoryController,
                  'Category',
                  required: false,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField(_unitController, 'Unit')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildNumberField(_costController, 'Cost Price'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNumberField(_priceController, 'Sale Price'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextField(
            _descriptionController,
            'Description',
            required: false,
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_formKey.currentState?.validate() ?? false) {
                  final now = DateTime.now();
                  final product = Product(
                    id: '',
                    businessOwnerId: '',
                    sku: _skuController.text.trim(),
                    name: _nameController.text.trim(),
                    unit: _unitController.text.trim(),
                    costPrice: double.parse(_costController.text),
                    salePrice: double.parse(_priceController.text),
                    category: _categoryController.text.trim().isEmpty
                        ? null
                        : _categoryController.text.trim(),
                    description: _descriptionController.text.trim().isEmpty
                        ? null
                        : _descriptionController.text.trim(),
                    createdAt: now,
                    updatedAt: now,
                  );
                  widget.onSubmit(product);
                }
              },
              child: const Text('Save Product'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool required = true,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
      validator: required && maxLines == 1
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Required';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildNumberField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final parsed = double.tryParse(value ?? '');
        if (parsed == null) {
          return 'Enter a valid number';
        }
        return null;
      },
    );
  }
}

