import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider with ChangeNotifier {
  String _name = '';
  String _phone = '';
  String _address = '';

  String get name => _name.isEmpty ? 'Гость' : _name;
  String get phone => _phone.isEmpty ? 'Не указан' : _phone;
  String get address => _address;
  
  // Получить чистый номер для отправки (с +992)
  String get fullPhone => _phone;

  UserProvider() {
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    _name = prefs.getString('user_name') ?? '';
    _phone = prefs.getString('user_phone') ?? '';
    _address = prefs.getString('user_address') ?? '';
    notifyListeners();
  }

  Future<void> updateAddress(String address) async {
    _address = address;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_address', address);
  }

  // Обновить данные (вызывать при Оформлении заказа)
  Future<void> updateUserData({required String name, required String phone, required String address}) async {
    _name = name;
    _phone = phone;
    _address = address;
    
    // Мгновенно обновляем экраны
    notifyListeners();

    // Сохраняем в память телефона
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setString('user_phone', phone);
    await prefs.setString('user_address', address);
  }

  /// Выход: удаляем имя, телефон и адрес из памяти. В оформлении заказа формы имени и телефона будут пустыми.
  Future<void> clearUser() async {
    _name = '';
    _phone = '';
    _address = '';
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_name');
    await prefs.remove('user_phone');
    await prefs.remove('user_address');
  }
}