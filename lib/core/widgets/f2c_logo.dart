import 'package:flutter/material.dart';

/// Reusable F2C logo widget that tries to load the logo image
/// and falls back to the agriculture icon if not found
class F2CLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final BoxFit fit;

  const F2CLogo({
    super.key,
    this.size = 100,
    this.color,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final logoColor = color ?? Theme.of(context).colorScheme.primary;
    
    // Try different image formats
    const logoOptions = [
      'assets/logos/f2c_logo.jpg',
      'assets/logos/f2c_logo.jpeg',
      'assets/logos/f2c_logo.png',
    ];
    
    return Image.asset(
      logoOptions[0], // Try jpg first
      width: size,
      height: size,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        // Try jpeg
        return Image.asset(
          logoOptions[1],
          width: size,
          height: size,
          fit: fit,
          errorBuilder: (context, error2, stackTrace2) {
            // Try png
            return Image.asset(
              logoOptions[2],
              width: size,
              height: size,
              fit: fit,
              errorBuilder: (context, error3, stackTrace3) {
                // Final fallback to icon
                return Icon(
                  Icons.agriculture,
                  size: size,
                  color: logoColor,
                );
              },
            );
          },
        );
      },
    );
  }
}
