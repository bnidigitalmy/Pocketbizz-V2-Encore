import 'package:flutter/foundation.dart' show debugPrint;
import '../../../core/supabase/supabase_client.dart';

/// Helper functions for admin access control
/// Now uses database-based admin_users table for secure admin management
class AdminHelper {
  static bool? _cachedAdminStatus;
  static DateTime? _cacheTimestamp;
  static const _cacheTTL = Duration(minutes: 5);
  static Future<bool>? _loadingFuture;

  /// Initialize admin status cache (call this early, e.g., in HomePage initState)
  /// This ensures cache is ready for sync checks
  static Future<void> initializeCache() async {
    if (_cachedAdminStatus == null || 
        _cacheTimestamp == null ||
        DateTime.now().difference(_cacheTimestamp!) >= _cacheTTL) {
      await isAdmin(); // This will fetch and cache
    }
  }

  /// Check if current user is admin (async version)
  /// Uses database-based admin_users table for secure access control
  /// Caches result for 5 minutes to reduce database queries
  static Future<bool> isAdmin() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      _cachedAdminStatus = false;
      return false;
    }

    // If already loading, wait for that future
    if (_loadingFuture != null) {
      return _loadingFuture!;
    }

    // Check cache first (if still valid)
    if (_cachedAdminStatus != null && 
        _cacheTimestamp != null && 
        DateTime.now().difference(_cacheTimestamp!) < _cacheTTL) {
      return _cachedAdminStatus!;
    }

    // Create loading future
    _loadingFuture = _fetchAdminStatus(user.id);
    try {
      final result = await _loadingFuture!;
      return result;
    } finally {
      _loadingFuture = null;
    }
  }

  static Future<bool> _fetchAdminStatus(String userId) async {
    // First, try to use database function (if migration applied)
    try {
      final response = await supabase.rpc('is_admin', params: {
        'user_uuid': userId,
      });
      final isAdmin = response as bool? ?? false;
      _cachedAdminStatus = isAdmin;
      _cacheTimestamp = DateTime.now();
      return isAdmin;
    } catch (rpcError) {
      // RPC function doesn't exist yet - this is expected before migration
      // Silently fall through to next method
      debugPrint('Admin check: RPC function not available (migration not applied), trying direct query...');
    }

    // If RPC function doesn't exist, try direct query to admin_users table
    // This works even if function doesn't exist yet
    // Note: This requires RLS policy "Users can check own admin status"
    try {
      final response = await supabase
          .from('admin_users')
          .select('id')
          .eq('user_id', userId)
          .eq('is_active', true)
          .maybeSingle();
      
      final isAdmin = response != null;
      _cachedAdminStatus = isAdmin;
      _cacheTimestamp = DateTime.now();
      return isAdmin;
    } catch (queryError) {
      // Table doesn't exist yet or RLS blocks it - fallback to old method
      debugPrint('Admin check: Direct query failed (migration not applied), using email whitelist fallback');
    }

    // Final fallback: metadata/email check (for migration period or if table doesn't exist)
    final user = supabase.auth.currentUser;
    if (user != null) {
      // Check user metadata for admin role
      final role = user.userMetadata?['role'] as String?;
      if (role == 'admin' || role == 'super_admin') {
        _cachedAdminStatus = true;
        _cacheTimestamp = DateTime.now();
        return true;
      }

      // Fallback to old email whitelist for backward compatibility
      final adminEmails = [
        'admin@pocketbizz.my',
        'corey@pocketbizz.my',
      ];
      final isAdminEmail = adminEmails.contains(user.email?.toLowerCase());
      if (isAdminEmail) {
        _cachedAdminStatus = true;
        _cacheTimestamp = DateTime.now();
        return true;
      }
    }

    // Default: not admin
    _cachedAdminStatus = false;
    _cacheTimestamp = DateTime.now();
    return false;
  }

  /// Check if current user is admin (synchronous version)
  /// Returns cached value if available, otherwise returns false
  /// For accurate results, use isAdmin() async version or call initializeCache() first
  static bool isAdminSync() {
    return _cachedAdminStatus ?? false;
  }

  /// Clear admin status cache (call after granting/revoking admin access)
  static void clearCache() {
    _cachedAdminStatus = null;
    _cacheTimestamp = null;
    _loadingFuture = null;
  }

  /// Get current user email
  static String? getCurrentUserEmail() {
    return supabase.auth.currentUser?.email;
  }
}

