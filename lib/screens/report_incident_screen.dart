import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/api/api_service.dart';

class ReportIncidentScreen extends StatefulWidget {
  final int orderId;
  final int carId;

  const ReportIncidentScreen({
    super.key,
    required this.orderId,
    required this.carId,
  });

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _contentController = TextEditingController();

  final List<XFile> _selectedFiles = [];
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  // 1. Chọn nhiều ảnh
  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() => _selectedFiles.addAll(images));
    }
  }

  // 2. Chụp ảnh
  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() => _selectedFiles.add(photo));
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2), // Giới hạn độ dài video
    );

    if (video != null) {
      setState(() => _selectedFiles.add(video));
    }
  }

  Future<void> _submitReport() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập nội dung sự cố')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiService = ApiService();
      // Chuyển danh sách file thành đường dẫn
      List<String> filePaths = _selectedFiles.map((e) => e.path).toList();

      await apiService.reportIncident(
        widget.orderId,
        widget.carId,
        _contentController.text.trim(),
        filePaths,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi báo cáo thành công!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper để kiểm tra xem file có phải video
  bool _isVideo(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv'].contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Báo cáo sự cố', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mô tả sự cố:',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contentController,
              style: const TextStyle(color: Colors.white),
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Nhập chi tiết sự cố (xe hỏng, va chạm, v.v...)',
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            // --- CÁC NÚT CHỌN MEDIA ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Hình ảnh / Video:',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    // Nút chụp ảnh
                    IconButton(
                      icon: const Icon(Icons.camera_alt, color: Color(0xFF1CE88A)),
                      onPressed: _takePhoto,
                      tooltip: 'Chụp ảnh',
                    ),
                    // Nút chọn ảnh
                    IconButton(
                      icon: const Icon(Icons.image, color: Color(0xFF1CE88A)),
                      onPressed: _pickImages,
                      tooltip: 'Chọn ảnh',
                    ),
                    // Nút chọn Video
                    IconButton(
                      icon: const Icon(Icons.videocam, color: Colors.orange),
                      onPressed: _pickVideo,
                      tooltip: 'Chọn video',
                    ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 10),

            // --- GRID HIỂN THỊ FILE ĐÃ CHỌN ---
            if (_selectedFiles.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _selectedFiles.length,
                itemBuilder: (context, index) {
                  final file = _selectedFiles[index];
                  final isVideoFile = _isVideo(file.path);

                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: Colors.grey[800], // Màu nền cho video
                          child: isVideoFile
                              ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.play_circle_fill, color: Colors.white, size: 30),
                                SizedBox(height: 4),
                                Text("Video", style: TextStyle(color: Colors.white, fontSize: 10))
                              ],
                            ),
                          )
                              : Image.file(
                            File(file.path),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      // Nút xóa
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedFiles.removeAt(index);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text('Chưa có media nào được chọn', style: TextStyle(color: Colors.grey[700])),
                ),
              ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1CE88A),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _submitReport,
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black))
                    : const Text('Gửi Báo Cáo', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}