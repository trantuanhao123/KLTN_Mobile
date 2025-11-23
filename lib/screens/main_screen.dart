import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:mobile/providers/home_provider.dart';
import 'package:mobile/providers/car_provider.dart';

import 'package:mobile/screens/home_screen.dart';
import 'package:mobile/screens/car_list_screen.dart';
import 'package:mobile/screens/my_booking_screen.dart';
import 'package:mobile/screens/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // Danh sách các màn hình con
  final List<Widget> _screens = [
    const HomeScreen(),
    const CarListScreen(),
    const MyBookingScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final homeProvider = Provider.of<HomeProvider>(context, listen: false);
      final carProvider = Provider.of<CarProvider>(context, listen: false);

      print("MainScreen: Đã đăng nhập. Bắt đầu tải dữ liệu...");

      // Tải dữ liệu trang chủ (Banner, Xe nổi bật)
      homeProvider.fetchHomeData();

      // Tải dữ liệu danh sách xe (Xe, Danh mục, Chi nhánh)
      carProvider.fetchAllData();
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Màu nền tối cho toàn app
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.house),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.car),
            label: 'Thuê xe',
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.calendarCheck),
            label: 'Lịch xe',
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.user),
            label: 'Cá nhân',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF1CE88A),
        unselectedItemColor: Colors.grey,
        backgroundColor: const Color(0xFF1E1E1E),
        type: BottomNavigationBarType.fixed, // Giữ cố định vị trí các icon
        onTap: _onItemTapped,
        showUnselectedLabels: true,
      ),
    );
  }
}