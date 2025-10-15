import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';

class ApiService {
  // URL cho API
  static const String _baseUrl = "http://192.168.1.10:8080";
  static const int _timeoutSeconds = 30; // Thời gian chờ tối đa cho yêu cầu HTTP

  // Getter để truy cập an toàn vào baseUrl
  String get baseUrl => _baseUrl;

  final _storage = const FlutterSecureStorage();

  // Hàm kiểm tra định dạng email
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  /// Lấy token JWT từ bộ nhớ an toàn.
  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  /// Lưu token JWT vào bộ nhớ an toàn.
  Future<void> _saveToken(String token) async {
    if (token.isEmpty) throw Exception('Token không hợp lệ');
    await _storage.write(key: 'jwt_token', value: token);
  }

  /// Xóa token JWT khỏi bộ nhớ an toàn.
  Future<void> deleteToken() async {
    await _storage.delete(key: 'jwt_token');
  }

  /// Tạo headers cho các yêu cầu cần xác thực.
  Future<Map<String, String>> _getHeaders() async {
    String? token = await getToken();
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Đăng nhập người dùng với email và mật khẩu, lưu token nếu thành công.
  Future<Map<String, dynamic>> login(String email, String password) async {
    if (!_isValidEmail(email)) throw Exception('Email không hợp lệ');
    if (password.isEmpty) throw Exception('Mật khẩu không được để trống');

    try {
      final response = await http
          .post(
        Uri.parse('$baseUrl/user/login'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'email': email, 'password': password}),
      )
          .timeout(Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['token'] != null) await _saveToken(data['token']);
        return data;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Đăng nhập thất bại');
      }
    } catch (e) {
      throw Exception('Lỗi kết nối: ${e.toString()}');
    }
  }

  /// Đăng ký người dùng mới với các thông tin được cung cấp.
  Future<Map<String, dynamic>> register({
    required String fullname,
    required String email,
    required String phone,
    required String password,
  }) async {
    if (fullname.isEmpty) throw Exception('Tên không được để trống');
    if (!_isValidEmail(email)) throw Exception('Email không hợp lệ');
    if (phone.isEmpty) throw Exception('Số điện thoại không được để trống');
    if (password.isEmpty) throw Exception('Mật khẩu không được để trống');

    try {
      final response = await http
          .post(
        Uri.parse('$baseUrl/user/register'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(<String, String>{
          'fullname': fullname,
          'email': email,
          'phone': phone,
          'password': password,
        }),
      )
          .timeout(Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Đăng ký thất bại');
      }
    } catch (e) {
      throw Exception('Lỗi kết nối: ${e.toString()}');
    }
  }

  /// Đăng xuất người dùng bằng cách xóa token.
  Future<void> logout() async {
    await deleteToken();
  }

  /// Lấy thông tin hồ sơ người dùng.
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final response = await http
          .get(
        Uri.parse('$baseUrl/user/profile'),
        headers: await _getHeaders(),
      )
          .timeout(Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Không thể lấy thông tin người dùng');
      }
    } catch (e) {
      throw Exception('Lỗi kết nối: ${e.toString()}');
    }
  }

  /// Cập nhật hồ sơ người dùng với dữ liệu được cung cấp.
  Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    if (userId.isEmpty) throw Exception('ID người dùng không hợp lệ');

    try {
      final response = await http
          .put(
        Uri.parse('$baseUrl/user/editProfile/$userId'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      )
          .timeout(Duration(seconds: _timeoutSeconds));

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Cập nhật thất bại');
      }
    } catch (e) {
      throw Exception('Lỗi kết nối: ${e.toString()}');
    }
  }

  /// Cập nhật ảnh đại diện của người dùng.
  Future<void> updateAvatar(String userId, String imagePath) async {
    if (userId.isEmpty) throw Exception('ID người dùng không hợp lệ');
    if (imagePath.isEmpty) throw Exception('Đường dẫn ảnh không hợp lệ');

    try {
      var uri = Uri.parse('$baseUrl/user/editAvatar/$userId');
      var request = http.MultipartRequest('POST', uri);
      final mimeTypeData = lookupMimeType(imagePath, headerBytes: [0xFF, 0xD8])?.split('/');

      request.files.add(
        await http.MultipartFile.fromPath(
          'avatar',
          imagePath,
          contentType: mimeTypeData != null ? MediaType(mimeTypeData[0], mimeTypeData[1]) : null,
        ),
      );

      String? token = await getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      var response = await request.send().timeout(Duration(seconds: _timeoutSeconds));
      if (response.statusCode != 200) {
        final responseBody = await response.stream.bytesToString();
        final errorData = jsonDecode(responseBody);
        throw Exception(errorData['error'] ?? 'Tải ảnh lên thất bại');
      }
    } catch (e) {
      throw Exception('Lỗi kết nối: ${e.toString()}');
    }
  }

  /// Lấy danh sách các banner có trạng thái 'ACTIVE'.
  Future<List<Map<String, dynamic>>> getBanners() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/banner'))
          .timeout(Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 200) {
        final List<dynamic> allBanners = jsonDecode(response.body);
        return allBanners
            .where((banner) => banner['STATUS'] == 'ACTIVE')
            .cast<Map<String, dynamic>>()
            .toList();
      } else {
        throw Exception('Không thể tải danh sách banners');
      }
    } catch (e) {
      throw Exception('Lỗi kết nối: ${e.toString()}');
    }
  }

  /// Lấy danh sách các xe.
  Future<List<Map<String, dynamic>>> getCars() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/car'))
          .timeout(Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 200) {
        return (jsonDecode(response.body) as List<dynamic>)
            .cast<Map<String, dynamic>>();
      } else {
        throw Exception('Không thể tải danh sách xe');
      }
    } catch (e) {
      throw Exception('Lỗi kết nối: ${e.toString()}');
    }
  }

  /// Lấy danh sách các loại xe.
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/category'))
          .timeout(Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 200) {
        return (jsonDecode(response.body) as List<dynamic>)
            .cast<Map<String, dynamic>>();
      } else {
        throw Exception('Không thể tải danh sách loại xe');
      }
    } catch (e) {
      throw Exception('Lỗi kết nối: ${e.toString()}');
    }
  }

  /// Lấy danh sách các chi nhánh.
  Future<List<Map<String, dynamic>>> getBranches() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/branch'))
          .timeout(Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 200) {
        return (jsonDecode(response.body) as List<dynamic>)
            .cast<Map<String, dynamic>>();
      } else {
        throw Exception('Không thể tải danh sách chi nhánh');
      }
    } catch (e) {
      throw Exception('Lỗi kết nối: ${e.toString()}');
    }
  }

  /// Yêu cầu đặt lại mật khẩu cho email được cung cấp.
  Future<void> requestPasswordReset(String email) async {
    if (!_isValidEmail(email)) throw Exception('Email không hợp lệ');

    try {
      final response = await http
          .post(
        Uri.parse('$baseUrl/auth/request-reset'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'email': email}),
      )
          .timeout(Duration(seconds: _timeoutSeconds));

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Yêu cầu thất bại');
      }
    } catch (e) {
      throw Exception('Lỗi kết nối: ${e.toString()}');
    }
  }

  /// Xác thực OTP và đặt lại mật khẩu.
  Future<void> verifyOtpAndResetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    if (!_isValidEmail(email)) throw Exception('Email không hợp lệ');
    if (otp.isEmpty) throw Exception('OTP không được để trống');
    if (newPassword.isEmpty) throw Exception('Mật khẩu mới không được để trống');

    try {
      final response = await http
          .post(
        Uri.parse('$baseUrl/auth/verify-otp'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'email': email, 'otp': otp, 'newPassword': newPassword}),
      )
          .timeout(Duration(seconds: _timeoutSeconds));

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Xác thực thất bại');
      }
    } catch (e) {
      throw Exception('Lỗi kết nối: ${e.toString()}');
    }
  }
}