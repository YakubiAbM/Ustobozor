import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/admin_dashboard_api.dart';
import '../../constants.dart';
import '../../models/admin_transaction.dart';
import '../../widgets/admin_section_header.dart';
import '../../widgets/admin_stat_card.dart';

class KassaTab extends StatefulWidget {
  const KassaTab({super.key});

  @override
  State<KassaTab> createState() => _KassaTabState();
}

class _KassaTabState extends State<KassaTab> with SingleTickerProviderStateMixin {
  AdminCashierSummary? _summary;
  List<AdminDebtor> _debtors = [];
  bool _loading = true;
  String? _error;
  late TabController _tabController;

  final _idController = TextEditingController();
  final _amountController = TextEditingController(text: '100');
  final _debtAmountController = TextEditingController(text: '50');
  final _promoTitleController = TextEditingController();
  final _promoBodyController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _idController.dispose();
    _amountController.dispose();
    _debtAmountController.dispose();
    _promoTitleController.dispose();
    _promoBodyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        AdminCashierApi.summary(),
        AdminCashierApi.fetchDebtors(),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as AdminCashierSummary;
        _debtors = results[1] as List<AdminDebtor>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _points(bool add) async {
    final id = _idController.text.trim();
    final amount = int.tryParse(_amountController.text.trim());
    if (id.isEmpty || amount == null || amount <= 0) {
      _snack('Укажите ID/телефон и сумму баллов', error: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      final res = add
          ? await AdminCashierApi.addPoints(id, amount)
          : await AdminCashierApi.spendPoints(id, amount);
      _snack(res.message, error: !res.ok);
      if (res.ok) _load();
    } catch (e) {
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _debt(bool add) async {
    final id = _idController.text.trim();
    final amount = double.tryParse(_debtAmountController.text.replaceAll(',', '.'));
    if (id.isEmpty || amount == null || amount <= 0) {
      _snack('Укажите ID/телефон и сумму долга (TJS)', error: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      final res = add
          ? await AdminCashierApi.addDebt(id, amount)
          : await AdminCashierApi.payDebt(id, amount);
      _snack(res.message, error: !res.ok);
      if (res.ok) _load();
    } catch (e) {
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _promo() async {
    final title = _promoTitleController.text.trim();
    if (title.isEmpty) {
      _snack('Введите заголовок акции', error: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      final msg = await AdminCashierApi.sendPromo(title, _promoBodyController.text.trim());
      _snack(msg);
    } catch (e) {
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.redAccent : AppColors.accent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AdminSectionHeader(title: 'Касса'),
            TabBar(
              controller: _tabController,
              labelColor: AppColors.accent,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.accent,
              tabs: const [
                Tab(text: 'Баллы'),
                Tab(text: 'Долги'),
                Tab(text: 'Акции'),
              ],
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: Color(0xFFFCA5A5))))
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _PointsTab(
                              summary: _summary,
                              idController: _idController,
                              amountController: _amountController,
                              submitting: _submitting,
                              onRefresh: _load,
                              onPoints: _points,
                            ),
                            _DebtTab(
                              debtors: _debtors,
                              idController: _idController,
                              debtAmountController: _debtAmountController,
                              submitting: _submitting,
                              onRefresh: _load,
                              onDebt: _debt,
                            ),
                            _PromoTab(
                              titleController: _promoTitleController,
                              bodyController: _promoBodyController,
                              submitting: _submitting,
                              onSend: _promo,
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PointsTab extends StatelessWidget {
  const _PointsTab({
    required this.summary,
    required this.idController,
    required this.amountController,
    required this.submitting,
    required this.onRefresh,
    required this.onPoints,
  });

  final AdminCashierSummary? summary;
  final TextEditingController idController;
  final TextEditingController amountController;
  final bool submitting;
  final Future<void> Function() onRefresh;
  final Future<void> Function(bool add) onPoints;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(AppLayout.screenPadding),
        children: [
          if (summary != null) ...[
            AdminStatCard(
              label: 'Операций сегодня',
              value: '${summary!.operationsToday}',
              icon: Icons.point_of_sale_outlined,
            ),
            const SizedBox(height: 12),
            AdminStatCard(
              label: 'Начислено сегодня',
              value: '${summary!.revenueToday.toStringAsFixed(0)} балл',
              icon: Icons.payments_outlined,
              accentColor: AppColors.orange,
            ),
          ],
          const SizedBox(height: 20),
          _OpsForm(
            title: 'Баллы мастеру',
            subtitle: 'ID мастера или последние 9 цифр телефона',
            idController: idController,
            amountController: amountController,
            amountLabel: 'Баллы',
            digitsOnly: true,
            submitting: submitting,
            onPrimary: () => onPoints(true),
            primaryLabel: 'Начислить',
            onSecondary: () => onPoints(false),
            secondaryLabel: 'Списать',
          ),
          const SizedBox(height: 20),
          const Text('Последние операции', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 10),
          if (summary == null || summary!.recent.isEmpty)
            const Text('Операций пока нет', style: TextStyle(color: AppColors.textSecondary))
          else
            ...summary!.recent.map((t) => _TxRow(tx: t)),
        ],
      ),
    );
  }
}

class _DebtTab extends StatelessWidget {
  const _DebtTab({
    required this.debtors,
    required this.idController,
    required this.debtAmountController,
    required this.submitting,
    required this.onRefresh,
    required this.onDebt,
  });

  final List<AdminDebtor> debtors;
  final TextEditingController idController;
  final TextEditingController debtAmountController;
  final bool submitting;
  final Future<void> Function() onRefresh;
  final Future<void> Function(bool add) onDebt;

  @override
  Widget build(BuildContext context) {
    final totalDebt = debtors.fold<double>(0, (s, d) => s + d.debt);
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(AppLayout.screenPadding),
        children: [
          AdminStatCard(
            label: 'Общий долг',
            value: '${totalDebt.toStringAsFixed(0)} TJS',
            icon: Icons.account_balance_wallet_outlined,
            accentColor: AppColors.orange,
          ),
          const SizedBox(height: 20),
          _OpsForm(
            title: 'Долг (TJS)',
            subtitle: 'Оформить или погасить долг мастера',
            idController: idController,
            amountController: debtAmountController,
            amountLabel: 'Сумма TJS',
            digitsOnly: false,
            submitting: submitting,
            onPrimary: () => onDebt(true),
            primaryLabel: 'Оформить долг',
            onSecondary: () => onDebt(false),
            secondaryLabel: 'Оплатить',
          ),
          const SizedBox(height: 20),
          const Text('Должники', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 10),
          if (debtors.isEmpty)
            const Text('Должников нет', style: TextStyle(color: AppColors.textSecondary))
          else
            ...debtors.map(
              (d) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cardElevated,
                  borderRadius: BorderRadius.circular(AppLayout.radiusMd),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.name ?? '—', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
                          Text(d.phone ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Text(
                      '${d.debt.toStringAsFixed(0)} TJS',
                      style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PromoTab extends StatelessWidget {
  const _PromoTab({
    required this.titleController,
    required this.bodyController,
    required this.submitting,
    required this.onSend,
  });

  final TextEditingController titleController;
  final TextEditingController bodyController;
  final bool submitting;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppLayout.screenPadding),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppLayout.radiusLg),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Рассылка акции',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
              ),
              const SizedBox(height: 4),
              const Text(
                'Уведомление получат все зарегистрированные мастера',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: titleController,
                style: const TextStyle(color: AppColors.text),
                decoration: const InputDecoration(labelText: 'Заголовок'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: bodyController,
                maxLines: 4,
                style: const TextStyle(color: AppColors.text),
                decoration: const InputDecoration(labelText: 'Текст акции'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: submitting ? null : onSend,
                child: const Text('Отправить всем мастерам'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OpsForm extends StatelessWidget {
  const _OpsForm({
    required this.title,
    required this.subtitle,
    required this.idController,
    required this.amountController,
    required this.amountLabel,
    required this.digitsOnly,
    required this.submitting,
    required this.onPrimary,
    required this.primaryLabel,
    required this.onSecondary,
    required this.secondaryLabel,
  });

  final String title;
  final String subtitle;
  final TextEditingController idController;
  final TextEditingController amountController;
  final String amountLabel;
  final bool digitsOnly;
  final bool submitting;
  final VoidCallback onPrimary;
  final String primaryLabel;
  final VoidCallback onSecondary;
  final String secondaryLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppLayout.radiusLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          TextField(
            controller: idController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: AppColors.text),
            decoration: const InputDecoration(labelText: 'ID / телефон', hintText: '986505650'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.numberWithOptions(decimal: !digitsOnly),
            inputFormatters: digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
            style: const TextStyle(color: AppColors.text),
            decoration: InputDecoration(labelText: amountLabel),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: ElevatedButton(onPressed: submitting ? null : onPrimary, child: Text(primaryLabel))),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: submitting ? null : onSecondary,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.orange,
                    side: const BorderSide(color: AppColors.orange),
                  ),
                  child: Text(secondaryLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({required this.tx});

  final AdminTransaction tx;

  @override
  Widget build(BuildContext context) {
    final positive = tx.amount >= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardElevated,
        borderRadius: BorderRadius.circular(AppLayout.radiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(tx.masterName ?? '—', style: const TextStyle(color: AppColors.text)),
          ),
          Text(
            '${positive ? '+' : ''}${tx.amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: positive ? AppColors.accent : AppColors.orange,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(tx.createdAt ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
