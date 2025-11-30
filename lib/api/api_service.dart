import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';

class ApiService {

  static const String _baseUrl = "https://kltn-backend-zceg.onrender.com";
  static const int _timeoutSeconds = 300;

  String get baseUrl => _baseUrl;
  final _storage = const FlutterSecureStorage();

  // ====================== HELPER ======================

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  Future<String?> getToken() async => await _storage.read(key: 'jwt_token');

  Future<void> _saveToken(String token) async {
    if (token.isEmpty) throw Exception('Token không hợp lệ');
    await _storage.write(key: 'jwt_token', value: token);
  }

  Future<void> deleteToken() async => await _storage.delete(key: 'jwt_token');

  Future<Map<String, String>> _getHeaders({bool hasBody = false}) async {
    final token = await getToken();
    return {
      if (hasBody) 'Content-Type': 'application/json; charset=UTF-8',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  void _handleAuthError(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('Phiên đăng nhập hết hạn (401). Vui lòng đăng nhập lại.');
    }
  }

  List<dynamic> _extractListFromResponse(http.Response response) {
    _handleAuthError(response); // Kiểm tra token hết hạn trước
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) return decoded;
      if (decoded is Map && decoded['data'] is List) return decoded['data'];
      if (decoded is Map && decoded['rows'] is List) return decoded['rows'];
      return [];
    } else {
      throw Exception('Lỗi tải dữ liệu: ${response.statusCode}');
    }
  }

  Map<String, dynamic> _safeJsonDecode(String source) {
    try {
      return jsonDecode(source) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  // ====================== AUTH ======================

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
        if (data['token'] != null) {
          await _saveToken(data['token']);
          print('--- LOGIN SUCCESS TOKEN ---');
          print(data['token']);
        }
        return data;
      } else {
        final error = jsonDecode(response.body);
        if (error['error']?.toString().contains('chưa được kích hoạt') ==
            true) {
          throw Exception(
              'Tài khoản chưa được kích hoạt. Vui lòng kiểm tra email.');
        }
        throw Exception(error['error'] ?? 'Đăng nhập thất bại');
      }
    } catch (e) {
      if (e is Exception &&
          e.toString().contains('Tài khoản chưa được kích hoạt')) rethrow;
      throw Exception('Lỗi kết nối khi đăng nhập: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> register({
    required String fullname,
    required String email,
    required String phone,
    required String password,
  }) async {
    if (fullname
        .trim()
        .isEmpty) throw Exception('Tên không được để trống');
    if (!_isValidEmail(email.trim())) throw Exception('Email không hợp lệ');
    if (phone
        .trim()
        .isEmpty) throw Exception('Số điện thoại không được để trống');
    if (password.length < 6) throw Exception(
        'Mật khẩu phải có ít nhất 6 ký tự');

    try {
      final response = await http
          .post(
        Uri.parse('$baseUrl/user/register'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'fullname': fullname.trim(),
          'email': email.trim(),
          'phone': phone.trim(),
          'password': password,
        }),
      )
          .timeout(Duration(seconds: _timeoutSeconds));

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) return data;
      throw Exception(data['error'] ?? 'Đăng ký thất bại');
    } catch (e) {
      rethrow;
    }
  }

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

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        if (data['token'] != null) await _saveToken(data['token']);
        return data;
      }
      throw Exception(data['message'] ?? 'Xác thực OTP thất bại');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async => await deleteToken();

  // ====================== PROFILE & USER ======================

  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/user/profile'), headers: await _getHeaders())
          .timeout(Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('UNAUTHORIZED');
      }

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      // Các lỗi khác (500, 404...) thì không logout, chỉ báo lỗi
      throw Exception('Lỗi tải dữ liệu: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateUserProfile(String userId,
      Map<String, dynamic> data) async {
    if (userId.isEmpty) throw Exception('ID người dùng không hợp lệ');
    try {
      final response = await http
          .put(
        Uri.parse('$baseUrl/user/editProfile/$userId'),
        headers: await _getHeaders(hasBody: true),
        body: jsonEncode(data),
      )
          .timeout(Duration(seconds: _timeoutSeconds));

      _handleAuthError(response);
      if (response.statusCode != 200) {
        final error = _safeJsonDecode(response.body);
        throw Exception(error['error'] ?? 'Cập nhật thất bại');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateAvatar(String userId, String imagePath) async {
    if (userId.isEmpty || imagePath.isEmpty) throw Exception(
        'Dữ liệu không hợp lệ');
    try {
      final request = http.MultipartRequest(
          'POST', Uri.parse('$baseUrl/user/editAvatar/$userId'));
      final mime = lookupMimeType(imagePath)?.split('/');
      request.files.add(await http.MultipartFile.fromPath(
        'avatar',
        imagePath,
        contentType: mime != null ? MediaType(mime[0], mime[1]) : null,
      ));

      final token = await getToken();
      if (token == null) throw Exception('Chưa đăng nhập');
      request.headers['Authorization'] = 'Bearer $token';

      final streamedResponse = await request.send().timeout(
          Duration(seconds: _timeoutSeconds));
      final response = await http.Response.fromStream(streamedResponse);

      _handleAuthError(response);
      if (response.statusCode != 200) {
        final error = _safeJsonDecode(response.body);
        throw Exception(error['error'] ?? 'Tải ảnh lên thất bại');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Hàm mới: Cập nhật bằng lái xe (Mặt trước + Mặt sau)
  Future<void> updateLicense(String userId, String frontPath,
      String backPath) async {
    if (userId.isEmpty || frontPath.isEmpty ||
        backPath.isEmpty) throw Exception('Dữ liệu không hợp lệ');
    try {
      final request = http.MultipartRequest(
          'POST', Uri.parse('$baseUrl/user/editLicense/$userId'));

      final mimeFront = lookupMimeType(frontPath)?.split('/');
      request.files.add(await http.MultipartFile.fromPath(
        'license_front', // Phải khớp với config multer trong backend
        frontPath,
        contentType: mimeFront != null
            ? MediaType(mimeFront[0], mimeFront[1])
            : null,
      ));

      final mimeBack = lookupMimeType(backPath)?.split('/');
      request.files.add(await http.MultipartFile.fromPath(
        'license_back', // Phải khớp với config multer trong backend
        backPath,
        contentType: mimeBack != null
            ? MediaType(mimeBack[0], mimeBack[1])
            : null,
      ));

      final token = await getToken();
      if (token == null) throw Exception('Chưa đăng nhập');
      request.headers['Authorization'] = 'Bearer $token';

      final streamedResponse = await request.send().timeout(
          Duration(seconds: _timeoutSeconds));
      final response = await http.Response.fromStream(streamedResponse);

      _handleAuthError(response);
      if (response.statusCode != 200) {
        final error = _safeJsonDecode(response.body);
        throw Exception(error['error'] ?? 'Cập nhật bằng lái thất bại');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Hàm mới: Đổi mật khẩu
  Future<void> changePassword(String oldPassword, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/change-password'),
        headers: await _getHeaders(hasBody: true),
        body: jsonEncode(
            {'oldPassword': oldPassword, 'newPassword': newPassword}),
      ).timeout(Duration(seconds: _timeoutSeconds));

      _handleAuthError(response);
      if (response.statusCode != 200) {
        final error = _safeJsonDecode(response.body);
        throw Exception(error['error'] ?? 'Đổi mật khẩu thất bại');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ====================== CAR & DATA ======================

  Future<List<Map<String, dynamic>>> getBanners() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/banner'), headers: headers)
          .timeout(Duration(seconds: _timeoutSeconds));

      final list = _extractListFromResponse(response);
      return list
          .where((item) => item['STATUS'] == 'ACTIVE')
          .cast<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      throw Exception('Lỗi kết nối banner: ${e.toString()}');
    }
  }

  Future<List<Map<String, dynamic>>> getCars() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/car'), headers: headers)
          .timeout(Duration(seconds: _timeoutSeconds));

      final list = _extractListFromResponse(response);
      return list.cast<Map<String, dynamic>>().toList();
    } catch (e) {
      throw Exception('Lỗi kết nối xe: ${e.toString()}');
    }
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/category'), headers: headers)
          .timeout(Duration(seconds: _timeoutSeconds));

      final list = _extractListFromResponse(response);
      return list.cast<Map<String, dynamic>>().toList();
    } catch (e) {
      throw Exception('Lỗi kết nối loại xe: ${e.toString()}');
    }
  }

  Future<List<Map<String, dynamic>>> getBranches() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/branch'), headers: headers)
          .timeout(Duration(seconds: _timeoutSeconds));

      final list = _extractListFromResponse(response);
      return list.cast<Map<String, dynamic>>().toList();
    } catch (e) {
      throw Exception('Lỗi kết nối chi nhánh: ${e.toString()}');
    }
  }

  // ====================== PASSWORD RESET ======================

  Future<void> requestPasswordReset(String email) async {
    if (!_isValidEmail(email)) throw Exception('Email không hợp lệ');
    try {
      final response = await http
          .post(Uri.parse('$baseUrl/auth/request-reset'),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode({'email': email}))
          .timeout(Duration(seconds: _timeoutSeconds));

      if (response.statusCode != 200) {
        final error = _safeJsonDecode(response.body);
        if (response.statusCode == 404) throw Exception(
            'Email không tồn tại trong hệ thống.');
        throw Exception(error['message'] ?? 'Yêu cầu thất bại');
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('Email không tồn tại'))
        rethrow;
      throw Exception('Lỗi kết nối: ${e.toString()}');
    }
  }

  Future<void> verifyOtpAndResetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    if (!_isValidEmail(email)) throw Exception('Email không hợp lệ');
    if (otp.length != 6) throw Exception('Mã OTP phải có 6 chữ số');
    if (newPassword.length < 6) throw Exception(
        'Mật khẩu mới phải có ít nhất 6 ký tự');

    try {
      final response = await http
          .post(Uri.parse('$baseUrl/auth/verify-otp'),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode(
              {'email': email, 'otp': otp, 'newPassword': newPassword}))
          .timeout(Duration(seconds: _timeoutSeconds));

      if (response.statusCode != 200) {
        final error = _safeJsonDecode(response.body);
        throw Exception(error['message'] ?? 'Xác thực thất bại');
      }
    } catch (e) {
      if (e is Exception && (e.toString().contains('OTP không hợp lệ') ||
          e.toString().contains('Email không tồn tại'))) rethrow;
      throw Exception('Lỗi kết nối: ${e.toString()}');
    }
  }

  Future<void> resendRegistrationOtp(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/resend-register-otp'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: _timeoutSeconds));

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Gửi lại thất bại');
      }
    } catch (e) {
      rethrow;
    }
  }
  // ====================== ORDERS & BOOKING ======================

  Future<Map<String, dynamic>> createOrderAndGetPaymentLink({
    required int carId,
    required String startDate,
    required String endDate,
    required String rentalType,
    required String paymentOption,
    String? discountCode,
  }) async {
    if (carId <= 0) throw Exception('ID xe không hợp lệ');

    try {
      final response = await http
          .post(
        Uri.parse('$baseUrl/order'),
        headers: await _getHeaders(hasBody: true),
        body: jsonEncode({
          'carId': carId,
          'startDate': startDate,
          'endDate': endDate,
          'rentalType': rentalType,
          'paymentOption': paymentOption,
          if (discountCode != null && discountCode.isNotEmpty)
            'discountCode': discountCode,
        }),
      )
          .timeout(const Duration(seconds: _timeoutSeconds));

      // Kiểm tra lỗi xác thực (401, token hết hạn, v.v.)
      _handleAuthError(response);

      // PayOS thường trả 201, nhưng có thể backend wrap lại trả 200
      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        // Một số backend trả thẳng object, một số lại bọc trong key "data"
        final payload = data['data'] ?? data;

        final String? checkoutUrl = payload['checkoutUrl'] as String?;
        final dynamic orderCode = payload['orderCode'] ?? payload['orderId'];

        if (checkoutUrl == null || checkoutUrl.isEmpty) {
          throw Exception('Không nhận được link thanh toán từ server');
        }

        if (orderCode == null) {
          throw Exception('Không nhận được mã đơn hàng từ server');
        }

        return {
          'url': checkoutUrl,
          // Link để mở thanh toán
          'orderId': orderCode.toString(),
          // orderCode của PayOS (dùng để hủy, tra cứu)
        };
      }

      // Nếu không thành công
      final errorBody = _safeJsonDecode(response.body);
      final message = errorBody['error'] ??
          errorBody['message'] ??
          'Tạo đơn hàng thất bại (mã: ${response.statusCode})';

      throw Exception(message);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getUserBookings() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/order/login-orders'),
          headers: await _getHeaders()).timeout(
          Duration(seconds: _timeoutSeconds));
      _handleAuthError(response);
      return response.statusCode == 200 ? jsonDecode(response.body) as List<
          dynamic> : throw Exception('Lỗi tải lịch sử đặt xe');
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> checkDiscountCode(String code) async {
    if (code
        .trim()
        .isEmpty) throw Exception('Vui lòng nhập mã giảm giá');
    try {
      final response = await http
          .post(Uri.parse('$baseUrl/discount/check'),
          headers: await _getHeaders(hasBody: true),
          body: jsonEncode({'code': code.trim().toUpperCase()}))
          .timeout(Duration(seconds: _timeoutSeconds));

      _handleAuthError(response);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success')
        return data['data'];
      throw Exception(data['message'] ?? 'Kiểm tra mã thất bại');
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> cancelOrder(int orderId, String status,
      {String? bankAccount, String? bankName}) async {
    if (orderId <= 0) throw Exception('ID đơn hàng không hợp lệ');
    String endpoint;
    Map<String, dynamic>? body;
    bool hasBody = false;

    if (status == 'PENDING') {
      endpoint = '$baseUrl/order/cancel-pending/$orderId';
    } else if (status == 'PAID_DEPOSIT') {
      endpoint = '$baseUrl/order/cancel-deposit/$orderId';
    } else if (status == 'PAID_FULL') {
      endpoint = '$baseUrl/order/cancel-paid/$orderId';
      if (bankAccount
          ?.trim()
          .isEmpty != false || bankName
          ?.trim()
          .isEmpty != false) {
        throw Exception(
            'Vui lòng cung cấp Số tài khoản và Tên ngân hàng để hoàn tiền.');
      }
      body = {'bankAccount': bankAccount!.trim(), 'bankName': bankName!.trim()};
      hasBody = true;
    } else {
      throw Exception('Không thể hủy đơn hàng ở trạng thái này ($status).');
    }

    try {
      final response = await http
          .patch(
          Uri.parse(endpoint), headers: await _getHeaders(hasBody: hasBody),
          body: hasBody ? jsonEncode(body) : null)
          .timeout(Duration(seconds: _timeoutSeconds));

      _handleAuthError(response);
      final data = _safeJsonDecode(response.body);
      if (response.statusCode == 200) return data;
      throw Exception(data['error'] ?? data['message'] ?? 'Hủy đơn thất bại');
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> changeOrderDate(int orderId, String newStartDate,
      String newEndDate) async {
    try {
      final response = await http
          .patch(
        Uri.parse('$baseUrl/order/change-date/$orderId'),
        headers: await _getHeaders(hasBody: true),
        body: jsonEncode(
            {'newStartDate': newStartDate, 'newEndDate': newEndDate}),
      )
          .timeout(Duration(seconds: _timeoutSeconds));

      _handleAuthError(response);
      final data = _safeJsonDecode(response.body);
      if (response.statusCode == 200) return data;
      throw Exception(data['error'] ?? data['message'] ?? 'Đổi lịch thất bại');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> submitReview(int orderId, int rating, String content) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/review'),
        headers: await _getHeaders(hasBody: true),
        body: jsonEncode({
          'orderId': orderId,
          'rating': rating,
          'content': content
        }),
      ).timeout(const Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(
            error['error'] ?? error['message'] ?? 'Lỗi khi gửi đánh giá');
      }
    } catch (e) {
      if (e.toString().contains("Exception:")) rethrow;
      throw Exception('Lỗi kết nối: ${e.toString()}');
    }
  }

  // Lấy danh sách đánh giá
  Future<List<dynamic>> getReviewsByCarId(int carId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/review/car/$carId'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) return decoded;
        if (decoded is Map && decoded['data'] is List) return decoded['data'];
        return [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Sửa đánh giá
  Future<void> updateReview(int reviewId, int rating, String content) async {
    final response = await http.put(
      Uri.parse('$baseUrl/review/$reviewId'),
      headers: await _getHeaders(hasBody: true),
      body: jsonEncode({'rating': rating, 'content': content}),
    ).timeout(const Duration(seconds: _timeoutSeconds));

    if (response.statusCode != 200) {
      throw Exception('Cập nhật thất bại: ${response.body}');
    }
  }

  // Xóa đánh giá
  Future<void> deleteReview(int reviewId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/review/$reviewId'),
      headers: await _getHeaders(),
    ).timeout(const Duration(seconds: _timeoutSeconds));

    if (response.statusCode != 200) {
      throw Exception('Xóa thất bại: ${response.body}');
    }
  }

  Future<List<dynamic>> getNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notification'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) return decoded;
        if (decoded is Map && decoded['data'] is List) return decoded['data'];
        return [];
      } else {
        throw Exception('Lỗi tải thông báo: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Lỗi kết nối: $e');
    }
  }

  Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    try {
      final response = await http
          .post(
        Uri.parse('$baseUrl/googleAuth/login'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'idToken': idToken}),
      )
          .timeout(const Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['token'] != null) {
          await _saveToken(data['token']);
          print('--- GOOGLE LOGIN SUCCESS ---');
          print('Token: ${data['token']}');
          print('User ID: ${data['user_id']}');
        }
        return data;
      } else {
        final error = _safeJsonDecode(response.body);
        throw Exception(error['message'] ??
            'Đăng nhập Google thất bại (${response.statusCode})');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ====================== Report Incident ======================

  Future<void> reportIncident(int orderId, int carId, String content, List<String> imagePaths) async {
    final url = Uri.parse('$baseUrl/incident'); // URL chính xác (không có 's')
    final token = await getToken();

    var request = http.MultipartRequest('POST', url);

    request.headers.addAll({
      'Authorization': 'Bearer $token',
    });

    request.fields['ORDER_ID'] = orderId.toString();
    request.fields['CAR_ID'] = carId.toString();
    request.fields['DESCRIPTION'] = content;

    for (String path in imagePaths) {
      if (path.isNotEmpty) {
        // 1. Xác định loại file (MIME type)
        final mimeTypeData = lookupMimeType(path)?.split('/');

        // 2. Tạo đối tượng MediaType
        MediaType? mediaType;
        if (mimeTypeData != null && mimeTypeData.length == 2) {
          mediaType = MediaType(mimeTypeData[0], mimeTypeData[1]);
        }

        // 3. Gửi file kèm Content-Type cụ thể
        var file = await http.MultipartFile.fromPath(
          'media',
          path,
          contentType: mediaType,
        );
        request.files.add(file);
      }
    }

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      print("Báo cáo sự cố thành công!");
    } else {
      print("Lỗi Server: ${response.body}");
      try {
        final body = json.decode(response.body);
        throw Exception(body['error'] ?? 'Gửi báo cáo thất bại: ${response.statusCode}');
      } catch (e) {
        throw Exception('Chỉ được báo cáo 1 lần (${response.statusCode})');
      }
    }
  }
}