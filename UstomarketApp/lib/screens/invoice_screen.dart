import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import '../models/order.dart';

/// Экран накладной — документ 1 в 1 как в макете. Кнопка «Скачать» сохраняет в галерею/файлы.
class InvoiceScreen extends StatefulWidget {
  final Order order;

  const InvoiceScreen({super.key, required this.order});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();

  String _formatDate(String raw) {
    if (raw.isEmpty) return raw;
    try {
      final s = raw.replaceFirst('T', ' ').trim();
      final parts = s.split(RegExp(r'[\s\-:T.]'));
      if (parts.length >= 3) {
        final y = parts[0];
        final m = parts[1].padLeft(2, '0');
        final d = parts[2].padLeft(2, '0');
        return '$d.$m.$y';
      }
    } catch (_) {}
    return raw;
  }

  Future<void> _download() async {
    try {
      final image = await _screenshotController.capture();
      if (image == null || !mounted) return;
      final dir = await getTemporaryDirectory();
      final name = 'nakladnaya_${widget.order.number}.png';
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

      // Fallback: сохраняем в папку приложения и показываем путь
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

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final orderNum = order.number.length >= 6 ? order.number : order.number.padLeft(6, '0');
    final buyer = order.clientName != null && order.clientName!.isNotEmpty
        ? '${order.clientName} (${order.clientPhone ?? ''})'
        : (order.clientPhone ?? '—');

    return Scaffold(
      backgroundColor: const Color(0xFF1F2937),
      appBar: AppBar(
        title: const Text('Накладная', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.save, color: Colors.white, size: 22),
                      const SizedBox(width: 8),
                      const Text('Скачать', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
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
                  'Накладная',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('№ $orderNum', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.red, decoration: TextDecoration.underline, decorationColor: Colors.red)),
                    Text('дата ${_formatDate(order.date)}', style: const TextStyle(fontSize: 16, color: Colors.black87, decoration: TextDecoration.underline)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'покупатель: $buyer',
                  style: const TextStyle(fontSize: 14, color: Colors.black),
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
                    TableRow(
                      decoration: const BoxDecoration(color: Colors.black),
                      children: const [
                        Padding(padding: EdgeInsets.all(8), child: Text('№', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white))),
                        Padding(padding: EdgeInsets.all(8), child: Text('Наименование', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white))),
                        Padding(padding: EdgeInsets.all(8), child: Text('Кол-во', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white))),
                        Padding(padding: EdgeInsets.all(8), child: Text('Цена', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white))),
                        Padding(padding: EdgeInsets.all(8), child: Text('Сумма', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white))),
                      ],
                    ),
                    ...List.generate(14, (i) {
                      if (i < order.items.length) {
                        final item = order.items[i];
                        final sum = item.price * item.qty;
                        return TableRow(
                          children: [
                            Padding(padding: const EdgeInsets.all(8), child: Text('${i + 1}', style: const TextStyle(color: Colors.black, fontSize: 13))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(item.name.isEmpty ? '—' : item.name, style: const TextStyle(color: Colors.black, fontSize: 13))),
                            Padding(padding: const EdgeInsets.all(8), child: Text('${item.qty}', style: const TextStyle(color: Colors.black, fontSize: 13))),
                            Padding(padding: const EdgeInsets.all(8), child: Text('${item.price.toInt()}', style: const TextStyle(color: Colors.black, fontSize: 13))),
                            Padding(padding: const EdgeInsets.all(8), child: Text('${sum.toInt()}', style: const TextStyle(color: Colors.black, fontSize: 13))),
                          ],
                        );
                      }
                      return TableRow(
                        children: List.generate(5, (_) => const Padding(padding: EdgeInsets.all(8), child: Text('', style: TextStyle(color: Colors.black)))),
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
                      Text('${order.total.toInt()} смн', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
