/// App Configuration
/// Centralized configuration for API keys and secrets
class AppConfig {
  // ============================================================================
  // SUPABASE
  // ============================================================================
  /// Supabase Project URL.
  ///
  /// Override via:
  /// `flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co`
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://gxllowlurizrkvpdircw.supabase.co',
  );

  /// Supabase anon key (public).
  ///
  /// Override via:
  /// `flutter run --dart-define=SUPABASE_ANON_KEY=...`
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd4bGxvd2x1cml6cmt2cGRpcmN3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQyMTAyMDksImV4cCI6MjA3OTc4NjIwOX0.Avft6LyKGwmU8JH3hXmO7ukNBlgG1XngjBX-prObycs',
  );

  // Google OAuth Configuration
  // Get these from Google Cloud Console > APIs & Services > Credentials
  // For Flutter Web, only Client ID is needed (Client Secret is for server-side only)
  
  /// Google OAuth Client ID for Web Application
  /// Format: xxxxxx-xxxxx.apps.googleusercontent.com
  static const String googleOAuthClientId = '214368454746-pvb44rkgman7elikd61q37673mlrdnuf.apps.googleusercontent.com';
  
  // Note: Client Secret is NOT needed for client-side OAuth flows
  // Client Secret is only used for server-side OAuth (backend-to-backend)
}



