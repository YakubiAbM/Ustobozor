import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../api_client.dart';
import '../../constants.dart';
import '../../providers/settings_provider.dart';
import 'master_auth_helpers.dart';

enum _AuthStep { phone, password, resetPassword, register }

/// Пошаговый вход: телефон → пароль / новый пароль / регистрация.
class MasterLoginPhoneScreen extends StatefulWidget {
  const MasterLoginPhoneScreen({super.key});

  @override
  State<MasterLoginPhoneScreen> createState() => _MasterLoginPhoneScreenState();
}

class _MasterLoginPhoneScreenState extends State<MasterLoginPhoneScreen> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _AuthStep _step = _AuthStep.phone;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String _phoneForApi = '';

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
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
        '/auth/check-phone',
        body: {'phone_number': phone},
      );
      final body = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (!mounted) return;

      final status = (body['status'] as String? ?? '').toUpperCase();
      _phoneForApi = phone;
      _passwordController.clear();
      _confirmPasswordController.clear();

      if (status == 'NOT_FOUND') {
        setState(() => _step = _AuthStep.register);
      } else if (status == 'RESET_REQUIRED') {
        setState(() => _step = _AuthStep.resetPassword);
      } else {
        setState(() => _step = _AuthStep.password);
      }
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
    final password = _passwordController.text;
    if (password.trim().length < 4) {
      _showError(settings.t('master_password_min'));
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await apiPost(
        '/auth/login',
        body: {'phone_number': _phoneForApi, 'password': password},
      );
      final body = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (!mounted) return;
      if (body['status'] == 'success') {
        await applyMasterLoginFromBody(
          context,
          body,
          phoneFallback: _phoneForApi,
        );
      } else {
        _showError(body['message'] as String? ?? settings.t('master_login_failed'));
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setNewPassword() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final pwd = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    if (pwd.trim().length < 4) {
      _showError(settings.t('master_password_min'));
      return;
    }
    if (pwd != confirm) {
      _showError(settings.t('master_password_mismatch'));
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await apiPost(
        '/auth/set-new-password',
        body: {'phone_number': _phoneForApi, 'new_password': pwd},
      );
      final body = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (!mounted) return;
      if (body['status'] == 'success') {
        await applyMasterLoginFromBody(
          context,
          body,
          phoneFallback: _phoneForApi,
        );
      } else {
        _showError(body['message'] as String? ?? settings.t('master_login_failed'));
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
    final name = _nameController.text.trim();
    final pwd = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (name.isEmpty) {
      _showError(settings.t('master_enter_name_title'));
      return;
    }
    if (pwd.trim().length < 4) {
      _showError(settings.t('master_password_min'));
      return;
    }
    if (pwd != confirm) {
      _showError(settings.t('master_password_mismatch'));
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await apiPost(
        '/auth/register',
        body: {
          'phone_number': _phoneForApi,
          'password': pwd,
          'name': name,
        },
      );
      final body = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (!mounted) return;
      if (body['status'] == 'success') {
        await applyMasterLoginFromBody(
          context,
          body,
          nameFromForm: name,
          phoneFallback: _phoneForApi,
        );
      } else {
        _showError(body['message'] as String? ?? settings.t('master_login_failed'));
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
      _step = _AuthStep.phone;
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark ? AppColors.inputBg : AppColors.inputBgLight;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(settings.t('master_auth_title')),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        leading: _step == _AuthStep.phone
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
              if (_step == _AuthStep.phone) ...[
                Text(
                  settings.t('master_phone_prompt'),
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
                ),
              ],
              if (_step == _AuthStep.password) ...[
                Text(
                  settings.t('master_password_prompt'),
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 12),
                _passwordField(
                  controller: _passwordController,
                  label: settings.t('master_password_label'),
                  obscure: _obscurePassword,
                  onToggle: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  fillColor: fillColor,
                ),
                const SizedBox(height: 24),
                _primaryButton(
                  label: settings.t('login'),
                  onPressed: _loading ? null : _login,
                ),
              ],
              if (_step == _AuthStep.resetPassword) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    settings.t('master_reset_password_info'),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _passwordField(
                  controller: _passwordController,
                  label: settings.t('master_new_password'),
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
                  label: settings.t('master_save_and_login'),
                  onPressed: _loading ? null : _setNewPassword,
                ),
              ],
              if (_step == _AuthStep.register) ...[
                Text(
                  settings.t('master_register_desc'),
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: settings.t('your_name'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: fillColor,
                  ),
                ),
                const SizedBox(height: 12),
                _passwordField(
                  controller: _passwordController,
                  label: settings.t('master_new_password'),
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
                  label: settings.t('master_register_btn'),
                  onPressed: _loading ? null : _register,
                ),
              ],
              const SizedBox(height: 24),
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
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: TextInputType.visiblePassword,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: fillColor,
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
        ),
      ),
      style: TextStyle(color: theme.colorScheme.onSurface),
    );
  }

  Widget _primaryButton({required String label, required VoidCallback? onPressed}) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.accentContrastText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _loading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
