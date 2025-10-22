import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/api/api_service.dart';
import 'package:mobile/screens/payment_webview_screen.dart';

class BookingScreen extends StatefulWidget {
  final Map<String, dynamic> car;
  const BookingScreen({super.key, required this.car});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTimeRange? _selectedDateRange;
  bool _isLoading = false;

  int get _numberOfDays {
    if (_selectedDateRange == null) return 0;
    // Thêm 1 để tính cả ngày cuối cùng
    return _selectedDateRange!.duration.inDays + 1;
  }

  double get _totalPrice {
    final pricePerDay = double.tryParse(widget.car['PRICE_PER_DAY'].toString()) ?? 0.0;
    return _numberOfDays * pricePerDay;
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  Future<void> _confirmBooking() async {
    if (_selectedDateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ngày thuê xe.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    final apiService = ApiService();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // Rút ngắn mô tả để đảm bảo không vượt quá 25 ký tự
      String description = 'TT thue xe ${widget.car['BRAND']}';
      if (description.length > 25) {
        description = description.substring(0, 25);
      }

      final paymentUrl = await apiService.createPaymentLink(
        amount: _totalPrice,
        description: description,
      );

      // Điều hướng đến màn hình WebView để hiển thị thanh toán
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PaymentWebViewScreen(url: paymentUrl)),
      );

      // Xử lý kết quả sau khi đóng WebView
      if (result == 'success') {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Thanh toán thành công!'), backgroundColor: Colors.green),
        );
        // Quay về màn hình danh sách xe
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else if (result == 'cancelled') {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Bạn đã hủy thanh toán.'), backgroundColor: Colors.orange),
        );
      }

    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.red),
      );
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final priceFormat = NumberFormat.simpleCurrency(locale: 'vi-VN', decimalDigits: 0);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Xác nhận Thuê xe', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Image.network(
                "${ApiService().baseUrl}/images/${widget.car['mainImageUrl']}",
                width: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Container(width: 80, color: Colors.grey[800], child: Icon(Icons.directions_car, color: Colors.grey)),
              ),
              title: Text('${widget.car['BRAND']} ${widget.car['MODEL']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text(
                priceFormat.format(double.tryParse(widget.car['PRICE_PER_DAY'].toString()) ?? 0.0) + '/ngày',
                style: const TextStyle(color: Color(0xFF1CE88A)),
              ),
            ),
            const Divider(color: Colors.white24, height: 32),
            const Text('Chọn thời gian thuê', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _selectDateRange(context),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[800]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedDateRange == null
                          ? 'Nhấn để chọn ngày bắt đầu & kết thúc'
                          : '${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.end)}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const Icon(Icons.calendar_today, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Số ngày thuê:', style: TextStyle(color: Colors.grey, fontSize: 16)),
                Text('$_numberOfDays ngày', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tổng cộng:', style: TextStyle(color: Colors.grey, fontSize: 18)),
                Text(
                  priceFormat.format(_totalPrice),
                  style: const TextStyle(color: Color(0xFF1CE88A), fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1CE88A),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          onPressed: _isLoading ? null : _confirmBooking,
          child: _isLoading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black))
              : const Text('Thanh toán', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}