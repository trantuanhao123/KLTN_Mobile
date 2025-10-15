import 'package:flutter/material.dart';
import 'package:mobile/api/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;

  AuthProvider() {
    _checkToken();
  }

  // Kiểm tra token khi khởi động app
  Future<void> _checkToken() async {
    String? token = await _apiService.getToken();
    if (token != null) {
      _isAuthenticated = true;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    await _apiService.login(email, password);
    _isAuthenticated = true;
    notifyListeners(); // Thông báo cho các widget đang lắng nghe về sự thay đổi
  }

  Future<void> logout() async {
    await _apiService.logout();
    _isAuthenticated = false;
    notifyListeners(); // Thông báo cho các widget đang lắng nghe
  }
}