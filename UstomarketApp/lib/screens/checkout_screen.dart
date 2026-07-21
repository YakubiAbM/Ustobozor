import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../api_client.dart';
import '../providers/cart_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/user_provider.dart';
import '../providers/master_auth_provider.dart';
import 'order_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _commentController = TextEditingController();
  bool _isLoading = false;
  bool _isDelivery = true; // true = Доставка, false = Самовывоз
  bool _isCash = true; // true = Наличными, false = Картой

  @override
  void initState() {
    super.initState();
    // Подставляем сохранённые данные: из UserProvider или, если мастер авторизован и юзер пустой — из данных мастера
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<UserProvider>(context, listen: false);
      final master = Provider.of<MasterAuthProvider>(context, listen: false);
      String name = user.name == 'Гость' ? '' : user.name;
      String phone = user.phone == 'Не указан' ? '' : user.phone.replaceAll('+992', '').trim();
      if (name.isEmpty && master.isLoggedIn && master.masterName.isNotEmpty) name = master.masterName;
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
    final cart = Provider.of<CartProvider>(context, listen: false);
    final user = Provider.of<UserProvider>(context, listen: false);

    String phone = _phoneController.text.trim().replaceAll(RegExp(r'[^\d]'), '');
    if (!phone.startsWith('992')) phone = '992$phone';
    final fullPhone = '+$phone';

    // Оформляем только выбранные в корзине товары
    final selected = cart.selectedItems;
    if (selected.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Выберите хотя бы один товар для оформления')));
      setState(() => _isLoading = false);
      return;
    }

    final itemsPayload = selected.values.map((item) {
      final productId = int.tryParse(item.id) ?? 0;
      return <String, dynamic>{
        'id': productId,
        'product_id': productId,
        'name': item.name ?? '',
        'qty': item.qty,
        'price': item.price.toDouble(),
        'image': item.image ?? '',
      };
    }).toList();

    // Все поля обязательны для API (OrderCreate): не null, ключи точно client_name, client_phone, client_address, total_price, items
    final total = cart.selectedTotalAmount.toDouble();
    final orderData = <String, dynamic>{
      'client_name': _nameController.text.trim(),
      'client_phone': fullPhone,
      'client_address': _isDelivery ? _addressController.text.trim() : '',
      'total_price': total.isNaN || total.isNegative ? 0.0 : total,
      'items': itemsPayload,
      'payment_type': _isCash ? 'cash' : 'card',
    };

    try {
      final response = await apiPost('/orders', body: orderData);

      if (mounted) {
        if (response.statusCode == 200) {
          // После успешного заказа сохраняем имя и телефон в память (для следующих заказов и профиля)
          await user.updateUserData(
            name: _nameController.text.trim(),
            phone: fullPhone,
            address: _addressController.text.trim(),
          );
          cart.removeSelected();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const OrderSuccessScreen()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: ${response.body}')));
        }
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        if (msg.isEmpty) msg = 'Ошибка соединения';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final cart = Provider.of<CartProvider>(context);
    final isDark = theme.brightness == Brightness.dark;
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: isDark ? AppColors.inputBg : AppColors.inputBgLight,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(settings.t('order_placement'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: theme.scaffoldBackgroundColor,
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
                      settings.t('contact_data'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: inputDecoration.copyWith(hintText: settings.t('your_name')),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Введите имя' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: inputDecoration.copyWith(
                        hintText: 'Введите номер ',
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 16, top: 14, bottom: 14),
                          child: Text('+992 ', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Введите телефон' : null,
                    ),
                    const SizedBox(height: 28),
                    Text(
                      settings.t('order_details'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(settings.t('delivery_method'), style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface)),
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
                    Text(settings.t('payment_method'), style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface)),
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
                    Text(settings.t('delivery_address'), style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _addressController,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: inputDecoration.copyWith(hintText: settings.t('address_hint')),
                      validator: (val) {
                        if (_isDelivery && (val == null || val.trim().isEmpty)) return 'Введите адрес';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(settings.t('comment'), style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface)),
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
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, -4))],
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
                          style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withOpacity(0.8)),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${cart.totalAmount.toInt()} ',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const Text('смн', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.accent)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : Text(settings.t('place_order'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({required this.label, required this.selected, required this.onTap});

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
              color: selected ? Colors.black : theme.colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
        ),
      ),
    );
  }
}
