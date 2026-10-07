import 'package:flutter/material.dart';
import '../../data/mock_store.dart';
import '../../utils/app_routes.dart';
import '../../widgets/venue_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _keyword = '';
  String _sport = 'Tất cả';
  double _maxPrice = 400000;

  @override
  Widget build(BuildContext context) {
    final sports = {'Tất cả', ...MockStore.venues.map((v) => v.sportType)}.toList();
    final results = MockStore.venues.where((v) {
      final matchesKeyword = v.name.toLowerCase().contains(_keyword.toLowerCase()) || v.address.toLowerCase().contains(_keyword.toLowerCase());
      final matchesSport = _sport == 'Tất cả' || v.sportType == _sport;
      return v.status == 'approved' && matchesKeyword && matchesSport && v.pricePerHour <= _maxPrice;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Tìm kiếm sân')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: const InputDecoration(labelText: 'Tên sân, khu vực...', prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => _keyword = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _sport,
                decoration: const InputDecoration(labelText: 'Môn thể thao'),
                items: sports.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _sport = v ?? 'Tất cả'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Giá tối đa: ${_maxPrice.toStringAsFixed(0)} đ/giờ', style: const TextStyle(fontSize: 12)),
                Slider(value: _maxPrice, min: 100000, max: 500000, divisions: 8, label: _maxPrice.toStringAsFixed(0), onChanged: (v) => setState(() => _maxPrice = v)),
              ]),
            ),
          ]),
        ),
        Expanded(
          child: results.isEmpty
              ? const Center(child: Text('Không tìm thấy sân phù hợp.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => VenueCard(
                    venue: results[i],
                    onTap: () => Navigator.pushNamed(context, AppRoutes.venueDetail, arguments: results[i]),
                  ),
                ),
        ),
      ]),
    );
  }
}
