import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter/foundation.dart' show kIsWeb;

/// DateTime Helper for User's Local Timezone
/// Auto-detects user's timezone and converts UTC DateTime to local timezone
/// Uses system/browser timezone automatically
class DateTimeHelper {
  static bool _initialized = false;

  /// Initialize timezone data (call this in main.dart)
  static void initialize() {
    if (!_initialized) {
      tz.initializeTimeZones();
      _initialized = true;
    }
  }

  /// Get user's local timezone location (auto-detected by system)
  static tz.Location get userLocation {
    if (!_initialized) {
      initialize();
    }
    // Use local timezone (auto-detected by system/browser)
    // This automatically uses the user's system timezone
    return tz.local;
  }

  /// Convert UTC DateTime to user's local timezone
  static DateTime toLocalTime(DateTime dateTime) {
    if (!_initialized) {
      initialize();
    }
    
    // If DateTime is already in local timezone, return as is
    if (!dateTime.isUtc) {
      return dateTime;
    }
    
    // Convert UTC to user's local timezone
    final localTZ = tz.TZDateTime.from(dateTime, userLocation);
    
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
    // DateTime.now() already uses local timezone
    // But we ensure consistency by using timezone package
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
}

