import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../constants.dart';
import '../../../providers/settings_provider.dart';
import '../models/project_model.dart';
import '../services/project_storage_service.dart';

/// Форма погашения долга: имя, телефон, сумма долга и поле + кнопка погашения.
class DebtRepaymentPage extends StatefulWidget {
  const DebtRepaymentPage({super.key, required this.projectId});

  final String projectId;

  @override
  State<DebtRepaymentPage> createState() => _DebtRepaymentPageState();
}

class _DebtRepaymentPageState extends State<DebtRepaymentPage> {
  ProjectModel? _project;
  bool _loading = true;
  final TextEditingController _amountController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProject();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadProject() async {
    final project = await ProjectStorageService.instance.getProjectById(widget.projectId);
    if (!mounted) return;
    setState(() {
      _project = project;
      _loading = false;
    });
  }

  static double _debtAmount(ProjectModel p) => p.debtAmount;

  static String _formatMoney(double value) {
    final s = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      buffer.write(s[i]);
      final fromEnd = s.length - i - 1;
      if (fromEnd > 0 && fromEnd % 3 == 0) buffer.write(' ');
    }
    return buffer.toString();
  }

  Future<void> _submitRepayment() async {
    final project = _project;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (project == null) return;

    final amountStr = _amountController.text.trim().replaceAll(',', '.');
    final payment = double.tryParse(amountStr);
    if (payment == null || payment <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(settings.t('debt_amount_error')),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    final debt = _debtAmount(project);
    if (payment > debt) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(settings.t('debt_amount_error')),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final newReceived = project.receivedAmount + payment;
    final paymentRecord = ProjectPayment(
      id: const Uuid().v4(),
      amount: payment,
      date: DateTime.now(),
      note: settings.t('debt_repayment_title'),
    );

    try {
      await ProjectStorageService.instance.updateProject(
        project.copyWith(
          receivedAmount: newReceived,
          payments: [...project.payments, paymentRecord],
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(settings.t('debt_repayment_success')),
          backgroundColor: AppColors.accent,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final surfaceColor = theme.colorScheme.surface;
    final inputBg = isDark ? AppColors.inputBg : AppColors.inputBgLight;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(settings.t('debt_repayment_title'))),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }

    final project = _project;
    if (project == null) {
      return Scaffold(
        appBar: AppBar(title: Text(settings.t('debt_repayment_title'))),
        body: Center(
          child: Text(
            settings.t('project_not_found'),
            style: TextStyle(color: onSurface.withValues(alpha: 0.8)),
          ),
        ),
      );
    }

    final debt = _debtAmount(project);
    final name = project.client.trim().isEmpty ? project.title : project.client;
    final phone = project.phone.trim().isEmpty
        ? settings.t('project_not_specified')
        : project.phone;

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('debt_repayment_title')),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailRow(settings.t('project_client'), name),
                    const SizedBox(height: 10),
                    _detailRow(settings.t('project_phone_label'), phone),
                    const SizedBox(height: 10),
                    _detailRow(
                      settings.t('project_debt_label'),
                      '${_formatMoney(debt)} ${settings.t('currency_somoni')}',
                      valueColor: AppColors.orange,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                settings.t('debt_repayment_amount'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: onSurface.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: onSurface, fontSize: 16),
                decoration: InputDecoration(
                  hintText: '${settings.t('debt_repayment_amount_hint')} (${_formatMoney(debt)} ${settings.t('currency_somoni')})',
                  hintStyle: TextStyle(color: onSurface.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submitRepayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.accentContrastText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          settings.t('debt_repayment_btn'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: valueColor ?? onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
