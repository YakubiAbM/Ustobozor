import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../api/admin_dashboard_api.dart';
import '../constants.dart';
import '../models/order_invoice.dart';

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  OrderInvoice? _invoice;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final inv = await AdminOrdersApi.fetchInvoice(widget.orderId);
      if (mounted) setState(() {
        _invoice = inv;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _print() async {
    final inv = _invoice;
    if (inv == null) return;
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: pw.Text(
                'НАКЛАДНАЯ № ${inv.invoiceNumber}',
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Дата: ${inv.date}'),
                pw.Text('Заказ #${inv.orderId}'),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Text('Покупатель: ${inv.clientName ?? '—'}'),
            pw.Text('Телефон: ${inv.clientPhone ?? '—'}'),
            if (inv.clientAddress != null && inv.clientAddress!.isNotEmpty)
              pw.Text('Адрес: ${inv.clientAddress}'),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              headers: ['№', 'Наименование', 'Кол-во', 'Ед.', 'Цена', 'Сумма'],
              data: [
                for (var i = 0; i < inv.items.length; i++)
                  [
                    '${i + 1}',
                    inv.items[i].name,
                    inv.items[i].qty.toStringAsFixed(0),
                    inv.items[i].unit,
                    inv.items[i].price.toStringAsFixed(2),
                    inv.items[i].lineTotal.toStringAsFixed(2),
                  ],
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            ),
            pw.SizedBox(height: 12),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'ИТОГО: ${inv.total.toStringAsFixed(2)} TJS',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
            ),
            if (inv.comment != null && inv.comment!.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Text('Комментарий: ${inv.comment}'),
            ],
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Накладная #${widget.orderId}'),
        actions: [
          if (_invoice != null)
            IconButton(
              tooltip: 'Печать / PDF',
              onPressed: _print,
              icon: const Icon(Icons.print_outlined),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
              : _invoice == null
                  ? const SizedBox.shrink()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          'Накладная № ${_invoice!.invoiceNumber}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text),
                        ),
                        const SizedBox(height: 8),
                        Text('Дата: ${_invoice!.date}', style: const TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 16),
                        _row('Покупатель', _invoice!.clientName ?? '—'),
                        _row('Телефон', _invoice!.clientPhone ?? '—'),
                        _row('Адрес', _invoice!.clientAddress ?? '—'),
                        const SizedBox(height: 16),
                        for (var i = 0; i < _invoice!.items.length; i++)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.cardElevated,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Text('${i + 1}. ', style: const TextStyle(color: AppColors.textSecondary)),
                                Expanded(
                                  child: Text(_invoice!.items[i].name, style: const TextStyle(color: AppColors.text)),
                                ),
                                Text(
                                  '${_invoice!.items[i].qty.toStringAsFixed(0)} × ${_invoice!.items[i].price.toStringAsFixed(0)}',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        Text(
                          'Итого: ${_invoice!.total.toStringAsFixed(2)} TJS',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _print,
                          icon: const Icon(Icons.print),
                          label: const Text('Печать / сохранить PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.black,
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(color: AppColors.text))),
        ],
      ),
    );
  }
}
