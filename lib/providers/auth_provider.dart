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
      try {
        await _apiService.getUserProfile();
        _isAuthenticated = true;
      } catch (e) {
        if (e.toString().contains('Phiên đăng nhập hết hạn')) {
          await _apiService.deleteToken();
        }
        _isAuthenticated = false;
        print("Lỗi kiểm tra token: $e");
      } finally {
        notifyListeners();
      }
    } else {
      _isAuthenticated = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    await _apiService.login(email, password);
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _apiService.logout();
    } catch (e) {
      print("Lỗi logout API: $e");
    } finally {
      _isAuthenticated = false;
      notifyListeners();
    }
  }

  void forceLogin() {
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<void> loginWithGoogle(String idToken) async {
    try {
      // Gọi API Service để gửi token lên Backend
      await _apiService.loginWithGoogle(idToken);

      // Nếu thành công, set trạng thái đăng nhập = true
      _isAuthenticated = true;
      notifyListeners();
    } catch (e) {
      _isAuthenticated = false;
      notifyListeners();
      rethrow; // Ném lỗi ra để LoginScreen hiển thị thông báo
    }
  }
}