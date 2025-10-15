import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/providers/auth_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Dữ liệu mẫu để test
  final List<Map<String, dynamic>> brands = [
    {'icon': Icons.directions_car, 'name': 'BMW'},
    {'icon': Icons.directions_car, 'name': 'Mercedes'},
    {'icon': Icons.directions_car, 'name': 'Porsche'},
    {'icon': Icons.directions_car, 'name': 'Toyota'},
    {'icon': Icons.directions_car, 'name': 'Honda'},
    {'icon': Icons.directions_car, 'name': 'Hyundai'},
  ];

  final List<Map<String, dynamic>> popularCars = [
    {'image': 'https://hips.hearstapps.com/hmg-prod/images/2024-mercedes-benz-e-class-sedan-101-6446b1499b927.jpg', 'rating': 4.9},
    {'image': 'https://www.topgear.com/sites/default/files/2022/09/1-Mercedes-G-Class.jpg', 'rating': 4.9},
    {'image': 'https://images.prismic.io/carwow/23e98b0f-9860-4458-81c1-a53b53f68480_2023+Porsche+911+GT3+RS+front+three+quarters.jpg', 'rating': 4.9},
    {'image': 'https://i.ytimg.com/vi/lqLbsB5aFNk/maxresdefault.jpg', 'rating': 4.9},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(context), // Truyền context vào AppBar
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildBannerSection(),
            const SizedBox(height: 24),
            _buildSectionHeader('Các loại xe', () {}),
            _buildBrandsSection(),
            const SizedBox(height: 24),
            _buildSectionHeader('Xe phổ biến', () {}),
            _buildPopularCarsSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      title: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Colors.grey,
            child: Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Xin chào',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              const Text(
                'Bạn 👋',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
        //Nút Đăng xuất (tạm thời)
        IconButton(
          onPressed: () {
            Provider.of<AuthProvider>(context, listen: false).logout();
          },
          icon: const Icon(Icons.logout, color: Colors.white),
          tooltip: 'Đăng xuất',
        ),
      ],
    );
  }

  // Widget cho Banner quảng cáo
  Widget _buildBannerSection() {
    return Container(
      height: 150,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          const SizedBox(width: 16),
          _buildBannerCard(
              'https://images.prismic.io/carwow/23e98b0f-9860-4458-81c1-a53b53f68480_2023+Porsche+911+GT3+RS+front+three+quarters.jpg'),
          _buildBannerCard(
              'https://i.ytimg.com/vi/lqLbsB5aFNk/maxresdefault.jpg'),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildBannerCard(String imageUrl) {
    return Container(
      width: 300,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(20),
          image: DecorationImage(
            image: NetworkImage(imageUrl),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
          )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Khám phá', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('Đặt ngay >', style: TextStyle(color: Colors.green[300], fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // Widget cho tiêu đề các mục
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

  // Widget cho danh sách thương hiệu
  Widget _buildBrandsSection() {
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
                  child: Icon(brands[index]['icon'], color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(brands[index]['name'], style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          );
        },
      ),
    );
  }

  // Widget cho danh sách xe phổ biến
  Widget _buildPopularCarsSection() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: popularCars.length,
        itemBuilder: (context, index) {
          final car = popularCars[index];
          return Container(
            width: 220,
            margin: EdgeInsets.only(left: index == 0 ? 24 : 0, right: 16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    car['image'],
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: Colors.yellow, size: 14),
                        const SizedBox(width: 4),
                        Text(car['rating'].toString(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const Positioned(
                  top: 10,
                  right: 10,
                  child: Icon(Icons.favorite_border, color: Colors.white),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}