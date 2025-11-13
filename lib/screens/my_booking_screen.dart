import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/api/api_service.dart';
import 'package:mobile/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class MyBookingScreen extends StatefulWidget {
  const MyBookingScreen({super.key});

  @override
  State<MyBookingScreen> createState() => _MyBookingScreenState();
}

class _MyBookingScreenState extends State<MyBookingScreen> {
  late Future<List<dynamic>> _bookingsFuture;
  final ApiService apiService = ApiService();

  // Controller cho form nhập thông tin hoàn tiền
  final _bankAccountController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _refundFormKey = GlobalKey<FormState>(); // Key để validate form

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  @override
  void dispose() {
    _bankAccountController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  /// Tải (hoặc tải lại) danh sách đơn hàng
  void _loadBookings() {
    setState(() {
      _bookingsFuture = apiService.getUserBookings(); // Vẫn gọi /login-orders
    });
  }

  /// Xử lý khi nhấn nút Hủy Đơn
  Future<void> _handleCancelBooking(Map<String, dynamic> booking) async {
    final int orderId = booking['ORDER_ID'];
    final String status = booking['STATUS'] ?? 'UNKNOWN'; // PENDING_PAYMENT, CONFIRMED...
    final String paymentStatus = (booking['PAYMENT_STATUS'] ?? 'unknown').toLowerCase(); // SỬA LỖI: Chuyển sang chữ thường

    String? bankAccount;
    String? bankName;
    String apiStatusToCall;

    // Ánh xạ STATUS và PAYMENT_STATUS sang API cần gọi
    if (status.toUpperCase() == 'PENDING_PAYMENT' && paymentStatus == 'unpaid') {
      apiStatusToCall = 'PENDING';
    }
    else if (status.toUpperCase() == 'CONFIRMED' && paymentStatus == 'partial') { // Đã cọc
      apiStatusToCall = 'PAID_DEPOSIT';
    }
    else if (status.toUpperCase() == 'CONFIRMED' && paymentStatus == 'paid') { // Đã thanh toán 100%
      apiStatusToCall = 'PAID_FULL';
    }
    else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể hủy đơn hàng ở trạng thái này (S:$status / PS:$paymentStatus).'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }


    // Nếu hủy đơn đã thanh toán 100%, yêu cầu nhập thông tin TKNH
    if (apiStatusToCall == 'PAID_FULL') {
      final refundInfoConfirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text('Thông tin hoàn tiền', style: TextStyle(color: Colors.white)),
          content: Form(
            key: _refundFormKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Để nhận lại tiền hoàn (nếu có theo chính sách), vui lòng cung cấp thông tin tài khoản ngân hàng của bạn:',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 15),
                  TextFormField(
                    controller: _bankAccountController,
                    style: TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Số tài khoản',
                      labelStyle: TextStyle(color: Colors.grey),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[700]!)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1CE88A))),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vui lòng nhập số tài khoản';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 10),
                  TextFormField(
                    controller: _bankNameController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Tên ngân hàng',
                      labelStyle: TextStyle(color: Colors.grey),
                      hintText: 'VD: Vietcombank, ACB, Momo...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[700]!)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1CE88A))),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vui lòng nhập tên ngân hàng';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Hủy bỏ', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF1CE88A)),
              onPressed: () {
                if (_refundFormKey.currentState!.validate()) {
                  Navigator.of(context).pop(true);
                }
              },
              child: Text('Xác nhận thông tin', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      );

      if (refundInfoConfirmed != true) return;

      bankAccount = _bankAccountController.text.trim();
      bankName = _bankNameController.text.trim();
      _bankAccountController.clear();
      _bankNameController.clear();

    } // Kết thúc if (apiStatusToCall == 'PAID_FULL')


    // Hỏi xác nhận hủy
    final bool? confirmedCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Xác nhận Hủy', style: TextStyle(color: Colors.white)),
        content: Text(
          'Bạn có chắc chắn muốn hủy đơn hàng này? ${apiStatusToCall == 'PAID_FULL' ? 'Yêu cầu hoàn tiền sẽ được xử lý sau khi hủy.' : 'Phí hủy (nếu có) sẽ được áp dụng theo chính sách.'}',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Không', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xác nhận Hủy', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmedCancel != true) return;
    _showLoadingDialog();

    try {
      final result = await apiService.cancelOrder(
        orderId,
        apiStatusToCall,
        bankAccount: bankAccount,
        bankName: bankName,
      );
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Hủy đơn thành công!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      _loadBookings();
    } catch (e) {
      _handleApiError(e);
    }
  }

  // --- (SỬA ĐỔI) Tách logic chọn ngày/giờ ---

  /// Helper: Chọn lịch MỚI cho thuê theo NGÀY
  Future<Map<String, String>?> _selectNewDayModeDateRange(DateTime currentStartDate) async {
    final now = DateTime.now();
    final firstSelectableDate = now.isBefore(currentStartDate) ? currentStartDate : now;

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: firstSelectableDate.add(const Duration(days: 1)),
      lastDate: DateTime(now.year + 2),
      initialDateRange: DateTimeRange(
        start: currentStartDate.add(const Duration(days: 1)),
        end: currentStartDate.add(const Duration(days: 2)),
      ),
      helpText: 'Chọn ngày nhận và trả xe MỚI',
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF1CE88A), onPrimary: Colors.black,
              surface: Colors.black, onSurface: Colors.white,
            ),
            dialogBackgroundColor: Colors.grey[900],
            textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: const Color(0xFF1CE88A))),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return null;

    // Định dạng kiểu NGÀY
    final startDateFormatted = DateFormat('yyyy-MM-dd HH:mm:ss').format(picked.start);
    final endDateFormatted = DateFormat('yyyy-MM-dd HH:mm:ss').format(
        DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59)
    );

    return {'startDate': startDateFormatted, 'endDate': endDateFormatted};
  }

  /// Helper: Chọn lịch MỚI cho thuê theo GIỜ
  Future<Map<String, String>?> _selectNewHourModeDateTime(DateTime currentStartDate) async {
    final now = DateTime.now();
    final firstSelectableDate = now.isBefore(currentStartDate) ? currentStartDate : now;

    // 1. Chọn Ngày
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: firstSelectableDate.add(const Duration(days: 1)),
      firstDate: firstSelectableDate.add(const Duration(days: 1)),
      lastDate: DateTime(now.year + 2),
      helpText: 'Chọn ngày thuê MỚI',
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF1CE88A), onPrimary: Colors.black,
              surface: Colors.black, onSurface: Colors.white,
            ),
            dialogBackgroundColor: Colors.grey[900],
            textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: const Color(0xFF1CE88A))),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return null;

    // 2. Chọn Giờ Bắt Đầu
    final TimeOfDay? pickedStartTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
      helpText: 'Chọn giờ nhận xe MỚI',
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF1CE88A), onPrimary: Colors.black,
              surface: Colors.black, onSurface: Colors.white,
            ),
            dialogBackgroundColor: Colors.grey[900],
            textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: const Color(0xFF1CE88A))),
          ),
          child: child!,
        );
      },
    );

    if (pickedStartTime == null) return null;

    // 3. Chọn Giờ Kết Thúc
    final TimeOfDay? pickedEndTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedStartTime.hour, pickedStartTime.minute).add(const Duration(hours: 3))),
      helpText: 'Chọn giờ trả xe MỚI',
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF1CE88A), onPrimary: Colors.black,
              surface: Colors.black, onSurface: Colors.white,
            ),
            dialogBackgroundColor: Colors.grey[900],
            textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: const Color(0xFF1CE88A))),
          ),
          child: child!,
        );
      },
    );

    if (pickedEndTime == null) return null;

    // 4. Validate giờ
    final startDateTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedStartTime.hour, pickedStartTime.minute);
    final endDateTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedEndTime.hour, pickedEndTime.minute);

    if (endDateTime.isBefore(startDateTime) || endDateTime == startDateTime) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Giờ trả xe phải sau giờ nhận xe.'), backgroundColor: Colors.orange),
      );
      return null;
    }

    // 5. Định dạng kiểu GIỜ
    final startDateFormatted = DateFormat('yyyy-MM-dd HH:mm:ss').format(startDateTime);
    final endDateFormatted = DateFormat('yyyy-MM-dd HH:mm:ss').format(endDateTime);

    return {'startDate': startDateFormatted, 'endDate': endDateFormatted};
  }


  /// Xử lý khi nhấn nút Đổi Lịch (ĐÃ VIẾT LẠI)
  Future<void> _handleChangeDate(int orderId, DateTime currentStartDate, String rentalType) async {

    Map<String, String>? newDates;

    // 1. Gọi đúng hàm chọn lịch dựa trên loại thuê
    if (rentalType == 'hour') {
      newDates = await _selectNewHourModeDateTime(currentStartDate);
    } else {
      // Mặc định (hoặc rentalType == 'day')
      newDates = await _selectNewDayModeDateRange(currentStartDate);
    }

    // Nếu người dùng hủy chọn (bấm back/cancel)
    if (newDates == null) return;

    final String newStartDateFormatted = newDates['startDate']!;
    final String newEndDateFormatted = newDates['endDate']!;

    // 2. Hỏi xác nhận
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Xác nhận Đổi lịch', style: TextStyle(color: Colors.white)),
        content: Text(
          'Đổi lịch thuê sang:\nBắt đầu: $newStartDateFormatted\nKết thúc: $newEndDateFormatted\n\nLưu ý: Việc đổi lịch có thể thất bại nếu xe đã có người đặt.',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF1CE88A)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xác nhận Đổi', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 3. Hiển thị loading
    _showLoadingDialog();

    try {
      // 4. Gọi API
      final result = await apiService.changeOrderDate(orderId, newStartDateFormatted, newEndDateFormatted);
      Navigator.of(context).pop(); // Ẩn loading

      // 5. Hiển thị thành công và tải lại
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Đổi lịch thành công!'),
          backgroundColor: Colors.green,
        ),
      );
      _loadBookings();
    } catch (e) {
      _handleApiError(e); // Sẽ báo lỗi nếu "Trùng lịch"
    }
  }

  // --- (Các hàm hỗ trợ còn lại giữ nguyên) ---
  void _showLoadingDialog() {
    if (ModalRoute.of(context)?.isCurrent != true) {
      Navigator.of(context).pop();
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF1CE88A))),
    );
  }

  void _handleApiError(Object e) {
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    final errorString = e.toString().replaceAll("Exception: ", "");

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi: $errorString'),
        backgroundColor: errorString.contains('Phiên đăng nhập hết hạn') ? Colors.orange : Colors.red,
      ),
    );
  }
  // ---------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Chuyến của tôi', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadBookings,
            tooltip: 'Tải lại',
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _bookingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1CE88A)));
          }

          if (snapshot.hasError) {
            final error = snapshot.error.toString().replaceAll("Exception: ", "");
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 60),
                    SizedBox(height: 20),
                    Text(
                      'Không thể tải lịch sử',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 10),
                    Text(
                      error,
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 30),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF1CE88A)),
                      onPressed: _loadBookings,
                      child: Text('Thử lại', style: TextStyle(color: Colors.black)),
                    )
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
                child: Text('Bạn chưa có chuyến xe nào.',
                    style: TextStyle(color: Colors.grey)));
          }

          final bookings = snapshot.data!;
          bookings.sort((a, b) {
            DateTime? dateA = DateTime.tryParse(a['CREATED_AT'] ?? '');
            DateTime? dateB = DateTime.tryParse(b['CREATED_AT'] ?? '');
            if (dateA == null || dateB == null) return 0;
            return dateB.compareTo(dateA);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              return _buildBookingCard(booking);
            },
          );
        },
      ),
    );
  }

  /// Widget để vẽ một thẻ đơn hàng
  Widget _buildBookingCard(Map<String, dynamic> booking) {
    try {
      final car = booking['Car'] ?? {};
      final status = (booking['STATUS'] ?? 'UNKNOWN').toUpperCase(); // Đảm bảo chữ hoa

      final String? imageUrl = car['mainImageUrl'];
      final String? fullCarImageUrl = imageUrl != null ? "${apiService.baseUrl}/images/$imageUrl" : null;

      final priceFormat = NumberFormat.simpleCurrency(locale: 'vi-VN', decimalDigits: 0);
      final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

      final DateTime? startDate = DateTime.tryParse(booking['START_DATE'] ?? '');
      final DateTime? endDate = DateTime.tryParse(booking['END_DATE'] ?? '');
      final double finalAmount = double.tryParse(booking['FINAL_AMOUNT']?.toString() ?? '0') ?? 0.0;

      if (startDate == null || endDate == null) {
        throw Exception('Ngày tháng không hợp lệ');
      }

      String rentalType;
      if (booking['RENTAL_TYPE'] != null) {
        rentalType = booking['RENTAL_TYPE']; // Ưu tiên giá trị từ DB
      } else {
        final duration = endDate.difference(startDate);
        if (duration.inHours < 24 &&
            startDate.day == endDate.day &&
            startDate.month == endDate.month &&
            startDate.year == endDate.year) {
          rentalType = 'hour'; // Đây là thuê theo giờ
        } else {
          rentalType = 'day'; // Đây là thuê theo ngày
        }
      }

      final bool isFuture = DateTime.now().isBefore(startDate);

      // Sửa logic hiển thị nút dựa trên trạng thái MỚI
      bool canCancel = (status == 'PENDING_PAYMENT' || status == 'CONFIRMED') && isFuture;
      bool canChangeDate = (status == 'CONFIRMED') && isFuture;


      return Card(
        color: Colors.grey[900],
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Thông tin xe
              Row(
                children: [
                  Container(
                    width: 80,
                    height: 60,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[800],
                    ),
                    child: fullCarImageUrl != null
                        ? Image.network(
                      fullCarImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.directions_car, color: Colors.grey, size: 40),
                    )
                        : const Icon(Icons.directions_car, color: Colors.grey, size: 40),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${car['BRAND'] ?? 'Xe'} ${car['MODEL'] ?? ''}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text('Biển số: ${car['LICENSE_PLATE'] ?? 'N/A'}', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 24),

              // 2. Thông tin chi tiết
              _buildInfoRow(Icons.calendar_today, 'Nhận xe:', dateFormat.format(startDate)),
              _buildInfoRow(Icons.calendar_today, 'Trả xe:', dateFormat.format(endDate)),
              _buildInfoRow(Icons.money, 'Tổng tiền:', priceFormat.format(finalAmount)),
              // Hiển thị loại thuê (đã sửa)
              _buildInfoRow(Icons.access_time, 'Loại thuê:', rentalType == 'hour' ? 'Theo giờ' : 'Theo ngày'),


              // 3. Trạng thái
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Trạng thái:', style: TextStyle(color: Colors.grey[400])),
                  // Sửa lỗi 1: Truyền paymentStatus đã chuẩn hóa (chữ thường)
                  _buildStatusChip(status, (booking['PAYMENT_STATUS'] ?? 'unknown').toLowerCase()),
                ],
              ),

              // 4. Dãy nút hành động
              if (canCancel || canChangeDate)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (canChangeDate)
                        TextButton(
                          // Truyền RENTAL_TYPE (đã đoán) vào
                          onPressed: () => _handleChangeDate(booking['ORDER_ID'], startDate, rentalType),
                          child: const Text('Đổi lịch', style: TextStyle(color: Color(0xFF1CE88A))),
                        ),
                      const SizedBox(width: 8),
                      if (canCancel)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[800],
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          onPressed: () => _handleCancelBooking(booking), // Gửi cả object booking
                          child: const Text('Hủy chuyến', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    } catch (e) {
      // Bắt lỗi nếu 1 thẻ bị lỗi
      return Card(
        color: Colors.grey[900],
        margin: const EdgeInsets.only(bottom: 16),
        child: ListTile(
          leading: Icon(Icons.error, color: Colors.red[700]),
          title: Text('Lỗi dữ liệu đơn hàng', style: TextStyle(color: Colors.white)),
          subtitle: Text('Không thể hiển thị đơn #${booking['ORDER_ID'] ?? 'N/A'}. Lý do: ${e.toString()}', style: TextStyle(color: Colors.grey)),
        ),
      );
    }
  }

  /// Widget con cho 1 hàng thông tin (icon, title, value)
  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 16),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: Colors.grey[400])),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, String paymentStatus) { // paymentStatus giờ đã là chữ thường
    Color chipColor = Colors.grey;
    String statusText = status;

    // Ưu tiên check trạng thái chung trước
    switch (status.toUpperCase()) { // Check chữ hoa cho an toàn
      case 'PENDING_PAYMENT':
        chipColor = Colors.orange;
        statusText = 'Chờ thanh toán';
        break;
      case 'CONFIRMED':
        if (paymentStatus == 'partial') { // Đã là chữ thường
          chipColor = Colors.blue;
          statusText = 'Đã cọc';
        } else if (paymentStatus == 'paid') { // Đã là chữ thường
          chipColor = Colors.green;
          statusText = 'Đã thanh toán'; // <-- SẼ HIỂN THỊ ĐÚNG CÁI NÀY
        } else {
          // (CONFIRMED + unpaid)
          chipColor = Colors.orange[700]!;
          statusText = 'Chờ thanh toán';
        }
        break;
      case 'IN_PROGRESS':
        chipColor = Colors.teal;
        statusText = 'Đang thuê';
        break;
      case 'COMPLETED':
        chipColor = Colors.grey[600]!;
        statusText = 'Hoàn thành';
        break;
      case 'CANCELLED':
        chipColor = Colors.red[800]!;
        statusText = 'Đã hủy';
        break;
      default:
        statusText = status;
    }

    return Chip(
      label: Text(statusText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      backgroundColor: chipColor,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      labelPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}