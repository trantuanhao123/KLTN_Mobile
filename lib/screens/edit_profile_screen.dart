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
  File? _licenseFrontImage;
  File? _licenseBackImage;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<UserProvider>(context, listen: false).user;

    _fullnameController = TextEditingController(text: user?['FULLNAME']);
    _phoneController = TextEditingController(text: user?['PHONE']);
    _addressController = TextEditingController(text: user?['ADDRESS']);

    // Xử lý ngày sinh
    _birthdateController = TextEditingController(
      text: user?['BIRTHDATE'] != null
          ? DateFormat('dd/MM/yyyy').format(
        DateTime.parse(user!['BIRTHDATE']).toLocal(),
      )
          : '',
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

  Future<void> _pickImage(String type) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        if (type == 'avatar') {
          _avatarImage = File(pickedFile.path);
        } else if (type == 'license_front') {
          _licenseFrontImage = File(pickedFile.path);
        } else if (type == 'license_back') {
          _licenseBackImage = File(pickedFile.path);
        }
      });
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
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) { // Thêm theme tối cho lịch
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF1CE88A),
              onPrimary: Colors.black,
              surface: Colors.grey,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: Colors.grey[900],
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _birthdateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final apiService = ApiService();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final userId = userProvider.user?['USER_ID'];
      if (userId == null) throw Exception("Không tìm thấy ID người dùng");

      // 1. Cập nhật Avatar
      if (_avatarImage != null) {
        await apiService.updateAvatar(userId.toString(), _avatarImage!.path);
      }

      // 2. Cập nhật Bằng lái (yêu cầu đủ 2 mặt)
      if (_licenseFrontImage != null && _licenseBackImage != null) {
        await apiService.updateLicense(
          userId.toString(),
          _licenseFrontImage!.path,
          _licenseBackImage!.path,
        );
      } else if ((_licenseFrontImage != null && _licenseBackImage == null) ||
          (_licenseFrontImage == null && _licenseBackImage != null)) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Vui lòng chọn cả 2 mặt bằng lái để cập nhật.'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // 3. Chuẩn bị ngày sinh gửi lên server
      String? birthdatePayload;
      if (_birthdateController.text.isNotEmpty) {
        final parsedDate =
        DateFormat('dd/MM/yyyy').parse(_birthdateController.text);
        birthdatePayload = DateFormat('yyyy-MM-dd').format(parsedDate);
      }

      // 4. Cập nhật thông tin văn bản
      await apiService.updateUserProfile(userId.toString(), {
        'fullname': _fullnameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        if (birthdatePayload != null) 'birthdate': birthdatePayload,
      });

      // 5. Refresh dữ liệu người dùng
      await userProvider.fetchUserProfile();

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Cập nhật hồ sơ thành công!'),
          backgroundColor: Colors.green,
        ),
      );

      navigator.pop(true); // Trả về kết quả thành công
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

  // logic đổi mật khẩu trực tiếp
  void _showChangePasswordDialog() {
    final apiService = ApiService();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    bool isDialogLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text('Đổi Mật Khẩu',
                  style: TextStyle(color: Colors.white)),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Nhập mật khẩu cũ và mật khẩu mới để thay đổi.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      // Mật khẩu cũ
                      _buildDialogTextField(
                        oldPasswordController,
                        'Mật khẩu cũ',
                        isPassword: true,
                        validator: (val) => val == null || val.isEmpty
                            ? 'Vui lòng nhập mật khẩu cũ'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      // Mật khẩu mới
                      _buildDialogTextField(
                        newPasswordController,
                        'Mật khẩu mới',
                        isPassword: true,
                        validator: (val) => val != null && val.length < 6
                            ? 'Mật khẩu phải trên 6 ký tự'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      // Xác nhận mật khẩu mới
                      _buildDialogTextField(
                        confirmPasswordController,
                        'Xác nhận mật khẩu mới',
                        isPassword: true,
                        validator: (val) => val != newPasswordController.text
                            ? 'Mật khẩu xác nhận không khớp'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child:
                  const Text('Hủy', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1CE88A)),
                  onPressed: isDialogLoading
                      ? null
                      : () async {
                    if (formKey.currentState!.validate()) {
                      setDialogState(() => isDialogLoading = true);
                      try {
                        // Gọi API đổi mật khẩu (không cần OTP)
                        await apiService.changePassword(
                          oldPasswordController.text,
                          newPasswordController.text,
                        );
                        if (!mounted) return;
                        Navigator.of(context).pop();
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('Đổi mật khẩu thành công!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text(
                                'Lỗi: ${e.toString().replaceFirst("Exception: ", "")}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } finally {
                        setDialogState(() => isDialogLoading = false);
                      }
                    }
                  },
                  child: isDialogLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black),
                  )
                      : const Text('Lưu thay đổi',
                      style: TextStyle(color: Colors.black)),
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

    // Logic hiển thị Avatar đồng bộ với ProfileScreen
    final avatarUrl = user?['AVATAR_URL'];
    ImageProvider? bgImage;

    if (_avatarImage != null) {
      bgImage = FileImage(_avatarImage!);
    } else if (avatarUrl != null && avatarUrl.toString().isNotEmpty && !avatarUrl.toString().contains('default-avatar')) {
      String finalUrl = avatarUrl.toString().startsWith('http')
          ? avatarUrl
          : "${ApiService().baseUrl}/images/$avatarUrl";
      bgImage = NetworkImage(finalUrl);
    } else {
      bgImage = const AssetImage('assets/default-avatar.png');
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Chỉnh Sửa Hồ Sơ',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Avatar
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey.shade800,
                    backgroundImage: bgImage,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: () => _pickImage('avatar'),
                      child: const CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(0xFF1CE88A),
                        child: Icon(Icons.camera_alt,
                            color: Colors.black, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionTitle("Thông tin cá nhân"),
            _buildTextFormField(_fullnameController, 'Họ và Tên',
                validator: (v) =>
                v!.isEmpty ? 'Tên không được để trống' : null),
            const SizedBox(height: 16),
            _buildTextFormField(_phoneController, 'Số điện thoại',
                keyboardType: TextInputType.phone),
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
                suffixIcon:
                Icon(Icons.calendar_today, color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF1CE88A))),
              ),
            ),

            const SizedBox(height: 24),
            _buildSectionTitle("Giấy phép lái xe"),
            const Text(
              "Cập nhật ảnh mặt trước và mặt sau để xác thực tài khoản.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildLicenseImage(
                    title: "Mặt Trước",
                    imageFile: _licenseFrontImage,
                    networkUrl: user?['LICENSE_FRONT_URL'],
                    onTap: () => _pickImage('license_front'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildLicenseImage(
                    title: "Mặt Sau",
                    imageFile: _licenseBackImage,
                    networkUrl: user?['LICENSE_BACK_URL'],
                    onTap: () => _pickImage('license_back'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            _buildSectionTitle("Bảo mật"),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
              const Icon(Icons.lock_outline, color: Colors.white70),
              title: const Text('Đổi mật khẩu',
                  style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.arrow_forward_ios,
                  color: Colors.white70, size: 16),
              onTap:
              _showChangePasswordDialog, // Gọi hàm đổi mật khẩu mới
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1CE88A),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Lưu Thay Đổi',
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLicenseImage({
    required String title,
    File? imageFile,
    String? networkUrl,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white, // Đặt nền trắng để dễ nhìn ảnh trong suốt
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(8),
            ),
            // Sử dụng ClipRRect để bo góc ảnh bên trong container
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageFile != null
                  ? Image.file(imageFile,
                  fit: BoxFit.contain) 
                  : (networkUrl != null
                  ? Image.network(
                "${ApiService().baseUrl}/images/$networkUrl",
                fit: BoxFit.contain, 
                errorBuilder: (context, error, stackTrace) =>
                const Center(
                    child: Icon(Icons.broken_image,
                        color: Colors.grey)),
              )
                  : const Center(
                  child: Icon(Icons.add_a_photo,
                      color: Colors.black54, size: 32))),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(title,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildTextFormField(TextEditingController controller, String label,
      {TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF1CE88A))),
      ),
    );
  }

  Widget _buildDialogTextField(TextEditingController controller, String label,
      {bool isPassword = false,
        TextInputType? keyboardType,
        String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.grey)),
        focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF1CE88A))),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
            color: Color(0xFF1CE88A),
            fontSize: 18,
            fontWeight: FontWeight.bold),
      ),
    );
  }
}