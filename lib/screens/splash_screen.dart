import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1D2D),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/app_icon.png',
              width: 120,
              height: 120,
              errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.directions_car, size: 100, color: Color(0xFF1CE88A)),
            ),
            const SizedBox(height: 30),
            // Vòng xoay loading
            const CircularProgressIndicator(
              color: Color(0xFF1CE88A),
            ),
            const SizedBox(height: 20),
            const Text(
              "Đang tải...",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            )
          ],
        ),
      ),
    );
  }
}