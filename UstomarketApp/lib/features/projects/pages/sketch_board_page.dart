import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../constants.dart';
import '../../../providers/settings_provider.dart';

enum SketchTool { freehand, autoRect, sizeLabel }

class SketchStroke {
  SketchStroke({required this.points, required this.color, required this.width});

  final List<Offset> points;
  final Color color;
  final double width;
}

class SketchLabel {
  SketchLabel({required this.position, required this.text});

  Offset position;
  String text;
}

class SketchShape {
  SketchShape.rect(this.rect);

  final Rect rect;
}

/// Доска эскиза: линии, авто-прямоугольник, размеры → PNG.
class SketchBoardPage extends StatefulWidget {
  const SketchBoardPage({super.key});

  @override
  State<SketchBoardPage> createState() => _SketchBoardPageState();
}

class _SketchBoardPageState extends State<SketchBoardPage> {
  final _boundaryKey = GlobalKey();
  final List<SketchStroke> _strokes = [];
  final List<SketchLabel> _labels = [];
  final List<SketchShape> _shapes = [];
  SketchStroke? _current;
  SketchTool _tool = SketchTool.autoRect;
  bool _saving = false;

  bool get _canUndo =>
      _strokes.isNotEmpty || _labels.isNotEmpty || _shapes.isNotEmpty;

  Future<void> _savePng() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    setState(() => _saving = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('no boundary');
      final image = await boundary.toImage(pixelRatio: 2);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw StateError('no bytes');
      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}${Platform.pathSeparator}sketch_${const Uuid().v4()}.png',
      );
      await file.writeAsBytes(Uint8List.fromList(bytes));
      if (!mounted) return;
      Navigator.pop(context, file.path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.t('project_sketch_save_error'))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _undo() {
    setState(() {
      if (_labels.isNotEmpty) {
        _labels.removeLast();
      } else if (_shapes.isNotEmpty) {
        _shapes.removeLast();
      } else if (_strokes.isNotEmpty) {
        _strokes.removeLast();
      }
    });
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _labels.clear();
      _shapes.clear();
      _current = null;
    });
  }

  void _finishStroke() {
    final stroke = _current;
    _current = null;
    if (stroke == null || stroke.points.length < 2) return;

    if (_tool == SketchTool.autoRect && stroke.points.length > 10) {
      final xs = stroke.points.map((p) => p.dx);
      final ys = stroke.points.map((p) => p.dy);
      final minX = xs.reduce(math.min);
      final maxX = xs.reduce(math.max);
      final minY = ys.reduce(math.min);
      final maxY = ys.reduce(math.max);
      // слишком маленькое — оставляем как линию
      if ((maxX - minX) > 24 && (maxY - minY) > 24) {
        setState(() {
          _shapes.add(SketchShape.rect(Rect.fromLTRB(minX, minY, maxX, maxY)));
        });
        return;
      }
    }

    setState(() => _strokes.add(stroke));
  }

  Future<void> _addLabelAt(Offset local) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final controller = TextEditingController(text: '2.1 м');
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(settings.t('project_sketch_size_title')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: settings.t('project_sketch_size_hint'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(settings.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(settings.t('save')),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty || !mounted) return;
    setState(() => _labels.add(SketchLabel(position: local, text: text)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strokeColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('project_sketch_title')),
        actions: [
          IconButton(
            tooltip: settings.t('project_sketch_undo'),
            onPressed: _canUndo ? _undo : null,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: settings.t('project_sketch_clear'),
            onPressed: _clear,
            icon: const Icon(Icons.delete_outline),
          ),
          TextButton(
            onPressed: _saving ? null : _savePng,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(settings.t('save')),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(settings.t('project_sketch_auto_rect')),
                    selected: _tool == SketchTool.autoRect,
                    onSelected: (_) =>
                        setState(() => _tool = SketchTool.autoRect),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(settings.t('project_sketch_draw')),
                    selected: _tool == SketchTool.freehand,
                    onSelected: (_) =>
                        setState(() => _tool = SketchTool.freehand),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(settings.t('project_sketch_size')),
                    selected: _tool == SketchTool.sizeLabel,
                    onSelected: (_) =>
                        setState(() => _tool = SketchTool.sizeLabel),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                settings.t(
                  _tool == SketchTool.autoRect
                      ? 'project_sketch_hint_rect'
                      : _tool == SketchTool.sizeLabel
                          ? 'project_sketch_hint_size'
                          : 'project_sketch_hint_draw',
                ),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: RepaintBoundary(
                key: _boundaryKey,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF111827) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: GestureDetector(
                      onPanStart: _tool == SketchTool.sizeLabel
                          ? null
                          : (d) {
                              setState(() {
                                _current = SketchStroke(
                                  points: [d.localPosition],
                                  color: _tool == SketchTool.autoRect
                                      ? AppColors.accent
                                      : strokeColor,
                                  width: 3,
                                );
                              });
                            },
                      onPanUpdate: _tool == SketchTool.sizeLabel
                          ? null
                          : (d) {
                              setState(() {
                                _current?.points.add(d.localPosition);
                              });
                            },
                      onPanEnd: _tool == SketchTool.sizeLabel
                          ? null
                          : (_) => _finishStroke(),
                      onTapUp: _tool != SketchTool.sizeLabel
                          ? null
                          : (d) => _addLabelAt(d.localPosition),
                      child: CustomPaint(
                        painter: _SketchPainter(
                          strokes: [
                            ..._strokes,
                            if (_current != null) _current!,
                          ],
                          labels: _labels,
                          shapes: _shapes,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
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

class _SketchPainter extends CustomPainter {
  _SketchPainter({
    required this.strokes,
    required this.labels,
    required this.shapes,
  });

  final List<SketchStroke> strokes;
  final List<SketchLabel> labels;
  final List<SketchShape> shapes;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.grey.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final shapePaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    for (final shape in shapes) {
      canvas.drawRect(shape.rect, shapePaint);
    }

    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()
        ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (var i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    for (final label in labels) {
      final tp = TextPainter(
        text: TextSpan(
          text: label.text,
          style: const TextStyle(
            color: AppColors.accent,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            backgroundColor: Color(0xCCFFFFFF),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, label.position);
    }
  }

  @override
  bool shouldRepaint(covariant _SketchPainter oldDelegate) => true;
}
