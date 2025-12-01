import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/api/api_service.dart';
import 'package:mobile/screens/booking_screen.dart';
import 'package:mobile/screens/edit_profile_screen.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  bool _isVerified = false;
  List<String> _carImages = [];
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _initDefaultImage();
    _initData();
  }

  void _initDefaultImage() {
    var img = widget.car['imageUrl'] ??
        widget.car['IMAGE_URL'] ??
        widget.car['mainImageUrl'] ??
        widget.car['thumbnail'];

    if (img != null && img.toString().trim().isNotEmpty) {
      _carImages.add(_getFullUrl(img.toString().trim()));
    } else {
      _carImages.add("https://via.placeholder.com/400x250?text=No+Image");
    }
  }

  Future<void> _initData() async {
    await Future.wait([
      _fetchCarImages(),
      _getCurrentUser(),
      _loadReviews(),
    ]);
  }

  // Lấy danh sách ảnh từ API getCarImages(carId)
  Future<void> _fetchCarImages() async {
    try {
      final carIdVal = widget.car['CAR_ID'] ?? widget.car['car_id'] ?? widget.car['id'];
      final carId = int.tryParse(carIdVal.toString()) ?? 0;
      if (carId == 0) return;

      final images = await _apiService.getCarImages(carId);

      if (images != null && images.isNotEmpty && mounted) {
        setState(() {
          _carImages.clear();
          for (var img in images) {
            var url = img['URL'] ?? img['url'] ?? img['imageUrl'] ?? img['path'];
            if (url != null && url.toString().trim().isNotEmpty) {
              _carImages.add(_getFullUrl(url.toString().trim()));
            }
          }

          // Nếu API không trả về ảnh nào -> giữ lại ảnh bìa cũ
          if (_carImages.isEmpty) {
            _initDefaultImage();
          }
        });
      }
    } catch (e) {
      print("Lỗi fetch ảnh chi tiết: $e");
      // Không làm gì -> giữ ảnh bìa tạm
    }
  }

  String _getFullUrl(String path) {
    if (path.isEmpty) return "https://via.placeholder.com/400x250?text=No+Image";
    if (path.startsWith('http')) return path;
    return "${_apiService.baseUrl}/images/$path";
  }

  // ================== USER & REVIEW HELPER ==================
  dynamic _findValue(Map<String, dynamic> data, List<String> keys) {
    for (var key in keys) {
      if (data.containsKey(key) && data[key] != null) return data[key];
    }
    if (data['data'] is Map<String, dynamic>) {
      for (var key in keys) {
        if (data['data'].containsKey(key)) return data['data'][key];
      }
    }
    if (data['user'] is Map<String, dynamic>) {
      for (var key in keys) {
        if (data['user'].containsKey(key)) return data['user'][key];
      }
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

          var verifiedVal = _findValue(profile, ['VERIFIED', 'verified', 'is_verified']);
          _isVerified = (verifiedVal == 1 || verifiedVal == true || verifiedVal == '1');
        });
      }
    } catch (e) {
      print("Lỗi lấy user: $e");
    }
  }

  Future<void> _loadReviews() async {
    try {
      final carIdVal = widget.car['CAR_ID'] ?? widget.car['car_id'] ?? widget.car['id'];
      final carId = int.tryParse(carIdVal.toString()) ?? 0;
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
      final total = _allReviews.fold(
          0.0, (sum, r) => sum + (double.tryParse(r['RATING']?.toString() ?? '0') ?? 0.0));
      _averageRating = total / _allReviews.length;
    } else {
      _averageRating = 0.0;
    }
  }

  void _applyFilter() {
    if (_selectedFilterRating == 0) {
      _filteredReviews = List.from(_allReviews);
    } else {
      _filteredReviews = _allReviews
          .where((r) => int.tryParse(r['RATING'].toString()) == _selectedFilterRating)
          .toList();
    }
  }

  void _onFilterSelected(int rating) {
    setState(() {
      _selectedFilterRating = rating;
      _applyFilter();
    });
  }

  // ================== DIALOG SỬA / XÓA REVIEW ==================
  void _showEditReviewDialog(Map<String, dynamic> review) {
    var content = review['CONTENT'] ?? review['content'] ?? "";
    var ratingVal = review['RATING'] ?? review['rating'] ?? 5;
    var reviewIdVal = review['REVIEW_ID'] ?? review['review_id'];
    final controller = TextEditingController(text: content);
    double rating = double.tryParse(ratingVal.toString()) ?? 5.0;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Sửa đánh giá', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                      (i) => IconButton(
                    icon: Icon(i < rating ? Icons.star : Icons.star_border, color: Colors.amber),
                    onPressed: () => setDialogState(() => rating = i + 1.0),
                  ),
                ),
              ),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Nhập nội dung...',
                  hintStyle: TextStyle(color: Colors.grey),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1CE88A)),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await _apiService.updateReview(
                      int.parse(reviewIdVal.toString()), rating.toInt(), controller.text);
                  setState(() {
                    final idx = _allReviews.indexWhere((r) =>
                    (r['REVIEW_ID'] ?? r['review_id']).toString() == reviewIdVal.toString());
                    if (idx != -1) {
                      _allReviews[idx]['CONTENT'] = controller.text;
                      _allReviews[idx]['RATING'] = rating.toInt();
                      _calculateAverage();
                      _applyFilter();
                    }
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã cập nhật!'), backgroundColor: Colors.green));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
                }
              },
              child: const Text('Lưu', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(dynamic reviewIdVal) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Xóa đánh giá?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _apiService.deleteReview(int.parse(reviewIdVal.toString()));
                setState(() {
                  _allReviews.removeWhere((r) =>
                  (r['REVIEW_ID'] ?? r['review_id']).toString() == reviewIdVal.toString());
                  _calculateAverage();
                  _applyFilter();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã xóa!'), backgroundColor: Colors.green));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ================== SLIDER ẢNH ==================
  Widget _buildImageSlider() {
    if (_carImages.isEmpty || _carImages.first.isEmpty) {
      return Container(
        color: Colors.grey[900],
        child: const Center(child: CircularProgressIndicator(color: Color(0xFF1CE88A))),
      );
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: double.infinity,
            viewportFraction: 1.0,
            enableInfiniteScroll: _carImages.length > 1,
            autoPlay: _carImages.length > 1,
            autoPlayInterval: const Duration(seconds: 4),
            onPageChanged: (index, _) => setState(() => _currentImageIndex = index),
          ),
          items: _carImages.map((url) {
            return CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (_, __) => Container(
                color: Colors.grey[900],
                child: const Center(child: CircularProgressIndicator(color: Color(0xFF1CE88A))),
              ),
              errorWidget: (_, __, ___) => Container(
                color: Colors.grey[900],
                child: const Icon(Icons.broken_image, size: 60, color: Colors.grey),
              ),
            );
          }).toList(),
        ),
        if (_carImages.length > 1)
          Positioned(
            bottom: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _carImages.asMap().entries.map((e) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(_currentImageIndex == e.key ? 0.9 : 0.4),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final carData = widget.car;
    final priceFormat = NumberFormat.simpleCurrency(locale: 'vi_VN', decimalDigits: 0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 280.0,
                pinned: true,
                backgroundColor: Colors.black,
                flexibleSpace: FlexibleSpaceBar(background: _buildImageSlider()),
                leading: IconButton(
                  icon: const CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.arrow_back, color: Colors.white)),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tiêu đề xe + giá
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${carData['BRAND'] ?? ''} ${carData['MODEL'] ?? ''}'.toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            '${priceFormat.format(double.tryParse((carData['PRICE_PER_DAY'] ?? carData['price_per_day'] ?? 0).toString()) ?? 0)}/ngày',
                            style: const TextStyle(color: Color(0xFF1CE88A), fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            _averageRating > 0 ? _averageRating.toStringAsFixed(1) : '0.0',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
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
                      Text(carData['DESCRIPTION'] ?? carData['description'] ?? '', style: const TextStyle(color: Colors.grey, height: 1.5)),
                      const SizedBox(height: 32),
                      const Divider(color: Colors.grey),

                      // Phần đánh giá
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Đánh giá từ khách hàng', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          if (_isLoadingReviews)
                            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1CE88A))),
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
                        const Center(
                            child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Text('Chưa có đánh giá nào.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))))
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _filteredReviews.length,
                          separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                          itemBuilder: (context, index) {
                            final review = _filteredReviews[index];
                            final reviewUserId = int.tryParse((review['USER_ID'] ?? review['user_id'] ?? review['userId'] ?? '').toString()) ?? -1;
                            final isOwner = reviewUserId == _currentUserId && _currentUserId != 0;

                            String displayName = (review['FULLNAME'] ?? review['fullname'] ?? review['name'] ?? "USER").toString();
                            if (isOwner) displayName = "$_currentUserName (Bạn)";

                            var avatar = review['AVATAR_URL'] ?? review['avatar_url'] ?? review['avatar'];
                            if (isOwner && avatar == null) avatar = _currentUserAvatar;

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: Colors.grey[800],
                                backgroundImage: avatar != null
                                    ? NetworkImage(avatar.toString().startsWith('http')
                                    ? avatar.toString()
                                    : "${_apiService.baseUrl}/images/$avatar")
                                    : null,
                                child: avatar == null
                                    ? Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                                    style: const TextStyle(color: Colors.white))
                                    : null,
                              ),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(displayName,
                                      style: TextStyle(
                                          color: isOwner ? const Color(0xFF1CE88A) : Colors.white,
                                          fontWeight: FontWeight.bold)),
                                  Text(
                                    review['CREATED_AT'] != null
                                        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(review['CREATED_AT'].toString()))
                                        : '',
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: List.generate(
                                      5,
                                          (i) => Icon(
                                          i < (int.tryParse(review['RATING'].toString()) ?? 0)
                                              ? Icons.star
                                              : Icons.star_border,
                                          color: Colors.amber,
                                          size: 14),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(review['CONTENT'] ?? review['content'] ?? '', style: const TextStyle(color: Colors.white70)),
                                ],
                              ),
                              trailing: isOwner
                                  ? PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Colors.white),
                                color: Colors.grey[850],
                                onSelected: (v) {
                                  if (v == 'edit') _showEditReviewDialog(review);
                                  if (v == 'delete') _showDeleteConfirmDialog(review['REVIEW_ID'] ?? review['review_id']);
                                },
                                itemBuilder: (_) => [
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

          // Nút đặt xe
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                  color: Colors.black,
                  border: Border(top: BorderSide(color: Colors.white12))),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1CE88A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () {
                  if (!_isVerified) {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: Colors.grey[900],
                        title: const Text('Chưa xác thực tài khoản', style: TextStyle(color: Colors.white)),
                        content: const Text(
                            'Bạn cần cập nhật Bằng lái xe và thông tin cá nhân để được xác thực trước khi thuê xe.',
                            style: TextStyle(color: Colors.grey)),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Đóng', style: TextStyle(color: Colors.grey))),
                          ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1CE88A)),
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                              },
                              child: const Text('Cập nhật ngay', style: TextStyle(color: Colors.black))),
                        ],
                      ),
                    );
                    return;
                  }
                  Navigator.push(context, MaterialPageRoute(builder: (_) => BookingScreen(car: widget.car)));
                },
                child: const Text('Đặt xe ngay',
                    style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int rating, String label) {
    final selected = _selectedFilterRating == rating;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: selected ? Colors.black : Colors.white)),
          if (rating > 0) ...[const SizedBox(width: 4), Icon(Icons.star, size: 14, color: selected ? Colors.black : Colors.amber)]
        ],
      ),
      selected: selected,
      selectedColor: const Color(0xFF1CE88A),
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: selected ? const Color(0xFF1CE88A) : Colors.grey[800]!)),
      onSelected: (v) => v ? _onFilterSelected(rating) : null,
    );
  }

  Widget _buildFeatureGrid() {
    final carData = widget.car;
    final features = [
      {'icon': Icons.speed, 'label': 'Hộp số', 'value': carData['TRANSMISSION'] ?? carData['transmission'] ?? 'N/A'},
      {'icon': Icons.airline_seat_recline_normal, 'label': 'Chỗ ngồi', 'value': '${carData['SEATS'] ?? carData['seats'] ?? 4} chỗ'},
      {'icon': Icons.local_gas_station, 'label': 'Nhiên liệu', 'value': carData['FUEL_TYPE'] ?? carData['fuel_type'] ?? 'Xăng'},
      {'icon': Icons.color_lens, 'label': 'Màu sắc', 'value': carData['COLOR'] ?? carData['color'] ?? 'Trắng'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, childAspectRatio: 2.5, crossAxisSpacing: 10, mainAxisSpacing: 10),
      itemCount: features.length,
      itemBuilder: (_, i) {
        final item = features[i];
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10)),
          child: Row(
            children: [
              Icon(item['icon'] as IconData, color: const Color(0xFF1CE88A)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item['label'].toString(), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(item['value'].toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
        );
      },
    );
  }
}