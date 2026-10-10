import 'package:flutter/material.dart';
import '../../data/mock_store.dart';
import '../../utils/app_routes.dart';
import '../../utils/app_theme.dart';
import '../../widgets/venue_card.dart';

/// Trang chủ khách hàng - hiển thị banner tìm kiếm và danh sách sân nổi bật.
/// Thuộc CustomerShell, không có BottomNavBar riêng.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _sport;

  @override
  Widget build(BuildContext context) {
    final venues = MockStore.venues
        .where(
          (v) =>
              v.status == 'approved' &&
              (_sport == null || v.sportType == _sport),
        )
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // ─── SliverAppBar với banner Nhom1_DatSanTheThao ─────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            floating: true,
            snap: true,
            pinned: false,
            automaticallyImplyLeading: false,
            backgroundColor: AppTheme.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primary, Color(0xFF047857)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.sports_soccer,
                              color: Colors.white70,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Nhom1_DatSanTheThao',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Tìm sân phù hợp\nvới bạn hôm nay!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Thanh tìm kiếm nằm dưới banner, có khoảng cách riêng.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: _SearchBar(),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.venueList),
                icon: const Icon(Icons.list_alt),
                label: const Text('Xem tất cả sân'),
              ),
            ),
          ),

          // ─── Chip lọc môn thể thao ─────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: _SportFilterRow(
                onSelected: (sport) => setState(() => _sport = sport),
              ),
            ),
          ),

          // ─── Section tiêu đề ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Sân nổi bật',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
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

          // ─── Danh sách sân ──────────────────────────────────────────
          venues.isEmpty
              ? const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Hiện chưa có sân nào được duyệt.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: VenueCard(
                          venue: venues[i],
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.venueDetail,
                            arguments: venues[i],
                          ),
                        ),
                      ),
                      childCount: venues.length,
                    ),
                  ),
                ),
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: AppTheme.primary,
                size: 18,
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
  const _SportFilterRow({required this.onSelected});
  final ValueChanged<String?> onSelected;
  @override
  State<_SportFilterRow> createState() => _SportFilterRowState();
}

class _SportFilterRowState extends State<_SportFilterRow> {
  int _selected = 0;

  static const _sports = [
    ('Tất cả', Icons.grid_view_rounded),
    ('Bóng đá', Icons.sports_soccer),
    ('Cầu lông', Icons.sports_tennis),
    ('Tennis', Icons.sports_tennis),
    ('Bóng rổ', Icons.sports_basketball),
  ];

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
