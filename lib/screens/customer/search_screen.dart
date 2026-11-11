import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/venue_repository.dart';
import '../../models/venue.dart';
import '../../widgets/venue_catalog_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with WidgetsBindingObserver {
  final _repository = VenueRepository();
  final _controller = TextEditingController();
  List<Venue> _venues = [];
  bool _loading = true;
  String _query = '';
  String? _sport;
  String? _district;
  RangeValues _price = const RangeValues(0, 1000000);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final rows = await _repository.getVenues(status: 'approved');
      if (mounted) setState(() { _venues = rows; _loading = false; });
    } catch (error) {
      debugPrint('[SearchScreen] Loading venues failed: $error');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _normalize(String value) => value.toLowerCase()
      .replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
      .replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e')
      .replaceAll(RegExp(r'[ìíịỉĩ]'), 'i')
      .replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
      .replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u')
      .replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y').replaceAll('đ', 'd');

  List<Venue> get _results {
    final query = _normalize(_query.trim());
    return _venues.where((v) {
      final matchesText = query.isEmpty || [v.name, v.address, v.district ?? '', v.city ?? '', v.sportType]
          .any((value) => _normalize(value).contains(query));
      final matchesSport = _sport == null || v.sportType == _sport;
      final matchesDistrict = _district == null || v.district == _district;
      final matchesPrice = v.pricePerHour >= _price.start && v.pricePerHour <= _price.end;
      return matchesText && matchesSport && matchesDistrict && matchesPrice;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final sports = _venues.map((v) => v.sportType).toSet().toList()..sort();
    final districts = _venues.map((v) => v.district).whereType<String>().where((v) => v.trim().isNotEmpty).toSet().toList()..sort();
    return Scaffold(
      appBar: AppBar(title: const Text('Tìm kiếm sân')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: TextField(
            controller: _controller,
            onChanged: (value) => setState(() => _query = value),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Tên sân hoặc địa điểm', prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty ? null : IconButton(icon: const Icon(Icons.close),
                onPressed: () { _controller.clear(); setState(() => _query = ''); }),
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
        ),
        SizedBox(height: 48, child: ListView(scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          children: [null, ...sports].map((sport) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(label: Text(sport ?? 'Tất cả môn'), selected: _sport == sport,
              onSelected: (_) => setState(() => _sport = sport)),
          )).toList(),
        )),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            Expanded(child: DropdownButtonFormField<String?>(
              initialValue: _district,
              decoration: InputDecoration(labelText: 'Khu vực', isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              items: [const DropdownMenuItem<String?>(value: null, child: Text('Tất cả khu vực')),
                ...districts.map((d) => DropdownMenuItem<String?>(value: d, child: Text(d, overflow: TextOverflow.ellipsis)))],
              onChanged: (value) => setState(() => _district = value),
            )),
            const SizedBox(width: 10),
            OutlinedButton.icon(onPressed: _choosePrice, icon: const Icon(Icons.tune), label: const Text('Giá')),
          ]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
          child: Row(children: [
            Expanded(child: Text(_loading ? 'Đang tải sân…' : '${results.length} sân đã duyệt',
              style: const TextStyle(fontWeight: FontWeight.w600))),
            if (_sport != null || _district != null || _query.isNotEmpty || _price.start > 0 || _price.end < 1000000)
              TextButton(onPressed: () { _controller.clear(); setState(() { _query = ''; _sport = null; _district = null; _price = const RangeValues(0, 1000000); }); },
                child: const Text('Xóa lọc')),
          ])),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : results.isEmpty
            ? _empty(context)
            : RefreshIndicator(onRefresh: _load, child: LayoutBuilder(builder: (context, constraints) {
                final columns = constraints.maxWidth >= 700 ? 2 : 1;
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: results.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns, crossAxisSpacing: 14, mainAxisSpacing: 14, mainAxisExtent: 258),
                  itemBuilder: (_, index) => VenueCatalogCard(venue: results[index]),
                );
              })),
        ),
      ]),
    );
  }

  Future<void> _choosePrice() async {
    var range = _price;
    final result = await showModalBottomSheet<RangeValues>(context: context, showDragHandle: true,
      builder: (context) => StatefulBuilder(builder: (context, setSheet) => SafeArea(
        child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Khoảng giá mỗi giờ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text('${_formatPrice(range.start)} – ${_formatPrice(range.end)} đ'),
            RangeSlider(values: range, min: 0, max: 1000000, divisions: 20,
              labels: RangeLabels(_formatPrice(range.start), _formatPrice(range.end)),
              onChanged: (value) => setSheet(() => range = value)),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context, range), child: const Text('Áp dụng'))),
          ],
        )),
      )),
    );
    if (result != null && mounted) setState(() => _price = result);
  }

  String _formatPrice(num value) {
    final digits = value.round().toString();
    final output = StringBuffer();
    for (var i = 0; i < digits.length; i++) { if (i > 0 && (digits.length - i) % 3 == 0) output.write('.'); output.write(digits[i]); }
    return output.toString();
  }

  Widget _empty(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
      SizedBox(height: MediaQuery.sizeOf(context).height * .24),
      const Icon(Icons.search_off_rounded, size: 58, color: Color(0xFF087451)),
      const SizedBox(height: 12),
      Center(child: Text(_venues.isEmpty ? 'Chưa có sân được duyệt' : 'Không tìm thấy sân phù hợp',
        style: const TextStyle(fontWeight: FontWeight.w700))),
      const SizedBox(height: 6),
      const Center(child: Text('Thử thay đổi từ khóa hoặc bộ lọc.', style: TextStyle(color: Colors.black54))),
    ]),
  );
}
