import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/venue_repository.dart';
import '../../models/venue.dart';
import '../../utils/app_routes.dart';
import '../../utils/app_theme.dart';
import '../../widgets/venue_catalog_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _repository = VenueRepository();
  List<Venue> _venues = [];
  bool _loading = true;
  String? _sport;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    // Picks up changes made by another screen/repository while this tab is kept alive.
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final venues = await _repository.getVenues(status: 'approved');
      if (mounted) setState(() { _venues = venues; _loading = false; });
    } catch (error) {
      debugPrint('[HomeScreen] Could not load approved venues: $error');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sports = _venues.map((v) => v.sportType).toSet().toList()..sort();
    final visible = _sport == null ? _venues : _venues.where((v) => v.sportType == _sport).toList();
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(child: _header(context)),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 10),
              child: _searchLauncher(context),
            )),
            SliverToBoxAdapter(child: SizedBox(
              height: 48,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 18),
                children: [null, ...sports].map((sport) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: Text(sport ?? 'Tất cả'), selected: _sport == sport,
                    onSelected: (_) => setState(() => _sport = sport)),
                )).toList(),
              ),
            )),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 8),
              child: Row(children: [
                Expanded(child: Text('Sân đã được duyệt', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                TextButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.venueList), child: const Text('Xem tất cả')),
              ]),
            )),
            if (_loading)
              const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
            else if (visible.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: _empty(context))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                sliver: SliverLayoutBuilder(builder: (context, constraints) {
                  final columns = constraints.crossAxisExtent >= 640 ? 2 : 1;
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns, crossAxisSpacing: 14, mainAxisSpacing: 14,
                      // Compact devices get a taller card to keep text within bounds.
                      mainAxisExtent: 258,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => VenueCatalogCard(venue: visible[index]),
                      childCount: visible.length,
                    ),
                  );
                }),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 26),
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [Color(0xFF087451), Color(0xFF0A9A68)]),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Đặt sân thể thao', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      const Text('Tìm sân phù hợp và đặt lịch nhanh chóng', style: TextStyle(color: Colors.white70)),
    ]),
  );

  Widget _searchLauncher(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.pushNamed(context, AppRoutes.search),
      child: const Padding(padding: EdgeInsets.all(15), child: Row(children: [
        Icon(Icons.search, color: Color(0xFF087451)), SizedBox(width: 10),
        Expanded(child: Text('Tìm tên sân, khu vực hoặc môn thể thao', maxLines: 1, overflow: TextOverflow.ellipsis)),
      ])),
    ),
  );

  Widget _empty(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 92, height: 92, decoration: const BoxDecoration(color: Color(0xFFE7F6EE), shape: BoxShape.circle),
          child: const Icon(Icons.sports, size: 46, color: Color(0xFF087451))),
        const SizedBox(height: 16),
        Text(_venues.isEmpty ? 'Chưa có sân được duyệt' : 'Không có sân thuộc môn này', textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Kéo xuống để tải lại danh sách.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
      ]),
    ),
  );
}
