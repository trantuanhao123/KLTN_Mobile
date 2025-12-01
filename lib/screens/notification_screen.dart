import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/api/api_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _apiService.getNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Thông báo', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1CE88A)));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Bạn chưa có thông báo nào.', style: TextStyle(color: Colors.grey)));
          }

          final notifications = snapshot.data!;
          // Sắp xếp thông báo mới nhất lên đầu
          // notifications.sort((a, b) => b['CREATED_AT'].compareTo(a['CREATED_AT']));

          return ListView.builder(
            itemCount: notifications.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final item = notifications[index];
              final title = item['TITLE'] ?? 'Thông báo';
              final content = item['CONTENT'] ?? '';
              final dateStr = item['CREATED_AT'];

              String timeDisplay = '';
              if (dateStr != null) {
                try {
                  final date = DateTime.parse(dateStr);
                  timeDisplay = DateFormat('dd/MM/yyyy HH:mm').format(date);
                } catch (_) {}
              }

              return Card(
                color: Colors.grey[900],
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.grey, // Hoặc Colors.grey[800]
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications, color: Color(0xFF1CE88A)),
                  ),
                  title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(content, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text(timeDisplay, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}