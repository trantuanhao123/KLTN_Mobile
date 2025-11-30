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

        // [ĐÃ SỬA] Logic hiển thị Avatar đồng bộ và xử lý đường dẫn đúng
        ImageProvider? avatarProvider;
        final String? avatarUrl = user?['AVATAR_URL'];

        if (avatarUrl != null && avatarUrl.isNotEmpty && !avatarUrl.contains('default-avatar')) {
          // Kiểm tra xem link có http chưa, nếu chưa thì nối thêm baseUrl
          String finalUrl = avatarUrl.startsWith('http')
              ? avatarUrl
              : "${ApiService().baseUrl}/images/$avatarUrl";
          avatarProvider = NetworkImage(finalUrl);
        } else {
          // [ĐÃ SỬA] Đường dẫn đúng là assets/default-avatar.png (không có thư mục images con)
          avatarProvider = const AssetImage('assets/default-avatar.png');
        }

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
                // --- PHẦN 1: THÔNG TIN USER ---
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF1CE88A), width: 2), // Thêm viền xanh cho đẹp
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey.shade800,
                      backgroundImage: avatarProvider,
                      // Không cần child icon nữa vì đã có ảnh mặc định assets
                    ),
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

                // Huy hiệu xác thực
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
                      ? formatDateString(user['BIRTHDATE'])
                      : 'Chưa cập nhật',
                ),

                // --- PHẦN 2: LIÊN HỆ HỖ TRỢ (Giữ nguyên code cũ của bạn) ---
                const Padding(
                  padding: EdgeInsets.only(top: 24.0, bottom: 8.0),
                  child: Divider(color: Colors.white24),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    "Liên hệ hỗ trợ",
                    style: TextStyle(
                        color: Color(0xFF1CE88A),
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                // Email hỗ trợ
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.email_outlined, color: Colors.white70),
                  title: const Text("Email", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  subtitle: const Text(
                    "trantuanhao308@gmail.com",
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                // Số điện thoại hỗ trợ
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.support_agent, color: Colors.white70),
                  title: const Text("Hotline", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  subtitle: const Text(
                    "0931504417",
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 40), // Khoảng trống dưới cùng
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

  String formatDateString(String dateString) {
    try {
      final dateTime = DateTime.parse(dateString).toLocal();
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return dateString;
    }
  }
}