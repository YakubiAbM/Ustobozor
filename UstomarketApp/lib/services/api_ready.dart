import 'dart:async';

import 'package:flutter/widgets.dart';

/// API-запросы только после того, как приложение на экране (не в фоне при установке).
class ApiReady {
  ApiReady._();

  static bool _ready = false;
  static Completer<void>? _completer;

  static bool get isReady => _ready;

  static void markReady() {
    if (_ready) return;
    _ready = true;
    _completer?.complete();
    _completer = null;
  }

  static Future<void> wait() async {
    if (_ready) return;
    _completer ??= Completer<void>();
    await _completer!.future;
  }
}

class ApiLifecycleGate extends StatefulWidget {
  const ApiLifecycleGate({super.key, required this.child});

  final Widget child;

  @override
  State<ApiLifecycleGate> createState() => _ApiLifecycleGateState();
}

class _ApiLifecycleGateState extends State<ApiLifecycleGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleReady();
  }

  void _scheduleReady() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        Future<void>.delayed(const Duration(milliseconds: 400), ApiReady.markReady);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ApiReady.markReady();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
