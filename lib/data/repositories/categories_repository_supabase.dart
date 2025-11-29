import '../../core/supabase/supabase_client.dart';
import '../models/category.dart';

class CategoriesRepositorySupabase {
  /// Get all categories for current user
  Future<List<Category>> getAll() async {
    try {
      final response = await supabase
          .from('categories')
          .select()
          .eq('is_active', true)
          .order('name', ascending: true);

      return (response as List)
          .map((json) => Category.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch categories: $e');
    }
  }

  /// Create category
  Future<Category> create(String name, {String? description, String? icon, String? color}) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final data = await supabase
        .from('categories')
        .insert({
          'business_owner_id': userId,
          'name': name,
          'description': description,
          'icon': icon,
          'color': color,
        })
        .select()
        .single();

    return Category.fromJson(data);
  }

  /// Update category
  Future<Category> update(String id, Map<String, dynamic> updates) async {
    final data = await supabase
        .from('categories')
        .update({
          ...updates,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();

    return Category.fromJson(data);
  }

  /// Delete category
  Future<void> delete(String id) async {
    await supabase.from('categories').delete().eq('id', id);
  }

  /// Get category by ID
  Future<Category> getById(String id) async {
    final data = await supabase
        .from('categories')
        .select()
        .eq('id', id)
        .single();

    return Category.fromJson(data);
  }
}

