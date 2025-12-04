/// Validation result for claim creation
/// Provides clear feedback to users about what's wrong and how to fix it
class ClaimValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final Map<String, dynamic>? data;

  ClaimValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
    this.data,
  });

  String get errorMessage {
    if (errors.isEmpty) return '';
    if (errors.length == 1) return errors.first;
    return 'Terdapat ${errors.length} masalah:\n${errors.map((e) => '• $e').join('\n')}';
  }

  String get warningMessage {
    if (warnings.isEmpty) return '';
    return warnings.map((w) => '⚠️ $w').join('\n');
  }
}

/// Exception for claim validation errors
class ClaimValidationException implements Exception {
  final ClaimValidationResult validation;

  ClaimValidationException(this.validation);

  @override
  String toString() => validation.errorMessage;
}

