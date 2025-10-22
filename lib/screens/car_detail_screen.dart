import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/api/api_service.dart';
import 'booking_screen.dart';

class CarDetailScreen extends StatelessWidget {
  final Map<String, dynamic> car;

  const CarDetailScreen({super.key, required this.car});

  @override
  Widget build(BuildContext context) {
    final priceFormat = NumberFormat.simpleCurrency(locale: 'vi-VN', decimalDigits: 0);
    final fullCarImageUrl = car['mainImageUrl'] != null
        ? "${ApiService().baseUrl}/images/${car['mainImageUrl']}"
        : null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('${car['BRAND'] ?? ''} ${car['MODEL'] ?? ''}', style: const TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Phần hình ảnh ---
            Container(
              height: 250,
              width: double.infinity,
              color: Colors.grey[900],
              child: fullCarImageUrl != null
                  ? Image.network(
                fullCarImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.image_not_supported, color: Colors.grey, size: 50),
              )
                  : const Icon(Icons.directions_car, color: Colors.grey, size: 50),
            ),
            // --- Phần thông tin chính ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${car['BRAND'] ?? ''} ${car['MODEL'] ?? ''}',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    priceFormat.format(double.tryParse(car['PRICE_PER_DAY'].toString()) ?? 0.0) + '/ngày',
                    style: const TextStyle(color: Color(0xFF1CE88A), fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),

                  // --- Phần thông số kỹ thuật ---
                  const Text('Thông số kỹ thuật', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildInfoRow(Icons.local_gas_station_outlined, 'Nhiên liệu', car['FUEL_TYPE'] ?? 'N/A'),
                  _buildInfoRow(Icons.settings_outlined, 'Hộp số', car['TRANSMISSION'] ?? 'N/A'),
                  _buildInfoRow(Icons.color_lens_outlined, 'Màu sắc', car['COLOR'] ?? 'N/A'),
                  _buildInfoRow(Icons.speed_outlined, 'Số dặm đã đi', '${car['CURRENT_MILEAGE'] ?? 0} km'),

                  const SizedBox(height: 24),

                  // --- Phần mô tả ---
                  const Text('Mô tả', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    car['DESCRIPTION'] ?? 'Không có mô tả chi tiết cho chiếc xe này.',
                    style: TextStyle(color: Colors.grey[400], fontSize: 15, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // --- Nút Đặt xe ---
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1CE88A),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => BookingScreen(car: car)),
            );
          },
          child: const Text('Thuê ngay', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[400], size: 20),
          const SizedBox(width: 16),
          Text('$title:', style: TextStyle(color: Colors.grey[400], fontSize: 15)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}