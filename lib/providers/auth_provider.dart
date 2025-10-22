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
      // Có thể thêm bước gọi API /profile để xác thực token thực sự còn hiệu lực
      // Nếu API /profile trả lỗi 401/403 thì gọi _apiService.deleteToken()
      try {
        await _apiService.getUserProfile(); // Thử gọi API cần token
        _isAuthenticated = true;
      } catch (e) {
        // Nếu lỗi do token không hợp lệ (ví dụ Exception chứa 'Phiên đăng nhập hết hạn')
        if (e.toString().contains('Phiên đăng nhập hết hạn')) {
          await _apiService.deleteToken(); // Xóa token cũ
        }
        _isAuthenticated = false; // Đặt là false nếu token không hợp lệ
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
    // Hàm login trong ApiService đã tự động lưu token nếu thành công
    await _apiService.login(email, password);
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<void> logout() async {
    await _apiService.logout(); // Chỉ xóa token local
    _isAuthenticated = false;
    notifyListeners();
  }

  /// Dùng sau khi xác thực OTP đăng ký thành công (ApiService đã lưu token)
  /// Hàm này chỉ cập nhật trạng thái UI, không gọi API login lại.
  void forceLogin() {
    _isAuthenticated = true;
    notifyListeners();
  }
}