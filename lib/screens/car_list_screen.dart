import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:mobile/providers/car_provider.dart';
import 'package:mobile/api/api_service.dart';
import 'package:mobile/screens/car_detail_screen.dart';

class CarListScreen extends StatefulWidget {
  const CarListScreen({super.key});

  @override
  State<CarListScreen> createState() => _CarListScreenState();
}

class _CarListScreenState extends State<CarListScreen> {
  final _searchController = TextEditingController();
  int? _selectedCategoryId;
  int? _selectedBranchId;
  RangeValues _currentPriceRange = const RangeValues(0, 5000000);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterModal(BuildContext context) {
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
            return Padding(
              padding: EdgeInsets.only(
                top: 24, left: 24, right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Wrap(
                runSpacing: 20,
                children: [
                  const Text("Bộ lọc", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),

                  DropdownButtonFormField<int>(
                    value: _selectedCategoryId,
                    hint: const Text("Tất cả loại xe"),
                    decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[700]!)),
                      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1CE88A))),
                    ),
                    dropdownColor: Colors.grey[800],
                    onChanged: (value) => setModalState(() => _selectedCategoryId = value),
                    items: carProvider.categories.map<DropdownMenuItem<int>>((category) {
                      return DropdownMenuItem<int>(
                        value: category['CATEGORY_ID'],
                        child: Text(category['NAME'], style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                  ),

                  DropdownButtonFormField<int>(
                    value: _selectedBranchId,
                    hint: const Text("Tất cả chi nhánh"),
                    decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[700]!)),
                      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1CE88A))),
                    ),
                    dropdownColor: Colors.grey[800],
                    onChanged: (value) => setModalState(() => _selectedBranchId = value),
                    items: carProvider.branches.map<DropdownMenuItem<int>>((branch) {
                      return DropdownMenuItem<int>(
                        value: branch['BRANCH_ID'],
                        child: Text(branch['NAME'], style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                  ),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Giá thuê: ${NumberFormat.simpleCurrency(locale: 'vi-VN', decimalDigits: 0).format(_currentPriceRange.start)} - ${NumberFormat.simpleCurrency(locale: 'vi-VN', decimalDigits: 0).format(_currentPriceRange.end)}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      RangeSlider(
                        values: _currentPriceRange,
                        min: 0, max: 10000000,
                        divisions: 20,
                        activeColor: const Color(0xFF1CE88A),
                        labels: RangeLabels(
                          NumberFormat.compactSimpleCurrency(locale: 'vi-VN').format(_currentPriceRange.start),
                          NumberFormat.compactSimpleCurrency(locale: 'vi-VN').format(_currentPriceRange.end),
                        ),
                        onChanged: (values) {
                          setModalState(() => _currentPriceRange = values);
                        },
                      ),
                    ],
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedCategoryId = null;
                            _selectedBranchId = null;
                            _currentPriceRange = const RangeValues(0, 5000000);
                          });
                          setModalState(() {
                            _selectedCategoryId = null;
                            _selectedBranchId = null;
                            _currentPriceRange = const RangeValues(0, 5000000);
                          });
                          Provider.of<CarProvider>(context, listen: false).applyFilters(
                            searchTerm: _searchController.text,
                          );
                        },
                        child: const Text("Xóa bộ lọc", style: TextStyle(color: Colors.white)),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {});
                          Provider.of<CarProvider>(context, listen: false).applyFilters(
                            searchTerm: _searchController.text,
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
        title: const Text("Thuê Xe", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: () => _showFilterModal(context),
          )
        ],
      ),
      body: Consumer<CarProvider>(
        builder: (context, carProvider, child) {
          if (carProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (carProvider.error != null) {
            return Center(child: Text(carProvider.error!, style: const TextStyle(color: Colors.red)));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên, hãng xe...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    carProvider.applyFilters(
                      searchTerm: value,
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
                  onRefresh: () => carProvider.fetchAllData(),
                  child: ListView(
                    children: const [
                      SizedBox(height: 150),
                      Center(child: Text("Không tìm thấy xe phù hợp", style: TextStyle(color: Colors.grey))),
                    ],
                  ),
                )
                    : RefreshIndicator(
                  onRefresh: () => carProvider.fetchAllData(),
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                                child: (fullCarImageUrl != null)
                                    ? Image.network(
                                  fullCarImageUrl,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                  const Center(child: Icon(Icons.image_not_supported, color: Colors.grey, size: 40)),
                                )
                                    : const Center(child: Icon(Icons.directions_car, color: Colors.grey, size: 40)),
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
                                      priceFormat.format(double.tryParse(car['PRICE_PER_DAY'].toString()) ?? 0.0) + '/ngày',
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