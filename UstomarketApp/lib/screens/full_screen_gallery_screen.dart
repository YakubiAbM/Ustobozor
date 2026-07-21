import 'dart:io';

import 'package:flutter/material.dart';
import '../widgets/app_cached_image.dart';

/// Полноэкранный просмотр фотографий товара. Листание свайпом, счётчик N/M.
class FullScreenGalleryScreen extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const FullScreenGalleryScreen({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<FullScreenGalleryScreen> createState() =>
      _FullScreenGalleryScreenState();
}

class _FullScreenGalleryScreenState extends State<FullScreenGalleryScreen> {
  late PageController _pageController;
  late int _currentIndex;

  bool _isLocalFilePath(String path) {
    if (path.trim().isEmpty) return false;
    if (path.startsWith('http://') || path.startsWith('https://')) return false;
    if (path.startsWith('static/')) return false;
    if (path.startsWith('file://')) return true;
    return File(path).existsSync();
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _currentIndex = widget.initialIndex;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls.where((u) => u.isNotEmpty).toList();
    final count = urls.isEmpty ? 1 : urls.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: urls.isEmpty ? 1 : urls.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, i) {
              if (urls.isEmpty) {
                return const Center(
                  child: Icon(Icons.image, color: Colors.grey, size: 80),
                );
              }
              final rawPath = urls[i];
              final isRemote = !_isLocalFilePath(rawPath);
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: isRemote
                      ? AppCachedImage(
                          imagePath: rawPath,
                          fit: BoxFit.contain,
                          disableMemCacheResize: true,
                          fallbackIcon: Icons.broken_image,
                          backgroundColor: Colors.black,
                        )
                      : Image.file(
                          File(
                            rawPath.startsWith('file://')
                                ? Uri.parse(rawPath).toFilePath()
                                : rawPath,
                          ),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                                size: 80,
                              ),
                        ),
                ),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.arrow_back, color: Colors.black),
                    ),
                  ),
                  if (count > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_currentIndex + 1}/$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
          if (count > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 40,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1}/$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
