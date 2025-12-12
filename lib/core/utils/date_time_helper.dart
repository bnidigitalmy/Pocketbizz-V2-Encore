import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

/// DateTime Helper for Malaysia Timezone
/// Converts UTC DateTime to Malaysia timezone (Asia/Kuala_Lumpur, UTC+8)
class DateTimeHelper {
  static bool _initialized = false;

  /// Initialize timezone data (call this in main.dart)
  static void initialize() {
    if (!_initialized) {
      tz.initializeTimeZones();
      _initialized = true;
    }
  }

  /// Get Malaysia timezone location
  static tz.Location get malaysiaLocation {
    return tz.getLocation('Asia/Kuala_Lumpur');
  }

  /// Convert UTC DateTime to Malaysia timezone
  static DateTime toMalaysiaTime(DateTime dateTime) {
    if (!_initialized) {
      initialize();
    }
    
    // DateTime.parse() from JSON usually creates a UTC DateTime
    // Convert to UTC if not already, then to Malaysia timezone
    final utc = dateTime.isUtc 
        ? dateTime 
        : DateTime.utc(
            dateTime.year,
            dateTime.month,
            dateTime.day,
            dateTime.hour,
            dateTime.minute,
            dateTime.second,
            dateTime.millisecond,
            dateTime.microsecond,
          );
    
    // Convert UTC to Malaysia timezone
    final malaysiaTZ = tz.TZDateTime.from(utc, malaysiaLocation);
    
    // Return as regular DateTime (local timezone, but represents Malaysia time)
    return DateTime(
      malaysiaTZ.year,
      malaysiaTZ.month,
      malaysiaTZ.day,
      malaysiaTZ.hour,
      malaysiaTZ.minute,
      malaysiaTZ.second,
      malaysiaTZ.millisecond,
      malaysiaTZ.microsecond,
    );
  }

  /// Format DateTime to Malaysia timezone with date only
  static String formatDate(DateTime dateTime, {String pattern = 'dd MMM yyyy'}) {
    final malaysiaTime = toMalaysiaTime(dateTime);
    return DateFormat(pattern, 'ms').format(malaysiaTime);
  }

  /// Format DateTime to Malaysia timezone with date and time
  static String formatDateTime(DateTime dateTime, {String pattern = 'dd MMM yyyy, hh:mm a'}) {
    final malaysiaTime = toMalaysiaTime(dateTime);
    return DateFormat(pattern, 'ms').format(malaysiaTime);
  }

  /// Format DateTime to Malaysia timezone with time only
  static String formatTime(DateTime dateTime, {String pattern = 'hh:mm a'}) {
    final malaysiaTime = toMalaysiaTime(dateTime);
    return DateFormat(pattern, 'ms').format(malaysiaTime);
  }

  /// Get current time in Malaysia timezone
  static DateTime now() {
    if (!_initialized) {
      initialize();
    }
    final malaysiaTZ = tz.TZDateTime.now(malaysiaLocation);
    return DateTime(
      malaysiaTZ.year,
      malaysiaTZ.month,
      malaysiaTZ.day,
      malaysiaTZ.hour,
      malaysiaTZ.minute,
      malaysiaTZ.second,
      malaysiaTZ.millisecond,
      malaysiaTZ.microsecond,
    );
  }
}

