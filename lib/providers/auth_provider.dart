import 'package:flutter/material.dart';
import 'package:mobile/api/api_service.dart';
import 'package:google_sign_in/google_sign_in.dart'; 
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; 

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  // [MỚI] Khai báo 2 biến còn thiếu
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

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

  // [ĐÃ SỬA] Hàm logout an toàn, không bị crash
  Future<void> logout() async {
    try {
      // Cố gắng báo cho server biết mình đăng xuất
      await _apiService.logout();
    } catch (e) {
      // Nếu server lỗi hoặc mạng lỗi, chỉ in ra và BỎ QUA
      print("Lỗi API logout (không quan trọng): $e");
    } finally {
      // BẮT BUỘC CHẠY: Xóa dữ liệu trong máy để người dùng thoát ra
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        print("Lỗi Google signout: $e");
      }
      await _storage.deleteAll();
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
      await _apiService.loginWithGoogle(idToken);
      _isAuthenticated = true;
      notifyListeners();
    } catch (e) {
      _isAuthenticated = false;
      notifyListeners();
      rethrow;
    }
  }
}