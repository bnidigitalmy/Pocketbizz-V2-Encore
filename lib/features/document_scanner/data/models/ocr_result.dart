/// Raw OCR result dari Google ML Kit
class OcrResult {
  /// All text blocks dari OCR
  final List<String> textBlocks;

  /// Full text (concatenated)
  final String fullText;

  OcrResult({
    required this.textBlocks,
    required this.fullText,
  });

  /// Get text lines (split by newline)
  List<String> get textLines {
    return fullText.split('\n').where((line) => line.trim().isNotEmpty).toList();
  }
}
