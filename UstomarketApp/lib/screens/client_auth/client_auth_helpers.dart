import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/client_auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/user_provider.dart';

Future<void> applyClientLoginFromBody(
  BuildContext context,
  Map<String, dynamic> body, {
  String? phoneFallback,
}) async {
  final clientId = body['client_id'] is int
      ? body['client_id'] as int
      : (body['client_id'] as num).toInt();
  final name = (body['name'] as String? ?? '').trim();
  final phone = body['phone'] as String? ?? phoneFallback ?? '';
  final accessToken =
      body['access_token'] is String ? (body['access_token'] as String).trim() : null;
  final refreshToken =
      body['refresh_token'] is String ? (body['refresh_token'] as String).trim() : null;

  await context.read<ClientAuthProvider>().setClient(
        clientId: clientId,
        name: name.isEmpty ? 'Клиент' : name,
        phone: phone,
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

  final userProvider = context.read<UserProvider>();
  await userProvider.updateUserData(
    name: name.isEmpty ? 'Клиент' : name,
    phone: phone,
    address: userProvider.address,
  );

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(context.read<SettingsProvider>().t('client_login_success')),
      backgroundColor: Colors.green,
    ),
  );
  Navigator.pop(context);
}
