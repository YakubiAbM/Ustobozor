import 'package:flutter/material.dart';

import '../screens/chat_order/models/chat_message_model.dart';
import '../screens/chat_order/models/invoice_models.dart';
import '../screens/chat_order/models/pick_models.dart';
import '../screens/chat_order/data/chat_order_api_client.dart';

enum ChatOrderMode {
  idle,
  awaitingPick,
  awaitingAddText,
  awaitingEditQtySelect,
  awaitingEditQtyValue,
  awaitingDeleteSelect,
  awaitingName,
  awaitingPhone,
  awaitingAddress,
  done,
}

class ChatOrderProvider with ChangeNotifier {
  String? _sessionId;
  final List<ChatMessageModel> _messages = [];
  bool _isLoading = false;
  ChatOrderMode _mode = ChatOrderMode.idle;
  String? _submitName;
  String? _submitPhone;
  String? _submitAddress;
  int? _editQtyItemIndex;
  int? _orderCreatedId;
  String? _orderCreatedStatus;
  String? _error;

  String? get sessionId => _sessionId;
  List<ChatMessageModel> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  ChatOrderMode get mode => _mode;
  int? get orderCreatedId => _orderCreatedId;
  String? get orderCreatedStatus => _orderCreatedStatus;
  String? get error => _error;

  Future<void> ensureSession() async {
    if (_sessionId != null && _sessionId!.isNotEmpty) return;
    _error = null;
    try {
      _sessionId = await ChatOrderApiClient.createSession();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Добавляет приветствие и инструкцию в начало чата, если сообщений ещё нет.
  void setWelcomeMessages(String welcome, String instruction) {
    if (_messages.isNotEmpty) return;
    _messages.add(ChatMessageModel.systemText(welcome));
    _messages.add(ChatMessageModel.systemText(instruction));
    notifyListeners();
  }

  Future<void> sendMessage(String text, {String? productNotFoundMessage}) async {
    if (text.trim().isEmpty || _sessionId == null) return;
    final trimmed = text.trim();
    _messages.add(ChatMessageModel.userText(trimmed));
    _messages.add(ChatMessageModel.loading());
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ChatOrderApiClient.sendMessage(_sessionId!, trimmed);
      _messages.removeWhere((m) => m.type == ChatMessageType.loading);
      _handleChatResponse(response, productNotFoundMessage: productNotFoundMessage);
    } catch (e) {
      _messages.removeWhere((m) => m.type == ChatMessageType.loading);
      _messages.add(ChatMessageModel.systemText('Сервер недоступен. Попробуйте позже.'));
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return;
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Проверяет, совпадает ли накладная с последней в чате (то же кол-во позиций и сумма).
  bool _isSameAsLastInvoice(InvoiceDraft draft) {
    final last = lastInvoice;
    if (last == null) return false;
    if (last.items.length != draft.items.length) return false;
    if ((last.totalPrice - draft.totalPrice).abs() > 0.01) return false;
    return true;
  }

  void _handleChatResponse(ChatResponse response, {
    String? duplicateInvoiceMessage,
    String? invoiceClearedMessage,
    String? productNotFoundMessage,
  }) {
    if (response.type == 'invoice' && response.draft != null) {
      final draft = response.draft!;
      if (draft.items.isEmpty) {
        _messages.add(ChatMessageModel.systemText(
          invoiceClearedMessage ?? 'Накладная очищена. Отправьте новый список товаров.',
        ));
      } else if (_isSameAsLastInvoice(draft)) {
        // Та же накладная = в поиске ничего не нашли, товар для клиента не создаём — просим написать заново
        _messages.add(ChatMessageModel.systemText(
          duplicateInvoiceMessage ?? productNotFoundMessage ?? 'Товар не найден. Напишите заново.',
        ));
      } else {
        _messages.add(ChatMessageModel.systemInvoice(draft));
      }
      _mode = ChatOrderMode.idle;
    } else if (response.type == 'pick' && response.pickPayload != null) {
      _messages.add(ChatMessageModel.systemPick(response.pickPayload!));
      _mode = ChatOrderMode.awaitingPick;
    } else if (response.type == 'product_not_found') {
      _messages.add(ChatMessageModel.systemText(
        productNotFoundMessage ?? 'Товар не найден. Напишите заново.',
      ));
      _mode = ChatOrderMode.idle;
    } else if (response.type == 'need_details' || response.type == 'text') {
      final text = response.message?.trim() ?? '';
      final showProductNotFound = text.isEmpty ||
          text.toLowerCase().contains('не найден') ||
          text.toLowerCase().contains('нет в наличии') ||
          text.toLowerCase().contains('нет такого');
      _messages.add(ChatMessageModel.systemText(
        showProductNotFound && productNotFoundMessage != null
            ? productNotFoundMessage!
            : (text.isNotEmpty ? text : 'Уточните, пожалуйста.'),
      ));
      _mode = ChatOrderMode.idle;
    } else {
      final text = response.message?.trim() ?? '';
      final showProductNotFound = text.isEmpty ||
          text.toLowerCase().contains('не найден') ||
          text.toLowerCase().contains('нет в наличии') ||
          text.toLowerCase().contains('нет такого');
      _messages.add(ChatMessageModel.systemText(
        showProductNotFound && productNotFoundMessage != null
            ? productNotFoundMessage!
            : (text.isNotEmpty ? text : 'Уточните.'),
      ));
      _mode = ChatOrderMode.idle;
    }
  }

  Future<void> pickOption(int itemIndex, int productId) async {
    if (_sessionId == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await ChatOrderApiClient.pick(_sessionId!, itemIndex, productId);
      _handleChatResponse(response);
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  /// [productNotFoundMessage] — текст, если товар не найден (та же накладная или type=product_not_found).
  Future<void> actionAddMore(String text, {String? productNotFoundMessage}) async {
    if (_sessionId == null || text.trim().isEmpty) return;
    _messages.add(ChatMessageModel.userText(text.trim()));
    _messages.add(ChatMessageModel.loading());
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await ChatOrderApiClient.action(
        _sessionId!,
        'add_more',
        {'text': text.trim()},
      );
      _messages.removeWhere((m) => m.type == ChatMessageType.loading);
      _handleChatResponse(response, duplicateInvoiceMessage: productNotFoundMessage, productNotFoundMessage: productNotFoundMessage);
    } catch (e) {
      _messages.removeWhere((m) => m.type == ChatMessageType.loading);
      _messages.add(ChatMessageModel.systemText('Ошибка. Попробуйте снова.'));
      _error = e.toString();
    }
    _mode = ChatOrderMode.idle;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> actionEditQty(int itemIndex, double qty) async {
    if (_sessionId == null || qty <= 0) return;
    _messages.add(ChatMessageModel.loading());
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await ChatOrderApiClient.action(
        _sessionId!,
        'edit_qty',
        {'item_index': itemIndex, 'qty': qty},
      );
      _messages.removeWhere((m) => m.type == ChatMessageType.loading);
      _handleChatResponse(response);
    } catch (e) {
      _messages.removeWhere((m) => m.type == ChatMessageType.loading);
      _messages.add(ChatMessageModel.systemText('Ошибка. Попробуйте снова.'));
      _error = e.toString();
    }
    _editQtyItemIndex = null;
    _mode = ChatOrderMode.idle;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> actionDeleteItem(int itemIndex, {String? invoiceClearedMessage}) async {
    if (_sessionId == null) return;
    _messages.add(ChatMessageModel.loading());
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await ChatOrderApiClient.action(
        _sessionId!,
        'delete_item',
        {'item_index': itemIndex},
      );
      _messages.removeWhere((m) => m.type == ChatMessageType.loading);
      _handleChatResponse(response, invoiceClearedMessage: invoiceClearedMessage);
    } catch (e) {
      _messages.removeWhere((m) => m.type == ChatMessageType.loading);
      _messages.add(ChatMessageModel.systemText('Ошибка. Попробуйте снова.'));
      _error = e.toString();
    }
    _mode = ChatOrderMode.idle;
    _isLoading = false;
    notifyListeners();
  }

  /// Включает режим «добавить товар». Сообщение показывается в чате (передаётся с переводами).
  void setAwaitingAddText(String promptMessage) {
    _mode = ChatOrderMode.awaitingAddText;
    _messages.add(ChatMessageModel.systemText(promptMessage));
    notifyListeners();
  }

  void setAwaitingEditQtySelect() {
    _mode = ChatOrderMode.awaitingEditQtySelect;
    notifyListeners();
  }

  void setEditQtyItemIndex(int index) {
    _editQtyItemIndex = index;
    _mode = ChatOrderMode.awaitingEditQtyValue;
    notifyListeners();
  }

  void setAwaitingDeleteSelect() {
    _mode = ChatOrderMode.awaitingDeleteSelect;
    notifyListeners();
  }

  /// Оформление заказа из экрана оформления (как в корзине). Телефон приводится к +992...
  Future<bool> submitOrderFromCheckout({
    required String clientName,
    required String clientPhone,
    required String clientAddress,
    required bool isDelivery,
    required bool isCash,
    String? comment,
  }) async {
    if (_sessionId == null) return false;
    String phone = clientPhone.replaceAll(RegExp(r'[^\d]'), '');
    if (phone.length < 8) return false;
    if (!phone.startsWith('992')) phone = '992$phone';
    final fullPhone = '+$phone';
    if (isDelivery && clientAddress.trim().length < 5) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await ChatOrderApiClient.submit(
        _sessionId!,
        clientName: clientName.trim(),
        clientPhone: fullPhone,
        clientAddress: clientAddress.trim(),
        isDelivery: isDelivery,
        isCash: isCash,
        comment: comment,
      );
      _orderCreatedId = response.orderId;
      _orderCreatedStatus = response.status;
      _mode = ChatOrderMode.done;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      String err = e.toString();
      if (err.startsWith('Exception:')) err = err.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
      _error = err.isEmpty ? 'Ошибка оформления заказа' : err;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clear() {
    _sessionId = null;
    _messages.clear();
    _isLoading = false;
    _mode = ChatOrderMode.idle;
    _submitName = null;
    _submitPhone = null;
    _submitAddress = null;
    _editQtyItemIndex = null;
    _orderCreatedId = null;
    _orderCreatedStatus = null;
    _error = null;
    notifyListeners();
  }

  InvoiceDraft? get lastInvoice {
    for (var i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].type == ChatMessageType.invoice && _messages[i].invoice != null) {
        return _messages[i].invoice;
      }
    }
    return null;
  }
}
