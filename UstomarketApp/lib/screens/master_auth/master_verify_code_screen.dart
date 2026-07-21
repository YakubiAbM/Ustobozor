import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../constants.dart';
import '../../api_client.dart';
import '../../providers/settings_provider.dart';
import 'master_auth_helpers.dart';

/// Экран ввода кода. POST /auth/verify-code.
class MasterVerifyCodeScreen extends StatefulWidget {
  final String phone;
  final String? nameFromForm;
  /// tg | sms — подсказка, куда пришёл код
  final String? codeChannel;
  /// Dev: код из SMS-stub (ответ request-code с dev_code)
  final String? devCodeHint;

  const MasterVerifyCodeScreen({
    super.key,
    required this.phone,
    this.nameFromForm,
    this.codeChannel,
    this.devCodeHint,
  });

  @override
  State<MasterVerifyCodeScreen> createState() => _MasterVerifyCodeScreenState();
}

class _MasterVerifyCodeScreenState extends State<MasterVerifyCodeScreen> {
  final _codeController = TextEditingController();
  final _codeFocus = FocusNode();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final hint = widget.devCodeHint?.trim();
    if (hint != null && hint.length == 4) {
      _codeController.text = hint;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (code.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<SettingsProvider>(context, listen: false).t('master_code_4_digits'),
          ),
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final verifyBody = <String, dynamic>{
        'phone_number': widget.phone,
        'code': code,
      };
      final nameFromForm = widget.nameFromForm?.trim();
      if (nameFromForm != null && nameFromForm.isNotEmpty) {
        verifyBody['name'] = nameFromForm;
      }
      final response = await apiPost('/auth/verify-code', body: verifyBody);
      final body = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (!mounted) return;

      if (body['status'] == 'success') {
        await applyMasterLoginFromBody(
          context,
          body,
          nameFromForm: widget.nameFromForm,
          phoneFallback: widget.phone,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(body['message'] as String? ?? 'Неверный код'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onCodeChanged(String value) {
    final digits = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digits != value) {
      _codeController.value = TextEditingValue(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length.clamp(0, 4)),
      );
    }
    if (digits.length == 4 && !_loading) {
      _verify();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(settings.t('master_enter_code')),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                settings.t('master_code_prompt'),
                style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface.withOpacity(0.9)),
              ),
              const SizedBox(height: 8),
              Text(
                widget.phone,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.accent),
              ),
              if (widget.codeChannel == 'tg') ...[
                const SizedBox(height: 6),
                Text(
                  settings.t('master_code_wait_tg'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                ),
              ] else if (widget.codeChannel == 'sms') ...[
                const SizedBox(height: 6),
                Text(
                  settings.t('master_code_sent_sms'),
                  style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                ),
              ],
              if (widget.devCodeHint != null && widget.devCodeHint!.length == 4) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withOpacity(0.4)),
                  ),
                  child: Text(
                    'Dev-код: ${widget.devCodeHint}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              TextField(
                controller: _codeController,
                focusNode: _codeFocus,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 4,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: _onCodeChanged,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 12,
                  color: theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••',
                  hintStyle: TextStyle(
                    letterSpacing: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.25),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: isDark ? AppColors.inputBg : AppColors.inputBgLight,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Можно вставить код из SMS целиком',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.55)),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.accentContrastText,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          settings.t('login_master'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
