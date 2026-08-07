import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:f2c/core/utils/logger.dart';

/// Service for handling Firebase Storage operations
/// Provides methods for uploading, deleting, and managing files in Firebase Storage
class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload a file to Firebase Storage
  /// 
  /// [bytes] - File data as Uint8List
  /// [fileName] - Name of the file
  /// [folder] - Storage folder path (e.g., 'product_images')
  /// [metadata] - Optional metadata for the file
  /// 
  /// Returns the download URL of the uploaded file
  Future<String> uploadFile({
    required Uint8List bytes,
    required String fileName,
    required String folder,
    SettableMetadata? metadata,
  }) async {
    try {
      final String filePath = '$folder/$fileName';
      final Reference ref = _storage.ref().child(filePath);

      // Set default metadata if not provided
      final SettableMetadata uploadMetadata = metadata ??
          SettableMetadata(
            contentType: _getContentType(fileName),
            cacheControl: 'public, max-age=31536000', // Cache for 1 year
          );

      // Upload file
      final UploadTask uploadTask = ref.putData(bytes, uploadMetadata);

      // Wait for upload to complete
      final TaskSnapshot snapshot = await uploadTask;

      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      AppLogger.info('File uploaded successfully: $filePath');
      return downloadUrl;
    } catch (e, stackTrace) {
      AppLogger.error('Error uploading file to Firebase Storage', e, stackTrace);
      rethrow;
    }
  }

  /// Upload multiple files in parallel
  /// 
  /// Returns a map of fileName -> downloadUrl
  Future<Map<String, String>> uploadMultipleFiles({
    required Map<String, Uint8List> files,
    required String folder,
  }) async {
    try {
      final Map<String, String> results = {};

      // Upload all files in parallel
      final List<Future<MapEntry<String, String>>> uploadFutures = files.entries.map((entry) async {
        final url = await uploadFile(
          bytes: entry.value,
          fileName: entry.key,
          folder: folder,
        );
        return MapEntry(entry.key, url);
      }).toList();

      final uploadResults = await Future.wait(uploadFutures);

      for (final result in uploadResults) {
        results[result.key] = result.value;
      }

      AppLogger.info('Uploaded ${results.length} files successfully');
      return results;
    } catch (e, stackTrace) {
      AppLogger.error('Error uploading multiple files', e, stackTrace);
      rethrow;
    }
  }

  /// Delete a file from Firebase Storage
  /// 
  /// [fileUrl] - The download URL or full path of the file
  Future<void> deleteFile(String fileUrl) async {
    try {
      // Extract path from URL if it's a download URL
      final String filePath = _extractPathFromUrl(fileUrl);
      final Reference ref = _storage.ref().child(filePath);

      await ref.delete();
      AppLogger.info('File deleted successfully: $filePath');
    } catch (e, stackTrace) {
      AppLogger.error('Error deleting file from Firebase Storage', e, stackTrace);
      rethrow;
    }
  }

  /// Delete multiple files in parallel
  Future<void> deleteMultipleFiles(List<String> fileUrls) async {
    try {
      final List<Future<void>> deleteFutures = fileUrls.map((url) => deleteFile(url)).toList();
      await Future.wait(deleteFutures);
      AppLogger.info('Deleted ${fileUrls.length} files successfully');
    } catch (e, stackTrace) {
      AppLogger.error('Error deleting multiple files', e, stackTrace);
      rethrow;
    }
  }

  /// Get file metadata
  Future<FullMetadata> getFileMetadata(String fileUrl) async {
    try {
      final String filePath = _extractPathFromUrl(fileUrl);
      final Reference ref = _storage.ref().child(filePath);
      return await ref.getMetadata();
    } catch (e, stackTrace) {
      AppLogger.error('Error getting file metadata', e, stackTrace);
      rethrow;
    }
  }

  /// Check if a file exists
  Future<bool> fileExists(String fileUrl) async {
    try {
      await getFileMetadata(fileUrl);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Extract file path from Firebase Storage download URL
  String _extractPathFromUrl(String url) {
    try {
      // If it's already a path, return it
      if (!url.startsWith('http')) {
        return url;
      }

      // Extract path from Firebase Storage URL
      // Format: https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{path}?alt=media&token={token}
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      if (pathSegments.length >= 4 && pathSegments[0] == 'v0' && pathSegments[1] == 'b') {
        // Find the 'o' segment and get everything after it
        final oIndex = pathSegments.indexOf('o');
        if (oIndex != -1 && oIndex < pathSegments.length - 1) {
          final encodedPath = pathSegments.sublist(oIndex + 1).join('/');
          return Uri.decodeComponent(encodedPath);
        }
      }

      throw Exception('Invalid Firebase Storage URL format');
    } catch (e) {
      AppLogger.error('Error extracting path from URL: $url', e, null);
      rethrow;
    }
  }

  /// Get content type based on file extension
  String _getContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'svg':
        return 'image/svg+xml';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  /// Generate a unique file name with timestamp
  String generateUniqueFileName(String originalFileName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = originalFileName.split('.').last;
    final nameWithoutExtension = originalFileName.split('.').first;
    return '${nameWithoutExtension}_$timestamp.$extension';
  }
}
