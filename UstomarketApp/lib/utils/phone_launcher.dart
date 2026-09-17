import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Нормализует номер Таджикистана до цифр с кодом 992.
String normalizeTjPhoneDigits(String phone) {
  final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.isEmpty) return '';
  if (digits.startsWith('992')) return digits;
  if (digits.length == 9) return '992$digits';
  return digits;
}

String formatTjPhoneDisplay(String phone) {
  final d = normalizeTjPhoneDigits(phone);
  if (d.isEmpty) return phone.trim();
  return '+$d';
}

/// Звонок. На эмуляторе dialer часто отсутствует — тогда копируем номер и показываем подсказку.
Future<void> launchPhoneCall(
  BuildContext context,
  String phone, {
  String? emptyMessage,
  String? failMessage,
}) async {
  final digits = normalizeTjPhoneDigits(phone);
  if (digits.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(emptyMessage ?? 'Номер телефона не указан'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  final display = '+$digits';
  final uri = Uri.parse('tel:$display');

  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (ok) return;
  } catch (_) {
    // ниже — fallback
  }

  try {
    final ok = await launchUrl(uri);
    if (ok) return;
  } catch (_) {
    // ниже — fallback
  }

  await Clipboard.setData(ClipboardData(text: display));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        failMessage ??
            'Звонок недоступен на этом устройстве. Номер скопирован: $display',
      ),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ),
  );
}

Future<void> launchWhatsApp(
  BuildContext context,
  String phone, {
  String? message,
  String? failMessage,
}) async {
  final digits = normalizeTjPhoneDigits(phone);
  if (digits.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Номер телефона не указан'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  final text = message?.trim() ?? '';
  final uri = text.isEmpty
      ? Uri.parse('https://wa.me/$digits')
      : Uri.parse(
          'https://wa.me/$digits?text=${Uri.encodeComponent(text)}',
        );
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (ok) return;
  } catch (_) {}

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(failMessage ?? 'Не удалось открыть WhatsApp'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
