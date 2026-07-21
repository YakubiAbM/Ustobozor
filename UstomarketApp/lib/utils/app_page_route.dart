import 'package:flutter/material.dart';

import 'deferred_screen_body.dart';

/// Маршрут с отложенной инициализацией тяжёлого экрана — меньше jank при push.
class AppPageRoute<T> extends MaterialPageRoute<T> {
  AppPageRoute({
    required WidgetBuilder builder,
    super.settings,
    super.fullscreenDialog,
    bool deferHeavyContent = true,
    Widget? deferPlaceholder,
  }) : super(
          builder: deferHeavyContent
              ? (context) => DeferredScreenBody(
                    placeholder: deferPlaceholder,
                    builder: builder,
                  )
              : builder,
        );

  static Route<T> deferred<T>(
    WidgetBuilder builder, {
    RouteSettings? settings,
    bool fullscreenDialog = false,
    Widget? placeholder,
  }) {
    return AppPageRoute<T>(
      builder: builder,
      settings: settings,
      fullscreenDialog: fullscreenDialog,
      deferPlaceholder: placeholder,
    );
  }
}
