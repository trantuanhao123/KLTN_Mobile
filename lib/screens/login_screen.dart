import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mobile/providers/auth_provider.dart';
import 'package:mobile/screens/signup_screen.dart';
import 'package:mobile/screens/forgot_password_screen.dart';
import 'package:mobile/screens/main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // CẤU HÌNH GOOGLE SIGN IN
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '463080509916-8cigt5q0fdpt6qm9g5rcorlalbm1iq5r.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );

  @override
  void initState() {
    super.initState();
  }

  // Đăng nhập bằng email/password
  Future<void> _login() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      // if (!mounted) return;
      // Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(builder: (_) => const MainScreen()),
      // );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Đăng nhập Google
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Không lấy được ID Token từ Google');
      }

      await Provider.of<AuthProvider>(context, listen: false).loginWithGoogle(idToken);

      // if (!mounted) return;
      //
      // Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(builder: (_) => const MainScreen()),
      // );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi đăng nhập Google: ${e.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Đăng nhập',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Đăng nhập để trải nghiệm trọn vẹn.',
                style: TextStyle(color: Colors.grey[400], fontSize: 16),
              ),
              const SizedBox(height: 48),

              // Email field
              _buildTextField(
                controller: _emailController,
                label: 'Email',
                hintText: 'NguyenVanA@gmail.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),

              // Password field
              _buildTextField(
                controller: _passwordController,
                label: 'Mật khẩu',
                hintText: '',
                isPassword: true,
              ),
              const SizedBox(height: 16),

              // Quên mật khẩu
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                  ),
                  child: const Text('Quên mật khẩu?', style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 24),

              // Nút đăng nhập
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1CE88A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3),
                  )
                      : const Text(
                    'Đăng nhập',
                    style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[800])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('Hoặc', style: TextStyle(color: Colors.grey[400])),
                  ),
                  Expanded(child: Divider(color: Colors.grey[800])),
                ],
              ),
              const SizedBox(height: 32),

              // Nút Google
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  icon: Image.asset('assets/google_logo.png', height: 24),
                  label: const Text(
                    'Đăng nhập bằng Google',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[800]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                ),
              ),
              const SizedBox(height: 48),

              // Đăng ký
              Align(
                alignment: Alignment.center,
                child: RichText(
                  text: TextSpan(
                    text: "Chưa có tài khoản? ",
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    children: [
                      TextSpan(
                        text: 'Đăng ký',
                        style: const TextStyle(color: Color(0xFF1CE88A), fontWeight: FontWeight.bold),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SignupScreen()),
                            );
                          },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // Helper xây TextField với hintText
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: isPassword && !_isPasswordVisible,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            // Cấu hình Placeholder ở đây
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey[600]), // Màu chữ mờ

            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[800]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1CE88A)),
            ),
            suffixIcon: isPassword
                ? IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
              ),
              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
            )
                : null,
          ),
        ),
      ],
    );
  }
}