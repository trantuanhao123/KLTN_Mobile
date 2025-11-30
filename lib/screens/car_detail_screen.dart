import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/api/api_service.dart';
import 'package:mobile/screens/booking_screen.dart';
import 'package:mobile/screens/edit_profile_screen.dart';

class CarDetailScreen extends StatefulWidget {
  final Map<String, dynamic> car;
  const CarDetailScreen({super.key, required this.car});

  @override
  State<CarDetailScreen> createState() => _CarDetailScreenState();
}

class _CarDetailScreenState extends State<CarDetailScreen> {
  final ApiService _apiService = ApiService();

  List<dynamic> _allReviews = [];
  List<dynamic> _filteredReviews = [];
  bool _isLoadingReviews = true;

  int _currentUserId = 0;
  String _currentUserName = "";
  String? _currentUserAvatar;
  double _averageRating = 0.0;
  int _selectedFilterRating = 0;

  bool _isVerified = false; // Biến lưu trạng thái xác thực

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _getCurrentUser();
    await _loadReviews();
  }

  // Helper tìm kiếm dữ liệu (Deep Search)
  dynamic _findValue(Map<String, dynamic> data, List<String> keys) {
    for (var key in keys) {
      if (data.containsKey(key) && data[key] != null) return data[key];
    }
    if (data['data'] is Map<String, dynamic>) {
      for (var key in keys) { if (data['data'].containsKey(key)) return data['data'][key]; }
    }
    if (data['user'] is Map<String, dynamic>) {
      for (var key in keys) { if (data['user'].containsKey(key)) return data['user'][key]; }
    }
    return null;
  }

  Future<void> _getCurrentUser() async {
    try {
      final profile = await _apiService.getUserProfile();
      if (mounted) {
        setState(() {
          var idVal = _findValue(profile, ['USER_ID', 'user_id', 'id', 'ID']);
          _currentUserId = int.tryParse(idVal.toString()) ?? 0;

          var nameVal = _findValue(profile, ['FULLNAME', 'fullname', 'name']);
          _currentUserName = nameVal?.toString() ?? "Tôi";

          var avatarVal = _findValue(profile, ['AVATAR_URL', 'avatar_url', 'avatar']);
          _currentUserAvatar = avatarVal?.toString();

          // Lấy trạng thái xác thực
          var verifiedVal = _findValue(profile, ['VERIFIED', 'verified', 'is_verified']);
          // Backend có thể trả về 1/0 hoặc true/false
          if (verifiedVal == 1 || verifiedVal == true || verifiedVal == '1') {
            _isVerified = true;
          } else {
            _isVerified = false;
          }
        });
      }
    } catch (e) {
      print("Lỗi user: $e");
    }
  }

  Future<void> _loadReviews() async {
    try {
      var carIdVal = widget.car['CAR_ID'] ?? widget.car['car_id'] ?? widget.car['id'];
      final carId = int.parse(carIdVal.toString());
      final reviews = await _apiService.getReviewsByCarId(carId);

      if (mounted) {
        setState(() {
          _allReviews = reviews;
          _calculateAverage();
          _applyFilter();
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  void _calculateAverage() {
    if (_allReviews.isNotEmpty) {
      final totalStars = _allReviews.fold(0.0, (sum, item) => sum + (double.tryParse(item['RATING']?.toString() ?? '0') ?? 0.0));
      _averageRating = totalStars / _allReviews.length;
    } else {
      _averageRating = 0.0;
    }
  }

  void _applyFilter() {
    if (_selectedFilterRating == 0) {
      _filteredReviews = List.from(_allReviews);
    } else {
      _filteredReviews = _allReviews.where((review) {
        final rating = int.tryParse(review['RATING'].toString()) ?? 0;
        return rating == _selectedFilterRating;
      }).toList();
    }
  }

  void _onFilterSelected(int rating) {
    setState(() {
      _selectedFilterRating = rating;
      _applyFilter();
    });
  }

  // --- LOGIC SỬA NHANH (Optimistic Update) ---
  void _showEditReviewDialog(Map<String, dynamic> review) {
    var content = review['CONTENT'] ?? review['content'] ?? "";
    var ratingVal = review['RATING'] ?? review['rating'] ?? 5;
    var reviewIdVal = review['REVIEW_ID'] ?? review['review_id'];

    final TextEditingController contentController = TextEditingController(text: content.toString());
    double rating = double.tryParse(ratingVal.toString()) ?? 5.0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Sửa đánh giá', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(index < rating ? Icons.star : Icons.star_border, color: Colors.amber),
                    onPressed: () => setDialogState(() => rating = index + 1.0),
                  );
                }),
              ),
              TextField(
                controller: contentController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: 'Nhập nội dung...', hintStyle: TextStyle(color: Colors.grey)),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1CE88A)),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  int reviewId = int.parse(reviewIdVal.toString());

                  // 1. Gọi API
                  await _apiService.updateReview(reviewId, rating.toInt(), contentController.text);

                  // 2. CẬP NHẬT GIAO DIỆN NGAY LẬP TỨC
                  setState(() {
                    final index = _allReviews.indexWhere((r) {
                      var rId = r['REVIEW_ID'] ?? r['review_id'];
                      return rId.toString() == reviewId.toString();
                    });

                    if (index != -1) {
                      _allReviews[index]['CONTENT'] = contentController.text;
                      _allReviews[index]['RATING'] = rating;
                      // Cập nhật cả filtered list để hiển thị ngay
                      _calculateAverage();
                      _applyFilter();
                    }
                  });

                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật!'), backgroundColor: Colors.green));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
                }
              },
              child: const Text('Lưu', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  // --- LOGIC XÓA NHANH (Optimistic Update) ---
  void _showDeleteConfirmDialog(dynamic reviewIdVal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Xóa đánh giá?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                int reviewId = int.parse(reviewIdVal.toString());

                // 1. Gọi API
                await _apiService.deleteReview(reviewId);

                // 2. XÓA KHỎI GIAO DIỆN NGAY LẬP TỨC
                setState(() {
                  _allReviews.removeWhere((r) {
                    var rId = r['REVIEW_ID'] ?? r['review_id'];
                    return rId.toString() == reviewId.toString();
                  });
                  _calculateAverage();
                  _applyFilter();
                });

                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa!'), backgroundColor: Colors.green));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Lấy thông tin xe
    var carData = widget.car;
    var carPriceDay = carData['PRICE_PER_DAY'] ?? carData['price_per_day'] ?? 0;
    var carBrand = carData['BRAND'] ?? carData['brand'] ?? '';
    var carModel = carData['MODEL'] ?? carData['model'] ?? '';
    var carDesc = carData['DESCRIPTION'] ?? carData['description'] ?? '';
    var carImg = carData['mainImageUrl'] ?? carData['imageUrl'] ?? carData['IMAGE_URL'];

    final priceFormat = NumberFormat.simpleCurrency(locale: 'vi-VN', decimalDigits: 0);
    final String fullImageUrl = carImg != null
        ? (carImg.toString().startsWith('http') ? carImg.toString() : "${_apiService.baseUrl}/images/$carImg")
        : 'https://via.placeholder.com/400x200';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // 1. Ảnh bìa (Giữ nguyên giao diện đẹp cũ)
              SliverAppBar(
                expandedHeight: 250.0,
                pinned: true,
                backgroundColor: Colors.black,
                flexibleSpace: FlexibleSpaceBar(
                  background: Image.network(fullImageUrl, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Center(child: Icon(Icons.error, color: Colors.white))),
                ),
                leading: IconButton(
                  icon: const CircleAvatar(backgroundColor: Colors.black54, child: Icon(Icons.arrow_back, color: Colors.white)),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // [ĐÃ XÓA] Thông báo màu vàng ở đây

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text('$carBrand $carModel'.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
                          Text('${priceFormat.format(double.tryParse(carPriceDay.toString()) ?? 0)}/ngày', style: const TextStyle(color: Color(0xFF1CE88A), fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),

                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 20),
                          const SizedBox(width: 4),
                          Text(_averageRating > 0 ? _averageRating.toStringAsFixed(1) : '0.0', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(' (${_allReviews.length} đánh giá)', style: const TextStyle(color: Colors.grey)),
                        ],
                      ),

                      const SizedBox(height: 24),
                      const Text('Đặc điểm', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildFeatureGrid(),

                      const SizedBox(height: 24),
                      const Text('Mô tả', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(carDesc.toString(), style: const TextStyle(color: Colors.grey, height: 1.5)),

                      const SizedBox(height: 32),
                      const Divider(color: Colors.grey),

                      // ================= PHẦN ĐÁNH GIÁ =================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Đánh giá từ khách hàng', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          if (_isLoadingReviews) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1CE88A))),
                        ],
                      ),
                      const SizedBox(height: 16),

                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip(0, 'Tất cả'), const SizedBox(width: 8),
                            _buildFilterChip(5, '5 sao'), const SizedBox(width: 8),
                            _buildFilterChip(4, '4 sao'), const SizedBox(width: 8),
                            _buildFilterChip(3, '3 sao'), const SizedBox(width: 8),
                            _buildFilterChip(2, '2 sao'), const SizedBox(width: 8),
                            _buildFilterChip(1, '1 sao'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (!_isLoadingReviews && _filteredReviews.isEmpty)
                        const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('Chưa có đánh giá nào.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))))
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _filteredReviews.length,
                          separatorBuilder: (context, index) => const Divider(color: Colors.white10),
                          itemBuilder: (context, index) {
                            final review = _filteredReviews[index];

                            // Tìm ID user (Deep search)
                            var rUserIdVal = review['USER_ID'] ?? review['user_id'] ?? review['userId'];
                            final int reviewUserId = int.tryParse(rUserIdVal.toString()) ?? -1;

                            // Check quyền sở hữu
                            final bool isOwner = (reviewUserId == _currentUserId) && (_currentUserId != 0);

                            // Lấy thông tin hiển thị
                            var rNameVal = review['FULLNAME'] ?? review['fullname'] ?? review['name'];
                            String displayName = rNameVal?.toString() ?? "USER $reviewUserId";
                            if (isOwner) displayName = "$_currentUserName (Bạn)";

                            var rAvatarVal = review['AVATAR_URL'] ?? review['avatar_url'] ?? review['avatar'];
                            if (isOwner && rAvatarVal == null) rAvatarVal = _currentUserAvatar;

                            var rRatingVal = review['RATING'] ?? review['rating'];
                            var rContentVal = review['CONTENT'] ?? review['content'];
                            var rReviewIdVal = review['REVIEW_ID'] ?? review['review_id'] ?? review['id'];
                            var rDateVal = review['CREATED_AT'] ?? review['created_at'];

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: Colors.grey[800],
                                backgroundImage: rAvatarVal != null ? NetworkImage(rAvatarVal.toString().startsWith('http') ? rAvatarVal.toString() : "${_apiService.baseUrl}/images/$rAvatarVal") : null,
                                child: rAvatarVal == null ? Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white)) : null,
                              ),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(displayName, style: TextStyle(color: isOwner ? const Color(0xFF1CE88A) : Colors.white, fontWeight: FontWeight.bold)),
                                  Text(rDateVal != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(rDateVal.toString())) : '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: List.generate(5, (i) => Icon(i < (int.tryParse(rRatingVal.toString()) ?? 0) ? Icons.star : Icons.star_border, color: Colors.amber, size: 14)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(rContentVal?.toString() ?? '', style: const TextStyle(color: Colors.white70)),
                                ],
                              ),
                              trailing: isOwner
                                  ? PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Colors.white),
                                color: Colors.grey[850],
                                onSelected: (value) {
                                  if (value == 'edit') _showEditReviewDialog(review);
                                  if (value == 'delete') _showDeleteConfirmDialog(rReviewIdVal);
                                },
                                itemBuilder: (BuildContext context) => [
                                  const PopupMenuItem(value: 'edit', child: Text('Sửa', style: TextStyle(color: Colors.white))),
                                  const PopupMenuItem(value: 'delete', child: Text('Xóa', style: TextStyle(color: Colors.redAccent))),
                                ],
                              )
                                  : null,
                            );
                          },
                        ),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),

          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: Colors.black, border: Border(top: BorderSide(color: Colors.white12))),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1CE88A), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () {
                  // KIỂM TRA XÁC THỰC
                  if (!_isVerified) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Colors.grey[900],
                        title: const Text('Chưa xác thực tài khoản', style: TextStyle(color: Colors.white)),
                        content: const Text(
                          'Bạn cần cập nhật Bằng lái xe và thông tin cá nhân để được xác thực trước khi thuê xe.',
                          style: TextStyle(color: Colors.grey),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Đóng', style: TextStyle(color: Colors.grey)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1CE88A)),
                            onPressed: () {
                              Navigator.pop(context); // 1. Đóng cái Dialog thông báo lại

                              // 2. Chuyển thẳng đến màn hình chỉnh sửa hồ sơ
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                              );
                            },
                            child: const Text('Cập nhật ngay', style: TextStyle(color: Colors.black)),
                          ),
                        ],
                      ),
                    );
                    return; // Dừng lại, không cho vào BookingScreen
                  }

                  // Nếu đã xác thực thì cho đi tiếp
                  Navigator.push(context, MaterialPageRoute(builder: (context) => BookingScreen(car: widget.car)));
                },
                child: const Text('Đặt xe ngay', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int rating, String label) {
    final bool isSelected = _selectedFilterRating == rating;
    return ChoiceChip(
      label: Row(mainAxisSize: MainAxisSize.min, children: [Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white)), if (rating > 0) ...[const SizedBox(width: 4), Icon(Icons.star, size: 14, color: isSelected ? Colors.black : Colors.amber)]]),
      selected: isSelected,
      selectedColor: const Color(0xFF1CE88A),
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? const Color(0xFF1CE88A) : Colors.grey[800]!)),
      onSelected: (bool selected) { if (selected) _onFilterSelected(rating); },
    );
  }

  Widget _buildFeatureGrid() {
    var carData = widget.car;
    var transVal = carData['TRANSMISSION'] ?? carData['transmission'] ?? 'N/A';
    var seatsVal = carData['SEATS'] ?? carData['seats'] ?? 4;
    var fuelVal = carData['FUEL_TYPE'] ?? carData['fuel_type'] ?? 'Xăng';
    var colorVal = carData['COLOR'] ?? carData['color'] ?? 'Trắng';

    final features = [
      {'icon': Icons.speed, 'label': 'Tự động', 'value': transVal},
      {'icon': Icons.airline_seat_recline_normal, 'label': 'Chỗ ngồi', 'value': '$seatsVal chỗ'},
      {'icon': Icons.local_gas_station, 'label': 'Nhiên liệu', 'value': fuelVal},
      {'icon': Icons.color_lens, 'label': 'Màu sắc', 'value': colorVal},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2.5, crossAxisSpacing: 10, mainAxisSpacing: 10),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final item = features[index];
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)),
          child: Row(children: [Icon(item['icon'] as IconData, color: const Color(0xFF1CE88A)), const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(item['label'].toString(), style: const TextStyle(color: Colors.grey, fontSize: 12)), Text(item['value'].toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))])]),
        );
      },
    );
  }
}