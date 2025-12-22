import 'dart:typed_data';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../core/services/document_cropper_service.dart';
import '../../../../core/theme/app_colors.dart';

/// Document Cropper Widget
/// 
/// Shows image dengan 4 draggable corners untuk manual adjustment
/// User boleh drag corners untuk adjust crop area
class DocumentCropperWidget extends StatefulWidget {
  final Uint8List imageBytes;
  final String? imageDataUrl; // Optional: untuk display
  final Function(Uint8List croppedBytes) onCropped;

  const DocumentCropperWidget({
    super.key,
    required this.imageBytes,
    this.imageDataUrl,
    required this.onCropped,
  });

  @override
  State<DocumentCropperWidget> createState() => _DocumentCropperWidgetState();
}

class _DocumentCropperWidgetState extends State<DocumentCropperWidget> {
  List<Offset> _corners = [];
  bool _isDetecting = false;
  bool _isCropping = false;
  String? _errorMessage;
  double _imageWidth = 0;
  double _imageHeight = 0;
  int? _selectedCornerIndex;

  @override
  void initState() {
    super.initState();
    _loadImageDimensions().then((_) => _detectEdges());
  }

  /// Get image dimensions dari bytes (web only)
  Future<void> _loadImageDimensions() async {
    if (!kIsWeb) return;
    
    try {
      final blob = html.Blob([widget.imageBytes], 'image/jpeg');
      final imageUrl = html.Url.createObjectUrlFromBlob(blob);
      
      final image = html.ImageElement();
      image.src = imageUrl;
      await image.onLoad.first;
      
      setState(() {
        _imageWidth = image.width!.toDouble();
        _imageHeight = image.height!.toDouble();
      });
      
      html.Url.revokeObjectUrl(imageUrl);
    } catch (e) {
      debugPrint('Failed to load image dimensions: $e');
    }
  }

  /// Auto-detect edges when widget loads
  Future<void> _detectEdges() async {
    if (!kIsWeb) {
      setState(() {
        _errorMessage = 'Document cropper hanya support web platform';
      });
      return;
    }

    setState(() {
      _isDetecting = true;
      _errorMessage = null;
    });

    try {
      // Detect edges
      final corners = await DocumentCropperService.detectEdges(widget.imageBytes);
      
      setState(() {
        _corners = corners;
        _isDetecting = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal detect edges: $e';
        _isDetecting = false;
        // Fallback: use default corners dengan margin
        if (_imageWidth > 0 && _imageHeight > 0) {
          final marginX = _imageWidth * 0.1;
          final marginY = _imageHeight * 0.1;
          _corners = [
            Offset(marginX, marginY),
            Offset(_imageWidth - marginX, marginY),
            Offset(_imageWidth - marginX, _imageHeight - marginY),
            Offset(marginX, _imageHeight - marginY),
          ];
        } else {
          _corners = [
            const Offset(50, 50),
            const Offset(300, 50),
            const Offset(300, 400),
            const Offset(50, 400),
          ];
        }
      });
    }
  }

  /// Handle corner drag
  void _onCornerDrag(int index, Offset newPosition) {
    setState(() {
      _corners[index] = newPosition;
    });
  }

  /// Crop document dengan current corners
  Future<void> _cropDocument() async {
    if (_corners.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sila pastikan semua 4 corners ditetapkan'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isCropping = true;
      _errorMessage = null;
    });

    try {
      // Crop document
      final croppedBytes = await DocumentCropperService.cropDocument(
        imageBytes: widget.imageBytes,
        corners: _corners,
      );

      // Enhance untuk OCR
      final enhancedBytes = await DocumentCropperService.enhanceForOCR(croppedBytes);

      // Callback dengan cropped image
      widget.onCropped(enhancedBytes);
    } catch (e) {
      debugPrint('❌ Error cropping document: $e');
      setState(() {
        _errorMessage = 'Gagal crop document: ${e.toString()}';
        _isCropping = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCropping = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adjust Document Corners'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Image dengan corners
          Expanded(
            child: _isDetecting
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Mengesan tepi dokumen...'),
                      ],
                    ),
                  )
                : _errorMessage != null && _corners.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error, size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _detectEdges,
                              child: const Text('Cuba Lagi'),
                            ),
                          ],
                        ),
                      )
                    : _buildImageWithCorners(),
          ),

          // Instructions & Actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              children: [
                if (_errorMessage != null && _corners.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(fontSize: 12, color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Text(
                  'Seret corners untuk adjust kawasan dokumen',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isDetecting || _isCropping
                            ? null
                            : () {
                                setState(() {
                                  _selectedCornerIndex = null;
                                });
                                _detectEdges();
                              },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Auto-Detect'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isCropping ? null : _cropDocument,
                        icon: _isCropping
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check),
                        label: Text(_isCropping ? 'Memproses...' : 'Teruskan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWithCorners() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate image display size (maintain aspect ratio)
        final imageAspectRatio = _imageWidth > 0 && _imageHeight > 0
            ? _imageWidth / _imageHeight
            : 1.0;
        
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        
        double displayWidth = maxWidth;
        double displayHeight = maxHeight;
        
        if (imageAspectRatio > 1) {
          // Landscape
          displayHeight = maxWidth / imageAspectRatio;
          if (displayHeight > maxHeight) {
            displayHeight = maxHeight;
            displayWidth = maxHeight * imageAspectRatio;
          }
        } else {
          // Portrait
          displayWidth = maxHeight * imageAspectRatio;
          if (displayWidth > maxWidth) {
            displayWidth = maxWidth;
            displayHeight = maxWidth / imageAspectRatio;
          }
        }
        
        // Scale factor untuk convert display coordinates ke image coordinates
        final scaleX = _imageWidth > 0 ? displayWidth / _imageWidth : 1.0;
        final scaleY = _imageHeight > 0 ? displayHeight / _imageHeight : 1.0;
        
        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 3.0,
          child: Center(
            child: SizedBox(
              width: displayWidth,
              height: displayHeight,
              child: Stack(
                children: [
                // Image dengan proper dimension detection
                Builder(
                  builder: (context) {
                    return Image.memory(
                      widget.imageBytes,
                      fit: BoxFit.contain,
                      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                        if (frame == null) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        return child;
                      },
                    );
                  },
                ),

                // Crop overlay (darken outside area) - scaled untuk display
                if (_corners.length == 4)
                  CustomPaint(
                    painter: _CropOverlayPainter(
                      _corners.map((c) => Offset(c.dx * scaleX, c.dy * scaleY)).toList(),
                    ),
                    size: Size(displayWidth, displayHeight),
                  ),

                // Draggable corners (scaled untuk display)
                if (_corners.length == 4)
                  ..._corners.asMap().entries.map((entry) {
                    final index = entry.key;
                    final corner = entry.value;
                    final displayX = corner.dx * scaleX;
                    final displayY = corner.dy * scaleY;
                    
                    return Positioned(
                      left: displayX - 20,
                      top: displayY - 20,
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          // Convert display delta ke image coordinates
                          final deltaX = details.delta.dx / scaleX;
                          final deltaY = details.delta.dy / scaleY;
                          final newPosition = Offset(
                            (corner.dx + deltaX).clamp(0.0, _imageWidth > 0 ? _imageWidth : 1000),
                            (corner.dy + deltaY).clamp(0.0, _imageHeight > 0 ? _imageHeight : 1000),
                          );
                          _onCornerDrag(index, newPosition);
                        },
                        onPanStart: (_) {
                          setState(() {
                            _selectedCornerIndex = index;
                          });
                        },
                        onPanEnd: (_) {
                          setState(() {
                            _selectedCornerIndex = null;
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _selectedCornerIndex == index
                                ? AppColors.primary
                                : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: _selectedCornerIndex == index
                                    ? Colors.white
                                    : AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),

                // Corner labels (scaled untuk display)
                if (_corners.length == 4)
                  ..._corners.asMap().entries.map((entry) {
                    final index = entry.key;
                    final corner = entry.value;
                    final labels = ['Kiri Atas', 'Kanan Atas', 'Kanan Bawah', 'Kiri Bawah'];
                    final displayX = corner.dx * scaleX;
                    final displayY = corner.dy * scaleY;
                    return Positioned(
                      left: displayX + 25,
                      top: displayY - 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          labels[index],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter untuk crop overlay (darken outside crop area)
class _CropOverlayPainter extends CustomPainter {
  final List<Offset> corners;

  _CropOverlayPainter(this.corners);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    // Create path dengan hole untuk crop area
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Add crop area sebagai hole
    final cropPath = Path();
    if (corners.length == 4) {
      cropPath.moveTo(corners[0].dx, corners[0].dy);
      for (int i = 1; i < corners.length; i++) {
        cropPath.lineTo(corners[i].dx, corners[i].dy);
      }
      cropPath.close();
    }

    path.addPath(cropPath, Offset.zero);
    path.fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Draw border around crop area
    final borderPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(cropPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

