import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../supabase/supabase_client.dart';

/// Service for handling image uploads to Supabase Storage
class ImageUploadService {
  static const String _bucketName = 'product-images';
  final ImagePicker _picker = ImagePicker();

  /// Pick image from gallery
  Future<XFile?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      return image;
    } catch (e) {
      throw Exception('Failed to pick image: $e');
    }
  }

  /// Pick image from camera
  Future<XFile?> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      return image;
    } catch (e) {
      throw Exception('Failed to take photo: $e');
    }
  }

  /// Upload image to Supabase Storage
  /// Returns the public URL of the uploaded image
  Future<String> uploadProductImage(XFile imageFile, String productId) async {
    try {
      // Read image bytes
      final Uint8List imageBytes = await imageFile.readAsBytes();
      
      // Generate unique file name
      final String fileName = '$productId-${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = 'products/$fileName';

      // Upload to Supabase Storage
      await supabase.storage
          .from(_bucketName)
          .uploadBinary(
            filePath,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      // Get public URL
      final String publicUrl = supabase.storage
          .from(_bucketName)
          .getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Delete image from Supabase Storage
  Future<void> deleteProductImage(String imageUrl) async {
    try {
      // Extract file path from URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      
      // Find the index of the bucket name
      final bucketIndex = pathSegments.indexOf(_bucketName);
      if (bucketIndex == -1 || bucketIndex == pathSegments.length - 1) {
        throw Exception('Invalid image URL format');
      }
      
      // Get the file path after the bucket name
      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');

      // Delete from storage
      await supabase.storage
          .from(_bucketName)
          .remove([filePath]);
    } catch (e) {
      // Log error but don't throw - image might already be deleted
      print('Warning: Failed to delete image: $e');
    }
  }

  /// Update product image (delete old, upload new)
  Future<String> updateProductImage(
    XFile newImageFile,
    String productId,
    String? oldImageUrl,
  ) async {
    // Delete old image if exists
    if (oldImageUrl != null && oldImageUrl.isNotEmpty) {
      try {
        await deleteProductImage(oldImageUrl);
      } catch (e) {
        print('Warning: Could not delete old image: $e');
      }
    }

    // Upload new image
    return await uploadProductImage(newImageFile, productId);
  }
}

