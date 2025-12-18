import '../../core/supabase/supabase_client.dart';
import '../models/supplier.dart';

/// Suppliers Repository
/// Manages suppliers (pembekal bahan/ingredients untuk production)
/// 
/// Note: Different from Vendors (consignee)
/// - Suppliers = Pembekal bahan untuk user beli dan buat produk
/// - Vendors = Consignee (kedai yang jual produk user dengan commission)
/// 
/// Uses vendors table (all vendors are treated as suppliers for this module)
class SuppliersRepository {
  /// Get all suppliers
  Future<List<Supplier>> getAllSuppliers({
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await supabase
          .from('vendors')
          .select()
          .eq('business_owner_id', userId)
          .order('name')
          .range(offset, offset + limit - 1); // Add pagination

      return (response as List)
          .map((json) => Supplier.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch suppliers: $e');
    }
  }

  /// Get supplier by ID
  Future<Supplier?> getSupplierById(String supplierId) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await supabase
          .from('vendors')
          .select()
          .eq('id', supplierId)
          .eq('business_owner_id', userId)
          .maybeSingle();

      if (response == null) return null;

      return Supplier.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to fetch supplier: $e');
    }
  }

  /// Create new supplier
  Future<Supplier> createSupplier({
    required String name,
    String? phone,
    String? email,
    String? address,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final data = {
        'business_owner_id': userId,
        'name': name.trim(),
        'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
        'email': email?.trim().isEmpty == true ? null : email?.trim(),
        'address': address?.trim().isEmpty == true ? null : address?.trim(),
      };

      final response = await supabase
          .from('vendors')
          .insert(data)
          .select()
          .single();

      return Supplier.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to create supplier: $e');
    }
  }

  /// Update supplier
  Future<Supplier> updateSupplier({
    required String id,
    required String name,
    String? phone,
    String? email,
    String? address,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final data = {
        'name': name.trim(),
        'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
        'email': email?.trim().isEmpty == true ? null : email?.trim(),
        'address': address?.trim().isEmpty == true ? null : address?.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await supabase
          .from('vendors')
          .update(data)
          .eq('id', id)
          .eq('business_owner_id', userId)
          .select()
          .single();

      return Supplier.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to update supplier: $e');
    }
  }

  /// Delete supplier
  Future<void> deleteSupplier(String id) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await supabase
          .from('vendors')
          .delete()
          .eq('id', id)
          .eq('business_owner_id', userId);
    } catch (e) {
      throw Exception('Failed to delete supplier: $e');
    }
  }
}

