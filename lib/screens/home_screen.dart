import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // Import intl để dùng NumberFormat
import 'package:mobile/providers/auth_provider.dart';
import 'package:mobile/providers/user_provider.dart';
import 'package:mobile/providers/home_provider.dart';
import 'package:mobile/api/api_service.dart';
import 'package:mobile/screens/car_list_screen.dart';
import 'package:mobile/screens/car_detail_screen.dart';
import 'package:mobile/providers/car_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<UserProvider, HomeProvider>(
      builder: (context, userProvider, homeProvider, child) {
        final user = userProvider.user;
        final avatarUrl = user?['AVATAR_URL'];
        final fullAvatarUrl = avatarUrl != null
            ? "${ApiService().baseUrl}/images/$avatarUrl"
            : null;

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            title: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade800,
                  backgroundImage: fullAvatarUrl != null ? NetworkImage(fullAvatarUrl) : null,
                  child: fullAvatarUrl == null
                      ? const Icon(Icons.person_outline, color: Colors.white70, size: 20,)
                      : null,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Xin chào',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                    Text(
                      // Lấy tên cuối cùng sau dấu cách cuối cùng
                      user?['FULLNAME']?.split(' ').last ?? 'Bạn',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: () {
                  // TODO: Điều hướng đến màn hình thông báo
                  print('Navigate to Notifications');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chức năng Thông báo chưa được cài đặt.'), backgroundColor: Colors.orange),
                  );
                },
                icon: const Icon(Icons.notifications_none, color: Colors.white),
              ),
            ],
          ),
          body: homeProvider.isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF1CE88A)))
              : homeProvider.error != null
              ? Center(child: Text('Lỗi tải dữ liệu: ${homeProvider.error!}', style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
            onRefresh: () async {
              // Tải lại dữ liệu trang chủ VÀ dữ liệu danh sách xe để đảm bảo provider được cập nhật
              await Future.wait([
                homeProvider.fetchHomeData(),
                Provider.of<CarProvider>(context, listen: false).fetchAllData(),
              ]);
            },
            color: const Color(0xFF1CE88A), // Màu của indicator
            backgroundColor: Colors.grey[900], // Màu nền của indicator
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(), // Luôn cho phép cuộn để Refresh hoạt động
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  // --- Banner Section ---
                  _buildBannerSection(homeProvider.banners),
                  const SizedBox(height: 24),

                  // --- Brands Section ---
                  _buildSectionHeader(
                      context,
                      'Thương hiệu',
                          () {
                        // Điều hướng đến CarListScreen không filter
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CarListScreen()),
                        );
                      }
                  ),
                  _buildBrandsSection(context, homeProvider.brands),
                  const SizedBox(height: 24),

                  // --- Popular Cars Section ---
                  _buildSectionHeader(
                      context,
                      'Xe phổ biến',
                          () {
                        // Điều hướng đến CarListScreen không filter
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CarListScreen()),
                        );
                      }
                  ),
                  _buildPopularCarsSection(context, homeProvider.popularCars), // Gọi hàm đã sửa layout
                  const SizedBox(height: 24), // Khoảng trống cuối trang
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Widget Header cho các section (Thương hiệu, Xe phổ biến)
  Widget _buildSectionHeader(BuildContext context, String title, VoidCallback onViewAll) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          TextButton(
            onPressed: onViewAll,
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[400], // Màu chữ nút
              padding: EdgeInsets.zero, // Bỏ padding thừa
              visualDensity: VisualDensity.compact, // Giảm khoảng cách
            ),
            child: Row( // Thêm icon mũi tên
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('Xem tất cả'),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios, size: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget hiển thị Banner
  Widget _buildBannerSection(List<dynamic> banners) {
    if (banners.isEmpty) {
      // Hiển thị placeholder nếu không có banner
      return Container(
        height: 150,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(20)),
        child: const Center(child: Text("Không có ưu đãi", style: TextStyle(color: Colors.grey))),
      );
    }
    // Slider Banner
    return Container(
      height: 150, // Chiều cao cố định cho banner
      margin: const EdgeInsets.symmetric(vertical: 16), // Khoảng cách trên dưới
      child: ListView.builder(
        scrollDirection: Axis.horizontal, // Cuộn ngang
        itemCount: banners.length,
        padding: const EdgeInsets.symmetric(horizontal: 16.0), // Padding 2 đầu list
        itemBuilder: (context, index) {
          final banner = banners[index];
          final imageUrl = banner['IMAGE_URL'] != null ? "${ApiService().baseUrl}/images/${banner['IMAGE_URL']}" : null;
          // Mỗi item banner
          return Container(
            width: 300, // Chiều rộng cố định cho banner
            padding: const EdgeInsets.only(right: 16), // Khoảng cách giữa các banner
            child: ClipRRect( // Bo góc
              borderRadius: BorderRadius.circular(20),
              child: Stack( // Chồng lớp Gradient và Text lên ảnh
                fit: StackFit.expand, // Cho các lớp con giãn hết cỡ
                children: [
                  // Ảnh nền
                  imageUrl != null
                      ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover, // Ảnh fill container
                    errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[800], child: const Icon(Icons.error_outline, color: Colors.grey)), // Hiển thị lỗi
                    loadingBuilder: (context, child, loadingProgress) { // Hiển thị loading
                      if (loadingProgress == null) return child; // Load xong thì hiện ảnh (child)
                      return Container(color: Colors.grey[900], child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey[700])));
                    },
                  )
                      : Container(color: Colors.grey[800], child: const Icon(Icons.image, color: Colors.grey)), // Placeholder nếu URL null
                  // Lớp phủ Gradient mờ ở dưới
                  Container(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withOpacity(0.7)], // Từ trong suốt -> đen mờ
                            stops: const [0.5, 1.0] // Gradient bắt đầu từ giữa ảnh xuống
                        )
                    ),
                  ),
                  // Tiêu đề Banner
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16, // Để text không tràn ra ngoài
                    child: Text(
                      banner['TITLE'] ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 2, color: Colors.black54)]), // Thêm đổ bóng cho dễ đọc
                      maxLines: 2, // Giới hạn 2 dòng
                      overflow: TextOverflow.ellipsis, // Hiển thị ... nếu quá dài
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Widget hiển thị danh sách Thương hiệu
  Widget _buildBrandsSection(BuildContext context, List<String> brands) {
    if (brands.isEmpty) return const SizedBox.shrink(); // Ẩn nếu không có brand
    return SizedBox(
      height: 80, // Chiều cao cố định cho list ngang
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: brands.length,
        padding: const EdgeInsets.symmetric(horizontal: 16.0), // Padding 2 đầu list
        itemBuilder: (context, index) {
          final brandName = brands[index];
          // Mỗi item brand
          return Padding(
            padding: const EdgeInsets.only(right: 20.0), // Khoảng cách giữa các brand
            child: GestureDetector( // Cho phép nhấn vào
              onTap: () {
                // Điều hướng đến CarListScreen với filter brand
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CarListScreen(initialBrandFilter: brandName),
                  ),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, // Căn giữa icon và text
                children: [
                  CircleAvatar( // Icon brand (có thể thay bằng logo nếu có)
                    radius: 25,
                    backgroundColor: Colors.grey[900], // Màu nền icon
                    child: const Icon(Icons.directions_car_filled, color: Colors.white70, size: 22,),
                  ),
                  const SizedBox(height: 8),
                  Text(brandName, style: const TextStyle(color: Colors.white70, fontSize: 12)), // Tên brand
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Widget hiển thị danh sách Xe phổ biến (Đã chỉnh sửa layout)
  Widget _buildPopularCarsSection(BuildContext context, List<dynamic> popularCars) {
    if (popularCars.isEmpty) return const SizedBox.shrink(); // Ẩn nếu không có xe
    // final priceFormat = NumberFormat.simpleCurrency(locale: 'vi-VN', decimalDigits: 0); // Vẫn có thể cần nếu bạn muốn hiển thị lại giá

    return SizedBox(
      height: 195, // Chiều cao tổng thể của list ngang
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: popularCars.length,
        padding: const EdgeInsets.symmetric(horizontal: 16.0), // Padding cho list
        itemBuilder: (context, index) {
          final car = popularCars[index];
          final imageUrl = car['mainImageUrl'];
          final fullCarImageUrl = imageUrl != null ? "${ApiService().baseUrl}/images/$imageUrl" : null;
          // final pricePerDay = double.tryParse(car['PRICE_PER_DAY']?.toString() ?? '0.0') ?? 0.0;

          // Mỗi card xe
          return Padding(
            padding: const EdgeInsets.only(right: 16.0), // Khoảng cách giữa các card
            child: GestureDetector( // Cho phép nhấn vào card
              onTap: () {
                // Điều hướng đến CarDetailScreen khi nhấn vào
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CarDetailScreen(car: car),
                  ),
                );
              },
              child: Container(
                width: 150, // Chiều rộng của mỗi card
                decoration: BoxDecoration(
                  color: Colors.grey[900], // Màu nền card
                  borderRadius: BorderRadius.circular(12), // Bo góc card
                ),
                clipBehavior: Clip.antiAlias, // Cắt ảnh theo bo góc của Container
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch, // Cho con giãn ngang
                  children: [
                    // --- Phần ảnh ---
                    Expanded( // Cho ảnh chiếm phần không gian còn lại phía trên
                      child: Container(
                        color: Colors.grey[800], // Màu nền khi chờ ảnh
                        child: fullCarImageUrl != null
                            ? Image.network(
                          fullCarImageUrl,
                          fit: BoxFit.cover, // Ảnh fill container
                          errorBuilder: (context, error, stackTrace) =>
                          const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40)), // Hiển thị lỗi
                          loadingBuilder: (context, child, loadingProgress) { // Hiển thị loading
                            if (loadingProgress == null) return child;
                            return Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey[700]));
                          },
                        )
                            : const Center(child: Icon(Icons.directions_car, color: Colors.grey, size: 50)), // Placeholder nếu URL null
                      ),
                    ),
                    // --- Phần thông tin chữ ---
                    Padding(
                      padding: const EdgeInsets.all(10.0), // Padding xung quanh chữ
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, // Căn chữ sang trái
                        mainAxisSize: MainAxisSize.min, // Giữ chiều cao tối thiểu cho chữ
                        children: [
                          Text( // Tên xe (cho phép 2 dòng)
                            "${car['BRAND'] ?? ''} ${car['MODEL'] ?? ''}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13, // Cỡ chữ
                              height: 1.3, // Khoảng cách dòng
                            ),
                            maxLines: 2, // Tối đa 2 dòng
                            overflow: TextOverflow.ellipsis, // Hiển thị ... nếu quá dài
                          ),
                          // Giá tiền đã bị ẩn ở đây
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}