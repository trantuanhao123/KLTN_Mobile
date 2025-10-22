// lib/providers/car_provider.dart
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

  // Lấy dữ liệu thô để filter ở frontend
  List<dynamic> get allCars => _allCars;
  List<dynamic> get filteredCars => _filteredCars;
  List<dynamic> get categories => _categories;
  List<dynamic> get branches => _branches;
  bool get isLoading => _isLoading;
  String? get error => _error;

  CarProvider() {
    fetchAllData();
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
      _allCars = results[0];
      _categories = results[1];
      _branches = results[2];
      _filteredCars = List.from(_allCars); // Khởi tạo ban đầu
    } catch (e) {
      _error = "Lỗi tải dữ liệu: ${e.toString()}";
      print(_error); // In lỗi ra console để debug
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Hàm áp dụng bộ lọc
  void applyFilters({
    String? searchTerm,
    String? brandName, // Bộ lọc theo tên thương hiệu
    int? categoryId,
    int? branchId,
    RangeValues? priceRange,
  }) {
    List<dynamic> tempCars = List.from(_allCars);

    // Lọc theo searchTerm (tìm kiếm trong tên, hãng, model, biển số)
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

    // Lọc theo brandName (nếu được cung cấp)
    if (brandName != null && brandName.isNotEmpty) {
      final lowerCaseBrand = brandName.toLowerCase();
      tempCars = tempCars.where((car) {
        final brand = (car['BRAND'] as String?)?.toLowerCase() ?? '';
        return brand == lowerCaseBrand; // So sánh chính xác tên thương hiệu
      }).toList();
      // Ghi chú: Có thể bạn muốn reset các filter khác khi lọc theo brand từ trang chủ
      // categoryId = null;
      // branchId = null;
      // priceRange = null;
    }

    // Lọc theo categoryId
    if (categoryId != null) {
      tempCars = tempCars.where((car) => car['CATEGORY_ID'] == categoryId).toList();
    }

    // Lọc theo branchId
    if (branchId != null) {
      tempCars = tempCars.where((car) => car['BRANCH_ID'] == branchId).toList();
    }

    // Lọc theo khoảng giá
    if (priceRange != null) {
      tempCars = tempCars.where((car) {
        final price = double.tryParse(car['PRICE_PER_DAY'].toString()) ?? 0.0;
        return price >= priceRange.start && price <= priceRange.end;
      }).toList();
    }

    _filteredCars = tempCars;
    notifyListeners(); // Thông báo cho các widget đang lắng nghe về sự thay đổi
  }
}