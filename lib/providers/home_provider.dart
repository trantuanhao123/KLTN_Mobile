import 'package:flutter/material.dart';
import 'package:mobile/api/api_service.dart';

class HomeProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<dynamic> _banners = [];
  List<String> _brands = [];
  List<dynamic> _popularCars = [];

  bool _isLoading = false;
  String? _error;

  // Getters
  List<dynamic> get banners => _banners;
  List<String> get brands => _brands;
  List<dynamic> get popularCars => _popularCars;
  bool get isLoading => _isLoading;
  String? get error => _error;

  HomeProvider() {
    fetchHomeData();
  }

  Future<void> fetchHomeData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Gọi đồng thời cả hai API
      final results = await Future.wait([
        _apiService.getBanners(),
        _apiService.getCars(),
      ]);

      _banners = results[0];
      final allCars = results[1];

      // Xử lý danh sách thương hiệu (brands)
      // Lấy danh sách brand từ tất cả xe, sau đó dùng Set để loại bỏ các brand trùng lặp
      final brandSet = <String>{};
      for (var car in allCars) {
        if (car['BRAND'] != null) {
          brandSet.add(car['BRAND']);
        }
      }
      _brands = brandSet.toList();

      // Tạm thời lấy 4 xe đầu tiên làm xe phổ biến
      _popularCars = allCars.take(4).toList();

    } catch (e) {
      _error = "Lỗi tải dữ liệu trang chủ: ${e.toString()}";
      print(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}