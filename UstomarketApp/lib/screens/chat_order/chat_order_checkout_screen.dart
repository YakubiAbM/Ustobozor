import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants.dart';
import '../../providers/chat_order_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/master_auth_provider.dart';
import '../../widgets/app_cached_image.dart';
import 'models/invoice_models.dart';

/// Экран оформления заказа из чата — те же поля и кнопки, что в корзине.
/// После появления накладной в чате нажимают «Подтвердить» → открывается этот экран.
class ChatOrderCheckoutScreen extends StatefulWidget {
  final String sessionId;
  final InvoiceDraft invoice;

  const ChatOrderCheckoutScreen({
    super.key,
    required this.sessionId,
    required this.invoice,
  });

  @override
  State<ChatOrderCheckoutScreen> createState() =>
      _ChatOrderCheckoutScreenState();
}

class _ChatOrderCheckoutScreenState extends State<ChatOrderCheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _commentController = TextEditingController();
  bool _isLoading = false;
  bool _isDelivery = true;
  bool _isCash = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<UserProvider>(context, listen: false);
      final master = Provider.of<MasterAuthProvider>(context, listen: false);
      String name = user.name == 'Гость' ? '' : user.name;
      String phone = user.phone == 'Не указан'
          ? ''
          : user.phone.replaceAll('+992', '').trim();
      if (name.isEmpty && master.isLoggedIn && master.masterName.isNotEmpty)
        name = master.masterName;
      if (phone.isEmpty && master.isLoggedIn && master.masterPhone.isNotEmpty) {
        phone = master.masterPhone.replaceAll(RegExp(r'[^\d]'), '');
        if (phone.startsWith('992')) phone = phone.substring(3);
      }
      _nameController.text = name;
      _phoneController.text = phone;
      _addressController.text = user.address;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final chat = Provider.of<ChatOrderProvider>(context, listen: false);
    final user = Provider.of<UserProvider>(context, listen: false);

    String phone = _phoneController.text.trim().replaceAll(
      RegExp(r'[^\d]'),
      '',
    );
    if (!phone.startsWith('992')) phone = '992$phone';
    final fullPhone = '+$phone';

    final ok = await chat.submitOrderFromCheckout(
      clientName: _nameController.text.trim(),
      clientPhone: fullPhone,
      clientAddress: _addressController.text.trim(),
      isDelivery: _isDelivery,
      isCash: _isCash,
      comment: _commentController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      await user.updateUserData(
        name: _nameController.text.trim(),
        phone: fullPhone,
        address: _addressController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(chat.error ?? 'Ошибка оформления')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: isDark ? AppColors.inputBg : AppColors.inputBgLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          settings.t('order_placement'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.t('order_details'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...widget.invoice.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _InvoiceItemCard(
                          item: item,
                          currency: widget.invoice.currency,
                          theme: theme,
                          isDark: isDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      settings.t('contact_data'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: inputDecoration.copyWith(
                        hintText: settings.t('your_name'),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty)
                          ? settings.t('enter_name')
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: inputDecoration.copyWith(
                        hintText: settings.t('enter_phone'),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(
                            left: 16,
                            top: 14,
                            bottom: 14,
                          ),
                          child: Text(
                            '+992 ',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (val) => (val == null || val.trim().isEmpty)
                          ? settings.t('enter_phone')
                          : null,
                    ),
                    const SizedBox(height: 28),
                    Text(
                      settings.t('delivery_method'),
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _SegmentButton(
                            label: settings.t('delivery'),
                            selected: _isDelivery,
                            onTap: () => setState(() => _isDelivery = true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SegmentButton(
                            label: settings.t('pickup'),
                            selected: !_isDelivery,
                            onTap: () => setState(() => _isDelivery = false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      settings.t('payment_method'),
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _SegmentButton(
                            label: settings.t('pay_cash'),
                            selected: _isCash,
                            onTap: () => setState(() => _isCash = true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SegmentButton(
                            label: settings.t('pay_card'),
                            selected: !_isCash,
                            onTap: () => setState(() => _isCash = false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      settings.t('delivery_address'),
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _addressController,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: inputDecoration.copyWith(
                        hintText: settings.t('address_hint'),
                      ),
                      validator: (val) {
                        if (_isDelivery && (val == null || val.trim().isEmpty))
                          return settings.t('enter_address');
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      settings.t('comment'),
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _commentController,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: inputDecoration.copyWith(hintText: ''),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          settings.t('total'),
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${widget.invoice.totalPrice.toInt()} ',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              '${widget.invoice.currency} ',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.accentContrastText,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Text(
                              settings.t('place_order'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                    ),
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

class _InvoiceItemCard extends StatelessWidget {
  final InvoiceItem item;
  final String currency;
  final ThemeData theme;
  final bool isDark;

  const _InvoiceItemCard({
    required this.item,
    required this.currency,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
            child: item.image.isEmpty
                ? const Icon(Icons.image_outlined, color: Colors.grey)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AppCachedImage(
                      imagePath: item.image,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(12),
                      fallbackIcon: Icons.image_not_supported,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.price.toInt()} $currency',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${item.qty} ${item.unit}',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                    Text(
                      '${item.lineTotal.toInt()} $currency',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? AppColors.accent : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected
                  ? Colors.black
                  : theme.colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
        ),
      ),
    );
  }
}
