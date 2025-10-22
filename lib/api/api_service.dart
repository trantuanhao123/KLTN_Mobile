import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';

class ApiService {
  // URL cho API - *** NHỚ THAY ĐỔI NẾU CẦN ***
  static const String _baseUrl = "http://192.168.1.5:8080";
  static const int _timeoutSeconds = 30; // Thời gian chờ tối đa

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
        // Kiểm tra lỗi tài khoản chưa kích hoạt
        if (error['error'] != null && error['error'].toString().contains('chưa được kích hoạt')) {
          throw Exception('Tài khoản chưa được kích hoạt. Vui lòng kiểm tra email.');
        }
        throw Exception(error['error'] ?? 'Đăng nhập thất bại');
      }
    } catch (e) {
      // Ném lại lỗi cụ thể nếu có
      if (e is Exception && e.toString().contains('Tài khoản chưa được kích hoạt')) {
        rethrow;
      }
      throw Exception('Lỗi kết nối: ${e.toString()}');
    }
  }

  /// Đăng ký người dùng mới. Chỉ gửi yêu cầu, không tự động đăng nhập.
  Future<Map<String, dynamic>> register({
    required String fullname,
    required String email,
    required String phone,
    required String password,
  }) async {
    if (fullname.trim().isEmpty) throw Exception('Tên không được để trống');
    if (!_isValidEmail(email.trim())) throw Exception('Email không hợp lệ');
    if (phone.trim().isEmpty) throw Exception('Số điện thoại không được để trống');
    if (password.length < 6) throw Exception('Mật khẩu phải có ít nhất 6 ký tự');

    try {
      final response = await http
          .post(
        Uri.parse('$baseUrl/user/register'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(<String, String>{
          'fullname': fullname.trim(),
          'email': email.trim(),
          'phone': phone.trim(),
          'password': password,
        }),
      )
          .timeout(Duration(seconds: _timeoutSeconds));

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return responseData; // vd: {"message": "Đăng ký thành công...", "userId": ...}
      } else {
        throw Exception(responseData['error'] ?? 'Đăng ký thất bại (Code: ${response.statusCode})');
      }
    } catch (e) {
      rethrow; // Ném lại lỗi để màn hình signup xử lý
    }
  }

  /// Xác thực OTP đăng ký và lấy token/user data.
  Future<Map<String, dynamic>> verifyRegistrationOtp({
    required String email,
    required String otp,
  }) async {
    if (!_isValidEmail(email)) throw Exception('Email không hợp lệ');
    if (otp.length != 6) throw Exception('Mã OTP phải có 6 chữ số');

    try {
      final response = await http
          .post(
        Uri.parse('$baseUrl/user/verify-register'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'email': email, 'otp': otp}),
      )
          .timeout(Duration(seconds: _timeoutSeconds));

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (responseData['token'] != null) {
          await _saveToken(responseData['token']); // Tự động lưu token
        } else {
          throw Exception('Xác thực thành công nhưng không nhận được token.');
        }
        return responseData; // Trả về {"message": "...", "token": "...", "user": {...}}
      } else {
        // Lỗi 400 (OTP sai/hết hạn), 404 (Email không tồn tại)
        throw Exception(responseData['message'] ?? 'Xác thực OTP thất bại (Code: ${response.statusCode})');
      }
    } catch (e) {
      rethrow; // Ném lại lỗi để màn hình verify OTP xử lý
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
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await deleteToken();
        throw Exception('Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.');
      }
      else {
        throw Exception('Không thể lấy thông tin người dùng (${response.statusCode})');
      }
    } catch (e) {
      if (e is! Exception || !e.toString().contains('Phiên đăng nhập hết hạn')) {
        throw Exception('Lỗi kết nối: ${e.toString()}');
      }
      rethrow;
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
      } else {
        throw Exception('Chưa đăng nhập');
      }

      var response = await request.send().timeout(Duration(seconds: _timeoutSeconds));
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        try {
          final errorData = jsonDecode(responseBody);
          throw Exception(errorData['error'] ?? 'Tải ảnh lên thất bại (Code: ${response.statusCode})');
        } catch(_) {
          throw Exception('Tải ảnh lên thất bại (Code: ${response.statusCode}) - $responseBody');
        }
      }
    } catch (e) {
      throw Exception('Lỗi kết nối hoặc xử lý: ${e.toString()}');
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
        if (response.statusCode == 404) {
          throw Exception('Email không tồn tại trong hệ thống.');
        }
        throw Exception(errorData['message'] ?? 'Yêu cầu thất bại');
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('Email không tồn tại')) {
        rethrow;
      }
      throw Exception('Lỗi kết nối hoặc xử lý: ${e.toString()}');
    }
  }


  /// Xác thực OTP và đặt lại mật khẩu.
  Future<void> verifyOtpAndResetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    if (!_isValidEmail(email)) throw Exception('Email không hợp lệ');
    if (otp.length != 6) throw Exception('Mã OTP phải có 6 chữ số');
    if (newPassword.length < 6) throw Exception('Mật khẩu mới phải có ít nhất 6 ký tự');

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
      if (e is Exception && (e.toString().contains('OTP không hợp lệ') || e.toString().contains('Email không tồn tại'))) {
        rethrow;
      }
      throw Exception('Lỗi kết nối hoặc xử lý: ${e.toString()}');
    }
  }

  /// Tạo đơn hàng và lấy link thanh toán PayOS
  Future<String> createOrderAndGetPaymentLink({
    required int carId,
    required String startDate, // Định dạng YYYY-MM-DD HH:MM:SS
    required String endDate,   // Định dạng YYYY-MM-DD HH:MM:SS
    String? rentalType,       // 'day' hoặc 'hour'
    required String paymentOption, // 'full' hoặc 'deposit'
    String? discountCode,
  }) async {
    if (carId <= 0) throw Exception('ID xe không hợp lệ');

    try {
      final response = await http
          .post(
        Uri.parse('$baseUrl/order'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'carId': carId,
          'startDate': startDate,
          'endDate': endDate,
          if (rentalType != null) 'rentalType': rentalType,
          'paymentOption': paymentOption,
          if (discountCode != null && discountCode.isNotEmpty) 'discountCode': discountCode,
        }),
      )
          .timeout(Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['checkoutUrl'] != null) {
          return data['checkoutUrl'];
        } else {
          throw Exception('Không nhận được link thanh toán (checkoutUrl) từ backend.');
        }
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Tạo đơn hàng thất bại (Code: ${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Lỗi kết nối khi tạo đơn hàng: ${e.toString()}');
    }
  }
  ///Lấy lịch sử đặt xe của người dùng
  Future<List<dynamic>> getUserBookings() async {
    try {
      // Backend cần cung cấp endpoint này, ví dụ: /order/user
      // Endpoint này cần được bảo vệ bằng authMiddleware
      final response = await http
          .get(
        Uri.parse('$baseUrl/order/user'), // ** GIẢ SỬ ENDPOINT LÀ /order/user **
        headers: await _getHeaders(), // Cần token
      )
          .timeout(Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 200) {
        // Giả sử backend trả về một mảng JSON các đơn hàng
        return jsonDecode(response.body) as List<dynamic>;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await deleteToken();
        throw Exception('Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.');
      } else {
        throw Exception('Không thể tải lịch sử đặt xe (${response.statusCode})');
      }
    } catch (e) {
      if (e is! Exception || !e.toString().contains('Phiên đăng nhập hết hạn')) {
        throw Exception('Lỗi kết nối khi tải lịch sử đặt xe: ${e.toString()}');
      }
      rethrow;
    }
  }
}