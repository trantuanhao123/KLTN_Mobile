import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final String url;
  const PaymentWebViewScreen({super.key, required this.url});

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _error = null;
            });
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },

          onUrlChange: (UrlChange change) {
            final newUrl = change.url;
            if (newUrl != null && newUrl.contains('payment-result')) {
              // Phân tích URL để lấy các tham số query
              final uri = Uri.parse(newUrl);

              final isCancelled = uri.queryParameters['cancel']; // 'true' hoặc null
              final status = uri.queryParameters['status'];     // 'PAID', 'CANCELLED', 'FAILED'

              print('PayOS Redirect URL: $newUrl'); // Dành cho debug
              print('PayOS Status: $status, Cancel: $isCancelled');

              if (isCancelled == 'true') {
                // Trường hợp 1: Người dùng nhấn "Hủy"
                Navigator.pop(context, 'cancelled');
              } else if (status == 'PAID') {
                // Trường hợp 2: Thanh toán thành công
                Navigator.pop(context, 'success');
              } else if (status == 'CANCELLED' || status == 'FAILED') {
                // Trường hợp 3: Thanh toán thất bại (hết hạn, từ chối...)
                Navigator.pop(context, 'error');
              }
              // Nếu không phải 3 trường hợp trên, WebView sẽ tiếp tục tải trang
            }
          },

          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
              _error = "Lỗi tải trang: ${error.description}";
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Thanh toán', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: Colors.grey[900],
                title: Text('Hủy thanh toán?', style: TextStyle(color: Colors.white)),
                content: Text('Bạn có chắc chắn muốn hủy giao dịch này?', style: TextStyle(color: Colors.grey)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context), // Đóng dialog
                    child: Text('Không', style: TextStyle(color: Colors.grey)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // Đóng dialog
                      Navigator.pop(context, 'cancelled'); // Quay về màn hình trước
                    },
                    child: Text('Đồng ý Hủy', style: TextStyle(color: Colors.orange)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      body: Stack(
        children: [
          if (_error != null)
            Center(
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            )
          else
            WebViewWidget(controller: _controller),

          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF1CE88A)),
            ),
        ],
      ),
    );
  }
}