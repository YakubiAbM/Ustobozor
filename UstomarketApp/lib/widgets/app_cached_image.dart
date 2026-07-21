import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../constants.dart';
import '../services/app_image_cache_manager.dart';

/// Кэширование сетевых изображений.
/// Важно: в память декодируем только по одной стороне (ширине), иначе
/// CachedNetworkImage принудительно сжимает картинку в прямоугольник и ломает пропорции.
class AppCachedImage extends StatelessWidget {
  const AppCachedImage({
    super.key,
    required this.imagePath,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.fallbackIcon = Icons.image_outlined,
    this.fallbackIconSize = 36,
    this.backgroundColor,
    this.memCacheWidth,
    this.memCacheHeight,
    this.maxMemCacheSide = 800,
    this.disableMemCacheResize = false,
  });

  final String imagePath;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxShape shape;
  final IconData fallbackIcon;
  final double fallbackIconSize;
  final Color? backgroundColor;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final int maxMemCacheSide;

  /// Полное качество (галерея / зум) — без даунскейла в RAM.
  final bool disableMemCacheResize;

  int? _resolveMemCacheWidth(BuildContext context) {
    if (disableMemCacheResize) return null;
    if (memCacheWidth != null) {
      return memCacheWidth!.clamp(1, maxMemCacheSide);
    }
    if (memCacheHeight != null) return null;

    final dpr = MediaQuery.devicePixelRatioOf(context);
    if (width != null && width!.isFinite) {
      return (width! * dpr).round().clamp(1, maxMemCacheSide);
    }

    final screenW = MediaQuery.sizeOf(context).width;
    return ((screenW / 2) * dpr).round().clamp(1, maxMemCacheSide);
  }

  int? _resolveMemCacheHeight(BuildContext context) {
    if (disableMemCacheResize) return null;
    if (memCacheWidth != null) return null;
    if (memCacheHeight != null) {
      return memCacheHeight!.clamp(1, maxMemCacheSide);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = getImageUrl(imagePath);
    if (imageUrl.isEmpty) {
      return _ImageClip(
        shape: shape,
        borderRadius: borderRadius,
        child: _ImageFallback(
          width: width,
          height: height,
          backgroundColor: backgroundColor,
          fallbackIcon: fallbackIcon,
          fallbackIconSize: fallbackIconSize,
        ),
      );
    }

    final cacheW = _resolveMemCacheWidth(context);
    final cacheH = _resolveMemCacheHeight(context);

    final image = CachedNetworkImage(
      imageUrl: imageUrl,
      cacheManager: AppImageCacheManager.instance,
      fit: fit,
      memCacheWidth: cacheW,
      memCacheHeight: cacheH,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (context, url) => _ImagePlaceholder(
        width: width,
        height: height,
        shape: shape,
        borderRadius: borderRadius,
        backgroundColor: backgroundColor,
      ),
      errorWidget: (context, url, error) => _ImageFallback(
        width: width,
        height: height,
        backgroundColor: backgroundColor,
        fallbackIcon: fallbackIcon,
        fallbackIconSize: fallbackIconSize,
      ),
    );

    return _ImageClip(
      shape: shape,
      borderRadius: borderRadius,
      child: _SizedImageShell(
        width: width,
        height: height,
        backgroundColor: backgroundColor,
        child: image,
      ),
    );
  }
}

class _SizedImageShell extends StatelessWidget {
  const _SizedImageShell({
    required this.child,
    this.width,
    this.height,
    this.backgroundColor,
  });

  final Widget child;
  final double? width;
  final double? height;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor;
    if (width != null &&
        height != null &&
        width!.isFinite &&
        height!.isFinite) {
      return ColoredBox(
        color: bg ?? Colors.transparent,
        child: SizedBox(width: width, height: height, child: child),
      );
    }
    if (width != null && width!.isFinite) {
      return ColoredBox(
        color: bg ?? Colors.transparent,
        child: SizedBox(width: width, height: height, child: child),
      );
    }
    return ColoredBox(
      color: bg ?? Colors.transparent,
      child: SizedBox.expand(child: child),
    );
  }
}

class _ImageClip extends StatelessWidget {
  const _ImageClip({
    required this.child,
    required this.shape,
    this.borderRadius,
  });

  final Widget child;
  final BoxShape shape;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    if (shape == BoxShape.circle) {
      return ClipOval(child: child);
    }
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({
    this.width,
    this.height,
    required this.shape,
    this.borderRadius,
    this.backgroundColor,
  });

  final double? width;
  final double? height;
  final BoxShape shape;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final baseColor =
        backgroundColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06));
    return SizedBox(
      width: width,
      height: height,
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: baseColor.withValues(alpha: 0.35),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: baseColor,
            shape: shape,
            borderRadius: shape == BoxShape.circle ? null : borderRadius,
          ),
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({
    this.width,
    this.height,
    this.backgroundColor,
    required this.fallbackIcon,
    required this.fallbackIconSize,
  });

  final double? width;
  final double? height;
  final Color? backgroundColor;
  final IconData fallbackIcon;
  final double fallbackIconSize;

  @override
  Widget build(BuildContext context) {
    final resolvedBackground =
        backgroundColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.05));

    return Container(
      width: width,
      height: height,
      color: resolvedBackground,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: fallbackIconSize + 16,
            height: fallbackIconSize + 16,
            child: Image.asset(
              kAppPlaceholderAssetPath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                fallbackIcon,
                color: Colors.grey,
                size: fallbackIconSize,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Icon(fallbackIcon, color: Colors.grey, size: fallbackIconSize),
        ],
      ),
    );
  }
}
