import 'package:flutter/material.dart';
import 'package:mobile/screens/home_screen.dart';

class BrandsScreen extends StatelessWidget {
  const BrandsScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(backgroundColor: Colors.black, body: Center(child: Text('Trang Thương Hiệu', style: TextStyle(color: Colors.white))));
}

class MyBookingScreen extends StatelessWidget {
  const MyBookingScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(backgroundColor: Colors.black, body: Center(child: Text('Trang Lịch Đặt Của Tôi', style: TextStyle(color: Colors.white))));
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(backgroundColor: Colors.black, body: Center(child: Text('Trang Hồ Sơ', style: TextStyle(color: Colors.white))));
}


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // Danh sách các màn hình tương ứng với các tab
  static const List<Widget> _widgetOptions = <Widget>[
    HomeScreen(),
    BrandsScreen(),
    MyBookingScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'Thương hiệu',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Lịch đặt',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Hồ sơ',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,

        // Cấu hình màu sắc cho theme tối
        backgroundColor: Colors.black,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1CE88A),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
      ),
    );
  }
}