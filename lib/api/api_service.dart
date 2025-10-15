import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  final String _baseUrl = "http://192.168.1.8:8080"; //ip nhà
  final _storage = const FlutterSecureStorage();

  /// Lấy token từ bộ nhớ an toàn
  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  /// Lưu token vào bộ nhớ an toàn
  Future<void> _saveToken(String token) async {
    await _storage.write(key: 'jwt_token', value: token);
  }

  /// Xóa token (dùng cho đăng xuất)
  Future<void> deleteToken() async {
    await _storage.delete(key: 'jwt_token');
  }

  // Lấy header kèm token JWT nếu có
  Future<Map<String, String>> _getHeaders() async {
    String? token = await getToken();
    if (token != null) {
      return {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      };
    }
    return {
      'Content-Type': 'application/json; charset=UTF-8',
    };
  }

  // Hàm Đăng nhập
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/user/login'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode(<String, String>{
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['token'] != null) {
        await _saveToken(data['token']);
      }
      return data;
    } else {
      throw Exception('Đăng nhập thất bại');
    }
  }

  Future<Map<String, dynamic>> register({
    required String fullname,
    required String email,
    required String phone,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/user/register'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode(<String, String>{
        'fullname': fullname,
        'email': email,
        'phone': phone,
        'password': password,
      }),
    );

    if (response.statusCode == 201) { //trả về 201 khi tạo thành công
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['error'] ?? 'Đăng ký thất bại');
    }
  }

  // Hàm Đăng xuất
  Future<void> logout() async {
    await deleteToken();
  }

  //HÀM GỬI OTP ĐẶT LẠI MẬT KHẨU
  Future<void> requestPasswordReset(String email) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/request-reset'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Yêu cầu thất bại');
    }
    // Nếu thành công, không cần trả về gì, chỉ cần không có lỗi
  }

  //HÀM XÁC THỰC OTP VÀ ĐẶT LẠI MẬT KHẨU MỚI
  Future<void> verifyOtpAndResetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/verify-otp'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({
        'email': email,
        'otp': otp,
        'newPassword': newPassword,
      }),
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Xác thực thất bại');
    }
  }

  // Lấy thông tin người dùng (yêu cầu xác thực)
  Future<Map<String, dynamic>> getUserProfile() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/user/profile'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Không thể lấy thông tin người dùng');
    }
  }

  // Lấy danh sách xe
  Future<List<dynamic>> getCars() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/car'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Không thể tải danh sách xe');
    }
  }
}