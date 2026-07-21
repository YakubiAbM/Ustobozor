import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../api_client.dart';
import '../../constants.dart';
import '../../providers/settings_provider.dart';
import 'client_auth_helpers.dart';

enum _ClientAuthStep { phone, password, register }

class ClientLoginPhoneScreen extends StatefulWidget {
  const ClientLoginPhoneScreen({super.key});

  @override
  State<ClientLoginPhoneScreen> createState() => _ClientLoginPhoneScreenState();
}

class _ClientLoginPhoneScreenState extends State<ClientLoginPhoneScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _ClientAuthStep _step = _ClientAuthStep.phone;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String _phoneForApi = '';

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _fullPhoneForApi() {
    final digits = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length >= 9) return '+992${digits.substring(0, 9)}';
    if (digits.isNotEmpty) return '+992$digits';
    return '';
  }

  bool _validatePhone() {
    final digits = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length != 9) {
      _showError(
        Provider.of<SettingsProvider>(context, listen: false).t('master_phone_invalid'),
      );
      return false;
    }
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _checkPhone() async {
    if (!_validatePhone()) return;
    final phone = _fullPhoneForApi();
    setState(() => _loading = true);
    try {
      final response = await apiPost(
        '/auth/client/check-phone',
        body: {'phone_number': phone},
      );
      final body = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (!mounted) return;

      final status = (body['status'] as String? ?? '').toUpperCase();
      _phoneForApi = phone;
      _passwordController.clear();
      _confirmPasswordController.clear();

      setState(() {
        _step = status == 'NOT_FOUND'
            ? _ClientAuthStep.register
            : _ClientAuthStep.password;
      });
    } catch (e) {
      if (mounted) {
        _showError(e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _login() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final code = _passwordController.text.trim();
    if (code.length < 4) {
      _showError(settings.t('client_code_min'));
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await apiPost(
        '/auth/client/login',
        body: {'phone_number': _phoneForApi, 'password': code},
      );
      final body = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (!mounted) return;
      if (body['status'] == 'success') {
        await applyClientLoginFromBody(context, body, phoneFallback: _phoneForApi);
      } else {
        _showError(body['message'] as String? ?? settings.t('client_login_failed'));
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final pwd = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (pwd.length < 4) {
      _showError(settings.t('client_code_min'));
      return;
    }
    if (pwd != confirm) {
      _showError(settings.t('client_code_mismatch'));
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await apiPost(
        '/auth/client/register',
        body: {'phone_number': _phoneForApi, 'password': pwd},
      );
      final body = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (!mounted) return;
      if (body['status'] == 'success') {
        await applyClientLoginFromBody(context, body, phoneFallback: _phoneForApi);
      } else {
        _showError(body['message'] as String? ?? settings.t('client_login_failed'));
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _backToPhone() {
    setState(() {
      _step = _ClientAuthStep.phone;
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final fillColor = theme.brightness == Brightness.dark
        ? AppColors.inputBg
        : AppColors.inputBgLight;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(settings.t('client_auth_title')),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        leading: _step == _ClientAuthStep.phone
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _loading ? null : _backToPhone,
              ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              if (_step == _ClientAuthStep.phone) ...[
                Text(
                  settings.t('client_phone_prompt'),
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 9,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'\d')),
                  ],
                  decoration: InputDecoration(
                    prefixText: '+992 ',
                    prefixStyle: TextStyle(
                      fontSize: 18,
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    hintText: '92 777 11 22',
                    counterText: '',
                    labelText: settings.t('phone'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: fillColor,
                  ),
                  style: TextStyle(
                    fontSize: 18,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 32),
                _primaryButton(
                  label: settings.t('next'),
                  onPressed: _loading ? null : _checkPhone,
                  loading: _loading,
                ),
              ],
              if (_step == _ClientAuthStep.password) ...[
                Text(
                  settings.t('client_code_prompt'),
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 12),
                _passwordField(
                  controller: _passwordController,
                  label: settings.t('client_code_label'),
                  obscure: _obscurePassword,
                  onToggle: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  fillColor: fillColor,
                ),
                const SizedBox(height: 24),
                _primaryButton(
                  label: settings.t('login'),
                  onPressed: _loading ? null : _login,
                  loading: _loading,
                ),
              ],
              if (_step == _ClientAuthStep.register) ...[
                Text(
                  settings.t('client_register_desc'),
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 16),
                _passwordField(
                  controller: _passwordController,
                  label: settings.t('client_code_label'),
                  obscure: _obscurePassword,
                  onToggle: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  fillColor: fillColor,
                ),
                const SizedBox(height: 12),
                _passwordField(
                  controller: _confirmPasswordController,
                  label: settings.t('master_confirm_password'),
                  obscure: _obscureConfirm,
                  onToggle: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  fillColor: fillColor,
                ),
                const SizedBox(height: 24),
                _primaryButton(
                  label: settings.t('client_register_btn'),
                  onPressed: _loading ? null : _register,
                  loading: _loading,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    required Color fillColor,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: fillColor,
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          onPressed: onToggle,
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.accentContrastText,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
