import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/venue_repository.dart';
import '../../models/venue.dart';
import '../../widgets/venue_catalog_card.dart';

class VenueListScreen extends StatefulWidget {
  const VenueListScreen({super.key});
  @override
  State<VenueListScreen> createState() => _VenueListScreenState();
}

class _VenueListScreenState extends State<VenueListScreen> with WidgetsBindingObserver {
  final _repository = VenueRepository();
  List<Venue> _venues = [];
  bool _loading = true;
  String? _sport;
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
      debugPrint('[VenueListScreen] Loading venues failed: $error');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sports = _venues.map((v) => v.sportType).toSet().toList()..sort();
    final visible = _sport == null ? _venues : _venues.where((v) => v.sportType == _sport).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Danh sách sân')),
      body: Column(children: [
        if (sports.isNotEmpty)
          SizedBox(height: 54, child: ListView(scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [null, ...sports].map((sport) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(label: Text(sport ?? 'Tất cả'), selected: _sport == sport,
                onSelected: (_) => setState(() => _sport = sport)),
            )).toList(),
          )),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : visible.isEmpty
            ? _empty(context)
            : RefreshIndicator(
                onRefresh: _load,
                child: LayoutBuilder(builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 700 ? 2 : 1;
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: visible.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns, crossAxisSpacing: 14, mainAxisSpacing: 14, mainAxisExtent: 258),
                    itemBuilder: (_, index) => VenueCatalogCard(venue: visible[index]),
                  );
                }),
              ),
        ),
      ]),
    );
  }

  Widget _empty(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
      SizedBox(height: MediaQuery.sizeOf(context).height * .28),
      const Icon(Icons.stadium_outlined, size: 58, color: Color(0xFF087451)),
      const SizedBox(height: 12),
      Center(child: Text(_venues.isEmpty ? 'Chưa có sân nào được duyệt' : 'Không tìm thấy sân phù hợp',
        style: const TextStyle(fontWeight: FontWeight.w700))),
      const SizedBox(height: 6),
      const Center(child: Text('Danh sách sẽ cập nhật khi có sân mới.', style: TextStyle(color: Colors.black54))),
    ]),
  );
}
