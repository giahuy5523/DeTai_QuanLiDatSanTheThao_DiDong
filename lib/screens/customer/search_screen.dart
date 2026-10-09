import 'package:flutter/material.dart';
import '../../data/mock_store.dart';
import '../../models/venue.dart';
import '../../utils/app_routes.dart';
import '../../widgets/venue_card.dart';

enum _SortOption { none, priceAsc, priceDesc, nameAsc }

extension on _SortOption {
  String get label {
    switch (this) {
      case _SortOption.none:
        return 'Mặc định';
      case _SortOption.priceAsc:
        return 'Giá thấp → cao';
      case _SortOption.priceDesc:
        return 'Giá cao → thấp';
      case _SortOption.nameAsc:
        return 'Tên A → Z';
    }
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const double _priceMin = 100000;
  static const double _priceMax = 500000;
  static const int _firstHour = 6;
  static const int _lastHour = 21;

  final TextEditingController _searchController = TextEditingController();

  String _normalizeSearchText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
        .replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e')
        .replaceAll(RegExp(r'[ìíịỉĩ]'), 'i')
        .replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
        .replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u')
        .replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y')
        .replaceAll('đ', 'd');
  }

  String _keyword = '';
  int? _sportTypeId; // SportTypes.sport_type_id
  RangeValues _priceRange = const RangeValues(_priceMin, _priceMax);
  String? _district; // Venues.district
  bool _onlyWithServices = false; // Có bản ghi trong Services của sân
  DateTime? _date; // Lọc theo lịch trống (TimeSlots)
  int? _hour; // Giờ bắt đầu mong muốn
  _SortOption _sort = _SortOption.none;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- Logic

  bool get _priceChanged =>
      _priceRange.start > _priceMin || _priceRange.end < _priceMax;

  /// Số bộ lọc nâng cao đang bật (hiển thị trên nút "Bộ lọc").
  int get _advancedCount =>
      (_priceChanged ? 1 : 0) +
      (_district != null ? 1 : 0) +
      (_onlyWithServices ? 1 : 0);

  bool get _hasAnyFilter =>
      _sportTypeId != null ||
      _date != null ||
      _hour != null ||
      _advancedCount > 0;

  void _resetFilters() {
    setState(() {
      _sportTypeId = null;
      _priceRange = const RangeValues(_priceMin, _priceMax);
      _district = null;
      _onlyWithServices = false;
      _date = null;
      _hour = null;
      _sort = _SortOption.none;
    });
  }

  List<Venue> _filterVenues() {
    final query = _normalizeSearchText(_keyword).trim();
    final checkAvailability = _date != null || _hour != null;
    final date = _date ?? DateTime.now();

    final list = MockStore.approvedVenues.where((v) {
      final services = MockStore.servicesFor(v.id);

      // Từ khóa: tên sân, địa chỉ, quận/huyện, thành phố, tên dịch vụ
      if (query.isNotEmpty) {
        final inVenue =
            _normalizeSearchText(v.name).contains(query) ||
            _normalizeSearchText(v.address).contains(query) ||
            _normalizeSearchText(v.district ?? '').contains(query) ||
            _normalizeSearchText(v.city ?? '').contains(query);

        final inService = services.any(
          (s) => _normalizeSearchText(s.name).contains(query),
        );
        if (!inVenue && !inService) return false;
      }

      if (_sportTypeId != null && v.sportTypeId != _sportTypeId) return false;

      final price = v.pricePerHour.toDouble();
      if (price < _priceRange.start || price > _priceRange.end) return false;

      if (_district != null && v.district != _district) return false;
      if (_onlyWithServices && services.isEmpty) return false;

      // Lịch trống: dựa trên TimeSlots (sinh từ bookings chưa huỷ)
      if (checkAvailability) {
        final slots = MockStore.timeSlotsFor(v.id, date);
        final ok = slots.any(
          (s) =>
              s['status'] == 'available' &&
              (_hour == null || s['startTime'] == MockStore.hourLabel(_hour!)),
        );
        if (!ok) return false;
      }
      return true;
    }).toList();

    switch (_sort) {
      case _SortOption.priceAsc:
        list.sort((a, b) => a.pricePerHour.compareTo(b.pricePerHour));
        break;
      case _SortOption.priceDesc:
        list.sort((a, b) => b.pricePerHour.compareTo(a.pricePerHour));
        break;
      case _SortOption.nameAsc:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case _SortOption.none:
        break;
    }
    return list;
  }

  // -------------------------------------------------------------- Helpers

  String _formatPrice(num value) {
    final s = value.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '${buf.toString()}đ';
  }

  String _weekday(DateTime d) {
    const names = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return names[d.weekday - 1];
  }

  String _dateShort(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dateLabel(DateTime? d) {
    if (d == null) return 'Chọn ngày';
    final now = DateTime.now();
    if (_isSameDay(d, now)) return 'Hôm nay';
    if (_isSameDay(d, now.add(const Duration(days: 1)))) return 'Ngày mai';
    return '${_weekday(d)}, ${_dateShort(d)}';
  }

  IconData _sportIcon(int id) {
    switch (id) {
      case 1:
        return Icons.sports_soccer;
      case 2:
      case 3:
        return Icons.sports_tennis;
      case 4:
        return Icons.sports_basketball;
      default:
        return Icons.sports;
    }
  }

  // -------------------------------------------------------------- Pickers

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 60)),
      helpText: 'Chọn ngày muốn đặt sân',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickHour() async {
    final result = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Giờ bắt đầu',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                _date == null
                    ? 'Chưa chọn ngày: hệ thống sẽ kiểm tra lịch trống hôm nay.'
                    : 'Kiểm tra lịch trống ngày ${_dateShort(_date!)}.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Bất kỳ'),
                    selected: _hour == null,
                    onSelected: (_) => Navigator.pop(ctx, -1),
                  ),
                  for (var h = _firstHour; h <= _lastHour; h++)
                    ChoiceChip(
                      label: Text(MockStore.hourLabel(h)),
                      selected: _hour == h,
                      onSelected: (_) => Navigator.pop(ctx, h),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null) return;
    setState(() => _hour = result == -1 ? null : result);
  }

  Future<void> _openAdvancedFilters() async {
    var range = _priceRange;
    var district = _district;
    var onlyServices = _onlyWithServices;
    final districts = MockStore.districts;

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              20 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Bộ lọc nâng cao',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setSheet(() {
                        range = const RangeValues(_priceMin, _priceMax);
                        district = null;
                        onlyServices = false;
                      }),
                      child: const Text('Đặt lại'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Khoảng giá (mỗi giờ)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatPrice(range.start)} – ${_formatPrice(range.end)}',
                  style: TextStyle(
                    color: Theme.of(ctx).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                RangeSlider(
                  values: range,
                  min: _priceMin,
                  max: _priceMax,
                  divisions: 8,
                  labels: RangeLabels(
                    _formatPrice(range.start),
                    _formatPrice(range.end),
                  ),
                  onChanged: (v) => setSheet(() => range = v),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Khu vực',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Tất cả'),
                      selected: district == null,
                      onSelected: (_) => setSheet(() => district = null),
                    ),
                    for (final d in districts)
                      ChoiceChip(
                        label: Text(d),
                        selected: district == d,
                        onSelected: (_) => setSheet(() => district = d),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Có dịch vụ đi kèm'),
                  subtitle: const Text('Thuê dụng cụ, nước uống, trọng tài...'),
                  value: onlyServices,
                  onChanged: (v) => setSheet(() => onlyServices = v),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Áp dụng'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (applied == true) {
      setState(() {
        _priceRange = range;
        _district = district;
        _onlyWithServices = onlyServices;
      });
    }
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final results = _filterVenues();

    return Scaffold(
      appBar: AppBar(title: const Text('Tìm kiếm sân')),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildSportChips(),
          _buildQuickFilters(),
          if (_advancedCount > 0) _buildActiveFilters(),
          _buildResultHeader(results.length),
          Expanded(
            child: results.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 20),
                    itemBuilder: (context, i) => _buildResultItem(results[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final fill = Theme.of(context).colorScheme.onSurface.withAlpha(15);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Tìm tên sân, địa chỉ, quận, dịch vụ...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _keyword.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Xóa từ khóa',
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _keyword = '');
                  },
                ),
          filled: true,
          fillColor: fill,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (v) => setState(() => _keyword = v),
      ),
    );
  }

  Widget _buildSportChips() {
    final sportTypes = MockStore.sportTypes;
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: const Icon(Icons.apps, size: 18),
              label: const Text('Tất cả'),
              selected: _sportTypeId == null,
              onSelected: (_) => setState(() => _sportTypeId = null),
            ),
          ),
          for (final st in sportTypes)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(_sportIcon(st['id'] as int), size: 18),
                label: Text(st['name'] as String),
                selected: _sportTypeId == st['id'],
                onSelected: (_) =>
                    setState(() => _sportTypeId = st['id'] as int),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickFilters() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InputChip(
              avatar: const Icon(Icons.calendar_today, size: 16),
              label: Text(_dateLabel(_date)),
              selected: _date != null,
              showCheckmark: false,
              onPressed: _pickDate,
              onDeleted: _date == null
                  ? null
                  : () => setState(() => _date = null),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InputChip(
              avatar: const Icon(Icons.access_time, size: 16),
              label: Text(
                _hour == null ? 'Chọn giờ' : MockStore.hourLabel(_hour!),
              ),
              selected: _hour != null,
              showCheckmark: false,
              onPressed: _pickHour,
              onDeleted: _hour == null
                  ? null
                  : () => setState(() => _hour = null),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: const Icon(Icons.tune, size: 16),
              label: Text(
                _advancedCount == 0 ? 'Bộ lọc' : 'Bộ lọc ($_advancedCount)',
              ),
              onPressed: _openAdvancedFilters,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (_priceChanged)
            InputChip(
              label: Text(
                '${_formatPrice(_priceRange.start)} – ${_formatPrice(_priceRange.end)}',
              ),
              onDeleted: () => setState(
                () => _priceRange = const RangeValues(_priceMin, _priceMax),
              ),
            ),
          if (_district != null)
            InputChip(
              label: Text(_district!),
              onDeleted: () => setState(() => _district = null),
            ),
          if (_onlyWithServices)
            InputChip(
              label: const Text('Có dịch vụ đi kèm'),
              onDeleted: () => setState(() => _onlyWithServices = false),
            ),
        ],
      ),
    );
  }

  Widget _buildResultHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$count sân phù hợp',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          if (_hasAnyFilter)
            TextButton(
              onPressed: _resetFilters,
              child: const Text('Xóa bộ lọc'),
            ),
          PopupMenuButton<_SortOption>(
            tooltip: 'Sắp xếp',
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => [
              for (final o in _SortOption.values)
                PopupMenuItem(value: o, child: Text(o.label)),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort, size: 18),
                  const SizedBox(width: 4),
                  Text(_sort.label, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(Venue v) {
    final date = _date ?? DateTime.now();
    final now = DateTime.now();
    final dayLabel = (_date == null || _isSameDay(_date!, now))
        ? 'hôm nay'
        : _isSameDay(_date!, now.add(const Duration(days: 1)))
        ? 'ngày mai'
        : 'ngày ${_dateShort(_date!)}';
    final free = MockStore.timeSlotsFor(v.id, date)
        .where((s) => s['status'] == 'available')
        .map((s) => s['startTime'] as String)
        .toList();
    final services = MockStore.servicesFor(v.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VenueCard(
          venue: v,
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.venueDetail, arguments: v),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _InfoChip(
              icon: free.isEmpty ? Icons.event_busy : Icons.event_available,
              text: free.isEmpty
                  ? 'Hết giờ trống $dayLabel'
                  : 'Còn ${free.length} giờ trống $dayLabel',
              color: free.isEmpty ? Colors.red.shade700 : Colors.green.shade700,
            ),
            if (services.isNotEmpty)
              _InfoChip(
                icon: Icons.room_service_outlined,
                text: '${services.length} dịch vụ đi kèm',
                color: Colors.blueGrey.shade600,
              ),
          ],
        ),
        if (free.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Giờ trống: ${free.take(5).join(' · ')}${free.length > 5 ? '  +${free.length - 5}' : ''}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Không tìm thấy sân phù hợp',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Thử đổi từ khóa, mở rộng khoảng giá hoặc chọn ngày/giờ khác.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (_hasAnyFilter || _keyword.isNotEmpty) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () {
                  _searchController.clear();
                  _keyword = '';
                  _resetFilters();
                },
                child: const Text('Xóa tất cả bộ lọc'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
