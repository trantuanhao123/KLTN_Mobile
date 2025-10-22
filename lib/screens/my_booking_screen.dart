import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/api/api_service.dart';

class MyBookingScreen extends StatefulWidget {
  const MyBookingScreen({super.key});

  @override
  State<MyBookingScreen> createState() => _MyBookingScreenState();
}

class _MyBookingScreenState extends State<MyBookingScreen> {
  final ApiService _apiService = ApiService();
  Future<List<dynamic>>? _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  void _loadBookings() {
    setState(() {
      _bookingsFuture = _apiService.getUserBookings();
    });
  }

  // Hàm để lấy màu trạng thái
  Color _getStatusColor(String? status) {
    switch (status) {
      case 'CONFIRMED':
        return Colors.blueAccent;
      case 'IN_PROGRESS':
        return Colors.orangeAccent;
      case 'COMPLETED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.redAccent;
      case 'PENDING_PAYMENT':
        return Colors.grey;
      default:
        return Colors.white;
    }
  }

  // Hàm để dịch trạng thái (có thể mở rộng)
  String _translateStatus(String? status) {
    switch (status) {
      case 'CONFIRMED': return 'Đã xác nhận';
      case 'IN_PROGRESS': return 'Đang thuê';
      case 'COMPLETED': return 'Đã hoàn thành';
      case 'CANCELLED': return 'Đã hủy';
      case 'PENDING_PAYMENT': return 'Chờ thanh toán';
      default: return status ?? 'Không rõ';
    }
  }

  @override
  Widget build(BuildContext context) {
    final priceFormat = NumberFormat.simpleCurrency(locale: 'vi-VN', decimalDigits: 0);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm'); // Định dạng ngày giờ

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Lịch sử Đặt Xe', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // Ẩn nút back nếu nó là tab trong MainScreen
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadBookings(); // Tải lại dữ liệu khi kéo xuống
        },
        color: const Color(0xFF1CE88A), // Màu indicator
        backgroundColor: Colors.grey[900],
        child: FutureBuilder<List<dynamic>>(
          future: _bookingsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF1CE88A)));
            } else if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 50),
                      const SizedBox(height: 10),
                      Text(
                        'Lỗi: ${snapshot.error.toString().replaceFirst("Exception: ", "")}',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                          icon: Icon(Icons.refresh, size: 18),
                          label: Text('Thử lại'),
                          onPressed: _loadBookings,
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.black, backgroundColor: Colors.grey[300],
                          )
                      )
                    ],
                  ),
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('Bạn chưa có đơn đặt xe nào.', style: TextStyle(color: Colors.grey)));
            } else {
              final bookings = snapshot.data!;
              return ListView.builder(
                itemCount: bookings.length,
                itemBuilder: (context, index) {
                  final booking = bookings[index];
                  final carBrand = booking['CAR_BRAND'] ?? 'N/A';
                  final carModel = booking['CAR_MODEL'] ?? '';
                  final carImageUrl = booking['CAR_IMAGE_URL'] != null
                      ? "${ApiService().baseUrl}/images/${booking['CAR_IMAGE_URL']}"
                      : null;
                  final startDate = DateTime.tryParse(booking['START_DATE'] ?? '');
                  final endDate = DateTime.tryParse(booking['END_DATE'] ?? '');
                  final status = booking['STATUS'];
                  final finalAmount = double.tryParse(booking['FINAL_AMOUNT']?.toString() ?? '0.0') ?? 0.0;

                  return Card(
                    color: Colors.grey[900],
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          // Ảnh xe
                          Container(
                            width: 80, height: 60,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[800],
                            ),
                            child: carImageUrl != null
                                ? Image.network(carImageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.error, color: Colors.red[300]))
                                : const Icon(Icons.directions_car, color: Colors.grey, size: 30),
                          ),
                          const SizedBox(width: 12),
                          // Thông tin đặt xe
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$carBrand $carModel', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 4),
                                if (startDate != null && endDate != null)
                                  Text(
                                      '${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}',
                                      style: TextStyle(color: Colors.grey[400], fontSize: 12)
                                  ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text('Tổng: ', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                                    Text(priceFormat.format(finalAmount), style: const TextStyle(color: Color(0xFF1CE88A), fontWeight: FontWeight.w500, fontSize: 13)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Trạng thái
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _translateStatus(status),
                              style: TextStyle(color: _getStatusColor(status), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                },
              );
            }
          },
        ),
      ),
    );
  }
}