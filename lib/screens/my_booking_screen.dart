import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/api/api_service.dart';
// import 'package:mobile/providers/auth_provider.dart'; // Có thể bỏ nếu không dùng trực tiếp
// import 'package:provider/provider.dart';

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
  final _refundFormKey = GlobalKey<FormState>();

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
      _bookingsFuture = apiService.getUserBookings();
    });
  }

  // =======================================================================
  // [MỚI] LOGIC ĐÁNH GIÁ (REVIEW)
  // =======================================================================
  void _showReviewDialog(int orderId) {
    final contentController = TextEditingController();
    double selectedRating = 5.0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Đánh giá chuyến đi', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Bạn cảm thấy thế nào về chiếc xe này?', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 20),
                // 5 ngôi sao
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < selectedRating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          selectedRating = index + 1.0;
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: contentController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Nhập nhận xét (tùy chọn)...',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1CE88A))),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1CE88A)),
              onPressed: () async {
                Navigator.pop(context); // Đóng dialog
                _handleSubmitReview(orderId, selectedRating.toInt(), contentController.text);
              },
              child: const Text('Gửi đánh giá', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmitReview(int orderId, int rating, String content) async {
    _showLoadingDialog();
    try {
      await apiService.submitReview(orderId, rating, content);
      if (!mounted) return;
      Navigator.of(context).pop(); // Tắt loading

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đánh giá thành công!'), backgroundColor: Colors.green),
      );
      _loadBookings(); // Tải lại danh sách để cập nhật nút
    } catch (e) {
      _handleApiError(e);
    }
  }
  // =======================================================================

  /// Xử lý khi nhấn nút Hủy Đơn (LOGIC CŨ GIỮ NGUYÊN)
  Future<void> _handleCancelBooking(Map<String, dynamic> booking) async {
    final int orderId = booking['ORDER_ID'];
    final String status = booking['STATUS'] ?? 'UNKNOWN';
    final String paymentStatus = (booking['PAYMENT_STATUS'] ?? 'unknown').toLowerCase();

    String? bankAccount;
    String? bankName;
    String apiStatusToCall;

    if (status.toUpperCase() == 'PENDING_PAYMENT' && paymentStatus == 'unpaid') {
      apiStatusToCall = 'PENDING';
    }
    else if (status.toUpperCase() == 'CONFIRMED' && paymentStatus == 'partial') {
      apiStatusToCall = 'PAID_DEPOSIT';
    }
    else if (status.toUpperCase() == 'CONFIRMED' && paymentStatus == 'paid') {
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

    // Form nhập hoàn tiền (GIỮ NGUYÊN)
    if (apiStatusToCall == 'PAID_FULL') {
      final refundInfoConfirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Thông tin hoàn tiền', style: TextStyle(color: Colors.white)),
          content: Form(
            key: _refundFormKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Để nhận lại tiền hoàn (nếu có theo chính sách), vui lòng cung cấp thông tin tài khoản ngân hàng của bạn:',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _bankAccountController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Số tài khoản',
                      labelStyle: const TextStyle(color: Colors.grey),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[700]!)),
                      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1CE88A))),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Vui lòng nhập số tài khoản';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _bankNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Tên ngân hàng',
                      labelStyle: const TextStyle(color: Colors.grey),
                      hintText: 'VD: Vietcombank, ACB...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[700]!)),
                      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1CE88A))),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Vui lòng nhập tên ngân hàng';
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
              child: const Text('Hủy bỏ', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1CE88A)),
              onPressed: () {
                if (_refundFormKey.currentState!.validate()) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('Xác nhận thông tin', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      );

      if (refundInfoConfirmed != true) return;

      bankAccount = _bankAccountController.text.trim();
      bankName = _bankNameController.text.trim();
      _bankAccountController.clear();
      _bankNameController.clear();
    }

    // Xác nhận hủy (GIỮ NGUYÊN)
    final bool? confirmedCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Xác nhận Hủy', style: TextStyle(color: Colors.white)),
        content: Text(
          'Bạn có chắc chắn muốn hủy đơn hàng này? ${apiStatusToCall == 'PAID_FULL' ? 'Yêu cầu hoàn tiền sẽ được xử lý sau khi hủy.' : 'Phí hủy (nếu có) sẽ được áp dụng theo chính sách.'}',
          style: const TextStyle(color: Colors.grey),
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
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Hủy đơn thành công!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      _loadBookings();
    } catch (e) {
      _handleApiError(e);
    }
  }

  // --- CÁC HÀM CHỌN NGÀY GIỜ (GIỮ NGUYÊN) ---

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

    final startDateFormatted = DateFormat('yyyy-MM-dd HH:mm:ss').format(picked.start);
    final endDateFormatted = DateFormat('yyyy-MM-dd HH:mm:ss').format(
        DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59)
    );

    return {'startDate': startDateFormatted, 'endDate': endDateFormatted};
  }

  Future<Map<String, String>?> _selectNewHourModeDateTime(DateTime currentStartDate) async {
    final now = DateTime.now();
    final firstSelectableDate = now.isBefore(currentStartDate) ? currentStartDate : now;

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

    final startDateTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedStartTime.hour, pickedStartTime.minute);
    final endDateTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedEndTime.hour, pickedEndTime.minute);

    if (endDateTime.isBefore(startDateTime) || endDateTime == startDateTime) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Giờ trả xe phải sau giờ nhận xe.'), backgroundColor: Colors.orange),
      );
      return null;
    }

    final startDateFormatted = DateFormat('yyyy-MM-dd HH:mm:ss').format(startDateTime);
    final endDateFormatted = DateFormat('yyyy-MM-dd HH:mm:ss').format(endDateTime);

    return {'startDate': startDateFormatted, 'endDate': endDateFormatted};
  }

  Future<void> _handleChangeDate(int orderId, DateTime currentStartDate, String rentalType) async {
    Map<String, String>? newDates;

    if (rentalType == 'hour') {
      newDates = await _selectNewHourModeDateTime(currentStartDate);
    } else {
      newDates = await _selectNewDayModeDateRange(currentStartDate);
    }

    if (newDates == null) return;

    final String newStartDateFormatted = newDates['startDate']!;
    final String newEndDateFormatted = newDates['endDate']!;

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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1CE88A)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xác nhận Đổi', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    _showLoadingDialog();

    try {
      final result = await apiService.changeOrderDate(orderId, newStartDateFormatted, newEndDateFormatted);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Đổi lịch thành công!'),
          backgroundColor: Colors.green,
        ),
      );
      _loadBookings();
    } catch (e) {
      _handleApiError(e);
    }
  }

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
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();

    final errorString = e.toString().replaceAll("Exception: ", "");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi: $errorString'),
        backgroundColor: errorString.contains('Phiên đăng nhập hết hạn') ? Colors.orange : Colors.red,
      ),
    );
  }

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
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 60),
                    const SizedBox(height: 20),
                    const Text(
                      'Không thể tải lịch sử',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      error,
                      style: const TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1CE88A)),
                      onPressed: _loadBookings,
                      child: const Text('Thử lại', style: TextStyle(color: Colors.black)),
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

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    try {
      final car = booking['Car'] ?? {};
      final status = (booking['STATUS'] ?? 'UNKNOWN').toUpperCase();

      final String? imageUrl = car['mainImageUrl'];
      String? fullCarImageUrl;
      if (imageUrl != null) {
        // Logic kiểm tra URL
        fullCarImageUrl = imageUrl.startsWith('http') ? imageUrl : "${apiService.baseUrl}/images/$imageUrl";
      }

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
        rentalType = booking['RENTAL_TYPE'];
      } else {
        final duration = endDate.difference(startDate);
        if (duration.inHours < 24 &&
            startDate.day == endDate.day &&
            startDate.month == endDate.month &&
            startDate.year == endDate.year) {
          rentalType = 'hour';
        } else {
          rentalType = 'day';
        }
      }

      final bool isFuture = DateTime.now().isBefore(startDate);

      bool canCancel = (status == 'PENDING_PAYMENT' || status == 'CONFIRMED') && isFuture;
      bool canChangeDate = (status == 'CONFIRMED') && isFuture;

      // [MỚI] Kiểm tra logic review
      final bool hasReviewed = booking['review'] != null;
      final bool canReview = (status == 'COMPLETED') && !hasReviewed;

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
              _buildInfoRow(Icons.access_time, 'Loại thuê:', rentalType == 'hour' ? 'Theo giờ' : 'Theo ngày'),

              // 3. Trạng thái
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Trạng thái:', style: TextStyle(color: Colors.grey[400])),
                  _buildStatusChip(status, (booking['PAYMENT_STATUS'] ?? 'unknown').toLowerCase()),
                ],
              ),

              // 4. Dãy nút hành động (ĐÃ UPDATE THÊM REVIEW)
              if (canCancel || canChangeDate || canReview)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Nút Đổi lịch (Logic cũ)
                      if (canChangeDate)
                        TextButton(
                          onPressed: () => _handleChangeDate(booking['ORDER_ID'], startDate, rentalType),
                          child: const Text('Đổi lịch', style: TextStyle(color: Color(0xFF1CE88A))),
                        ),

                      // [MỚI] Nút Đánh giá
                      if (canReview)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber[700],
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          icon: const Icon(Icons.star, size: 16, color: Colors.white),
                          label: const Text('Đánh giá', style: TextStyle(color: Colors.white, fontSize: 13)),
                          onPressed: () => _showReviewDialog(booking['ORDER_ID']),
                        ),

                      const SizedBox(width: 8),

                      // Nút Hủy chuyến (Logic cũ)
                      if (canCancel)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[800],
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          onPressed: () => _handleCancelBooking(booking),
                          child: const Text('Hủy chuyến', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ),
                    ],
                  ),
                ),

              // [MỚI] Nếu đã đánh giá rồi, hiện thông báo nhỏ
              if (status == 'COMPLETED' && hasReviewed)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: const [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      SizedBox(width: 4),
                      Text('Đã đánh giá', style: TextStyle(color: Colors.green, fontSize: 12, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    } catch (e) {
      return Card(
        color: Colors.grey[900],
        margin: const EdgeInsets.only(bottom: 16),
        child: ListTile(
          leading: Icon(Icons.error, color: Colors.red[700]),
          title: const Text('Lỗi dữ liệu đơn hàng', style: TextStyle(color: Colors.white)),
          subtitle: Text('Không thể hiển thị đơn #${booking['ORDER_ID'] ?? 'N/A'}. Lý do: ${e.toString()}', style: const TextStyle(color: Colors.grey)),
        ),
      );
    }
  }

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

  Widget _buildStatusChip(String status, String paymentStatus) {
    Color chipColor = Colors.grey;
    String statusText = status;

    switch (status.toUpperCase()) {
      case 'PENDING_PAYMENT':
        chipColor = Colors.orange;
        statusText = 'Chờ thanh toán';
        break;
      case 'CONFIRMED':
        if (paymentStatus == 'partial') {
          chipColor = Colors.blue;
          statusText = 'Đã cọc';
        } else if (paymentStatus == 'paid') {
          chipColor = Colors.green;
          statusText = 'Đã thanh toán';
        } else {
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