import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:mobile/providers/car_provider.dart';
import 'package:mobile/api/api_service.dart';
import 'package:mobile/screens/car_detail_screen.dart';

class CarListScreen extends StatefulWidget {
  final String? initialBrandFilter;

  const CarListScreen({super.key, this.initialBrandFilter});

  @override
  State<CarListScreen> createState() => _CarListScreenState();
}

class _CarListScreenState extends State<CarListScreen> {
  final _searchController = TextEditingController();
  String? _selectedBrand;
  int? _selectedCategoryId;
  int? _selectedBranchId;
  RangeValues _currentPriceRange = const RangeValues(0, 5000000);

  String? _modalSelectedBrand;
  int? _modalSelectedCategoryId;
  int? _modalSelectedBranchId;
  RangeValues _modalPriceRange = const RangeValues(0, 5000000);

  @override
  void initState() {
    super.initState();
    _selectedBrand = widget.initialBrandFilter;
    _modalSelectedBrand = _selectedBrand;
    _modalPriceRange = _currentPriceRange;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final carProvider = Provider.of<CarProvider>(context, listen: false);
      carProvider.applyFilters(
        brandName: _selectedBrand,
        searchTerm: _searchController.text,
        categoryId: _selectedCategoryId,
        branchId: _selectedBranchId,
        priceRange: _currentPriceRange,
      );
      if (_selectedBrand != null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterModal(BuildContext context) {
    _modalSelectedBrand = _selectedBrand;
    _modalSelectedCategoryId = _selectedCategoryId;
    _modalSelectedBranchId = _selectedBranchId;
    _modalPriceRange = _currentPriceRange;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final carProvider = Provider.of<CarProvider>(context, listen: false);
            final uniqueBrands = carProvider.allCars.map((c) => c['BRAND'] as String?).where((b) => b != null).toSet().toList();
            uniqueBrands.sort();

            InputDecoration dropdownDecoration(String hint) {
              return InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[850],
                enabledBorder: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF1CE88A)), borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                top: 24, left: 24, right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Wrap(
                runSpacing: 20,
                children: [
                  const Text("Bộ lọc", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),

                  DropdownButtonFormField<String>(
                      value: _modalSelectedBrand,
                      decoration: dropdownDecoration("Tất cả thương hiệu"),
                      dropdownColor: Colors.grey[800],
                      style: const TextStyle(color: Colors.white),
                      iconEnabledColor: Colors.grey[400],
                      isExpanded: true,
                      onChanged: (value) => setModalState(() => _modalSelectedBrand = value),
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text("Tất cả thương hiệu", style: TextStyle(color: Colors.grey))),
                        ...uniqueBrands.map<DropdownMenuItem<String>>((brand) {
                          return DropdownMenuItem<String>(value: brand, child: Text(brand!));
                        }).toList(),
                      ]
                  ),

                  DropdownButtonFormField<int>(
                      value: _modalSelectedCategoryId,
                      decoration: dropdownDecoration("Tất cả loại xe"),
                      dropdownColor: Colors.grey[800],
                      style: const TextStyle(color: Colors.white),
                      iconEnabledColor: Colors.grey[400],
                      isExpanded: true,
                      onChanged: (value) => setModalState(() => _modalSelectedCategoryId = value),
                      items: [
                        const DropdownMenuItem<int>(value: null, child: Text("Tất cả loại xe", style: TextStyle(color: Colors.grey))),
                        ...carProvider.categories.map<DropdownMenuItem<int>>((category) {
                          return DropdownMenuItem<int>(
                            value: category['CATEGORY_ID'],
                            child: Text(category['NAME'] ?? 'N/A'),
                          );
                        }).toList(),
                      ]
                  ),

                  DropdownButtonFormField<int>(
                      value: _modalSelectedBranchId,
                      decoration: dropdownDecoration("Tất cả chi nhánh"),
                      dropdownColor: Colors.grey[800],
                      style: const TextStyle(color: Colors.white),
                      iconEnabledColor: Colors.grey[400],
                      isExpanded: true,
                      onChanged: (value) => setModalState(() => _modalSelectedBranchId = value),
                      items: [
                        const DropdownMenuItem<int>(value: null, child: Text("Tất cả chi nhánh", style: TextStyle(color: Colors.grey))),
                        ...carProvider.branches.map<DropdownMenuItem<int>>((branch) {
                          return DropdownMenuItem<int>(
                            value: branch['BRANCH_ID'],
                            child: Text(branch['NAME'] ?? 'N/A'),
                          );
                        }).toList(),
                      ]
                  ),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Giá thuê/ngày: ${NumberFormat.simpleCurrency(locale: 'vi-VN', decimalDigits: 0).format(_modalPriceRange.start)} - ${NumberFormat.simpleCurrency(locale: 'vi-VN', decimalDigits: 0).format(_modalPriceRange.end)}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      RangeSlider(
                        values: _modalPriceRange,
                        min: 0, max: 10000000,
                        divisions: 20,
                        activeColor: const Color(0xFF1CE88A),
                        inactiveColor: Colors.grey[700],
                        // SỬA LỖI: Xóa `const` khỏi RangeLabels
                        labels: RangeLabels(
                          NumberFormat.compactSimpleCurrency(locale: 'vi-VN', decimalDigits: 0).format(_modalPriceRange.start),
                          NumberFormat.compactSimpleCurrency(locale: 'vi-VN', decimalDigits: 0).format(_modalPriceRange.end),
                        ),
                        onChanged: (values) {
                          setModalState(() => _modalPriceRange = values);
                        },
                      ),
                    ],
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _modalSelectedBrand = null;
                            _modalSelectedCategoryId = null;
                            _modalSelectedBranchId = null;
                            _modalPriceRange = const RangeValues(0, 5000000);
                          });
                          setState(() {
                            _selectedBrand = null;
                            _selectedCategoryId = null;
                            _selectedBranchId = null;
                            _currentPriceRange = const RangeValues(0, 5000000);
                            _searchController.clear();
                          });
                          Provider.of<CarProvider>(context, listen: false).applyFilters();
                          Navigator.pop(context);
                        },
                        child: const Text("Xóa bộ lọc", style: TextStyle(color: Colors.white)),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedBrand = _modalSelectedBrand;
                            _selectedCategoryId = _modalSelectedCategoryId;
                            _selectedBranchId = _modalSelectedBranchId;
                            _currentPriceRange = _modalPriceRange;
                          });
                          Provider.of<CarProvider>(context, listen: false).applyFilters(
                            searchTerm: _searchController.text,
                            brandName: _selectedBrand,
                            categoryId: _selectedCategoryId,
                            branchId: _selectedBranchId,
                            priceRange: _currentPriceRange,
                          );
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1CE88A)),
                        child: const Text("Áp dụng", style: TextStyle(color: Colors.black)),
                      ),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseUrl = ApiService().baseUrl;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
            _selectedBrand ?? "Thuê Xe",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: () => _showFilterModal(context),
          )
        ],
      ),
      body: Consumer<CarProvider>(
        builder: (context, carProvider, child) {
          if (carProvider.isLoading && carProvider.filteredCars.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1CE88A)));
          }
          if (carProvider.error != null) {
            return Center(child: Text('Lỗi: ${carProvider.error!}', style: const TextStyle(color: Colors.red)));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên, hãng, biển số...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  onChanged: (value) {
                    carProvider.applyFilters(
                      searchTerm: value,
                      brandName: _selectedBrand,
                      categoryId: _selectedCategoryId,
                      branchId: _selectedBranchId,
                      priceRange: _currentPriceRange,
                    );
                  },
                ),
              ),
              Expanded(
                child: carProvider.filteredCars.isEmpty
                    ? RefreshIndicator(
                  onRefresh: () => carProvider.fetchAllData().then((_){
                    carProvider.applyFilters(
                      searchTerm: _searchController.text,
                      brandName: _selectedBrand,
                      categoryId: _selectedCategoryId,
                      branchId: _selectedBranchId,
                      priceRange: _currentPriceRange,
                    );
                  }),
                  color: const Color(0xFF1CE88A),
                  backgroundColor: Colors.grey[900],
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 150),
                      Center(child: Text("Không tìm thấy xe phù hợp", style: TextStyle(color: Colors.grey))),
                    ],
                  ),
                )
                    : RefreshIndicator(
                  onRefresh: () => carProvider.fetchAllData().then((_){
                    carProvider.applyFilters(
                      searchTerm: _searchController.text,
                      brandName: _selectedBrand,
                      categoryId: _selectedCategoryId,
                      branchId: _selectedBranchId,
                      priceRange: _currentPriceRange,
                    );
                  }),
                  color: const Color(0xFF1CE88A),
                  backgroundColor: Colors.grey[900],
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16.0,
                      mainAxisSpacing: 16.0,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: carProvider.filteredCars.length,
                    itemBuilder: (context, index) {
                      final car = carProvider.filteredCars[index];
                      final priceFormat = NumberFormat.simpleCurrency(locale: 'vi-VN', decimalDigits: 0);
                      final imageUrl = car['mainImageUrl'];
                      final fullCarImageUrl = imageUrl != null ? "$baseUrl/images/$imageUrl" : null;
                      final pricePerDay = double.tryParse(car['PRICE_PER_DAY']?.toString() ?? '0.0') ?? 0.0;

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CarDetailScreen(car: car),
                            ),
                          );
                        },
                        child: Card(
                          color: Colors.grey[900],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: SizedBox(
                                  width: double.infinity,
                                  child: (fullCarImageUrl != null)
                                      ? Image.network(
                                    fullCarImageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                    const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40)),
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey[700]));
                                    },
                                  )
                                      : const Center(child: Icon(Icons.directions_car, color: Colors.grey, size: 40)),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${car['BRAND'] ?? ''} ${car['MODEL'] ?? ''}",
                                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      priceFormat.format(pricePerDay) + '/ngày',
                                      style: const TextStyle(color: Color(0xFF1CE88A), fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}