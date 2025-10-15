import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/providers/auth_provider.dart';
import 'package:mobile/providers/user_provider.dart';
import 'package:mobile/providers/home_provider.dart';
import 'package:mobile/api/api_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Sử dụng Consumer để lắng nghe cả hai provider
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
                  backgroundColor: Colors.grey.shade800,
                  backgroundImage: fullAvatarUrl != null ? NetworkImage(fullAvatarUrl) : null,
                  child: fullAvatarUrl == null
                      ? const Icon(Icons.person, color: Colors.white70)
                      : null,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Xin chào',
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                    Text(
                      user?['FULLNAME']?.split(' ').last ?? 'Bạn', // Lấy tên cuối
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_none, color: Colors.white),
              ),
              IconButton(
                onPressed: () => Provider.of<AuthProvider>(context, listen: false).logout(),
                icon: const Icon(Icons.logout, color: Colors.white),
                tooltip: 'Đăng xuất',
              ),
            ],
          ),
          body: homeProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : homeProvider.error != null
              ? Center(child: Text(homeProvider.error!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
            onRefresh: () => homeProvider.fetchHomeData(),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBannerSection(homeProvider.banners),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Thương hiệu', () {}),
                  _buildBrandsSection(homeProvider.brands),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Xe phổ biến', () {}),
                  _buildPopularCarsSection(homeProvider.popularCars),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onViewAll) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          TextButton(
            onPressed: onViewAll,
            child: Text('Xem tất cả', style: TextStyle(color: Colors.grey[400])),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerSection(List<dynamic> banners) {
    if (banners.isEmpty) {
      return const SizedBox(
        height: 150,
        child: Center(child: Text("Không có banner", style: TextStyle(color: Colors.grey))),
      );
    }
    return Container(
      height: 150,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: banners.length,
        itemBuilder: (context, index) {
          final banner = banners[index];
          final imageUrl = "${ApiService().baseUrl}/images/${banner['IMAGE_URL']}";
          return Container(
            width: 300,
            margin: EdgeInsets.only(left: index == 0 ? 24 : 0, right: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(20),
              image: DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  banner['TITLE'] ?? 'Ưu đãi đặc biệt',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBrandsSection(List<String> brands) {
    if (brands.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: brands.length,
        itemBuilder: (context, index) {
          return Container(
            width: 80,
            margin: EdgeInsets.only(left: index == 0 ? 24 : 0, right: 16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.grey[900],
                  child: const Icon(Icons.directions_car, color: Colors.white), // Có thể thay bằng logo hãng
                ),
                const SizedBox(height: 8),
                Text(brands[index], style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPopularCarsSection(List<dynamic> popularCars) {
    if (popularCars.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: popularCars.length,
        itemBuilder: (context, index) {
          final car = popularCars[index];
          final imageUrl = car['mainImageUrl'];
          final fullCarImageUrl = imageUrl != null ? "${ApiService().baseUrl}/images/$imageUrl" : null;

          return Container(
            width: 220,
            margin: EdgeInsets.only(left: index == 0 ? 24 : 0, right: 16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                if (fullCarImageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      fullCarImageUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                      const Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
                    ),
                  )
                else
                  const Center(child: Icon(Icons.directions_car, color: Colors.grey, size: 50)),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 15,
                  left: 15,
                  right: 15,
                  child: Text(
                    "${car['BRAND'] ?? ''} ${car['MODEL'] ?? ''}",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}