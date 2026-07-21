import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Откладывает построение тяжёлого контента до завершения анимации перехода
/// (или до следующего кадра, если маршрут без анимации — overlay в MainLayout).
class DeferredScreenBody extends StatefulWidget {
  const DeferredScreenBody({
    super.key,
    required this.builder,
    this.placeholder,
    this.waitForRouteAnimation = true,
  });

  final WidgetBuilder builder;
  final Widget? placeholder;
  final bool waitForRouteAnimation;

  @override
  State<DeferredScreenBody> createState() => _DeferredScreenBodyState();
}

class _DeferredScreenBodyState extends State<DeferredScreenBody> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) => _scheduleReady());
  }

  void _scheduleReady() {
    if (!mounted || _ready) return;

    if (!widget.waitForRouteAnimation) {
      setState(() => _ready = true);
      return;
    }

    final route = ModalRoute.of(context);
    final animation = route?.animation;
    if (animation == null || animation.isCompleted) {
      setState(() => _ready = true);
      return;
    }

    void listener(AnimationStatus status) {
      if (status == AnimationStatus.completed && mounted) {
        animation.removeStatusListener(listener);
        setState(() => _ready = true);
      }
    }

    animation.addStatusListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return widget.placeholder ??
          const ColoredBox(
            color: Colors.transparent,
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
    }
    return widget.builder(context);
  }
}
