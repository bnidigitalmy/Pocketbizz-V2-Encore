import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

/// DateTime Helper for User's Local Timezone
/// Auto-detects user's timezone and converts UTC DateTime to local timezone
/// Uses system/browser timezone automatically with Malaysia (Asia/Kuala_Lumpur) as default
class DateTimeHelper {
  static bool _initialized = false;
  static tz.Location? _userLocation;
  
  // Malaysia timezone as default for Malaysian users
  static const String _defaultTimezone = 'Asia/Kuala_Lumpur';

  /// Initialize timezone data (call this in main.dart)
  static void initialize() {
    if (!_initialized) {
      tzdata.initializeTimeZones();
      _initialized = true;
      
      // Try to detect user's timezone
      _detectUserTimezone();
    }
  }
  
  /// Detect user's timezone from browser/system
  static void _detectUserTimezone() {
    try {
      if (kIsWeb) {
        // For web, try to get browser timezone
        // tz.local might not work correctly on web, so we'll use a workaround
        try {
          _userLocation = tz.local;
          debugPrint('DateTimeHelper: Detected timezone: ${_userLocation?.name}');
        } catch (e) {
          debugPrint('DateTimeHelper: Failed to detect timezone, using default: $_defaultTimezone');
          _userLocation = tz.getLocation(_defaultTimezone);
        }
      } else {
        // For mobile, tz.local should work
        _userLocation = tz.local;
      }
    } catch (e) {
      debugPrint('DateTimeHelper: Error detecting timezone: $e');
      _userLocation = tz.getLocation(_defaultTimezone);
    }
    
    // Fallback to Malaysia timezone if detection failed
    _userLocation ??= tz.getLocation(_defaultTimezone);
    
    debugPrint('DateTimeHelper: Using timezone: ${_userLocation?.name}');
  }

  /// Get user's local timezone location
  static tz.Location get userLocation {
    if (!_initialized) {
      initialize();
    }
    return _userLocation ?? tz.getLocation(_defaultTimezone);
  }
  
  /// Get timezone name
  static String get timezoneName => userLocation.name;
  
  /// Get timezone offset in hours (e.g., +8 for Malaysia)
  static int get timezoneOffset {
    final now = tz.TZDateTime.now(userLocation);
    return now.timeZoneOffset.inHours;
  }

  /// Convert UTC DateTime to user's local timezone
  static DateTime toLocalTime(DateTime dateTime) {
    if (!_initialized) {
      initialize();
    }
    
    // If DateTime is already in local timezone, convert to ensure it's correct
    DateTime utcTime;
    if (dateTime.isUtc) {
      utcTime = dateTime;
    } else {
      // Assume it's UTC if not marked (common for database dates)
      utcTime = DateTime.utc(
        dateTime.year,
        dateTime.month,
        dateTime.day,
        dateTime.hour,
        dateTime.minute,
        dateTime.second,
        dateTime.millisecond,
        dateTime.microsecond,
      );
    }
    
    // Convert UTC to user's local timezone
    final localTZ = tz.TZDateTime.from(utcTime, userLocation);
    
    // Return as regular DateTime (local timezone)
    return DateTime(
      localTZ.year,
      localTZ.month,
      localTZ.day,
      localTZ.hour,
      localTZ.minute,
      localTZ.second,
      localTZ.millisecond,
      localTZ.microsecond,
    );
  }

  /// Format DateTime to user's local timezone with date only
  static String formatDate(DateTime dateTime, {String pattern = 'dd MMM yyyy'}) {
    final localTime = toLocalTime(dateTime);
    return DateFormat(pattern, 'ms').format(localTime);
  }

  /// Format DateTime to user's local timezone with date and time
  static String formatDateTime(DateTime dateTime, {String pattern = 'dd MMM yyyy, hh:mm a'}) {
    final localTime = toLocalTime(dateTime);
    return DateFormat(pattern, 'ms').format(localTime);
  }

  /// Format DateTime to user's local timezone with time only
  static String formatTime(DateTime dateTime, {String pattern = 'hh:mm a'}) {
    final localTime = toLocalTime(dateTime);
    return DateFormat(pattern, 'ms').format(localTime);
  }

  /// Get current time in user's local timezone
  /// This automatically uses the system/browser timezone
  static DateTime now() {
    if (!_initialized) {
      initialize();
    }
    final localTZ = tz.TZDateTime.now(userLocation);
    return DateTime(
      localTZ.year,
      localTZ.month,
      localTZ.day,
      localTZ.hour,
      localTZ.minute,
      localTZ.second,
      localTZ.millisecond,
      localTZ.microsecond,
    );
  }

  /// Get current time as TZDateTime in user's timezone (for real-time clock)
  static tz.TZDateTime nowTZ() {
    if (!_initialized) {
      initialize();
    }
    return tz.TZDateTime.now(userLocation);
  }
  
  /// Get today's date at midnight in user's timezone
  static DateTime today() {
    final n = now();
    return DateTime(n.year, n.month, n.day);
  }
  
  /// Check if a DateTime is today in user's timezone
  static bool isToday(DateTime dateTime) {
    final todayDate = today();
    final localDate = toLocalTime(dateTime);
    return localDate.year == todayDate.year &&
           localDate.month == todayDate.month &&
           localDate.day == todayDate.day;
  }
  
  /// Get greeting based on current hour in user's timezone
  static String getGreeting() {
    final hour = now().hour;
    if (hour < 12) {
      return 'Selamat Pagi';
    } else if (hour < 18) {
      return 'Selamat Petang';
    } else {
      return 'Selamat Malam';
    }
  }
}
