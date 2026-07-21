import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/master_auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/master_code_format.dart';

/// Сохраняет сессию мастера после успешного входа /auth/login, /auth/register или /auth/set-new-password.
Future<void> applyMasterLoginFromBody(
  BuildContext context,
  Map<String, dynamic> body, {
  String? nameFromForm,
  String? phoneFallback,
}) async {
  final masterId = body['master_id'] is int
      ? body['master_id'] as int
      : (body['master_id'] as num).toInt();
  var name = (body['name'] as String? ?? '').trim();
  if (name.isEmpty && nameFromForm != null && nameFromForm.trim().isNotEmpty) {
    name = nameFromForm.trim();
  }
  if (name.isEmpty) name = 'Мастер';
  final phone = body['phone'] as String? ?? phoneFallback ?? '';
  final points = body['points'] is int
      ? body['points'] as int
      : (body['points'] as num?)?.toInt() ?? 0;
  final masterCodeRaw = body['master_code'] ?? body['barcode'];
  String? masterCode;
  if (masterCodeRaw != null) {
    final trimmed = masterCodeRaw.toString().trim();
    if (trimmed.isNotEmpty && !isLegacyBarcodeImagePath(trimmed)) {
      masterCode = trimmed;
    }
  }
  final accessToken = body['access_token'] is String ? (body['access_token'] as String).trim() : null;
  final refreshToken = body['refresh_token'] is String ? (body['refresh_token'] as String).trim() : null;

  await context.read<MasterAuthProvider>().setMaster(
        masterId: masterId,
        name: name,
        phone: phone,
        points: points,
        masterCode: masterCode,
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

  final userProvider = context.read<UserProvider>();
  await userProvider.updateUserData(
    name: name,
    phone: phone,
    address: userProvider.address,
  );

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(context.read<SettingsProvider>().t('master_login_success')),
      backgroundColor: Colors.green,
    ),
  );
  Navigator.popUntil(context, (route) => route.isFirst);
}
