import 'package:flutter/foundation.dart';
import '../models/product.dart';

class NavigationProvider with ChangeNotifier {
  static const int tabHome = 0;
  static const int tabMasters = 1;
  static const int tabPublish = 2;
  static const int tabMaterials = 3;
  static const int tabCart = 4;
  static const int tabProfile = 5;

  int _currentIndex = 0;
  Product? _detailProduct;
  String? _selectedBrand;
  int? _lastProfileTapMs;
  bool _requestProfileRefresh = false;
  int? _lastHomeTapMs;
  bool _requestHomeRefresh = false;
  bool _homeDataLoadedOnce = false;

  int get currentIndex => _currentIndex;
  Product? get detailProduct => _detailProduct;
  String? get selectedBrand => _selectedBrand;
  bool get requestProfileRefresh => _requestProfileRefresh;
  bool get requestHomeRefresh => _requestHomeRefresh;
  bool get homeDataLoadedOnce => _homeDataLoadedOnce;

  void setBrandProducts(String? brand) {
    _selectedBrand = brand;
    notifyListeners();
  }

  void clearBrandProducts() {
    if (_selectedBrand != null) {
      _selectedBrand = null;
      notifyListeners();
    }
  }

  void setIndex(int index) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (index == tabProfile && _currentIndex == tabProfile) {
      if (_lastProfileTapMs != null && now - _lastProfileTapMs! < 500) {
        _requestProfileRefresh = true;
      }
      _lastProfileTapMs = now;
    } else {
      _lastProfileTapMs = null;
    }
    if (index == tabHome && _currentIndex == tabHome) {
      if (_lastHomeTapMs != null && now - _lastHomeTapMs! < 500) {
        _requestHomeRefresh = true;
      }
      _lastHomeTapMs = now;
    } else {
      _lastHomeTapMs = null;
    }
    _currentIndex = index;
    notifyListeners();
  }

  void setHomeDataLoadedOnce(bool value) {
    if (_homeDataLoadedOnce != value) {
      _homeDataLoadedOnce = value;
      notifyListeners();
    }
  }

  void clearRequestHomeRefresh() {
    if (_requestHomeRefresh) {
      _requestHomeRefresh = false;
      notifyListeners();
    }
  }

  void clearRequestProfileRefresh() {
    if (_requestProfileRefresh) {
      _requestProfileRefresh = false;
      notifyListeners();
    }
  }

  void showProductDetail(Product product) {
    _detailProduct = product;
    notifyListeners();
  }

  void clearProductDetail() {
    _detailProduct = null;
    notifyListeners();
  }
}
