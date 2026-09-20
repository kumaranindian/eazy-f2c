/// Image optimization utilities for Firebase Storage images
class ImageUtils {
  /// Get optimized image URL with size suffix
  /// Firebase Storage automatically generates resized versions with _WIDTHxHEIGHT suffix
  static String getOptimizedImageUrl(String originalUrl, ImageSize size) {
    if (originalUrl.isEmpty) return originalUrl;
    
    // Extract the base URL and file extension
    final uri = Uri.parse(originalUrl);
    final path = uri.path;
    
    // Find the last dot for extension
    final lastDotIndex = path.lastIndexOf('.');
    if (lastDotIndex == -1) return originalUrl;
    
    final basePath = path.substring(0, lastDotIndex);
    final extension = path.substring(lastDotIndex);
    
    // Add size suffix before extension
    final sizeSuffix = _getSizeSuffix(size);
    final optimizedPath = '$basePath$sizeSuffix$extension';
    
    // Rebuild the URL with optimized path
    final optimizedUri = uri.replace(path: optimizedPath);
    return optimizedUri.toString();
  }
  
  /// Get size suffix for Firebase Storage resized images
  static String _getSizeSuffix(ImageSize size) {
    switch (size) {
      case ImageSize.thumbnail:
        return '_200x200';
      case ImageSize.small:
        return '_400x400';
      case ImageSize.medium:
        return '_800x800';
      case ImageSize.large:
        return '_1200x1200';
      case ImageSize.original:
        return '';
    }
  }
  
  /// Get memory cache dimensions based on image size
  static CacheDimensions getCacheDimensions(ImageSize size) {
    switch (size) {
      case ImageSize.thumbnail:
        return const CacheDimensions(width: 200, height: 200);
      case ImageSize.small:
        return const CacheDimensions(width: 400, height: 400);
      case ImageSize.medium:
        return const CacheDimensions(width: 800, height: 800);
      case ImageSize.large:
        return const CacheDimensions(width: 1200, height: 1200);
      case ImageSize.original:
        return const CacheDimensions(width: null, height: null);
    }
  }
}

/// Image size options for optimization
enum ImageSize {
  thumbnail,  // 200x200 - for small previews, lists
  small,      // 400x400 - for product cards, mobile
  medium,     // 800x800 - for product details, desktop
  large,      // 1200x1200 - for zoomed views
  original,   // Original size - use sparingly
}

/// Cache dimensions for memory optimization
class CacheDimensions {
  final int? width;
  final int? height;
  
  const CacheDimensions({this.width, this.height});
}
