import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../constants.dart';

class ProjectVideoPlayer extends StatefulWidget {
  const ProjectVideoPlayer({
    super.key,
    required this.videoPath,
    this.height = 220,
  });

  final String videoPath;
  final double height;

  @override
  State<ProjectVideoPlayer> createState() => _ProjectVideoPlayerState();
}

class _ProjectVideoPlayerState extends State<ProjectVideoPlayer> {
  VideoPlayerController? _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final file = File(widget.videoPath);
    if (!await file.exists()) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final controller = VideoPlayerController.file(file);
    await controller.initialize();
    controller.setLooping(true);
    if (!mounted) {
      await controller.dispose();
      return;
    }

    setState(() {
      _controller = controller;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_loading) {
      return _placeholder(
        child: const CircularProgressIndicator(color: AppColors.accent),
      );
    }
    if (controller == null || !controller.value.isInitialized) {
      return _placeholder(
        child: const Icon(
          Icons.videocam_off_outlined,
          size: 42,
          color: AppColors.textSecondary,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: widget.height,
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              if (controller.value.isPlaying) {
                controller.pause();
              } else {
                controller.play();
              }
              setState(() {});
            },
            child: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.black54,
              child: Icon(
                controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: AppColors.accent,
                bufferedColor: Colors.white54,
                backgroundColor: Colors.white24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder({required Widget child}) {
    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(child: child),
    );
  }
}
