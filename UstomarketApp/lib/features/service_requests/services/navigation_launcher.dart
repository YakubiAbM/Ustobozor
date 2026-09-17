import 'package:url_launcher/url_launcher.dart';

/// Открыть внешний навигатор до точки (Яндекс → Google Maps).
Future<bool> openRouteNavigator({
  required double latitude,
  required double longitude,
}) async {
  final lat = latitude.toStringAsFixed(6);
  final lng = longitude.toStringAsFixed(6);

  final candidates = <Uri>[
    // Яндекс Навигатор
    Uri.parse('yandexnavi://build_route_on_map?lat_to=$lat&lon_to=$lng'),
    // Яндекс Карты (приложение)
    Uri.parse('yandexmaps://maps.yandex.ru/?rtext=~$lat,$lng&rtt=auto'),
    // Яндекс Карты (web / deep link)
    Uri.parse('https://yandex.ru/maps/?rtext=~$lat,$lng&rtt=auto'),
    // Google Maps
    Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    ),
    // geo: fallback
    Uri.parse('geo:$lat,$lng?q=$lat,$lng'),
  ];

  for (final uri in candidates) {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) return true;
    } catch (_) {
      // пробуем следующий
    }
  }
  return false;
}
