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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _notificationTimer;
  int _lastNotificationId = 0; // Lưu ID thông báo mới nhất để tránh hiện trùng

  @override
  void initState() {
    super.initState();

    // 1. Khởi tạo tính năng thông báo
    LocalNotificationHelper.initialize();

    // 2. Bắt đầu chạy ngầm kiểm tra thông báo mới
    _startNotificationPolling();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel(); // Hủy chạy ngầm khi thoát màn hình
    super.dispose();
  }

  /// Hàm chạy định kỳ để kiểm tra tin mới
  void _startNotificationPolling() {
    // Kiểm tra ngay lần đầu mở app
    _checkNewNotifications();

    // Sau đó cứ 60 giây kiểm tra 1 lần
    _notificationTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      _checkNewNotifications();
    });
  }

  /// Gọi API lấy danh sách và so sánh
  Future<void> _checkNewNotifications() async {
    try {
      final apiService = ApiService();
      // Gọi API lấy danh sách thông báo
      final notifications = await apiService.getNotifications();

      if (notifications.isNotEmpty) {
        // Sắp xếp để lấy cái mới nhất (ID lớn nhất)
        notifications.sort((a, b) => (b['NOTIFICATION_ID'] ?? 0).compareTo(a['NOTIFICATION_ID'] ?? 0));

        final newest = notifications.first;
        final newestId = newest['NOTIFICATION_ID'] as int;

        // Nếu ID mới nhận được > ID đã lưu => Có thông báo mới
        if (_lastNotificationId != 0 && newestId > _lastNotificationId) {
          // HIỆN THÔNG BÁO "TING TING"
          LocalNotificationHelper.showNotification(
            id: newestId,
            title: newest['TITLE'] ?? 'Thông báo mới',
            body: newest['CONTENT'] ?? 'Bạn có thông báo mới từ hệ thống.',
          );
        }

        // Cập nhật lại ID mới nhất
        _lastNotificationId = newestId;
      }
    } catch (e) {
      debugPrint("Lỗi polling notification: $e");
    }
  }

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
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NotificationScreen()),
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
                  _buildBannerSection(homeProvider.banners),
                  const SizedBox(height: 24),
                  _buildSectionHeader(context,'Thương hiệu', () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const CarListScreen()));
                  }),
                  _buildBrandsSection(context, homeProvider.brands),
                  const SizedBox(height: 24),
                  _buildSectionHeader(context,'Xe phổ biến', () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const CarListScreen()));
                  }),
                  _buildPopularCarsSection(context, homeProvider.popularCars),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- CÁC WIDGET UI ---

  Widget _buildSectionHeader(BuildContext context, String title, VoidCallback onViewAll) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          TextButton(
            onPressed: onViewAll,
            style: TextButton.styleFrom(foregroundColor: Colors.grey[400], padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [Text('Xem tất cả'), SizedBox(width: 4), Icon(Icons.arrow_forward_ios, size: 12)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerSection(List<dynamic> banners) {
    if (banners.isEmpty) {
      return Container(
        height: 150, margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(20)),
        child: const Center(child: Text("Không có ưu đãi", style: TextStyle(color: Colors.grey))),
      );
    }
    return Container(
      height: 150, margin: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal, itemCount: banners.length, padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemBuilder: (context, index) {
          final banner = banners[index];
          final imageUrl = banner['IMAGE_URL'] != null ? "${ApiService().baseUrl}/images/${banner['IMAGE_URL']}" : null;
          return Container(
            width: 300, padding: const EdgeInsets.only(right: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl != null ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey[800], child: const Icon(Icons.error_outline, color: Colors.grey))) : Container(color: Colors.grey[800], child: const Icon(Icons.image, color: Colors.grey)),
                  Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.7)], stops: const [0.5, 1.0]))),
                  Positioned(bottom: 16, left: 16, right: 16, child: Text(banner['TITLE'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 2, color: Colors.black54)]), maxLines: 2, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          );
        },
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
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => CarListScreen(initialBrandFilter: brandName)));
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Ô tròn chứa chữ cái
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[800], // Màu nền xám
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade700, width: 1),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      firstLetter,
                      style: const TextStyle(
                        color: Color(0xFF1CE88A),
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                      brandName,
                      style: const TextStyle(color: Colors.white70, fontSize: 12)
                  ),
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
        scrollDirection: Axis.horizontal, itemCount: popularCars.length, padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemBuilder: (context, index) {
          final car = popularCars[index];
          final imageUrl = car['mainImageUrl'];
          final fullCarImageUrl = imageUrl != null ? "${ApiService().baseUrl}/images/$imageUrl" : null;
          return Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => CarDetailScreen(car: car))); },
              child: Container(
                width: 150, decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(12)), clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: Container(color: Colors.grey[800], child: fullCarImageUrl != null ? Image.network(fullCarImageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40))) : const Center(child: Icon(Icons.directions_car, color: Colors.grey, size: 50)))),
                    Padding(padding: const EdgeInsets.all(10.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text("${car['BRAND'] ?? ''} ${car['MODEL'] ?? ''}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis)])),
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

class LocalNotificationHelper {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // Khởi tạo (Gọi ở initState)
  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
    DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(initializationSettings);

    if (Platform.isAndroid) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  // Hàm hiển thị thông báo
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'promotion_channel', // ID kênh
      'Khuyến mãi & Tin tức', // Tên kênh
      channelDescription: 'Nhận thông báo mới từ hệ thống',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails details =
    NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(id, title, body, details);
  }
}