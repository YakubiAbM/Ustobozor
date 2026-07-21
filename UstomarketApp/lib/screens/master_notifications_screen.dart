import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_client.dart';
import '../constants.dart';
import '../models/master_notification.dart';
import '../providers/master_auth_provider.dart';
import '../providers/notifications_provider.dart';
import '../providers/settings_provider.dart';

/// Список уведомлений мастера: акции (promo), начисление/списание баллов.
class MasterNotificationsScreen extends StatefulWidget {
  const MasterNotificationsScreen({super.key});

  @override
  State<MasterNotificationsScreen> createState() => _MasterNotificationsScreenState();
}

class _MasterNotificationsScreenState extends State<MasterNotificationsScreen> {
  List<MasterNotification> _list = [];
  int _unreadCount = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final master = Provider.of<MasterAuthProvider>(context, listen: false);
    final token = master.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'no_token';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final listRes = await apiGetWithBearer(
        '/notifications',
        token,
        queryParameters: {'limit': '50'},
      );
      final countRes = await apiGetWithBearer('/notifications/unread_count', token);
      if (!mounted) return;
      final listBody = json.decode(utf8.decode(listRes.bodyBytes));
      final countBody = json.decode(utf8.decode(countRes.bodyBytes));
      final List<dynamic> rawList = listBody is List ? listBody : [];
      final count = countBody is Map && countBody['count'] != null
          ? (countBody['count'] is int ? countBody['count'] as int : (countBody['count'] as num).toInt())
          : 0;
      setState(() {
        _list = rawList
            .map((e) => MasterNotification.fromJson(e as Map<String, dynamic>))
            .where((n) =>
                kMasterPointsEnabled ||
                (n.type != 'points_added' && n.type != 'points_spent'))
            .toList();
        _unreadCount = count;
        _loading = false;
      });
      Provider.of<NotificationsProvider>(context, listen: false).setUnreadCount(count);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').replaceFirst(RegExp(r'^ApiClientException:\s*'), '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _markRead(MasterNotification n) async {
    if (n.isRead) return;
    final master = Provider.of<MasterAuthProvider>(context, listen: false);
    final token = master.accessToken;
    if (token == null || token.isEmpty) return;
    try {
      await apiPatchWithBearer('/notifications/${n.id}/read', token);
      if (!mounted) return;
      setState(() {
        final idx = _list.indexWhere((e) => e.id == n.id);
        if (idx >= 0) {
          _list = List.from(_list);
          _list[idx] = MasterNotification(
            id: n.id,
            masterId: n.masterId,
            type: n.type,
            title: n.title,
            body: n.body,
            payload: n.payload,
            createdAt: n.createdAt,
            readAt: DateTime.now().toIso8601String(),
          );
        }
        if (_unreadCount > 0) _unreadCount--;
      });
      Provider.of<NotificationsProvider>(context, listen: false).setUnreadCount(_unreadCount);
    } catch (_) {}
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'points_added':
        return Icons.add_circle_outline;
      case 'points_spent':
        return Icons.remove_circle_outline;
      case 'debt':
        return Icons.account_balance_wallet_outlined;
      case 'promo':
      default:
        return Icons.campaign_outlined;
    }
  }

  String _typeLabel(String type, SettingsProvider settings) {
    switch (type) {
      case 'points_added':
        return settings.t('type_points_added');
      case 'points_spent':
        return settings.t('type_points_spent');
      case 'debt':
        return settings.t('type_debt');
      case 'promo':
      default:
        return settings.t('type_promo');
    }
  }

  Color _iconColor(String type, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (type) {
      case 'points_added':
        return AppColors.accent;
      case 'points_spent':
      case 'debt':
        return Colors.orange;
      case 'promo':
      default:
        return isDark ? Colors.amber : Colors.amber.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final cardBg = isDark ? const Color(0xFF374151) : Colors.white;
    final cardBorder = isDark ? Colors.white12 : Colors.black.withOpacity(0.06);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1F2937) : const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: Text(settings.t('notifications_title')),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_unreadCount ${settings.t('notifications_unread')}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
                  const SizedBox(height: 16),
                  Text(
                    settings.t('loading'),
                    style: TextStyle(fontSize: 14, color: onSurface.withOpacity(0.6)),
                  ),
                ],
              ),
            )
          : _error != null
              ? _buildErrorState(settings, onSurface, isDark)
              : _list.isEmpty
                  ? _buildEmptyState(settings, onSurface, isDark)
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.accent,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                        itemCount: _list.length,
                        itemBuilder: (context, i) {
                          final n = _list[i];
                          return _buildNotificationCard(
                            n,
                            settings,
                            theme,
                            isDark,
                            onSurface,
                            cardBg,
                            cardBorder,
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildErrorState(SettingsProvider settings, Color onSurface, bool isDark) {
    final isNoToken = _error == 'no_token';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 64,
              color: onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 20),
            Text(
              isNoToken ? settings.t('notifications_error_login') : _error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: onSurface.withOpacity(0.85), height: 1.4),
            ),
            if (!isNoToken) ...[
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: Text(settings.t('try_again')),
                style: TextButton.styleFrom(foregroundColor: AppColors.accent),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(SettingsProvider settings, Color onSurface, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_active_rounded,
                size: 56,
                color: AppColors.accent.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              settings.t('notifications_empty'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              settings.t('notifications_empty_hint'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: onSurface.withOpacity(0.6), height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
    MasterNotification n,
    SettingsProvider settings,
    ThemeData theme,
    bool isDark,
    Color onSurface,
    Color cardBg,
    Color cardBorder,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: n.isRead ? cardBorder : AppColors.accent.withOpacity(0.35), width: n.isRead ? 1 : 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _markRead(n),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _iconColor(n.type, context).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_iconForType(n.type), color: _iconColor(n.type, context), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _typeLabel(n.type, settings),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _iconColor(n.type, context),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        n.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
                          color: onSurface,
                          height: 1.25,
                        ),
                      ),
                      if (n.body.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          n.body,
                          style: TextStyle(fontSize: 14, color: onSurface.withOpacity(0.8), height: 1.35),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        n.createdAt,
                        style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.5)),
                      ),
                    ],
                  ),
                ),
                if (!n.isRead)
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
