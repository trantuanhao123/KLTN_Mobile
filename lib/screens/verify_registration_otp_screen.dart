import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/api/api_service.dart';
import 'package:mobile/providers/auth_provider.dart';
import 'package:mobile/screens/main_screen.dart';

class VerifyRegistrationOtpScreen extends StatefulWidget {
  final String email; // Nhận email từ màn hình đăng ký
  const VerifyRegistrationOtpScreen({super.key, required this.email});

  @override
  State<VerifyRegistrationOtpScreen> createState() => _VerifyRegistrationOtpScreenState();
}

class _VerifyRegistrationOtpScreenState extends State<VerifyRegistrationOtpScreen> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final apiService = ApiService();
    // Lấy AuthProvider để cập nhật trạng thái sau khi xác thực thành công
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      // Gọi API xác thực OTP đăng ký
      await apiService.verifyRegistrationOtp(
        email: widget.email,
        otp: _otpController.text,
      );

      // ApiService đã lưu token
      // Cập nhật trạng thái đăng nhập trong AuthProvider
      authProvider.forceLogin(); // Cập nhật trạng thái isAuthenticated

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Xác thực tài khoản thành công!'),
          backgroundColor: Colors.green,
        ),
      );
      navigator.popUntil((route) => route.isFirst);

    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if(mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Xác thực Email', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: false, // Ẩn nút back mặc định
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Mã OTP đã được gửi đến ${widget.email}. Vui lòng nhập mã vào ô bên dưới để kích hoạt tài khoản.',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _otpController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Mã OTP',
                  labelStyle: const TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[800]!)),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1CE88A))),
                  errorBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.red)),
                  focusedErrorBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2)),
                ),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null, // Ẩn bộ đếm
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập mã OTP';
                  }
                  if (value.length != 6 || int.tryParse(value) == null) {
                    return 'Mã OTP phải là 6 chữ số';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1CE88A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3,))
                      : const Text('Xác thực', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                  setState(() => _isLoading = true);
                  try {
                    await ApiService().resendRegistrationOtp(widget.email);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã gửi lại mã OTP! Kiểm tra email.'), backgroundColor: Colors.green),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.red),
                    );
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
                child: Text(
                  'Chưa nhận được mã? Gửi lại',
                  style: TextStyle(color: Colors.grey[400], decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}