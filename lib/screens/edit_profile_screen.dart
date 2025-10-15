// lib/screens/edit_profile_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:mobile/providers/user_provider.dart';
import 'package:mobile/api/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullnameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _birthdateController;

  File? _avatarImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<UserProvider>(context, listen: false).user;
    _fullnameController = TextEditingController(text: user?['FULLNAME']);
    _phoneController = TextEditingController(text: user?['PHONE']);
    _addressController = TextEditingController(text: user?['ADDRESS']);
    _birthdateController = TextEditingController(text: user?['BIRTHDATE'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(user!['BIRTHDATE'])) : '');
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      setState(() => _avatarImage = File(pickedFile.path));
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime initialDate = DateTime.now();
    if (_birthdateController.text.isNotEmpty) {
      try {
        initialDate = DateFormat('dd/MM/yyyy').parse(_birthdateController.text);
      } catch (_) {}
    }
    final DateTime? picked = await showDatePicker(
      context: context, initialDate: initialDate,
      firstDate: DateTime(1900), lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _birthdateController.text = DateFormat('dd/MM/yyyy').format(picked));
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    // ... (logic lưu thông tin cá nhân và avatar giữ nguyên)
    final apiService = ApiService();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final userId = userProvider.user?['USER_ID'];
      if (userId == null) throw Exception("Không tìm thấy ID người dùng");

      if (_avatarImage != null) {
        await apiService.updateAvatar(userId.toString(), _avatarImage!.path);
      }

      String? birthdatePayload;
      if (_birthdateController.text.isNotEmpty) {
        DateTime parsedDate = DateFormat('dd/MM/yyyy').parse(_birthdateController.text);
        birthdatePayload = DateFormat('yyyy-MM-dd').format(parsedDate);
      }

      await apiService.updateUserProfile(userId.toString(), {
        'fullname': _fullnameController.text,
        'phone': _phoneController.text,
        'address': _addressController.text,
        if (birthdatePayload != null) 'birthdate': birthdatePayload,
      });

      await userProvider.fetchUserProfile();

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Cập nhật thành công!'), backgroundColor: Colors.green),
      );
      navigator.pop(true); // Trả về true để báo hiệu cần làm mới
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString().replaceFirst("Exception: ", "")}'), backgroundColor: Colors.red),
      );
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  // *** HÀM MỚI: HIỂN THỊ DIALOG ĐỔI MẬT KHẨU ***
  void _showChangePasswordDialog() {
    final apiService = ApiService();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final otpController = TextEditingController();

    bool isOtpSent = false;
    bool isDialogLoading = false;
    String? dialogError;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: Text(isOtpSent ? 'Xác thực OTP' : 'Đổi Mật Khẩu Mới', style: const TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isOtpSent) ...[
                      const Text('Nhập mật khẩu mới. Một mã OTP sẽ được gửi đến email của bạn để xác nhận.', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      _buildDialogTextField(newPasswordController, 'Mật khẩu mới', isPassword: true),
                      const SizedBox(height: 16),
                      _buildDialogTextField(confirmPasswordController, 'Xác nhận mật khẩu mới', isPassword: true),
                    ] else ...[
                      Text('Mã OTP đã được gửi đến ${userProvider.user?['EMAIL']}.', style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      _buildDialogTextField(otpController, 'Nhập mã OTP', keyboardType: TextInputType.number),
                    ],
                    if (dialogError != null) ...[
                      const SizedBox(height: 8),
                      Text(dialogError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1CE88A)),
                  onPressed: isDialogLoading ? null : () async {
                    setDialogState(() {
                      isDialogLoading = true;
                      dialogError = null;
                    });
                    try {
                      final userEmail = userProvider.user?['EMAIL'];
                      if (userEmail == null) throw Exception("Không tìm thấy email người dùng.");

                      if (!isOtpSent) {
                        // Giai đoạn 1: Gửi OTP
                        if (newPasswordController.text.isEmpty || newPasswordController.text.length < 6) {
                          throw Exception("Mật khẩu mới phải có ít nhất 6 ký tự.");
                        }
                        if (newPasswordController.text != confirmPasswordController.text) {
                          throw Exception("Mật khẩu xác nhận không khớp.");
                        }
                        await apiService.requestPasswordReset(userEmail);
                        setDialogState(() => isOtpSent = true);
                      } else {
                        // Giai đoạn 2: Xác thực và đổi mật khẩu
                        if (otpController.text.isEmpty || otpController.text.length != 6) {
                          throw Exception("Mã OTP phải có 6 chữ số.");
                        }
                        await apiService.verifyOtpAndResetPassword(
                          email: userEmail,
                          otp: otpController.text,
                          newPassword: newPasswordController.text,
                        );
                        Navigator.of(context).pop(); // Đóng dialog
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(content: Text('Đổi mật khẩu thành công!'), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      setDialogState(() {
                        dialogError = e.toString().replaceFirst("Exception: ", "");
                      });
                    } finally {
                      setDialogState(() => isDialogLoading = false);
                    }
                  },
                  child: isDialogLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : Text(
                      isOtpSent ? 'Xác Nhận' : 'Gửi Mã OTP',
                      style: const TextStyle(color: Colors.black)
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Chỉnh Sửa Hồ Sơ', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey.shade800,
                    backgroundImage: _avatarImage != null
                        ? FileImage(_avatarImage!)
                        : (user?['AVATAR_URL'] != null
                        ? NetworkImage("${ApiService().baseUrl}/images/${user!['AVATAR_URL']}")
                        : null) as ImageProvider?,
                    child: (user?['AVATAR_URL'] == null && _avatarImage == null)
                        ? const Icon(Icons.person, size: 60, color: Colors.white70)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.white),
                      onPressed: _pickImage,
                      style: IconButton.styleFrom(backgroundColor: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle("Thông tin cá nhân"),
            _buildTextFormField(_fullnameController, 'Họ và Tên'),
            const SizedBox(height: 16),
            _buildTextFormField(_phoneController, 'Số điện thoại'),
            const SizedBox(height: 16),
            _buildTextFormField(_addressController, 'Địa chỉ'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _birthdateController,
              readOnly: true,
              onTap: () => _selectDate(context),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Ngày sinh (dd/MM/yyyy)',
                labelStyle: TextStyle(color: Colors.white70),
                suffixIcon: Icon(Icons.calendar_today, color: Colors.white70),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1CE88A))),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle("Bảo mật"),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_outline, color: Colors.white70),
              title: const Text('Đổi mật khẩu', style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
              onTap: _showChangePasswordDialog,
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1CE88A),
                    padding: const EdgeInsets.symmetric(vertical: 16)
                ),
                child: const Text('Lưu Thay Đổi', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget con cho các trường nhập liệu chính
  Widget _buildTextFormField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1CE88A))),
      ),
    );
  }

  // Widget con cho các trường nhập liệu trong Dialog
  Widget _buildDialogTextField(TextEditingController controller, String label, {bool isPassword = false, TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF1CE88A))),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(color: Color(0xFF1CE88A), fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  void dispose() {
    _fullnameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _birthdateController.dispose();
    super.dispose();
  }
}