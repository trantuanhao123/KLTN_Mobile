import 'package:flutter/material.dart';
import 'package:mobile/api/api_service.dart';

class UserProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _user;

  Map<String, dynamic>? get user => _user;

  Future<void> fetchUserProfile() async {
    try {
      // Chỉ fetch khi user chưa có dữ liệu hoặc để làm mới
      final result = await _apiService.getUserProfile();
      _user = result['user'];
      notifyListeners();
    } catch (e) {
      _user = null;
      notifyListeners();
      print("Lỗi khi fetch user profile: $e");
    }
  }
}