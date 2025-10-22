import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/providers/user_provider.dart';
import 'package:mobile/screens/edit_profile_screen.dart';
import 'package:mobile/providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Sử dụng Consumer để tự động cập nhật UI khi UserProvider thay đổi
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final user = userProvider.user;
        final avatarUrl = user?['AVATAR_URL'];
        // Xây dựng URL đầy đủ cho ảnh đại diện
        final fullAvatarUrl = avatarUrl != null ? "http://192.168.1.5:8080/images/$avatarUrl" : null;

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: const Text('Hồ Sơ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      // Chuyển sang màn hình chỉnh sửa và chờ kết quả
                      builder: (context) => const EditProfileScreen(),
                    ),
                  ).then((_) {
                    // Sau khi màn hình chỉnh sửa đóng lại, làm mới dữ liệu
                    userProvider.fetchUserProfile();
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                tooltip: 'Đăng xuất',
                onPressed: () {
                  Provider.of<AuthProvider>(context, listen: false).logout();
                },
              ),
            ],
          ),
          body: user == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
            onRefresh: () => userProvider.fetchUserProfile(),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey.shade800,
                    // Sử dụng URL đầy đủ đã xây dựng
                    backgroundImage: fullAvatarUrl != null ? NetworkImage(fullAvatarUrl) : null,
                    child: fullAvatarUrl == null
                        ? const Icon(Icons.person, size: 50, color: Colors.white70)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    user['FULLNAME'] ?? 'Chưa có tên',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    user['EMAIL'] ?? 'Chưa có email',
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 32),
                const Divider(color: Colors.white24),
                _buildProfileInfoTile(
                  icon: Icons.phone_outlined,
                  title: 'Số điện thoại',
                  subtitle: user['PHONE'] ?? 'Chưa cập nhật',
                ),
                _buildProfileInfoTile(
                  icon: Icons.home_outlined,
                  title: 'Địa chỉ',
                  subtitle: user['ADDRESS'] ?? 'Chưa cập nhật',
                ),
                _buildProfileInfoTile(
                  icon: Icons.cake_outlined,
                  title: 'Ngày sinh',
                  subtitle: user['BIRTHDATE'] != null
                      ? formatDateString(user['BIRTHDATE'])
                      : 'Chưa cập nhật',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Widget con để hiển thị thông tin
  Widget _buildProfileInfoTile({required IconData icon, required String title, required String subtitle}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
      leading: Icon(icon, color: Colors.white70, size: 28),
      title: Text(title, style: const TextStyle(color: Colors.white70)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
    );
  }

  // Hàm helper để định dạng lại ngày tháng
  String formatDateString(String dateString) {
    try {
      final dateTime = DateTime.parse(dateString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return dateString; // Trả về chuỗi gốc nếu không thể parse
    }
  }
}