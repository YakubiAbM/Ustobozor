import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../constants.dart';
import '../../api_client.dart';
import '../../models/product.dart';
import '../../providers/chat_order_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/master_auth_provider.dart';
import '../../utils/translations.dart';
import '../product_detail_screen.dart';
import 'models/chat_message_model.dart';
import 'models/invoice_models.dart';
import 'chat_order_checkout_screen.dart';
import 'draft_invoice_screen.dart';
import 'widgets/chat_bubble_loading.dart';
import 'widgets/chat_bubble_system.dart';
import 'widgets/chat_bubble_user.dart';
import 'widgets/invoice_card_widget.dart';
import 'widgets/pick_card_widget.dart';

class ChatOrderScreen extends StatefulWidget {
  const ChatOrderScreen({super.key});

  @override
  State<ChatOrderScreen> createState() => _ChatOrderScreenState();
}

class _ChatOrderScreenState extends State<ChatOrderScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatOrderProvider>().ensureSession();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final chat = Provider.of<ChatOrderProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (chat.mode == ChatOrderMode.done && chat.orderCreatedId != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(settings.t('chat_order_title')),
          backgroundColor: theme.scaffoldBackgroundColor,
          foregroundColor: theme.colorScheme.onSurface,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: AppColors.accent, size: 64),
                const SizedBox(height: 16),
                Text(
                  '${settings.t('order_created')}: №${chat.orderCreatedId}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '${settings.t('order_status')}: ${chat.orderCreatedStatus ?? ''}',
                  style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface.withOpacity(0.8)),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    chat.clear();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.accentContrastText,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(settings.t('back_to_shop')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (chat.sessionId != null && chat.messages.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final c = context.read<ChatOrderProvider>();
        c.setWelcomeMessages(settings.t('chat_welcome'), settings.t('chat_instruction'));
        _scrollToEnd();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('chat_order_title')),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _showClearConfirm(context, settings, chat),
            tooltip: settings.t('clear'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: chat.messages.length >= 2 ? chat.messages.length + 1 : chat.messages.length,
              itemBuilder: (context, i) {
                if (chat.messages.length >= 2 && i == 2) {
                  return _buildContactManagerButton(context, settings, theme, isDark);
                }
                final msgIndex = i > 2 ? i - 1 : i;
                final msg = chat.messages[msgIndex];
                if (msg.type == ChatMessageType.loading) {
                  return const ChatBubbleLoading();
                }
                if (msg.type == ChatMessageType.text) {
                  if (msg.role == ChatRole.user) {
                    return ChatBubbleUser(text: msg.text ?? '');
                  }
                  return ChatBubbleSystem(text: msg.text ?? '');
                }
                if (msg.type == ChatMessageType.invoice && msg.invoice != null) {
                  return InvoiceCardWidget(
                    invoice: msg.invoice!,
                    invoiceTitle: settings.t('invoice_title'),
                    totalLabel: settings.t('invoice_total'),
                    addLabel: settings.t('add_item'),
                    addProductBtnLabel: settings.t('add_product_btn'),
                    editQtyLabel: settings.t('edit_qty'),
                    deleteLabel: settings.t('delete_item'),
                    placeOrderLabel: settings.t('place_order'),
                    downloadInvoiceLabel: settings.t('download_invoice'),
                    onAddPressed: () {
                      chat.setAwaitingAddText(settings.t('add_product_prompt'));
                      _scrollToEnd();
                    },
                    onEditQtyPressed: () => _showEditQtySheet(context, settings, chat, msg.invoice!),
                    onDeletePressed: () => _showDeleteSheet(context, settings, chat, msg.invoice!),
                    onPlaceOrderPressed: () => _openCheckout(context, chat),
                    onDownloadPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DraftInvoiceScreen(invoice: msg.invoice!),
                        ),
                      );
                    },
                    onQtyChanged: (itemIndex, newQty) async {
                      await chat.actionEditQty(itemIndex, newQty);
                      if (mounted) _scrollToEnd();
                    },
                    onProductTap: (item) => _openProductDetail(context, item),
                  );
                }
                if (msg.type == ChatMessageType.pick && msg.pick != null) {
                  return PickCardWidget(
                    pick: msg.pick!,
                    defaultPrompt: settings.t('pick_choose_variant'),
                    onOptionSelected: (productId) async {
                      await chat.pickOption(msg.pick!.itemIndex, productId);
                      if (mounted) _scrollToEnd();
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          _buildInputBar(context, settings, chat, isDark),
        ],
      ),
    );
  }

  static const _whatsappTeal = Color(0xFF25D366);

  Widget _buildContactManagerButton(BuildContext context, SettingsProvider settings, ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Material(
        color: _whatsappTeal,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () async {
            final uri = Uri.parse('https://wa.me/+992872148008');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chat, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Text(
                  settings.t('contact_manager'),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(BuildContext context, SettingsProvider settings, ChatOrderProvider chat, bool isDark) {
    final theme = Theme.of(context);
    final isAwaitingAdd = chat.mode == ChatOrderMode.awaitingAddText;
    final hint = isAwaitingAdd ? settings.t('add_product_hint') : settings.t('chat_order_hint');
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              enabled: !chat.isLoading,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                filled: true,
                fillColor: isDark ? AppColors.inputBg : AppColors.inputBgLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 15),
              onSubmitted: (_) => _sendIfCan(chat, settings),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: chat.isLoading ? null : () => _sendIfCan(chat, settings),
            icon: chat.isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  Future<void> _sendIfCan(ChatOrderProvider chat, SettingsProvider settings) async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final productNotFoundMsg = settings.t('product_not_found_write_again');
    _textController.clear();
    if (chat.mode == ChatOrderMode.awaitingAddText) {
      await chat.actionAddMore(text, productNotFoundMessage: productNotFoundMsg);
    } else {
      await chat.sendMessage(text, productNotFoundMessage: productNotFoundMsg);
    }
    if (!mounted) return;
    _scrollToEnd();
  }

  void _showClearConfirm(BuildContext context, SettingsProvider settings, ChatOrderProvider chat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(settings.t('clear')),
        content: Text(settings.t('clear_chat_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(settings.t('cancel'))),
          TextButton(
            onPressed: () {
              chat.clear();
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text(settings.t('clear')),
          ),
        ],
      ),
    );
  }

  void _showEditQtySheet(BuildContext context, SettingsProvider settings, ChatOrderProvider chat, InvoiceDraft invoice) {
    if (invoice.items.isEmpty) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: invoice.items.length,
          itemBuilder: (_, i) {
            final item = invoice.items[i];
            return ListTile(
              title: Text(item.name),
              subtitle: Text('${item.qty} ${item.unit}'),
              onTap: () {
                Navigator.pop(ctx);
                _showQtyDialog(context, settings, chat, i, item.qty);
              },
            );
          },
        ),
      ),
    );
  }

  void _showQtyDialog(BuildContext context, SettingsProvider settings, ChatOrderProvider chat, int itemIndex, double currentQty) {
    final controller = TextEditingController(text: currentQty.toInt().toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(settings.t('edit_qty')),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Количество',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(settings.t('cancel'))),
          TextButton(
            onPressed: () async {
              final qty = double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;
              if (qty > 0) {
                Navigator.pop(ctx);
                await chat.actionEditQty(itemIndex, qty);
                if (mounted) _scrollToEnd();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите число больше 0')));
              }
            },
            child: Text(settings.t('confirm')),
          ),
        ],
      ),
    );
  }

  void _openCheckout(BuildContext context, ChatOrderProvider chat) {
    if (chat.sessionId == null) return;
    final invoice = chat.lastInvoice;
    if (invoice == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatOrderCheckoutScreen(
          sessionId: chat.sessionId!,
          invoice: invoice,
        ),
      ),
    );
  }

  /// Открыть базовый экран детали товара (тот же, что в каталоге/корзине) с полными данными, включая размеры.
  Future<void> _openProductDetail(BuildContext context, InvoiceItem item) async {
    try {
      final response = await apiGet('/products');
      if (response.statusCode != 200 || !context.mounted) return;
      final body = utf8.decode(response.bodyBytes);
      final List<dynamic> data = json.decode(body);
      Product? product;
      final idStr = item.productId.toString();
      for (final e in data) {
        final p = Product.fromJson(e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e));
        if (p.id == idStr) {
          product = p;
          break;
        }
      }
      if (!context.mounted) return;
      if (product != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(
              product: product!,
              onBack: () => Navigator.of(context).pop(),
            ),
          ),
        );
      } else {
        final msg = Provider.of<SettingsProvider>(context, listen: false).t('product_not_found_short');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось загрузить товар')));
      }
    }
  }

  void _showDeleteSheet(BuildContext context, SettingsProvider settings, ChatOrderProvider chat, InvoiceDraft invoice) {
    if (invoice.items.isEmpty) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: invoice.items.length,
          itemBuilder: (_, i) {
            final item = invoice.items[i];
            return ListTile(
              title: Text(item.name),
              subtitle: Text('${item.qty} ${item.unit}'),
              onTap: () async {
                Navigator.pop(ctx);
                await chat.actionDeleteItem(i, invoiceClearedMessage: settings.t('invoice_cleared_send_new_list'));
                if (mounted) _scrollToEnd();
              },
            );
          },
        ),
      ),
    );
  }
}
