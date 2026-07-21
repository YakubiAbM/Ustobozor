import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'models/invoice_models.dart';

/// Экран черновика накладной из чата: товары, сумма, без номера заказа. Кнопка «Скачать» сохраняет в галерею.
class DraftInvoiceScreen extends StatefulWidget {
  final InvoiceDraft invoice;

  const DraftInvoiceScreen({super.key, required this.invoice});

  @override
  State<DraftInvoiceScreen> createState() => _DraftInvoiceScreenState();
}

class _DraftInvoiceScreenState extends State<DraftInvoiceScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();

  Future<void> _download() async {
    try {
      final image = await _screenshotController.capture();
      if (image == null || !mounted) return;
      final dir = await getTemporaryDirectory();
      final name = 'nakladnaya_chernovik_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(image);

      try {
        final hasAccess = await Gal.hasAccess();
        if (!hasAccess) await Gal.requestAccess();
        if (await Gal.hasAccess()) {
          await Gal.putImage(file.path);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Накладная сохранена в галерею'), backgroundColor: Colors.green),
            );
          }
          return;
        }
      } catch (_) {}

      final appDir = await getApplicationDocumentsDirectory();
      final savedFile = File('${appDir.path}/$name');
      await savedFile.writeAsBytes(image);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Накладная сохранена: ${savedFile.path}'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  static String _todayDate() {
    final n = DateTime.now();
    return '${n.day.toString().padLeft(2, '0')}.${n.month.toString().padLeft(2, '0')}.${n.year}';
  }

  @override
  Widget build(BuildContext context) {
    final invoice = widget.invoice;
    return Scaffold(
      backgroundColor: const Color(0xFF1F2937),
      appBar: AppBar(
        title: const Text('Черновик накладной', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Material(
              color: Colors.green,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: _download,
                borderRadius: BorderRadius.circular(10),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.save, color: Colors.white, size: 22),
                      SizedBox(width: 8),
                      Text('Скачать', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Screenshot(
          controller: _screenshotController,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Накладная (черновик)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                const SizedBox(height: 16),
                Text(
                  'дата ${_todayDate()}',
                  style: const TextStyle(fontSize: 16, color: Colors.black87, decoration: TextDecoration.underline),
                ),
                const SizedBox(height: 20),
                Table(
                  border: TableBorder.all(color: Colors.grey.shade400),
                  columnWidths: const {
                    0: FlexColumnWidth(0.5),
                    1: FlexColumnWidth(3),
                    2: FlexColumnWidth(0.7),
                    3: FlexColumnWidth(0.8),
                    4: FlexColumnWidth(0.8),
                  },
                  children: [
                    const TableRow(
                      decoration: BoxDecoration(color: Colors.black),
                      children: [
                        Padding(padding: EdgeInsets.all(8), child: Text('№', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white))),
                        Padding(padding: EdgeInsets.all(8), child: Text('Наименование', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white))),
                        Padding(padding: EdgeInsets.all(8), child: Text('Кол-во', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white))),
                        Padding(padding: EdgeInsets.all(8), child: Text('Цена', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white))),
                        Padding(padding: EdgeInsets.all(8), child: Text('Сумма', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white))),
                      ],
                    ),
                    ...List.generate(14, (i) {
                      if (i < invoice.items.length) {
                        final item = invoice.items[i];
                        final sum = item.price * item.qty;
                        return TableRow(
                          children: [
                            Padding(padding: const EdgeInsets.all(8), child: Text('${i + 1}', style: const TextStyle(color: Colors.black, fontSize: 13))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(item.name.isEmpty ? '—' : item.name, style: const TextStyle(color: Colors.black, fontSize: 13))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(item.qty == item.qty.toInt() ? '${item.qty.toInt()}' : '${item.qty}', style: const TextStyle(color: Colors.black, fontSize: 13))),
                            Padding(padding: const EdgeInsets.all(8), child: Text('${item.price.toInt()}', style: const TextStyle(color: Colors.black, fontSize: 13))),
                            Padding(padding: const EdgeInsets.all(8), child: Text('${sum.toInt()}', style: const TextStyle(color: Colors.black, fontSize: 13))),
                          ],
                        );
                      }
                      return const TableRow(
                        children: [
                          Padding(padding: EdgeInsets.all(8), child: Text('', style: TextStyle(color: Colors.black))),
                          Padding(padding: EdgeInsets.all(8), child: Text('', style: TextStyle(color: Colors.black))),
                          Padding(padding: EdgeInsets.all(8), child: Text('', style: TextStyle(color: Colors.black))),
                          Padding(padding: EdgeInsets.all(8), child: Text('', style: TextStyle(color: Colors.black))),
                          Padding(padding: EdgeInsets.all(8), child: Text('', style: TextStyle(color: Colors.black))),
                        ],
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  color: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Итого:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text('${invoice.totalPrice.toInt()} ${invoice.currency}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
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
