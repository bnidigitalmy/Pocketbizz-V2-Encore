import '../../../core/supabase/supabase_client.dart';

/// Helper functions for admin access control
class AdminHelper {
  /// Check if current user is admin
  /// For now, check via user metadata or email whitelist
  static bool isAdmin() {
    final user = supabase.auth.currentUser;
    if (user == null) return false;
    
    // Check user metadata for admin role
    final role = user.userMetadata?['role'] as String?;
    if (role == 'admin' || role == 'super_admin') {
      return true;
    }
    
    // Admin email whitelist (for testing - should be moved to database)
    final adminEmails = [
      'admin@pocketbizz.my',
      'corey@pocketbizz.my',
      // Add more admin emails here
    ];
    
    return adminEmails.contains(user.email?.toLowerCase());
  }
  
  /// Get current user email
  static String? getCurrentUserEmail() {
    return supabase.auth.currentUser?.email;
  }
}

