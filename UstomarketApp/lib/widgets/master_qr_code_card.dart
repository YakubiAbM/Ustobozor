import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../utils/master_code_format.dart';

const _qrGraphite = Color(0xFF1A1A1A);

/// Белая карточка с векторным QR-кодом и текстовым дублированием ID.
class MasterQrCodeCard extends StatelessWidget {
  const MasterQrCodeCard({
    super.key,
    required this.code,
    this.size = 200,
    this.compact = false,
    this.onTap,
  });

  final String code;
  final double size;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final digits = normalizeMasterCodeDigits(code);
    final hasCode = digits.isNotEmpty;

    final card = Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: hasCode
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QrImageView(
                  data: digits,
                  version: QrVersions.auto,
                  size: compact ? size * 0.55 : size,
                  gapless: false,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: _qrGraphite,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: _qrGraphite,
                  ),
                ),
                SizedBox(height: compact ? 8 : 16),
                Text(
                  formatMasterCodeDisplay(digits),
                  style: GoogleFonts.montserrat(
                    fontSize: compact ? 16 : 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.6,
                    color: _qrGraphite,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '—',
                style: TextStyle(color: Colors.black.withValues(alpha: 0.4)),
                textAlign: TextAlign.center,
              ),
            ),
    );

    if (onTap == null || !hasCode) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: card,
      ),
    );
  }
}

/// Полноэкранный QR с максимальной яркостью экрана.
Future<void> showMasterQrFullScreen(
  BuildContext context, {
  required String code,
  required String title,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => _MasterQrFullScreenDialog(code: code, title: title),
  );
}

class _MasterQrFullScreenDialog extends StatefulWidget {
  const _MasterQrFullScreenDialog({
    required this.code,
    required this.title,
  });

  final String code;
  final String title;

  @override
  State<_MasterQrFullScreenDialog> createState() =>
      _MasterQrFullScreenDialogState();
}

class _MasterQrFullScreenDialogState extends State<_MasterQrFullScreenDialog> {
  double? _previousBrightness;

  @override
  void initState() {
    super.initState();
    _boostBrightness();
  }

  Future<void> _boostBrightness() async {
    try {
      final brightness = ScreenBrightness();
      _previousBrightness = await brightness.application;
      await brightness.setApplicationScreenBrightness(1.0);
    } catch (_) {}
  }

  Future<void> _restoreBrightness() async {
    final prev = _previousBrightness;
    if (prev == null) return;
    try {
      await ScreenBrightness().setApplicationScreenBrightness(prev);
    } catch (_) {}
  }

  @override
  void dispose() {
    _restoreBrightness();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            style: GoogleFonts.montserrat(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          MasterQrCodeCard(code: widget.code, size: 260),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              MaterialLocalizations.of(context).closeButtonLabel,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

/// Поднимает яркость на время жизни виджета (для экрана профиля мастера).
class MasterQrBrightnessScope extends StatefulWidget {
  const MasterQrBrightnessScope({super.key, required this.child});

  final Widget child;

  @override
  State<MasterQrBrightnessScope> createState() =>
      _MasterQrBrightnessScopeState();
}

class _MasterQrBrightnessScopeState extends State<MasterQrBrightnessScope> {
  double? _previousBrightness;

  @override
  void initState() {
    super.initState();
    _boostBrightness();
  }

  Future<void> _boostBrightness() async {
    try {
      final brightness = ScreenBrightness();
      _previousBrightness = await brightness.application;
      await brightness.setApplicationScreenBrightness(1.0);
    } catch (_) {}
  }

  Future<void> _restoreBrightness() async {
    final prev = _previousBrightness;
    if (prev == null) return;
    try {
      await ScreenBrightness().setApplicationScreenBrightness(prev);
    } catch (_) {}
  }

  @override
  void dispose() {
    _restoreBrightness();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
