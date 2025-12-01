import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:mobile/api/api_service.dart'; // Import API service

class PaymentWebViewScreen extends StatefulWidget {
  final String url;
  final int orderId; // Nhận Order ID để hủy

  const PaymentWebViewScreen({
    super.key,
    required this.url,
    required this.orderId,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isHandle = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            if (_checkResultUrl(request.url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (String url) {
            _checkResultUrl(url);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  // Hàm xử lý gọi API hủy đơn hàng
  Future<void> _cancelOrderAndPop() async {
    if (_isHandle) return;
    _isHandle = true;

    // Hiển thị loading nhẹ
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator(color: Color(0xFF1CE88A))),
    );

    try {
      final apiService = ApiService();
      // Gọi API hủy đơn với trạng thái 'PENDING'
      // Hàm này dựa trên logic trong MyBookingScreen của bạn
      await apiService.cancelOrder(widget.orderId, 'PENDING');
      print("Đã gọi API hủy đơn hàng ${widget.orderId} thành công");
    } catch (e) {
      print("Lỗi khi gọi API hủy: $e");
    } finally {
      Navigator.of(context).pop(); // Đóng loading dialog
      Navigator.of(context).pop('cancelled'); // Đóng màn hình thanh toán trả về cancelled
    }
  }

  bool _checkResultUrl(String url) {
    if (_isHandle) return true;

    final uri = Uri.parse(url);

    if (url.contains('/result') || uri.queryParameters['status'] == 'PAID') {

      // TRƯỜNG HỢP 1: Bấm nút "Hủy" trên giao diện PayOS
      if (uri.queryParameters['cancel'] == 'true' ||
          uri.queryParameters['status'] == 'CANCELLED') {
        _cancelOrderAndPop(); // Gọi hàm hủy
        return true;
      }

      // TRƯỜNG HỢP 2: Thanh toán thành công
      if (uri.queryParameters['code'] == '00' ||
          uri.queryParameters['status'] == 'PAID' ||
          uri.queryParameters['id'] != null) {
        _isHandle = true;
        Navigator.pop(context, 'success');
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Thanh toán PayOS', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            // TRƯỜNG HỢP 3: Bấm nút "X" trên App Bar
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: Colors.grey[900],
                title: const Text('Hủy thanh toán?', style: TextStyle(color: Colors.white)),
                content: const Text('Giao dịch sẽ bị hủy và xe sẽ được mở lại cho người khác.', style: TextStyle(color: Colors.grey)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Tiếp tục thanh toán', style: TextStyle(color: Colors.white)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // Đóng dialog
                      _cancelOrderAndPop(); // Gọi hàm hủy đơn + đóng webview
                    },
                    child: const Text('Hủy đơn', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}