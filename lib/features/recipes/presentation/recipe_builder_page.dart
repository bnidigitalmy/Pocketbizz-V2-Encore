import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../data/repositories/recipes_repository_supabase.dart';
import '../../../data/repositories/stock_repository_supabase.dart' as stock_repo;
import '../../../data/models/recipe.dart';
import '../../../data/models/recipe_item.dart';
import '../../../data/models/stock_item.dart';

/// Recipe Builder Page - NEW STRUCTURE
/// Creates recipes for products, then adds ingredients
class RecipeBuilderPage extends StatefulWidget {
  final String productId;
  final String productName;
  final String productUnit;

  const RecipeBuilderPage({
    super.key,
    required this.productId,
    required this.productName,
    required this.productUnit,
  });

  @override
  State<RecipeBuilderPage> createState() => _RecipeBuilderPageState();
}

class _RecipeBuilderPageState extends State<RecipeBuilderPage> {
  final _recipesRepo = RecipesRepositorySupabase();
  late final _stockRepo;
  
  Recipe? _activeRecipe;
  List<RecipeItem> _recipeItems = [];
  List<StockItem> _availableStock = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _stockRepo = stock_repo.StockRepository(supabase);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Get active recipe for this product
      _activeRecipe = await _recipesRepo.getActiveRecipe(widget.productId);
      
      // If no recipe exists, create one
      if (_activeRecipe == null) {
        _activeRecipe = await _createDefaultRecipe();
      }
      
      // Get recipe items
      if (_activeRecipe != null) {
        _recipeItems = await _recipesRepo.getRecipeItems(_activeRecipe!.id);
      }
      
      // Get all stock items
      _availableStock = await _stockRepo.getAllStockItems();

      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<Recipe> _createDefaultRecipe() async {
    return await _recipesRepo.createRecipe(
      productId: widget.productId,
      name: '${widget.productName} - Recipe V1',
      yieldQuantity: 1,
      yieldUnit: widget.productUnit,
    );
  }

  Future<void> _addIngredient() async {
    if (_activeRecipe == null) return;

    StockItem? selectedStock;
    double quantity = 1.0;
    String unit = 'kg';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Ingredient'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Stock item dropdown
              DropdownButtonFormField<StockItem>(
                value: selectedStock,
                decoration: const InputDecoration(labelText: 'Ingredient'),
                items: _availableStock.map((stock) {
                  return DropdownMenuItem(
                    value: stock,
                    child: Text(stock.name),
                  );
                }).toList(),
                onChanged: (value) => setDialogState(() => selectedStock = value),
              ),
              const SizedBox(height: 16),
              // Quantity
              TextFormField(
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
                initialValue: '1.0',
                onChanged: (value) => quantity = double.tryParse(value) ?? 1.0,
              ),
              const SizedBox(height: 16),
              // Unit
              TextFormField(
                decoration: const InputDecoration(labelText: 'Unit'),
                initialValue: unit,
                onChanged: (value) => unit = value,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (selectedStock != null) {
                try {
                  await _recipesRepo.addRecipeItem(
                    recipeId: _activeRecipe!.id,
                    stockItemId: selectedStock!.id,
                    quantityNeeded: quantity,
                    usageUnit: unit,
                  );
                  Navigator.pop(context);
                  _loadData();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Recipe: ${widget.productName}'),
        backgroundColor: AppColors.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Recipe Info Card
                if (_activeRecipe != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _activeRecipe!.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Yield: ${_activeRecipe!.yieldQuantity} ${_activeRecipe!.yieldUnit}'),
                        Text('Total Cost: RM ${_activeRecipe!.totalCost.toStringAsFixed(2)}'),
                        Text('Cost Per Unit: RM ${_activeRecipe!.costPerUnit.toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                const Divider(),
                // Recipe Items List
                Expanded(
                  child: _recipeItems.isEmpty
                      ? const Center(
                          child: Text('No ingredients added yet.\nTap + to add.'),
                        )
                      : ListView.builder(
                          itemCount: _recipeItems.length,
                          itemBuilder: (context, index) {
                            final item = _recipeItems[index];
                            return ListTile(
                              title: Text(item.stockItemName ?? 'Unknown'),
                              subtitle: Text(
                                '${item.quantityNeeded} ${item.usageUnit}',
                              ),
                              trailing: Text(
                                'RM ${item.totalCost.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              onLongPress: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Ingredient?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _recipesRepo.deleteRecipeItem(item.id);
                                  _loadData();
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addIngredient,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }
}
