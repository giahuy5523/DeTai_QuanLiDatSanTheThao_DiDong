import 'package:flutter/material.dart';
import '../../data/mock_store.dart';
import '../../data/booking_repository.dart' as data_repo;
import '../../data/venue_repository.dart';
import '../../models/venue.dart';
import '../../utils/app_routes.dart';
import '../../utils/app_theme.dart';
import '../../widgets/venue_image.dart';

/// Trang chủ khách hàng - hiển thị banner tìm kiếm và danh sách sân nổi bật.
/// Thuộc CustomerShell, không có BottomNavBar riêng.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _unreadCount = 0;

  Future<void> _refreshUnreadCount() async {
    final userId = MockStore.currentUser?.id ?? '';
    if (userId.isEmpty) {
      if (mounted) setState(() => _unreadCount = 0);
      return;
    }
    final notifications =
        await data_repo.BookingRepository.getNotificationsForUser(userId);
    if (!mounted) return;
    setState(() {
      _unreadCount = notifications.where((n) => !n.isRead).length;
    });
  }

  void _onNotificationsChanged() => _refreshUnreadCount();

  String? _sport;
  List<Venue> _databaseVenues = const [];
  List<String> _databaseSports = const [];
  bool _hasDatabaseSnapshot = false;

  @override
  void initState() {
    super.initState();
    MockStore.notificationRevision.addListener(_onNotificationsChanged);
    _refreshUnreadCount();
    WidgetsBinding.instance.addObserver(this);
    _reloadVenues();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    MockStore.notificationRevision.removeListener(_onNotificationsChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reloadVenues();
  }

  Future<void> _reloadVenues() async {
    if (!VenueRepository.isInitialized) return;
    try {
      final venues = await VenueRepository.loadVenues(approvedOnly: true);
      final sports = (await VenueRepository.loadSportTypes())
          .map((row) => row['name'] as String)
          .toList();
      if (mounted) {
        setState(() {
          _databaseVenues = venues;
          _databaseSports = sports;
          _hasDatabaseSnapshot = true;
        });
      }
    } catch (_) {
      // Keep the startup snapshot visible if a refresh cannot complete.
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = _hasDatabaseSnapshot ? _databaseVenues : MockStore.venues;
    final venues = source
        .where(
          (v) =>
              v.status == 'approved' &&
              (_sport == null || v.sportType == _sport),
        )
        .toList();
    final allApproved = source
        .where((v) => v.status == 'approved')
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: _reloadVenues,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: 245,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (allApproved.isNotEmpty)
                      _buildBanner(context, allApproved.first)
                    else
                      _buildEmptyBanner(),
                    Positioned(
                      top: 8,
                      right: 18,
                      child: SafeArea(
                        bottom: false,
                        child: ValueListenableBuilder<int>(
                          valueListenable: MockStore.notificationRevision,
                          builder: (context, _, _) {
                            final unread = _unreadCount;
                            return Material(
                              color: Colors.black.withValues(alpha: 0.24),
                              shape: const CircleBorder(),
                              child: IconButton(
                                tooltip: 'Thông báo',
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.notifications,
                                ),
                                icon: Badge(
                                  isLabelVisible: unread > 0,
                                  label: Text(unread > 99 ? '99+' : '$unread'),
                                  child: const Icon(
                                    Icons.notifications_none_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 0,
                      child: _SearchBar(),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: _SportFilterRow(
                  sports: _hasDatabaseSnapshot ? _databaseSports : null,
                  onSelected: (sport) => setState(() => _sport = sport),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Sân nổi bật',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.search),
                      child: const Text('Xem tất cả'),
                    ),
                  ],
                ),
              ),
            ),
            if (venues.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(
                    child: Text(
                      'Hiện chưa có sân nào được duyệt.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 230,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: venues.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (context, i) =>
                        _buildFeaturedCard(context, venues[i]),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.venueList),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Xem tất cả sân'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner(BuildContext context, Venue venue) {
    // Ảnh banner sân vận động lấy từ nguồn ảnh trực tuyến.
    const bannerImageUrl =
        'https://images.pexels.com/photos/30747154/pexels-photo-30747154.jpeg?auto=compress&cs=tinysrgb&w=1600';

    return Container(
      height: 220,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            bannerImageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildPlaceholderBanner(venue),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.12),
                  AppTheme.primary.withValues(alpha: 0.88),
                ],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Xin chào, ${MockStore.currentUser?.name ?? 'bạn'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Tìm sân phù hợp\nvới bạn hôm nay!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Đặt sân nhanh chóng',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBanner() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
      child: const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(22, 28, 20, 60),
          child: Text(
            'Xin chào!\nTìm sân phù hợp với bạn hôm nay!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              height: 1.3,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderBanner(Venue venue) {
    return Container(
      color: AppTheme.primary,
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.stadium_outlined, color: Colors.white70, size: 42),
            const SizedBox(height: 8),
            Text(
              'Ảnh sân thể thao',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedCard(BuildContext context, Venue venue) {
    final images = venue.imageUrls;
    return SizedBox(
      width: 218,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.pushNamed(
            context,
            AppRoutes.venueDetail,
            arguments: venue,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 104,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (images.isNotEmpty)
                      VenueImage(
                        source: images.first,
                        placeholder: _buildPlaceholderBanner(venue),
                      )
                    else
                      _buildPlaceholderBanner(venue),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          venue.sportType,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: Text(
                  venue.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
                child: Text(
                  venue.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 5, 10, 10),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFFFC928), size: 17),
                    const SizedBox(width: 4),
                    const Text('4.8', style: TextStyle(fontSize: 12)),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        '${venue.pricePerHour.toStringAsFixed(0)}đ/1 giờ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thanh tìm kiếm nhanh dẫn tới SearchScreen
class _SearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.search),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppTheme.textSecondary, size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Tìm tên sân, khu vực, môn thể thao...',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Row chip lọc môn thể thao nhanh
class _SportFilterRow extends StatefulWidget {
  const _SportFilterRow({required this.onSelected, this.sports});
  final ValueChanged<String?> onSelected;
  final List<String>? sports;
  @override
  State<_SportFilterRow> createState() => _SportFilterRowState();
}

class _SportFilterRowState extends State<_SportFilterRow> {
  int _selected = 0;

  static const _defaultSports = [
    ('Tất cả', Icons.grid_view_rounded),
    ('Bóng đá', Icons.sports_soccer),
    ('Cầu lông', Icons.sports_tennis),
    ('Tennis', Icons.sports_tennis),
    ('Bóng rổ', Icons.sports_basketball),
  ];

  List<(String, IconData)> get _sports => widget.sports == null
      ? _defaultSports
      : [
          ('Tất cả', Icons.grid_view_rounded),
          for (final sport in widget.sports!)
            (sport, _sportIcon(sport)),
        ];

  IconData _sportIcon(String sport) => switch (sport) {
    'Bóng đá' => Icons.sports_soccer,
    'Cầu lông' => Icons.sports_tennis,
    'Tennis' => Icons.sports_tennis,
    'Bóng rổ' => Icons.sports_basketball,
    _ => Icons.sports,
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_sports.length, (i) {
          final (label, icon) = _sports[i];
          final isSelected = _selected == i;
          return Padding(
            padding: EdgeInsets.only(right: i < _sports.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () {
                setState(() => _selected = i);
                widget.onSelected(i == 0 ? null : label);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : AppTheme.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
