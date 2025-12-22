import 'dart:typed_data';
import 'dart:convert';
import 'dart:math' as math;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Document Cropper Service untuk Web
/// 
/// Handles:
/// - Edge detection (basic untuk web)
/// - Manual corner adjustment
/// - Perspective correction
/// - Document cropping
class DocumentCropperService {
  /// Crop document dari image dengan 4 corner points
  /// 
  /// [imageBytes] - Original image bytes
  /// [corners] - 4 corner points dalam order: topLeft, topRight, bottomRight, bottomLeft
  /// Returns cropped image bytes
  static Future<Uint8List> cropDocument({
    required Uint8List imageBytes,
    required List<Offset> corners,
  }) async {
    if (!kIsWeb) {
      throw Exception('DocumentCropperService hanya support web platform');
    }

    if (corners.length != 4) {
      throw Exception('Perlu 4 corner points untuk crop document');
    }

    try {
      // Create image element dari bytes
      final blob = html.Blob([imageBytes], 'image/jpeg');
      final imageUrl = html.Url.createObjectUrlFromBlob(blob);
      
      final image = html.ImageElement();
      // Set src FIRST, then wait for load event
      image.src = imageUrl;
      // Wait for image to load with timeout
      await image.onLoad.first.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Image loading timeout - image terlalu besar atau corrupt');
        },
      );

      // Create canvas untuk crop
      final canvas = html.CanvasElement(
        width: image.width!,
        height: image.height!,
      );
      final ctx = canvas.context2D;

      // Draw original image
      ctx.drawImage(image, 0, 0);

      // Calculate destination rectangle (bounding box dari corners)
      final minX = corners.map((p) => p.dx).reduce(math.min);
      final minY = corners.map((p) => p.dy).reduce(math.min);
      final maxX = corners.map((p) => p.dx).reduce(math.max);
      final maxY = corners.map((p) => p.dy).reduce(math.max);

      final width = maxX - minX;
      final height = maxY - minY;

      // Create destination canvas untuk cropped image
      final destCanvas = html.CanvasElement(
        width: width.toInt(),
        height: height.toInt(),
      );
      final destCtx = destCanvas.context2D;

      // Apply perspective transform menggunakan homography
      // Calculate homography matrix dari source corners ke destination rectangle
      final sourceCorners = corners;
      final destCorners = [
        Offset(0, 0), // topLeft
        Offset(width, 0), // topRight
        Offset(width, height), // bottomRight
        Offset(0, height), // bottomLeft
      ];

      // Calculate homography matrix
      // Returns: [h[0], h[1], h[3], h[4], h[6], h[7]] = [a, b, c, d, e, f]
      final homography = _calculateHomography(sourceCorners, destCorners);

      // Apply perspective transform
      destCtx.save();
      
      // Use transform matrix untuk perspective correction
      // Canvas setTransform expects: (a, b, c, d, e, f)
      // homography array: [a, b, c, d, e, f] = indices [0, 1, 2, 3, 4, 5]
      destCtx.setTransform(
        homography[0], homography[1], // a, b
        homography[2], homography[3], // c, d
        homography[4], homography[5], // e, f
      );

      // Draw image dengan perspective transform
      destCtx.drawImage(image, 0, 0);

      destCtx.restore();

      // Convert to bytes
      final dataUrl = destCanvas.toDataUrl('image/jpeg', 0.95);
      final base64Data = dataUrl.split(',').last;
      final croppedBytes = base64Decode(base64Data);

      // Cleanup
      html.Url.revokeObjectUrl(imageUrl);

      return croppedBytes;
    } catch (e) {
      throw Exception('Failed to crop document: $e');
    }
  }

  /// Auto-detect document edges (enhanced implementation)
  /// 
  /// Uses:
  /// - Grayscale conversion
  /// - Sobel edge detection untuk find edges
  /// - Contour detection untuk find document boundaries
  /// - Corner detection dari contours
  /// 
  /// Returns 4 corner points dalam order: topLeft, topRight, bottomRight, bottomLeft
  static Future<List<Offset>> detectEdges(Uint8List imageBytes) async {
    if (!kIsWeb) {
      throw Exception('DocumentCropperService hanya support web platform');
    }

    try {
      // Create image element
      final blob = html.Blob([imageBytes], 'image/jpeg');
      final imageUrl = html.Url.createObjectUrlFromBlob(blob);
      
      final image = html.ImageElement();
      // Set src FIRST, then wait for load event
      image.src = imageUrl;
      // Wait for image to load with timeout
      await image.onLoad.first.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Image loading timeout - image terlalu besar atau corrupt');
        },
      );

      final width = image.width!.toDouble();
      final height = image.height!.toDouble();

      // Create canvas untuk edge detection
      final canvas = html.CanvasElement(
        width: image.width!,
        height: image.height!,
      );
      final ctx = canvas.context2D;
      ctx.drawImage(image, 0, 0);

      // Get image data
      final imageData = ctx.getImageData(0, 0, image.width!, image.height!);
      final data = imageData.data;

      // Step 1: Convert to grayscale
      final grayData = List<int>.filled(data.length ~/ 4, 0);
      for (int i = 0; i < data.length; i += 4) {
        final gray = (data[i] * 0.299 + data[i + 1] * 0.587 + data[i + 2] * 0.114).round();
        grayData[i ~/ 4] = gray;
      }

      // Step 2: Apply Gaussian blur untuk reduce noise
      final blurred = _gaussianBlur(grayData, image.width!, image.height!, radius: 2);

      // Step 3: Sobel edge detection
      final edges = _sobelEdgeDetection(blurred, image.width!, image.height!);

      // Step 4: Threshold untuk binary image
      final threshold = _calculateThreshold(edges);
      final binary = edges.map((e) => e > threshold ? 255 : 0).toList();

      // Step 5: Find largest contour (document boundary)
      final contours = _findContours(binary, image.width!, image.height!);
      if (contours.isEmpty) {
        // Fallback: use default corners dengan margin
        final marginX = width * 0.1;
        final marginY = height * 0.1;
        html.Url.revokeObjectUrl(imageUrl);
        return [
          Offset(marginX, marginY),
          Offset(width - marginX, marginY),
          Offset(width - marginX, height - marginY),
          Offset(marginX, height - marginY),
        ];
      }

      // Find largest contour (should be document)
      final largestContour = contours.reduce((a, b) => a.length > b.length ? a : b);

      // Step 6: Find corners dari contour (convex hull + corner detection)
      final corners = _findCornersFromContour(largestContour, width, height);

      html.Url.revokeObjectUrl(imageUrl);
      return corners;
    } catch (e) {
      throw Exception('Failed to detect edges: $e');
    }
  }

  /// Gaussian blur untuk reduce noise
  static List<int> _gaussianBlur(List<int> data, int width, int height, {int radius = 2}) {
    final result = List<int>.filled(data.length, 0);
    final kernel = _createGaussianKernel(radius);
    final kernelSize = radius * 2 + 1;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        double sum = 0;
        double weightSum = 0;

        for (int ky = -radius; ky <= radius; ky++) {
          for (int kx = -radius; kx <= radius; kx++) {
            final px = (x + kx).clamp(0, width - 1);
            final py = (y + ky).clamp(0, height - 1);
            final idx = py * width + px;
            final weight = kernel[ky + radius][kx + radius];
            sum += data[idx] * weight;
            weightSum += weight;
          }
        }

        result[y * width + x] = (sum / weightSum).round();
      }
    }

    return result;
  }

  /// Create Gaussian kernel
  static List<List<double>> _createGaussianKernel(int radius) {
    final size = radius * 2 + 1;
    final kernel = List.generate(size, (_) => List<double>.filled(size, 0));
    final sigma = radius / 3.0;
    final twoSigmaSquare = 2 * sigma * sigma;
    double sum = 0;

    for (int y = -radius; y <= radius; y++) {
      for (int x = -radius; x <= radius; x++) {
        final distance = x * x + y * y;
        final value = math.exp(-distance / twoSigmaSquare);
        kernel[y + radius][x + radius] = value;
        sum += value;
      }
    }

    // Normalize
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        kernel[y][x] /= sum;
      }
    }

    return kernel;
  }

  /// Sobel edge detection
  static List<int> _sobelEdgeDetection(List<int> data, int width, int height) {
    final result = List<int>.filled(data.length, 0);
    final sobelX = [
      [-1, 0, 1],
      [-2, 0, 2],
      [-1, 0, 1],
    ];
    final sobelY = [
      [-1, -2, -1],
      [0, 0, 0],
      [1, 2, 1],
    ];

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        int gx = 0, gy = 0;

        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final idx = (y + ky) * width + (x + kx);
            final value = data[idx];
            gx += value * sobelX[ky + 1][kx + 1];
            gy += value * sobelY[ky + 1][kx + 1];
          }
        }

        final magnitude = math.sqrt(gx * gx + gy * gy).round();
        result[y * width + x] = magnitude.clamp(0, 255);
      }
    }

    return result;
  }

  /// Calculate threshold menggunakan Otsu's method
  static int _calculateThreshold(List<int> data) {
    // Histogram
    final histogram = List<int>.filled(256, 0);
    for (final value in data) {
      histogram[value.clamp(0, 255)]++;
    }

    // Otsu's threshold
    int total = data.length;
    double sum = 0;
    for (int i = 0; i < 256; i++) {
      sum += i * histogram[i];
    }

    double sumB = 0;
    int wB = 0;
    int wF = 0;
    double maxVariance = 0;
    int threshold = 0;

    for (int i = 0; i < 256; i++) {
      wB += histogram[i];
      if (wB == 0) continue;
      wF = total - wB;
      if (wF == 0) break;

      sumB += i * histogram[i];
      final mB = sumB / wB;
      final mF = (sum - sumB) / wF;
      final variance = wB * wF * (mB - mF) * (mB - mF);

      if (variance > maxVariance) {
        maxVariance = variance;
        threshold = i;
      }
    }

    return threshold;
  }

  /// Find contours menggunakan border following algorithm
  static List<List<Offset>> _findContours(List<int> binary, int width, int height) {
    final contours = <List<Offset>>[];
    final visited = List.generate(height, (_) => List<bool>.filled(width, false));

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        if (binary[y * width + x] == 255 && !visited[y][x]) {
          final contour = _traceContour(binary, visited, x, y, width, height);
          if (contour.length > 100) { // Filter small contours
            contours.add(contour);
          }
        }
      }
    }

    return contours;
  }

  /// Trace contour menggunakan border following
  static List<Offset> _traceContour(
    List<int> binary,
    List<List<bool>> visited,
    int startX,
    int startY,
    int width,
    int height,
  ) {
    final contour = <Offset>[];
    final stack = <Offset>[Offset(startX.toDouble(), startY.toDouble())];

    while (stack.isNotEmpty) {
      final point = stack.removeLast();
      final x = point.dx.toInt();
      final y = point.dy.toInt();

      if (x < 0 || x >= width || y < 0 || y >= height || visited[y][x]) continue;
      if (binary[y * width + x] != 255) continue;

      visited[y][x] = true;
      contour.add(point);

      // Add neighbors
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          stack.add(Offset((x + dx).toDouble(), (y + dy).toDouble()));
        }
      }
    }

    return contour;
  }

  /// Find corners dari contour menggunakan Douglas-Peucker algorithm + corner detection
  static List<Offset> _findCornersFromContour(
    List<Offset> contour,
    double width,
    double height,
  ) {
    if (contour.length < 4) {
      // Fallback
      final marginX = width * 0.1;
      final marginY = height * 0.1;
      return [
        Offset(marginX, marginY),
        Offset(width - marginX, marginY),
        Offset(width - marginX, height - marginY),
        Offset(marginX, height - marginY),
      ];
    }

    // Simplify contour dengan Douglas-Peucker
    final simplified = _douglasPeucker(contour, 5.0);

    // Find 4 corners (furthest points from center)
    final center = Offset(width / 2, height / 2);
    final corners = <Offset>[];

    // Find top-left (min x + y)
    corners.add(simplified.reduce((a, b) => (a.dx + a.dy) < (b.dx + b.dy) ? a : b));

    // Find top-right (max x - y)
    corners.add(simplified.reduce((a, b) => (a.dx - a.dy) > (b.dx - b.dy) ? a : b));

    // Find bottom-right (max x + y)
    corners.add(simplified.reduce((a, b) => (a.dx + a.dy) > (b.dx + b.dy) ? a : b));

    // Find bottom-left (min x - y)
    corners.add(simplified.reduce((a, b) => (a.dx - a.dy) < (b.dx - b.dy) ? a : b));

    // Ensure order: topLeft, topRight, bottomRight, bottomLeft
    corners.sort((a, b) {
      if ((a.dy - b.dy).abs() < 10) {
        // Same row, sort by x
        return a.dx.compareTo(b.dx);
      }
      return a.dy.compareTo(b.dy);
    });

    // Reorder to: topLeft, topRight, bottomRight, bottomLeft
    if (corners.length >= 4) {
      final top = corners.where((p) => p.dy < height / 2).toList()..sort((a, b) => a.dx.compareTo(b.dx));
      final bottom = corners.where((p) => p.dy >= height / 2).toList()..sort((a, b) => a.dx.compareTo(b.dx));

      if (top.length >= 2 && bottom.length >= 2) {
        return [
          top[0], // topLeft
          top[top.length - 1], // topRight
          bottom[bottom.length - 1], // bottomRight
          bottom[0], // bottomLeft
        ];
      }
    }

    return corners.take(4).toList();
  }

  /// Douglas-Peucker algorithm untuk simplify contour
  static List<Offset> _douglasPeucker(List<Offset> points, double epsilon) {
    if (points.length <= 2) return points;

    double maxDistance = 0;
    int maxIndex = 0;
    final start = points.first;
    final end = points.last;

    for (int i = 1; i < points.length - 1; i++) {
      final distance = _pointToLineDistance(points[i], start, end);
      if (distance > maxDistance) {
        maxDistance = distance;
        maxIndex = i;
      }
    }

    if (maxDistance > epsilon) {
      final left = _douglasPeucker(points.sublist(0, maxIndex + 1), epsilon);
      final right = _douglasPeucker(points.sublist(maxIndex), epsilon);
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      return [start, end];
    }
  }

  /// Calculate distance from point to line
  static double _pointToLineDistance(Offset point, Offset lineStart, Offset lineEnd) {
    final A = point.dx - lineStart.dx;
    final B = point.dy - lineStart.dy;
    final C = lineEnd.dx - lineStart.dx;
    final D = lineEnd.dy - lineStart.dy;

    final dot = A * C + B * D;
    final lenSq = C * C + D * D;
    if (lenSq == 0) return math.sqrt(A * A + B * B);

    final param = dot / lenSq;
    final xx = lineStart.dx + param * C;
    final yy = lineStart.dy + param * D;

    final dx = point.dx - xx;
    final dy = point.dy - yy;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Enhance cropped image untuk better OCR
  /// 
  /// Applies:
  /// - Grayscale conversion
  /// - Contrast adjustment
  /// - Brightness optimization
  static Future<Uint8List> enhanceForOCR(Uint8List imageBytes) async {
    if (!kIsWeb) {
      throw Exception('DocumentCropperService hanya support web platform');
    }

    try {
      // Create image element
      final blob = html.Blob([imageBytes], 'image/jpeg');
      final imageUrl = html.Url.createObjectUrlFromBlob(blob);
      
      final image = html.ImageElement();
      image.src = imageUrl;
      // Wait for image to load with timeout
      await image.onLoad.first.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Image loading timeout - image terlalu besar atau corrupt');
        },
      );

      // Create canvas
      final canvas = html.CanvasElement(
        width: image.width!,
        height: image.height!,
      );
      final ctx = canvas.context2D;

      // Draw image
      ctx.drawImage(image, 0, 0);

      // Get image data untuk processing
      final imageData = ctx.getImageData(0, 0, image.width!, image.height!);
      final data = imageData.data;

      // Apply enhancements
      for (int i = 0; i < data.length; i += 4) {
        // Grayscale: average of RGB
        final gray = (data[i] * 0.299 + data[i + 1] * 0.587 + data[i + 2] * 0.114).round();
        
        // Contrast adjustment (increase contrast)
        final contrast = 1.5;
        final adjusted = ((gray - 128) * contrast + 128).clamp(0, 255).round();
        
        // Brightness optimization
        final brightness = 1.1;
        final brightened = (adjusted * brightness).clamp(0, 255).round();

        // Set RGB to grayscale value
        data[i] = brightened; // R
        data[i + 1] = brightened; // G
        data[i + 2] = brightened; // B
        // Alpha stays the same
      }

      // Put enhanced data back
      ctx.putImageData(imageData, 0, 0);

      // Convert to bytes
      final dataUrl = canvas.toDataUrl('image/jpeg', 0.95);
      final base64Data = dataUrl.split(',').last;
      final enhancedBytes = base64Decode(base64Data);

      // Cleanup
      html.Url.revokeObjectUrl(imageUrl);

      return enhancedBytes;
    } catch (e) {
      throw Exception('Failed to enhance image: $e');
    }
  }

  /// Calculate homography matrix untuk perspective transform
  /// 
  /// Uses Direct Linear Transform (DLT) algorithm
  /// Returns 3x3 matrix as flat array [a, b, c, d, e, f, g, h, i]
  /// Note: Canvas 2D transform uses 2x3 matrix, so we'll extract 6 values
  static List<double> _calculateHomography(
    List<Offset> sourcePoints,
    List<Offset> destPoints,
  ) {
    if (sourcePoints.length != 4 || destPoints.length != 4) {
      throw Exception('Need exactly 4 points for homography');
    }

    // Build system of equations untuk DLT
    final A = List.generate(8, (_) => List<double>.filled(8, 0));
    final b = List<double>.filled(8, 0);

    for (int i = 0; i < 4; i++) {
      final src = sourcePoints[i];
      final dst = destPoints[i];

      // Two equations per point
      final row1 = i * 2;
      final row2 = i * 2 + 1;

      A[row1] = [src.dx, src.dy, 1, 0, 0, 0, -dst.dx * src.dx, -dst.dx * src.dy];
      b[row1] = dst.dx;

      A[row2] = [0, 0, 0, src.dx, src.dy, 1, -dst.dy * src.dx, -dst.dy * src.dy];
      b[row2] = dst.dy;
    }

    // Solve system menggunakan Gaussian elimination
    final h = _solveLinearSystem(A, b);

    // Return as 2x3 matrix untuk Canvas transform
    // Canvas transform: [a, b, c, d, e, f] where:
    // a = h[0], b = h[1], c = h[3], d = h[4], e = h[6], f = h[7]
    return [
      h[0], h[1], // a, b
      h[3], h[4], // c, d
      h[6], h[7], // e, f
    ];
  }

  /// Solve linear system menggunakan Gaussian elimination
  static List<double> _solveLinearSystem(List<List<double>> A, List<double> b) {
    final n = A.length;
    final augmented = List.generate(n, (i) => [...A[i], b[i]]);

    // Forward elimination
    for (int i = 0; i < n; i++) {
      // Find pivot
      int maxRow = i;
      for (int k = i + 1; k < n; k++) {
        if (augmented[k][i].abs() > augmented[maxRow][i].abs()) {
          maxRow = k;
        }
      }

      // Swap rows
      final temp = augmented[i];
      augmented[i] = augmented[maxRow];
      augmented[maxRow] = temp;

      // Eliminate
      for (int k = i + 1; k < n; k++) {
        final factor = augmented[k][i] / augmented[i][i];
        for (int j = i; j <= n; j++) {
          augmented[k][j] -= factor * augmented[i][j];
        }
      }
    }

    // Back substitution
    final x = List<double>.filled(n, 0);
    for (int i = n - 1; i >= 0; i--) {
      x[i] = augmented[i][n];
      for (int j = i + 1; j < n; j++) {
        x[i] -= augmented[i][j] * x[j];
      }
      x[i] /= augmented[i][i];
    }

    return x;
  }
}


