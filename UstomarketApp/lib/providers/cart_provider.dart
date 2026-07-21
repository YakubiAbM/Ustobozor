import 'package:flutter/material.dart';
import '../models/cart_item.dart';

class CartProvider with ChangeNotifier {
  Map<String, CartItem> _items = {};
  /// Выбранные для оформления заказа ключи (галочки)
  Set<String> _selectedKeys = {};
  /// Последний добавленный ключ — по умолчанию только он выбран
  String? _lastAddedKey;

  Map<String, CartItem> get items => {..._items};

  Set<String> get selectedKeys => Set.from(_selectedKeys);

  bool isSelected(String key) => _selectedKeys.contains(key);

  /// Инициализация выбора: если ничего не выбрано, выбираем последний добавленный
  void ensureSelectionInit() {
    if (_items.isEmpty) return;
    if (_selectedKeys.isNotEmpty) return;
    _selectedKeys = {_lastAddedKey ?? _items.keys.last};
    notifyListeners();
  }

  void toggleSelection(String key) {
    if (_selectedKeys.contains(key)) {
      _selectedKeys.remove(key);
    } else {
      _selectedKeys.add(key);
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedKeys = Set.from(_items.keys);
    notifyListeners();
  }

  void deselectAll() {
    _selectedKeys = {};
    notifyListeners();
  }

  bool get allSelected => _items.isNotEmpty && _selectedKeys.length == _items.length;

  /// Только выбранные товары для оформления
  Map<String, CartItem> get selectedItems {
    final map = <String, CartItem>{};
    for (final key in _selectedKeys) {
      if (_items.containsKey(key)) map[key] = _items[key]!;
    }
    return map;
  }

  int get itemCount => _items.length;

  int get selectedCount => _selectedKeys.length;

  double get totalAmount {
    var total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.price * cartItem.qty;
    });
    return total;
  }

  /// Сумма только по выбранным
  double get selectedTotalAmount {
    var total = 0.0;
    for (final key in _selectedKeys) {
      final item = _items[key];
      if (item != null) total += item.price * item.qty;
    }
    return total;
  }

  void addItem(CartItem newItem) {
    final uniqueKey = "${newItem.id}_${newItem.name}";

    if (_items.containsKey(uniqueKey)) {
      _items.update(
        uniqueKey,
        (existing) => CartItem(
          id: existing.id,
          name: existing.name,
          qty: existing.qty + newItem.qty,
          price: existing.price,
          image: existing.image,
        ),
      );
    } else {
      _items.putIfAbsent(uniqueKey, () => newItem);
    }
    _lastAddedKey = uniqueKey;
    _selectedKeys = {uniqueKey};
    notifyListeners();
  }

  // Уменьшить кол-во (-)
  void removeSingleItem(String key) {
    if (!_items.containsKey(key)) return;

    if (_items[key]!.qty > 1) {
      _items.update(
        key,
        (existing) => CartItem(
          id: existing.id,
          name: existing.name,
          qty: existing.qty - 1,
          price: existing.price,
          image: existing.image,
        ),
      );
    } else {
      _items.remove(key);
    }
    notifyListeners();
  }
  
  // Увеличить кол-во (+)
  void addSingleItem(String key) {
    if (!_items.containsKey(key)) return;
    
    _items.update(
      key,
      (existing) => CartItem(
        id: existing.id,
        name: existing.name,
        qty: existing.qty + 1,
        price: existing.price,
        image: existing.image,
      ),
    );
    notifyListeners();
  }

  void removeItem(String key) {
    _items.remove(key);
    _selectedKeys.remove(key);
    if (_lastAddedKey == key) _lastAddedKey = _items.isEmpty ? null : _items.keys.last;
    notifyListeners();
  }

  void clear() {
    _items = {};
    _selectedKeys = {};
    _lastAddedKey = null;
    notifyListeners();
  }

  /// Удалить из корзины только выбранные (после успешного заказа)
  void removeSelected() {
    for (final key in _selectedKeys.toList()) {
      _items.remove(key);
      _selectedKeys.remove(key);
    }
    if (_lastAddedKey != null && !_items.containsKey(_lastAddedKey)) {
      _lastAddedKey = _items.isEmpty ? null : _items.keys.last;
    }
    notifyListeners();
  }
}