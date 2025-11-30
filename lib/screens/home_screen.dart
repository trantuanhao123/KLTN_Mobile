import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mobile/providers/user_provider.dart';
import 'package:mobile/providers/home_provider.dart';
import 'package:mobile/providers/car_provider.dart';
import 'package:mobile/api/api_service.dart';
import 'package:mobile/screens/car_list_screen.dart';
import 'package:mobile/screens/car_detail_screen.dart';
import 'package:mobile/screens/notification_screen.dart';
import 'package:carousel_slider/carousel_slider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _notificationTimer;
  int _lastNotificationId = 0;

  @override
  void initState() {
    super.initState();
    LocalNotificationHelper.initialize((details) {
      // Điều hướng sang màn hình NotificationScreen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const NotificationScreen()),
      );
    });
    _startNotificationPolling();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  void _startNotificationPolling() {
    _checkNewNotifications();
    _notificationTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      _checkNewNotifications();
    });
  }

  Future<void> _checkNewNotifications() async {
    try {
      final apiService = ApiService();
      final notifications = await apiService.getNotifications();

      if (notifications.isNotEmpty) {
        notifications.sort((a, b) => (b['NOTIFICATION_ID'] ?? 0).compareTo(a['NOTIFICATION_ID'] ?? 0));
        final newest = notifications.first;
        final newestId = newest['NOTIFICATION_ID'] as int;

        if (_lastNotificationId != 0 && newestId > _lastNotificationId) {
          LocalNotificationHelper.showNotification(
            id: newestId,
            title: newest['TITLE'] ?? 'Thông báo mới',
            body: newest['CONTENT'] ?? 'Bạn có thông báo mới từ hệ thống.',
          );
        }
        _lastNotificationId = newestId;
      }
    } catch (e) {
      debugPrint("Lỗi polling notification: $e");
    }
  }

  // ==================== HÀM HIỆN POPUP KHI NHẤN BANNER ====================
  void _showBannerInfo(BuildContext context, Map<String, dynamic> banner) {
    final apiService = ApiService();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 680),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ảnh banner + nút đóng
              Stack(
                children: [
                  if (banner['IMAGE_URL'] != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: Image.network(
                        banner['IMAGE_URL'].toString().startsWith('http')
                            ? banner['IMAGE_URL']
                            : "${apiService.baseUrl}/images/${banner['IMAGE_URL']}",
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 220,
                          color: Colors.grey[800],
                          child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 60),
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 220,
                      decoration: const BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: const Center(child: Icon(Icons.local_offer, size: 80, color: Colors.white54)),
                    ),

                  // Nút đóng
                  Positioned(
                    top: 10,
                    right: 10,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ],
              ),

              // Nội dung ưu đãi
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        banner['TITLE'] ?? 'Ưu đãi đặc biệt',
                        style: const TextStyle(
                          color: Color(0xFF1CE88A),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        banner['DESCRIPTION'] ?? 'Đừng bỏ lỡ cơ hội thuê xe với giá cực tốt ngay hôm nay!',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF1CE88A), width: 1),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Color(0xFF1CE88A), size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Mã giảm giá số lượng có hạn – Nhanh tay dùng ngay!',
                                style: TextStyle(color: Color(0xFF1CE88A), fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Nút hành động
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // Đóng popup trước
                      // Chuyển sang màn hình thuê xe
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CarListScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.directions_car, color: Colors.black),
                    label: const Text(
                      'Đặt xe ngay',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1CE88A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBannerList(List<dynamic> banners) {
    if (banners.isEmpty) {
      return Container(
        height: 180,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('Không có ưu đãi nào', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final apiService = ApiService();

    return CarouselSlider.builder(
      itemCount: banners.length,
      options: CarouselOptions(
        height: 180,
        autoPlay: true,
        autoPlayInterval: const Duration(seconds: 5),
        enlargeCenterPage: true,
        viewportFraction: 0.92,
        aspectRatio: 16 / 9,
        enableInfiniteScroll: banners.length > 1,
      ),
      itemBuilder: (context, index, realIndex) {
        final banner = banners[index];
        final String? imageUrlRaw = banner['IMAGE_URL'];
        final String imageUrl = imageUrlRaw != null && imageUrlRaw.toString().startsWith('http')
            ? imageUrlRaw
            : imageUrlRaw != null
            ? "${apiService.baseUrl}/images/$imageUrlRaw"
            : '';

        return GestureDetector(
          onTap: () => _showBannerInfo(context, banner),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.grey[800],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl.isNotEmpty)
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey[800],
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF1CE88A),
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[800],
                          child: const Icon(Icons.broken_image, color: Colors.grey, size: 50),
                        );
                      },
                    )
                  else
                    Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.local_offer, color: Colors.white54, size: 60),
                    ),

                  // Lớp tối dần + tiêu đề
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),

                  // Tiêu đề banner
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Text(
                      banner['TITLE'] ?? 'Ưu đãi đặc biệt',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            blurRadius: 10,
                            color: Colors.black87,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<UserProvider, HomeProvider>(
      builder: (context, userProvider, homeProvider, child) {
        final user = userProvider.user;

        // [ĐÃ SỬA] Logic hiển thị Avatar nhỏ ở Home
        ImageProvider? avatarProvider;
        final String? avatarUrl = user?['AVATAR_URL'];

        if (avatarUrl != null && avatarUrl.isNotEmpty && !avatarUrl.contains('default-avatar')) {
          String finalUrl = avatarUrl.startsWith('http')
              ? avatarUrl
              : "${ApiService().baseUrl}/images/$avatarUrl";
          avatarProvider = NetworkImage(finalUrl);
        } else {
          avatarProvider = const AssetImage('assets/default-avatar.png'); // Ảnh mặc định đúng
        }

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
                  backgroundImage: avatarProvider, // Dùng provider đã xử lý
                  // Bỏ child icon vì đã có asset
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Xin chào', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                    Text(
                      user?['FULLNAME']?.split(' ').last ?? 'Bạn',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())),
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
              await Future.wait([
                homeProvider.fetchHomeData(),
                Provider.of<CarProvider>(context, listen: false).fetchAllData(),
              ]);
            },
            color: const Color(0xFF1CE88A),
            backgroundColor: Colors.grey[900],
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  // BANNER
                  _buildBannerList(homeProvider.banners),
                  const SizedBox(height: 24),

                  _buildSectionHeader(context, 'Thương hiệu', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CarListScreen()));
                  }),
                  _buildBrandsSection(context, homeProvider.brands),
                  const SizedBox(height: 24),

                  _buildSectionHeader(context, 'Xe phổ biến', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CarListScreen()));
                  }),
                  _buildPopularCarsSection(context, homeProvider.popularCars),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Các hàm UI khác giữ nguyên
  Widget _buildSectionHeader(BuildContext context, String title, VoidCallback onViewAll) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          TextButton(
            onPressed: onViewAll,
            style: TextButton.styleFrom(foregroundColor: Colors.grey[400], padding: EdgeInsets.zero),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [Text('Xem tất cả'), SizedBox(width: 4), Icon(Icons.arrow_forward_ios, size: 12)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandsSection(BuildContext context, List<String> brands) {
    if (brands.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: brands.length,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemBuilder: (context, index) {
          final brandName = brands[index];
          final firstLetter = brandName.isNotEmpty ? brandName[0].toUpperCase() : '?';
          return Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CarListScreen(initialBrandFilter: brandName))),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade700, width: 1),
                    ),
                    alignment: Alignment.center,
                    child: Text(firstLetter, style: const TextStyle(color: Color(0xFF1CE88A), fontWeight: FontWeight.bold, fontSize: 22)),
                  ),
                  const SizedBox(height: 8),
                  Text(brandName, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPopularCarsSection(BuildContext context, List<dynamic> popularCars) {
    if (popularCars.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 195,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: popularCars.length,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemBuilder: (context, index) {
          final car = popularCars[index];
          final imageUrl = car['mainImageUrl'];
          final fullCarImageUrl = imageUrl != null ? "${ApiService().baseUrl}/images/$imageUrl" : null;

          return Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CarDetailScreen(car: car))),
              child: Container(
                width: 150,
                decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: fullCarImageUrl != null
                          ? Image.network(fullCarImageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40))
                          : const Icon(Icons.directions_car, color: Colors.grey, size: 50),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        "${car['BRAND'] ?? ''} ${car['MODEL'] ?? ''}",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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

// LocalNotificationHelper giữ nguyên
class LocalNotificationHelper {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  // 1. Thêm tham số onNotificationTap vào hàm initialize
  static Future<void> initialize(Function(NotificationResponse) onNotificationTap) async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    // 2. Thêm tham số onDidReceiveNotificationResponse
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onNotificationTap,
    );

    if (Platform.isAndroid) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'promotion_channel',
      'Khuyến mãi & Tin tức',
      channelDescription: 'Nhận thông báo mới từ hệ thống',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(id, title, body, details);
  }
}