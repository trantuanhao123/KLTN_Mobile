import 'package:flutter/material.dart';
import 'package:mobile/api/api_service.dart';

class UserProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _user;

  Map<String, dynamic>? get user => _user;

  // Xóa hàm khởi tạo để tránh gọi API liên tục, chúng ta sẽ gọi thủ công
  // UserProvider() {
  //   fetchUserProfile();
  // }

  Future<void> fetchUserProfile() async {
    try {
      // Chỉ fetch khi user chưa có dữ liệu hoặc để làm mới
      final result = await _apiService.getUserProfile();
      _user = result['user']; // Dữ liệu user nằm trong key 'user'
      notifyListeners();
    } catch (e) {
      // Ở đây bạn có thể xử lý lỗi, ví dụ: clear user data nếu token hết hạn
      _user = null;
      notifyListeners();
      print("Lỗi khi fetch user profile: $e");
    }
  }
}