import 'package:flutter/material.dart';
import 'package:mobile/api/api_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UserProvider with ChangeNotifier {
  Map<String, dynamic>? _user;
  final ApiService _apiService = ApiService();
  final _storage = const FlutterSecureStorage();

  bool _isFetching = false;

  Map<String, dynamic>? get user => _user;

  // Hàm tải thông tin user
  Future<void> fetchUserProfile() async {
    // 1. Nếu đang tải rồi thì thôi, không tải nữa
    if (_isFetching) return;

    _isFetching = true;

    try {
      final userProfile = await _apiService.getUserProfile();
      _user = userProfile['user'];
      notifyListeners();
    } catch (e) {
      print("Lỗi tải profile: $e");

      // 2. Chỉ Logout nếu lỗi là do hết hạn Token
      if (e.toString().contains('UNAUTHORIZED') || e.toString().contains('Phiên đăng nhập hết hạn')) {
        await logout();
      }
    } finally {
      // 3. Mở khóa để cho phép tải lần sau
      _isFetching = false;
    }
  }

  Future<void> logout() async {
    _user = null;
    await _storage.delete(key: 'jwt_token');
    notifyListeners();
  }

  // Hàm xóa dữ liệu local
  void clearUser() {
    _user = null;
    notifyListeners();
  }
}