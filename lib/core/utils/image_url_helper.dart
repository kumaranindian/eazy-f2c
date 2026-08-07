/// Helper class for handling image URLs from various sources
class ImageUrlHelper {
  /// Converts a Google Drive URL to a direct image URL
  /// 
  /// Supports the following Google Drive URL formats:
  /// - https://drive.google.com/file/d/FILE_ID/view
  /// - https://drive.google.com/open?id=FILE_ID
  /// - https://drive.google.com/uc?id=FILE_ID
  /// 
  /// Returns the direct image URL format:
  /// - https://drive.google.com/uc?export=view&id=FILE_ID
  static String convertGoogleDriveUrl(String url) {
    if (!url.contains('drive.google.com')) {
      return url;
    }

    // Extract file ID from various Google Drive URL formats
    String? fileId;

    // Format 1: https://drive.google.com/file/d/FILE_ID/view
    final fileIdMatch = RegExp(r'/file/d/([a-zA-Z0-9_-]+)').firstMatch(url);
    if (fileIdMatch != null) {
      fileId = fileIdMatch.group(1);
    }

    // Format 2: https://drive.google.com/open?id=FILE_ID
    if (fileId == null) {
      final openIdMatch = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)').firstMatch(url);
      if (openIdMatch != null) {
        fileId = openIdMatch.group(1);
      }
    }

    // If we found a file ID, convert to direct URL
    if (fileId != null) {
      return 'https://drive.google.com/uc?export=view&id=$fileId';
    }

    // If already in direct format or couldn't parse, return as is
    return url;
  }

  /// Gets a safe image URL that works with Image.network
  /// Handles Google Drive URLs and other image sources
  static String getSafeImageUrl(String? url) {
    if (url == null || url.isEmpty) {
      return '';
    }

    return convertGoogleDriveUrl(url);
  }
}
