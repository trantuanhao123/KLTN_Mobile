import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/api/api_service.dart';
import 'package:mobile/screens/payment_webview_screen.dart';
import 'package:mobile/screens/my_booking_screen.dart';
// import 'package:url_launcher/url_launcher.dart';

enum RentalMode { day, hour }

class BookingScreen extends StatefulWidget {
  final Map<String, dynamic> car;
  const BookingScreen({super.key, required this.car});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  RentalMode _rentalMode = RentalMode.day;
  DateTime? _selectedDate;
  DateTimeRange? _selectedDateRange;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  final _discountCodeController = TextEditingController();
  String _paymentOption = 'full';
  bool _isLoading = false;

  // State cho việc kiểm tra mã giảm giá
  Map<String, dynamic>? _validatedDiscount; // Lưu thông tin mã hợp lệ
  String? _discountCheckMessage; // Thông báo kết quả check mã
  bool _isCheckingDiscount = false; // Trạng thái đang kiểm tra mã

  int get _numberOfDays {
    if (_rentalMode == RentalMode.day && _selectedDateRange != null) {
      return _selectedDateRange!.end.difference(_selectedDateRange!.start).inDays + 1;
    }
    return 0;
  }

  int get _numberOfHours {
    if (_rentalMode == RentalMode.hour && _selectedDate != null && _startTime != null && _endTime != null) {
      final startDateTime = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _startTime!.hour, _startTime!.minute);
      final endDateTime = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _endTime!.hour, _endTime!.minute);
      final duration = endDateTime.difference(startDateTime);
      if (duration.isNegative) return 0;
      return (duration.inMinutes + 59) ~/ 60;
    }
    return 0;
  }

  double get _totalPrice {
    if (_rentalMode == RentalMode.day) {
      final pricePerDay = double.tryParse(widget.car['PRICE_PER_DAY']?.toString() ?? '0.0') ?? 0.0;
      return _numberOfDays * pricePerDay;
    } else {
      final pricePerHour = double.tryParse(widget.car['PRICE_PER_HOUR']?.toString() ?? '0.0') ?? 0.0;
      return _numberOfHours * pricePerHour;
    }
  }

  // Tính toán số tiền giảm giá
  double get _discountAmount {
    if (_validatedDiscount == null || _totalPrice == 0) return 0.0;

    try {
      final type = _validatedDiscount!['TYPE'];
      final value = double.tryParse(_validatedDiscount!['VALUE']?.toString() ?? '0.0') ?? 0.0;

      if (type == 'PERCENT') {
        return _totalPrice * (value / 100);
      } else if (type == 'AMOUNT') {
        // Đảm bảo không giảm giá nhiều hơn tổng tiền
        return (value > _totalPrice) ? _totalPrice : value;
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  // Tính toán giá cuối cùng
  double get _finalPrice {
    return _totalPrice - _discountAmount;
  }

  // Hàm xử lý áp dụng mã
  Future<void> _applyDiscountCode() async {
    final code = _discountCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() {
        _discountCheckMessage = 'Vui lòng nhập mã.';
        _validatedDiscount = null; // Xóa mã cũ nếu có
      });
      return;
    }
    // Nếu người dùng nhập lại đúng mã đã xác thực, không cần gọi API
    if (_validatedDiscount != null && _validatedDiscount!['CODE'] == code) {
      return;
    }

    setState(() {
      _isCheckingDiscount = true;
      _discountCheckMessage = null; // Xóa thông báo cũ
      _validatedDiscount = null; // Xóa mã cũ khi bắt đầu check mã mới
    });

    final apiService = ApiService();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final discountData = await apiService.checkDiscountCode(code);
      setState(() {
        _validatedDiscount = discountData;
        // Tính toán giá trị giảm để hiển thị
        final discountValue = _discountAmount; // Dùng getter mới
        _discountCheckMessage = 'Áp dụng thành công! Giảm ${NumberFormat.simpleCurrency(locale: 'vi-VN', decimalDigits: 0).format(discountValue)}';
      });
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(_discountCheckMessage!), backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() {
        _discountCheckMessage = e.toString();
        _validatedDiscount = null; // Xóa mã nếu không hợp lệ
      });
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Lỗi: $_discountCheckMessage'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isCheckingDiscount = false);
      }
    }
  }


  Future<void> _selectDayModeDateRange(BuildContext context) async {
    final now = DateTime.now();
    final initialStartDate = _selectedDateRange?.start ?? now;
    final initialEndDate = _selectedDateRange?.end ?? now.add(const Duration(days: 1));

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, now.month, now.day),
      initialDateRange: DateTimeRange(start: initialStartDate, end: initialEndDate),
      helpText: 'Chọn ngày nhận và trả xe',
      confirmText: 'Xác nhận',
      cancelText: 'Hủy',
      errorInvalidRangeText: 'Ngày trả phải sau ngày nhận',
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
    if (picked != null && picked != _selectedDateRange) {
      if (picked.end.isBefore(picked.start)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ngày trả xe không hợp lệ.'), backgroundColor: Colors.orange),
        );
      } else {
        setState(() {
          _selectedDateRange = picked;
          _selectedDate = picked.start;
          _startTime = null;
          _endTime = null;
          _validatedDiscount = null; // Reset mã khi đổi ngày
          _discountCheckMessage = null;
        });
      }
    }
  }

  Future<void> _selectHourModeDateTime(BuildContext context) async {
    final now = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, now.month, now.day),
      helpText: 'Chọn ngày thuê',
      confirmText: 'Chọn giờ',
      cancelText: 'Hủy',
      locale: const Locale('vi', 'VN'),
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

    if (pickedDate != null) {
      final TimeOfDay? pickedStartTime = await showTimePicker(
        context: context,
        initialTime: _startTime ?? TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
        helpText: 'Chọn giờ nhận xe',
        confirmText: 'LƯU',
        cancelText: 'HỦY',
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          );
        },
      );

      if (pickedStartTime != null) {
        final TimeOfDay? pickedEndTime = await showTimePicker(
          context: context,
          initialTime: _endTime ?? TimeOfDay.fromDateTime(DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedStartTime.hour, pickedStartTime.minute).add(const Duration(hours: 3))),
          helpText: 'Chọn giờ trả xe',
          confirmText: 'LƯU',
          cancelText: 'HỦY',
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
              child: child!,
            );
          },
        );

        if (pickedEndTime != null) {
          final startDateTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedStartTime.hour, pickedStartTime.minute);
          final endDateTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedEndTime.hour, pickedEndTime.minute);
          if (endDateTime.isBefore(startDateTime) || endDateTime == startDateTime) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Giờ trả xe phải sau giờ nhận xe.'), backgroundColor: Colors.orange),
            );
          } else {
            setState(() {
              _selectedDate = pickedDate;
              _startTime = pickedStartTime;
              _endTime = pickedEndTime;
              _selectedDateRange = null;
              _validatedDiscount = null; // Reset mã khi đổi giờ
              _discountCheckMessage = null;
            });
          }
        }
      }
    }
  }

  Future<void> _confirmBooking() async {
    bool isValidSelection = false;
    if (_rentalMode == RentalMode.day && _selectedDateRange != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (!_selectedDateRange!.start.isBefore(today)) {
        isValidSelection = true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ngày bắt đầu không hợp lệ.'), backgroundColor: Colors.red),
        );
        return;
      }
    } else if (_rentalMode == RentalMode.hour && _selectedDate != null && _startTime != null && _endTime != null) {
      isValidSelection = true;
    }

    if (!isValidSelection || _totalPrice <= 0) { // Thêm check _totalPrice
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn thời gian thuê hợp lệ.'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Check nếu mã đang nhập khác mã đã validate
    final currentCode = _discountCodeController.text.trim().toUpperCase();
    String? codeWarning;
    if (currentCode.isNotEmpty && (_validatedDiscount == null || _validatedDiscount!['CODE'] != currentCode)) {
      codeWarning = 'Mã giảm giá "$currentCode" chưa được "Áp dụng". Bạn vẫn muốn tiếp tục?';
    }


    bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) { // Thêm BuildContext
        // Định dạng tiền tệ
        final priceFormat = NumberFormat.simpleCurrency(locale: 'vi-VN', decimalDigits: 0);

        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Xác nhận Đặt xe', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Xe: ${widget.car['BRAND'] ?? ''} ${widget.car['MODEL'] ?? ''}', style: const TextStyle(color: Colors.white)),
                if (_rentalMode == RentalMode.day && _selectedDateRange != null)
                  Text('Thời gian: ${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.end)} (${_numberOfDays} ngày)', style: const TextStyle(color: Colors.white)),
                if (_rentalMode == RentalMode.hour && _selectedDate != null && _startTime != null && _endTime != null)
                  Text('Thời gian: ${DateFormat('dd/MM/yyyy').format(_selectedDate!)} (${_startTime!.format(context)} - ${_endTime!.format(context)}) (${_numberOfHours} giờ)', style: const TextStyle(color: Colors.white)),

                // Hiển thị chi tiết giá
                const SizedBox(height: 10),
                Text('Tổng tiền: ${priceFormat.format(_totalPrice)}', style: const TextStyle(color: Colors.white)),

                if (_validatedDiscount != null)
                  Text('Mã giảm giá: ${_validatedDiscount!['CODE']}', style: const TextStyle(color: Colors.white)),

                if (_discountAmount > 0)
                  Text('Giảm giá: ${priceFormat.format(-_discountAmount)}', style: const TextStyle(color: Color(0xFF1CE88A))),

                if (_discountAmount > 0)
                  Text('Thành tiền: ${priceFormat.format(_finalPrice)}', style: const TextStyle(color: Color(0xFF1CE88A), fontWeight: FontWeight.bold, fontSize: 16)),

                if (_discountAmount == 0) // Hiển thị tổng nếu không giảm giá
                  Text('Thành tiền: ${priceFormat.format(_totalPrice)}', style: const TextStyle(color: Color(0xFF1CE88A), fontWeight: FontWeight.bold, fontSize: 16)),

                if (codeWarning != null) // Cảnh báo mã chưa áp dụng
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(codeWarning, style: const TextStyle(color: Colors.orange, fontStyle: FontStyle.italic, fontSize: 13)),
                  ),

                const SizedBox(height: 10),
                Text('Thanh toán: ${_paymentOption == 'full' ? '100%' : 'Đặt cọc 10%'}', style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 15),
                const Text('Vui lòng đọc kỹ chính sách hủy chuyến:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                    children: [
                      const TextSpan(text: '• Hủy khi chưa thanh toán (trong 15 phút): Miễn phí.\n'),
                      const TextSpan(text: '• Hủy sau khi '),
                      const TextSpan(text: 'đặt cọc 10%', style: TextStyle(fontWeight: FontWeight.bold)),
                      const TextSpan(text: ': Mất toàn bộ tiền cọc.\n'),
                      const TextSpan(text: '• Hủy sau khi '),
                      const TextSpan(text: 'thanh toán 100%', style: TextStyle(fontWeight: FontWeight.bold)),
                      const TextSpan(text: ':\n'),
                      const TextSpan(text: '   - Trước 24h nhận xe: Phí hủy 10% (Hoàn 90%).\n'),
                      const TextSpan(text: '   - Trong vòng 24h nhận xe: Phí hủy 50% (Hoàn 50%).\n'),
                      TextSpan(
                        text: 'Xem chi tiết chính sách.',
                        style: const TextStyle(color: Color(0xFF1CE88A), decoration: TextDecoration.underline),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: Colors.grey[850],
                                title: const Text("Chính Sách Chi Tiết", style: TextStyle(color: Colors.white)),
                                content: const SingleChildScrollView(
                                    child: Text( // Thêm nội dung vào đây
                                      '''
Chính sách Hủy Chuyến
Để đảm bảo trải nghiệm tốt nhất cho tất cả khách hàng, chúng tôi áp dụng chính sách hủy đơn như sau. Vui lòng đọc kỹ trước khi xác nhận hủy.

1. Hủy khi chưa thanh toán
- Đơn hàng "Chờ thanh toán" trong 15 phút sau khi đặt.
- Tự hủy: Miễn phí trong thời gian này.
- Hệ thống hủy: Sau 15 phút không thanh toán, đơn tự hủy miễn phí.

2. Hủy sau khi đã thanh toán (Đơn đã xác nhận)
- Đã đặt cọc (10%): Nếu hủy, mất toàn bộ tiền cọc.
- Đã thanh toán 100%:
  + Hủy trước 24 giờ so với giờ nhận xe: Phí hủy 10% tổng giá trị. Hoàn lại 90%.
  + Hủy trong vòng 24 giờ so với giờ nhận xe: Phí hủy 50% tổng giá trị. Hoàn lại 50%.
- Tiền hoàn (nếu có) sẽ được xử lý qua PayOS về tài khoản đã dùng.

Chi phí Phát sinh & Bồi thường
- Chi phí phát sinh/thiệt hại sẽ được xác định và thu khi trả xe.
- Quy trình: Kiểm tra xe -> Thông báo chi phí (nếu có) -> Thanh toán tiền mặt -> Ghi nhận vào biên bản.
                                          ''',
                                      style: TextStyle(color: Colors.grey),
                                    )
                                ),
                                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đã hiểu', style: TextStyle(color: Color(0xFF1CE88A))))],
                              ),
                            );
                          },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                const Text('Bằng việc nhấn "Đồng ý", bạn xác nhận đã hiểu và chấp nhận các điều khoản.', style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic, fontSize: 12)),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Hủy bỏ', style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1CE88A)),
              child: const Text('Đồng ý & Thanh toán', style: TextStyle(color: Colors.black)),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    final apiService = ApiService();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      String startDateFormatted;
      String endDateFormatted;
      String rentalTypeParam = _rentalMode == RentalMode.day ? 'day' : 'hour';

      if (_rentalMode == RentalMode.day) {
        startDateFormatted = DateFormat('yyyy-MM-dd HH:mm:ss').format(_selectedDateRange!.start);
        final endDateEndOfDay = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);
        endDateFormatted = DateFormat('yyyy-MM-dd HH:mm:ss').format(endDateEndOfDay);
      } else {
        final startDateTime = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _startTime!.hour, _startTime!.minute);
        final endDateTime = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _endTime!.hour, _endTime!.minute);
        startDateFormatted = DateFormat('yyyy-MM-dd HH:mm:ss').format(startDateTime);
        endDateFormatted = DateFormat('yyyy-MM-dd HH:mm:ss').format(endDateTime);
      }

      final codeToSubmit = _discountCodeController.text.trim().toUpperCase();

      final resultData = await apiService.createOrderAndGetPaymentLink(
        carId: widget.car['CAR_ID'],
        startDate: startDateFormatted,
        endDate: endDateFormatted,
        paymentOption: _paymentOption,
        discountCode: codeToSubmit,
        rentalType: rentalTypeParam,
      );

      final paymentUrl = resultData['url'];
      final int orderId = int.parse(resultData['orderId'].toString());

      // Truyền orderId sang màn hình thanh toán
      final result = await navigator.push(
        MaterialPageRoute(
          builder: (context) => PaymentWebViewScreen(
              url: paymentUrl,
              orderId: orderId
          ),
        ),
      );

      if (!mounted) return;

      if (result == 'success') {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Đặt xe và thanh toán thành công!'), backgroundColor: Colors.green),
        );
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MyBookingScreen()),
              (route) => route.isFirst,
        );
      } else if (result == 'cancelled') {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Bạn đã hủy thanh toán.'), backgroundColor: Colors.orange),
        );
      } else if (result == 'error') {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Quá trình thanh toán gặp lỗi.'), backgroundColor: Colors.red),
        );
      }

    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _discountCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final priceFormat = NumberFormat.simpleCurrency(locale: 'vi-VN', decimalDigits: 0);
    final String? imageUrl = widget.car['mainImageUrl'];
    final String? fullCarImageUrl = imageUrl != null ? "${ApiService().baseUrl}/images/$imageUrl" : null;

    String selectedTimeText = 'Chọn thời gian thuê';
    if (_rentalMode == RentalMode.day && _selectedDateRange != null) {
      selectedTimeText = '${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.end)}';
    } else if (_rentalMode == RentalMode.hour && _selectedDate != null && _startTime != null && _endTime != null) {
      selectedTimeText = '${DateFormat('dd/MM/yyyy').format(_selectedDate!)} (${_startTime!.format(context)} - ${_endTime!.format(context)})';
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Xác nhận Thuê xe', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: ListView(
            children: [
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
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
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                        strokeWidth: 2,
                        color: Colors.grey,
                      ));
                    },
                  )
                      : const Icon(Icons.directions_car, color: Colors.grey, size: 40),
                ),
                title: Text('${widget.car['BRAND'] ?? ''} ${widget.car['MODEL'] ?? ''}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text(
                  priceFormat.format(double.tryParse(widget.car['PRICE_PER_DAY'].toString()) ?? 0.0) + '/ngày',
                  style: const TextStyle(color: Color(0xFF1CE88A), fontWeight: FontWeight.w500),
                ),
              ),
              const Divider(color: Colors.white24, height: 32),

              const Text('Chọn hình thức thuê', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Theme(
                data: Theme.of(context).copyWith(
                  unselectedWidgetColor: Colors.grey[700],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: RadioListTile<RentalMode>(
                        title: const Text('Theo Ngày', style: TextStyle(color: Colors.white)),
                        value: RentalMode.day,
                        groupValue: _rentalMode,
                        onChanged: (RentalMode? value) {
                          if (value != null) {
                            setState(() {
                              _rentalMode = value;
                              if(_selectedDate != null) {
                                _selectedDateRange = DateTimeRange(start: _selectedDate!, end: _selectedDate!.add(const Duration(days:1)));
                              } else {
                                _selectedDateRange = null;
                              }
                              _startTime = null;
                              _endTime = null;
                              _validatedDiscount = null; // Reset mã
                              _discountCheckMessage = null;
                            });
                          }
                        },
                        activeColor: const Color(0xFF1CE88A),
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        tileColor: _rentalMode == RentalMode.day ? Colors.grey[850] : null,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RadioListTile<RentalMode>(
                        title: const Text('Theo Giờ', style: TextStyle(color: Colors.white)),
                        value: RentalMode.hour,
                        groupValue: _rentalMode,
                        onChanged: (RentalMode? value) {
                          if (value != null) {
                            setState(() {
                              _rentalMode = value;
                              _selectedDate = _selectedDateRange?.start;
                              _selectedDateRange = null;
                              _startTime = null;
                              _endTime = null;
                              _validatedDiscount = null; // Reset mã
                              _discountCheckMessage = null;
                            });
                          }
                        },
                        activeColor: const Color(0xFF1CE88A),
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        tileColor: _rentalMode == RentalMode.hour ? Colors.grey[850] : null,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text('Chọn thời gian', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              InkWell(
                onTap: () {
                  if (_rentalMode == RentalMode.day) {
                    _selectDayModeDateRange(context);
                  } else {
                    _selectHourModeDateTime(context);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[700]!),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[900]
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedTimeText,
                        style: TextStyle(color: ( _rentalMode == RentalMode.day && _selectedDateRange == null) || (_rentalMode == RentalMode.hour && _selectedDate == null) ? Colors.grey[500] : Colors.white , fontSize: 16),
                      ),
                      Icon(Icons.calendar_today_outlined, color: Colors.grey[500], size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text('Mã giảm giá', style: TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _discountCodeController,
                      style: const TextStyle(color: Colors.white),
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'Nhập mã',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        filled: true,
                        fillColor: Colors.grey[900],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(color: Colors.grey[700]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(color: Colors.grey[700]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: Color(0xFF1CE88A)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      // Khi người dùng sửa mã, reset mã đã validate
                      onChanged: (value) {
                        if (_validatedDiscount != null && value.trim().toUpperCase() != _validatedDiscount!['CODE']) {
                          setState(() {
                            _validatedDiscount = null;
                            _discountCheckMessage = 'Mã đã thay đổi, cần áp dụng lại.';
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1CE88A),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isCheckingDiscount ? null : _applyDiscountCode,
                    child: _isCheckingDiscount
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3),
                    )
                        : const Text('Áp dụng', style: TextStyle(color: Colors.black, fontSize: 16)),
                  ),
                ],
              ),
              // Hiển thị thông báo check mã
              if (_discountCheckMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _discountCheckMessage!,
                    style: TextStyle(
                      color: _validatedDiscount != null ? Colors.green : Colors.orange,
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              const Text('Hình thức thanh toán', style: TextStyle(color: Colors.white, fontSize: 16)),
              Theme(
                data: Theme.of(context).copyWith(unselectedWidgetColor: Colors.grey[700]),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text('Thanh toán 100%', style: TextStyle(color: Colors.white)),
                      value: 'full',
                      groupValue: _paymentOption,
                      onChanged: (value) => setState(() => _paymentOption = value!),
                      activeColor: const Color(0xFF1CE88A),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    RadioListTile<String>(
                      title: const Text('Đặt cọc 10%', style: TextStyle(color: Colors.white)),
                      value: 'deposit',
                      groupValue: _paymentOption,
                      onChanged: (value) => setState(() => _paymentOption = value!),
                      activeColor: const Color(0xFF1CE88A),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Thời gian thuê:', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                  Text(
                      _rentalMode == RentalMode.day
                          ? '$_numberOfDays ngày'
                          : '$_numberOfHours giờ',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Tổng tiền:', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                  Text(
                    priceFormat.format(_totalPrice),
                    style: TextStyle(color: Colors.white, fontSize: 16,
                      decoration: _discountAmount > 0 ? TextDecoration.lineThrough : TextDecoration.none, // Gạch đi nếu có giảm giá
                    ),
                  ),
                ],
              ),

              // Hiển thị tiền giảm giá
              if (_discountAmount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Giảm giá:', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                      Text(
                        priceFormat.format(-_discountAmount), // Hiển thị số âm
                        style: const TextStyle(color: Color(0xFF1CE88A), fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Thành tiền:', style: TextStyle(color: Colors.grey[400], fontSize: 18)),
                  Text(
                    priceFormat.format(_finalPrice), // Dùng giá cuối cùng
                    style: const TextStyle(color: Color(0xFF1CE88A), fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    children: [
                      const TextSpan(text: 'Bằng việc tiếp tục, bạn đồng ý với '),
                      TextSpan(
                        text: 'Chính sách đặt xe & hủy chuyến',
                        style: const TextStyle(color: Color(0xFF1CE88A), decoration: TextDecoration.underline),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: Colors.grey[850],
                                title: const Text("Chính Sách Chi Tiết", style: TextStyle(color: Colors.white)),
                                content: const SingleChildScrollView(
                                  child: Text(
                                    '''
Chính sách Hủy Chuyến
Để đảm bảo trải nghiệm tốt nhất cho tất cả khách hàng, chúng tôi áp dụng chính sách hủy đơn như sau. Vui lòng đọc kỹ trước khi xác nhận hủy.

1. Hủy khi chưa thanh toán
- Đơn hàng "Chờ thanh toán" trong 15 phút sau khi đặt.
- Tự hủy: Miễn phí trong thời gian này.
- Hệ thống hủy: Sau 15 phút không thanh toán, đơn tự hủy miễn phí.

2. Hủy sau khi đã thanh toán (Đơn đã xác nhận)
- Đã đặt cọc (10%): Nếu hủy, mất toàn bộ tiền cọc.
- Đã thanh toán 100%:
  + Hủy trước 24 giờ so với giờ nhận xe: Phí hủy 10% tổng giá trị. Hoàn lại 90%.
  + Hủy trong vòng 24 giờ so với giờ nhận xe: Phí hủy 50% tổng giá trị. Hoàn lại 50%.
- Tiền hoàn (nếu có) sẽ được xử lý qua PayOS về tài khoản đã dùng.

Chi phí Phát sinh & Bồi thường
- Chi phí phát sinh/thiệt hại sẽ được xác định và thu khi trả xe.
- Quy trình: Kiểm tra xe -> Thông báo chi phí (nếu có) -> Thanh toán tiền mặt -> Ghi nhận vào biên bản.
                                    ''',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng', style: TextStyle(color: Color(0xFF1CE88A))))],
                              ),
                            );
                          },
                      ),
                      const TextSpan(text: ' của chúng tôi.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        // SỬA LỖI: Thêm tham số `padding`
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1CE88A),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            disabledBackgroundColor: Colors.grey[700],
          ),
          onPressed: _isLoading ||
              (_rentalMode == RentalMode.day && _selectedDateRange == null) ||
              (_rentalMode == RentalMode.hour && (_selectedDate == null || _startTime == null || _endTime == null)) ||
              _totalPrice <= 0
              ? null
              : _confirmBooking,
          child: _isLoading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3,))
              : const Text(
              'Tiến hành thanh toán',
              style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold
              )
          ),
        ),
      ),
    );
  }
}