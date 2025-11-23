import 'package:flutter/material.dart';
import 'package:mobile/api/api_service.dart';

class CarProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<dynamic> _allCars = [];
  List<dynamic> _categories = [];
  List<dynamic> _branches = [];
  List<dynamic> _filteredCars = [];
  bool _isLoading = false;
  String? _error;

  List<dynamic> get allCars => _allCars;
  List<dynamic> get filteredCars => _filteredCars;
  List<dynamic> get categories => _categories;
  List<dynamic> get branches => _branches;
  bool get isLoading => _isLoading;
  String? get error => _error;

  CarProvider() {
    // fetchAllData();
  }

  Future<void> fetchAllData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _apiService.getCars(),
        _apiService.getCategories(),
        _apiService.getBranches(),
      ]);

      // Xử lý chuẩn hóa dữ liệu xe trước khi lưu
      _allCars = results[0].map((car) {
        // Backend trả về 'mainImageUrl', ta map nó sang 'image' hoặc 'thumbnail' để UI dùng
        car['image'] = car['mainImageUrl'] ?? car['IMAGE_URL'] ?? '';
        car['thumbnail'] = car['mainImageUrl'] ?? '';
        return car;
      }).toList();

      _categories = results[1];
      _branches = results[2];
      _filteredCars = List.from(_allCars);
    } catch (e) {
      _error = "Lỗi tải dữ liệu: ${e.toString()}";
      print(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void applyFilters({
    String? searchTerm,
    String? brandName,
    int? categoryId,
    int? branchId,
    RangeValues? priceRange,
  }) {
    List<dynamic> tempCars = List.from(_allCars);

    if (searchTerm != null && searchTerm.isNotEmpty) {
      final lowerCaseSearch = searchTerm.toLowerCase();
      tempCars = tempCars.where((car) {
        final brand = (car['BRAND'] as String?)?.toLowerCase() ?? '';
        final model = (car['MODEL'] as String?)?.toLowerCase() ?? '';
        final licensePlate = (car['LICENSE_PLATE'] as String?)?.toLowerCase() ?? '';
        return brand.contains(lowerCaseSearch) ||
            model.contains(lowerCaseSearch) ||
            licensePlate.contains(lowerCaseSearch);
      }).toList();
    }

    if (brandName != null && brandName.isNotEmpty) {
      final lowerCaseBrand = brandName.toLowerCase();
      tempCars = tempCars.where((car) {
        final brand = (car['BRAND'] as String?)?.toLowerCase() ?? '';
        return brand == lowerCaseBrand;
      }).toList();
    }

    if (categoryId != null) {
      // Backend trả về CATEGORY_ID (viết hoa)
      tempCars = tempCars.where((car) => car['CATEGORY_ID'] == categoryId).toList();
    }

    if (branchId != null) {
      // Backend trả về BRANCH_ID (viết hoa)
      tempCars = tempCars.where((car) => car['BRANCH_ID'] == branchId).toList();
    }

    if (priceRange != null) {
      tempCars = tempCars.where((car) {
        // Backend trả về PRICE_PER_DAY, ép kiểu an toàn
        final price = double.tryParse(car['PRICE_PER_DAY'].toString()) ?? 0.0;
        return price >= priceRange.start && price <= priceRange.end;
      }).toList();
    }

    _filteredCars = tempCars;
    notifyListeners();
  }
}