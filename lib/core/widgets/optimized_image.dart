import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:f2c/core/utils/image_utils.dart';

/// Optimized image widget with automatic resizing and caching
class OptimizedImage extends StatelessWidget {
  final String imageUrl;
  final ImageSize size;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const OptimizedImage({
    super.key,
    required this.imageUrl,
    this.size = ImageSize.small,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    // Get optimized URL and cache dimensions
    final optimizedUrl = ImageUtils.getOptimizedImageUrl(imageUrl, size);
    final cacheDimensions = ImageUtils.getCacheDimensions(size);

    Widget imageWidget = CachedNetworkImage(
      imageUrl: optimizedUrl,
      fit: fit,
      width: width,
      height: height,
      // Memory cache optimization - resize in memory
      memCacheWidth: cacheDimensions.width,
      memCacheHeight: cacheDimensions.height,
      // Smooth fade-in animation
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 100),
      placeholderFadeInDuration: const Duration(milliseconds: 100),
      // Custom placeholder
      placeholder: (context, url) {
        return placeholder ??
            Container(
              width: width,
              height: height,
              color: Colors.grey[100],
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.grey[400]!,
                    ),
                  ),
                ),
              ),
            );
      },
      // Custom error widget
      errorWidget: (context, url, error) {
        return errorWidget ??
            Container(
              width: width,
              height: height,
              color: Colors.grey[100],
              child: Icon(
                Icons.image_not_supported,
                color: Colors.grey[400],
                size: (width != null && width! < 100) ? 24 : 48,
              ),
            );
      },
    );

    // Apply border radius if provided
    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}

/// Optimized product image specifically for product listings
class OptimizedProductImage extends StatelessWidget {
  final String imageUrl;
  final double size;
  final bool isMobile;

  const OptimizedProductImage({
    super.key,
    required this.imageUrl,
    required this.size,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    // Choose appropriate image size based on display size
    final imageSize = size <= 80 
        ? ImageSize.thumbnail 
        : (size <= 200 ? ImageSize.small : ImageSize.medium);

    return OptimizedImage(
      imageUrl: imageUrl,
      size: imageSize,
      width: size,
      height: size,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(8),
    );
  }
}
