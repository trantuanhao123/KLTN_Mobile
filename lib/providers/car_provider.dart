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

      // Xử lý chuẩn hóa dữ liệu xe
      _allCars = results[0].map((car) {
        // Backend có thể trả về 'mainImageUrl', 'IMAGE_URL' hoặc 'imageUrl'
        car['image'] = car['mainImageUrl'] ?? car['IMAGE_URL'] ?? car['imageUrl'] ?? '';
        car['thumbnail'] = car['mainImageUrl'] ?? car['imageUrl'] ?? '';
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

  // Helper để lấy giá trị từ key thường hoặc key hoa
  dynamic _getValue(Map<dynamic, dynamic> map, String key) {
    return map[key] ?? map[key.toUpperCase()] ?? map[key.toLowerCase()];
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
        final brand = (_getValue(car, 'brand') as String?)?.toLowerCase() ?? '';
        final model = (_getValue(car, 'model') as String?)?.toLowerCase() ?? '';
        final licensePlate = (_getValue(car, 'license_plate') as String?)?.toLowerCase() ?? ''; // licensePlate hoặc LICENSE_PLATE
        return brand.contains(lowerCaseSearch) ||
            model.contains(lowerCaseSearch) ||
            licensePlate.contains(lowerCaseSearch);
      }).toList();
    }

    if (brandName != null && brandName.isNotEmpty) {
      final lowerCaseBrand = brandName.toLowerCase();
      tempCars = tempCars.where((car) {
        final brand = (_getValue(car, 'brand') as String?)?.toLowerCase() ?? '';
        return brand == lowerCaseBrand;
      }).toList();
    }

    if (categoryId != null) {
      // Dùng _getValue để tìm cả 'categoryId' hoặc 'CATEGORY_ID'
      tempCars = tempCars.where((car) {
        final cId = _getValue(car, 'category_id');
        return cId == categoryId;
      }).toList();
    }

    if (branchId != null) {
      tempCars = tempCars.where((car) {
        final bId = _getValue(car, 'branch_id');
        return bId == branchId;
      }).toList();
    }

    if (priceRange != null) {
      tempCars = tempCars.where((car) {
        final priceVal = _getValue(car, 'price_per_day') ?? _getValue(car, 'pricePerDay');
        final price = double.tryParse(priceVal.toString()) ?? 0.0;
        return price >= priceRange.start && price <= priceRange.end;
      }).toList();
    }

    _filteredCars = tempCars;
    notifyListeners();
  }
}