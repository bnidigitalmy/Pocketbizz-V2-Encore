import 'package:flutter/material.dart';

import '../../data/models/stock_item.dart';

/// Searchable picker for StockItem.
/// Replaces long dropdown lists with type-to-search (autocomplete).
class StockItemSearchField extends StatelessWidget {
  final List<StockItem> items;
  final StockItem? value;
  final ValueChanged<StockItem?> onChanged;
  final String labelText;
  final String? helperText;
  final bool enabled;

  const StockItemSearchField({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.labelText = 'Pilih Bahan',
    this.helperText,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<StockItem>(
      initialValue: TextEditingValue(text: value?.name ?? ''),
      displayStringForOption: (opt) => opt.name,
      optionsBuilder: (TextEditingValue textEditingValue) {
        final q = textEditingValue.text.trim().toLowerCase();
        if (q.isEmpty) {
          // Show all (sorted) when empty so user can scroll a bit + search.
          final all = List<StockItem>.from(items)
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          return all;
        }
        final filtered = items.where((s) => s.name.toLowerCase().contains(q)).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return filtered;
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        // Keep field in sync with selected value when not actively searching
        if ((value?.name ?? '').isNotEmpty && controller.text.isEmpty) {
          controller.text = value!.name;
        }

        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          decoration: InputDecoration(
            labelText: labelText,
            helperText: helperText,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: controller.text.isEmpty
                ? const Icon(Icons.keyboard_arrow_down)
                : IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      controller.clear();
                      onChanged(null);
                      FocusScope.of(context).requestFocus(focusNode);
                    },
                  ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320, maxWidth: 520),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final stock = options.elementAt(index);
                  final pricePerUnit =
                      stock.packageSize > 0 ? (stock.purchasePrice / stock.packageSize) : 0.0;
                  return ListTile(
                    dense: true,
                    title: Text(
                      stock.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${stock.packageSize.toStringAsFixed(0)}${stock.unit} @ RM${stock.purchasePrice.toStringAsFixed(2)} '
                      '(RM${pricePerUnit.toStringAsFixed(2)}/${stock.unit})  •  Stok: ${stock.currentQuantity.toStringAsFixed(1)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => onSelected(stock),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (selection) => onChanged(selection),
    );
  }
}


