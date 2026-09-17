import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../constants.dart';
import '../../../providers/client_auth_provider.dart';
import '../services/service_catalog_api.dart';

/// Экран отзыва после завершения заказа.
class LeaveReviewPage extends StatefulWidget {
  const LeaveReviewPage({super.key, required this.orderId});

  final int orderId;

  @override
  State<LeaveReviewPage> createState() => _LeaveReviewPageState();
}

class _LeaveReviewPageState extends State<LeaveReviewPage> {
  int _rating = 0;
  final _commentCtrl = TextEditingController();
  final List<XFile> _photos = [];
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= 4) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Галерея'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Камера'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picker = ImagePicker();
    if (source == ImageSource.gallery) {
      final files = await picker.pickMultiImage(imageQuality: 75);
      if (!mounted) return;
      setState(() {
        for (final f in files) {
          if (_photos.length >= 4) break;
          _photos.add(f);
        }
      });
    } else {
      final file = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
      );
      if (file == null || !mounted) return;
      setState(() => _photos.add(file));
    }
  }

  Future<void> _submit() async {
    if (_rating < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите оценку от 1 до 5')),
      );
      return;
    }
    final token = context.read<ClientAuthProvider>().accessToken;
    if (token == null || token.isEmpty) return;

    setState(() => _submitting = true);
    try {
      final b64 = <String>[];
      for (final f in _photos.take(4)) {
        final bytes = await File(f.path).readAsBytes();
        b64.add(base64Encode(bytes));
      }
      await ServiceCatalogApi.instance.submitReview(
        clientToken: token,
        orderId: widget.orderId,
        rating: _rating,
        comment: _commentCtrl.text.trim(),
        photosBase64: b64,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Отзыв опубликован'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Оставить отзыв')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Оценка',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return IconButton(
                onPressed: () => setState(() => _rating = star),
                iconSize: 40,
                icon: Icon(
                  star <= _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber.shade700,
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commentCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Отзыв',
              hintText:
                  'Расскажите, как мастер справился с работой, вовремя ли пришел, чисто ли оставил место...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _photos.length >= 4 ? null : _addPhoto,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text('Добавить фото работы (${_photos.length}/4)'),
          ),
          if (_photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_photos[i].path),
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() => _photos.removeAt(i)),
                          icon: const Icon(Icons.cancel, color: Colors.white),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.accentContrastText,
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Опубликовать отзыв',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
