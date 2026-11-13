import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/mock_store.dart';
import '../../data/venue_repository.dart';
import '../../models/service.dart';
import '../../models/venue.dart';
import '../../utils/app_routes.dart';
import '../../utils/app_theme.dart';
import '../../widgets/venue_image.dart';

class VenueDetailScreen extends StatefulWidget {
  const VenueDetailScreen({super.key});

  @override
  State<VenueDetailScreen> createState() => _VenueDetailScreenState();
}

class _VenueDetailScreenState extends State<VenueDetailScreen> {
  bool _isFavorite = false;
  int _currentImageIndex = 0;
  final PageController _imagePageController = PageController();
  bool _showFullInfo = false;

  String? _catalogVenueId;
  List<VenueService> _services = const [];
  List<String> _images = const [];
  List<int> _hours = const [6, 22];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final venue = ModalRoute.of(context)?.settings.arguments;
    if (venue is Venue && venue.id != _catalogVenueId) {
      _catalogVenueId = venue.id;
      _loadCatalog(venue.id);
    }
  }

  Future<void> _loadCatalog(String venueId) async {
    final services = await VenueRepository.loadServicesFor(venueId);
    final images = await VenueRepository.loadImageUrlsFor(venueId);
    final hours = await VenueRepository.loadHoursFor(venueId);
    if (!mounted || _catalogVenueId != venueId) return;
    setState(() {
      _services = services;
      _images = images;
      _hours = hours;
    });
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final venue = ModalRoute.of(context)!.settings.arguments as Venue;
    final services = _services;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Chi tiết sân'),
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: _isFavorite ? 'Bỏ yêu thích' : 'Thêm vào yêu thích',
            icon: Icon(
              _isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: _isFavorite ? AppTheme.error : AppTheme.primary,
            ),
            onPressed: () => setState(() => _isFavorite = !_isFavorite),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Banner hình ảnh hoặc placeholder thể thao kèm nút Back và Yêu thích
          SliverToBoxAdapter(child: _buildBanner(context, venue)),

          // Nội dung chi tiết cuộn được
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 36),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Thẻ thông tin tổng quan sân
                _buildHeaderCard(venue),
                const SizedBox(height: 16),

                // Thẻ "Thông tin sân" & tiện ích
                _buildCourtInfoCard(venue),
                const SizedBox(height: 16),

                // Thẻ "Dịch vụ"
                _buildServicesCard(services),
                const SizedBox(height: 16),

                // Thẻ "Đánh giá"
                _buildReviewsCard(venue),
                const SizedBox(height: 16),

                // Thẻ "Địa chỉ"
                _buildAddressCard(venue),
              ]),
            ),
          ),
        ],
      ),

      bottomNavigationBar: _buildBottomCTA(context, venue),
    );
  }

  Widget _buildBanner(BuildContext context, Venue venue) {
    final images = _images;
    final itemCount = images.isEmpty ? 1 : images.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 315,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _imagePageController,
                itemCount: itemCount,
                onPageChanged: (index) =>
                    setState(() => _currentImageIndex = index),
                itemBuilder: (context, index) {
                  if (images.isEmpty) {
                    return _buildPlaceholderBanner(venue);
                  }

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showFullScreenGallery(
                      context,
                      images,
                      initialIndex: index,
                      venue: venue,
                    ),
                    child: VenueImage(
                      source: images[index],
                      placeholder: _buildPlaceholderBanner(venue),
                    ),
                  );
                },
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.28),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.18),
                        ],
                        stops: const [0, 0.42, 1],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.48),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getSportIcon(venue.sportType),
                        color: Colors.white,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        venue.sportType,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (images.length > 1) ...[
                Positioned(
                  left: 10,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _galleryArrow(
                      icon: Icons.chevron_left_rounded,
                      onTap: () => _imagePageController.previousPage(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOut,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _galleryArrow(
                      icon: Icons.chevron_right_rounded,
                      onTap: () => _imagePageController.nextPage(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOut,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.66),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.photo_library_outlined,
                          size: 13,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${_currentImageIndex + 1}/$itemCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (images.length > 1)
          SizedBox(
            height: 78,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final selected = index == _currentImageIndex;
                return GestureDetector(
                  onTap: () => _imagePageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOut,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 88,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? AppTheme.primary : AppTheme.border,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: VenueImage(
                      source: images[index],
                      placeholder: _buildPlaceholderBanner(venue),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _galleryArrow({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: AppTheme.textPrimary, size: 24),
        ),
      ),
    );
  }

  Future<void> _showFullScreenGallery(
    BuildContext context,
    List<String> images, {
    required int initialIndex,
    required Venue venue,
  }) async {
    if (images.isEmpty) return;

    final controller = PageController(initialPage: initialIndex);
    var currentIndex = initialIndex;

    try {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return Dialog.fullscreen(
                backgroundColor: Colors.black,
                child: Scaffold(
                  backgroundColor: Colors.black,
                  appBar: AppBar(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    title: Text(
                      '${currentIndex + 1}/${images.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    centerTitle: true,
                    leading: IconButton(
                      tooltip: 'Đóng ảnh',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ),
                  body: PageView.builder(
                    controller: controller,
                    itemCount: images.length,
                    onPageChanged: (index) {
                      setDialogState(() => currentIndex = index);
                    },
                    itemBuilder: (context, index) {
                      return Center(
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: SizedBox(
                            width: double.infinity,
                            height: double.infinity,
                            child: VenueImage(
                              source: images[index],
                              placeholder: _buildPlaceholderBanner(venue),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Widget _buildPlaceholderBanner(Venue venue) {
    return Container(
      color: AppTheme.background,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.image_not_supported_outlined,
            size: 42,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 10),
          Text(
            'Chưa có ảnh cho sân ${venue.name}.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Hãy bổ sung ảnh sân vào dữ liệu trước khi sử dụng.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // Thẻ thông tin tổng quan sân
  Widget _buildHeaderCard(Venue venue) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    venue.name,
                    style: const TextStyle(
                      fontSize: 22,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getSportIcon(venue.sportType),
                        size: 15,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        venue.sportType,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.star_rounded, size: 20, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  venue.rating > 0
                      ? venue.rating.toStringAsFixed(1)
                      : 'Chưa có đánh giá',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Đánh giá của khách hàng',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                    softWrap: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    venue.address,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryLight, Colors.white],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                ),
              ),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    '${_formatPrice(venue.pricePerHour)} đ',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    '/ giờ',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Thẻ "Thông tin sân"
  Widget _buildCourtInfoCard(Venue venue) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(Icons.info_outline_rounded, 'Thông tin sân'),
            const Divider(height: 22, color: AppTheme.border),
            _buildInfoRow(
              'Giờ mở cửa',
              '${_hours[0].toString().padLeft(2, '0')}:00 - ${_hours[1].toString().padLeft(2, '0')}:00 hàng ngày',
            ),
            const SizedBox(height: 10),
            _buildInfoRow(
              'Giá niêm yết',
              '${_formatPrice(venue.pricePerHour)} đ / giờ',
            ),
            const SizedBox(height: 10),
            _buildInfoRow('Loại hình', venue.sportType),
            const SizedBox(height: 10),
            _buildInfoRow('Trạng thái', switch (venue.status) {
              'approved' => 'Đang hoạt động',
              'pending' => 'Chờ duyệt',
              'rejected' => 'Bị từ chối',
              _ => 'Không xác định',
            }),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _showFullInfo
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(height: 8),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Khu vực', _venueArea(venue)),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Tọa độ',
                        '${venue.latitude.toStringAsFixed(5)}, ${venue.longitude.toStringAsFixed(5)}',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() => _showFullInfo = !_showFullInfo),
                icon: Icon(
                  _showFullInfo
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                ),
                label: Text(_showFullInfo ? 'Thu gọn' : 'Xem thêm thông tin'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tiện ích sẵn có',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _buildAmenityItem(Icons.local_parking_rounded, 'Chỗ đậu xe'),
                _buildAmenityItem(
                  Icons.lightbulb_outline_rounded,
                  'Đèn chiếu sáng',
                ),
                _buildAmenityItem(Icons.checkroom_rounded, 'Phòng thay đồ'),
                _buildAmenityItem(Icons.wifi_rounded, 'Wi-Fi'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Thẻ "Dịch vụ"
  Widget _buildServicesCard(List services) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(Icons.room_service_outlined, 'Dịch vụ'),
            const Divider(height: 22, color: AppTheme.border),
            if (services.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Sân hiện chưa cung cấp dịch vụ bổ sung.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              )
            else
              ...services.map(
                (s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          s.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '${_formatPrice(s.price)} đ / ${s.unit}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Thẻ "Đánh giá"
  // Chỉ hiển thị điểm rating có trong model; không tự tạo số lượt đánh giá hoặc nội dung review.
  Widget _buildReviewsCard(Venue venue) {
    final hasRating = venue.rating > 0;
    final ratingValue = venue.rating.clamp(0.0, 5.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(Icons.star_outline_rounded, 'Đánh giá'),
            const Divider(height: 22, color: AppTheme.border),
            if (!hasRating)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.rate_review_outlined,
                      color: AppTheme.primary,
                      size: 30,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Chưa có đánh giá',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Thông tin đánh giá sẽ xuất hiện khi có dữ liệu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Text(
                          ratingValue.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            5,
                            (i) => Icon(
                              i < ratingValue.floor()
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 15,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Điểm sân',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Điểm đánh giá hiện có của sân. Chi tiết nhận xét chưa được cung cấp trong dữ liệu ứng dụng.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // Thẻ "Địa chỉ"
  Widget _buildAddressCard(Venue venue) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(Icons.map_outlined, 'Địa chỉ'),
            const Divider(height: 22, color: AppTheme.border),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: 20,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    venue.address,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Material(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);

                  await Clipboard.setData(
                    ClipboardData(
                      text: '${venue.latitude}, ${venue.longitude}',
                    ),
                  );

                  if (!mounted) return;

                  messenger.showSnackBar(
                    const SnackBar(content: Text('Đã sao chép tọa độ sân')),
                  );
                },
                child: Container(
                  height: 90,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 25,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${venue.latitude.toStringAsFixed(5)}, ${venue.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Chạm để sao chép tọa độ',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Thanh Booking CTA dính ở đáy (Sticky Bottom CTA)
  Widget _buildBottomCTA(BuildContext context, Venue venue) {
    final canBook = venue.status == 'approved';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Giá thuê',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${_formatPrice(venue.pricePerHour)} đ',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                        const TextSpan(
                          text: ' /h',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: ElevatedButton.icon(
                onPressed: canBook
                    ? () => Navigator.pushNamed(
                        context,
                        AppRoutes.booking,
                        arguments: venue,
                      )
                    : null,
                icon: const Icon(Icons.calendar_month_rounded, size: 20),
                label: Text(
                  canBook
                      ? 'Đặt sân ngay'
                      : venue.status == 'pending'
                          ? 'Sân đang chờ duyệt'
                          : 'Sân chưa thể đặt',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 19, color: AppTheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 12,
      runSpacing: 6,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildAmenityItem(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppTheme.border),
          ),
          child: Icon(icon, size: 24, color: AppTheme.primary),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  String _formatPrice(num value) {
    final digits = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  String _venueArea(Venue venue) {
    final parts = [venue.district, venue.city]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    return parts.isEmpty ? 'Chưa cập nhật' : parts.join(', ');
  }

  IconData _getSportIcon(String sportType) {
    switch (sportType.toLowerCase()) {
      case 'bóng đá':
        return Icons.sports_soccer_rounded;
      case 'cầu lông':
        return Icons.sports_tennis_rounded;
      case 'tennis':
        return Icons.sports_tennis_outlined;
      case 'bóng rổ':
        return Icons.sports_basketball_rounded;
      case 'bóng chuyền':
        return Icons.sports_volleyball_rounded;
      default:
        return Icons.sports_rounded;
    }
  }
}
