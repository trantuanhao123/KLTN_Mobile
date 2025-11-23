import 'package:flutter/material.dart';
import 'package:mobile/api/api_service.dart';

class HomeProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<dynamic> _banners = [];
  List<String> _brands = [];
  List<dynamic> _popularCars = [];

  bool _isLoading = false;
  String? _error;

  List<dynamic> get banners => _banners;
  List<String> get brands => _brands;
  List<dynamic> get popularCars => _popularCars;
  bool get isLoading => _isLoading;
  String? get error => _error;

  HomeProvider() {
    // fetchHomeData();
  }

  Future<void> fetchHomeData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiService.getBanners(),
        _apiService.getCars(),
      ]);

      _banners = results[0];

      // Xử lý dữ liệu xe
      final allCars = results[1].map((car) {
        // Map mainImageUrl sang key phổ thông để widget dễ dùng
        car['image'] = car['mainImageUrl'] ?? '';
        return car;
      }).toList();

      // Lấy danh sách thương hiệu (BRAND)
      final brandSet = <String>{};
      for (var car in allCars) {
        // Kiểm tra null safety và ép kiểu String
        if (car['BRAND'] != null) {
          brandSet.add(car['BRAND'].toString());
        }
      }
      _brands = brandSet.toList();

      // Lấy 4 xe đầu tiên làm xe phổ biến
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