import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/providers/user_provider.dart';
import 'package:mobile/screens/edit_profile_screen.dart';
import 'package:mobile/providers/auth_provider.dart';
import 'package:mobile/api/api_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final user = userProvider.user;
        final avatarUrl = user?['AVATAR_URL'];
        final fullAvatarUrl = avatarUrl != null
            ? "${ApiService().baseUrl}/images/$avatarUrl"
            : null;

        final bool isVerified = (user?['VERIFIED'] == 1 || user?['VERIFIED'] == true);

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: const Text('Hồ Sơ',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const EditProfileScreen(),
                    ),
                  ).then((_) {
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
                    backgroundImage: fullAvatarUrl != null
                        ? NetworkImage(fullAvatarUrl)
                        : null,
                    child: fullAvatarUrl == null
                        ? const Icon(Icons.person, size: 50, color: Colors.white70)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    user['FULLNAME'] ?? 'Chưa có tên',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),

                // HUY HIỆU XÁC THỰC
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isVerified
                          ? Colors.green.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: isVerified ? Colors.green : Colors.red, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isVerified ? Icons.verified : Icons.gpp_bad,
                          color: isVerified ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isVerified ? "Đã xác thực tài khoản" : "Chưa xác thực",
                          style: TextStyle(
                            color: isVerified ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
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
                      ? formatDateString(user['BIRTHDATE']) // Gọi hàm đã sửa
                      : 'Chưa cập nhật',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileInfoTile(
      {required IconData icon, required String title, required String subtitle}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
      leading: Icon(icon, color: Colors.white70, size: 28),
      title: Text(title, style: const TextStyle(color: Colors.white70)),
      subtitle: Text(subtitle,
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
    );
  }

  // [SỬA LỖI] Thêm .toLocal() để hiển thị đúng múi giờ Việt Nam
  String formatDateString(String dateString) {
    try {
      // Chuyển đổi từ UTC (Server) sang Local (Điện thoại) trước khi lấy ngày
      final dateTime = DateTime.parse(dateString).toLocal();
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return dateString;
    }
  }
}