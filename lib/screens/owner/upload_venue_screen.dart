import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/mock_store.dart';
import '../../data/venue_repository.dart';
import '../../models/venue.dart';
import '../../utils/app_theme.dart';

// Hằng số riêng của màn hình
const _maxImages = 8;
const _minImages = 3;
const _minNameLength = 3;
const _maxNameLength = 60;
const _minAddressLength = 5;
const _maxAddressLength = 120;
const _minPrice = 10000;
const _maxPrice = 10000000; // 10 triệu / giờ
const _maxPriceDigits = 8;
const _maxImageBytes = 5 * 1024 * 1024; // 5 MB

// "  Sân   Cầu Lông " -> "Sân Cầu Lông"
String _normalizeSpaces(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

// 30000 -> "30.000"
String _formatMoney(num value) {
  final digits = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

int? _parsePrice(String? raw) =>
    RegExp(r'^\d+$|^\d{1,3}(\.\d{3})+$').hasMatch(raw ?? '')
    ? int.tryParse(raw!.replaceAll('.', ''))
    : null;

class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!RegExp(r'^[0-9.]*$').hasMatch(newValue.text)) return newValue;
    final digits = newValue.text.replaceAll('.', '');
    if (digits.isEmpty) return const TextEditingValue();
    if (digits.length > _maxPriceDigits) return oldValue;
    final text = _formatMoney(int.parse(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class UploadVenueScreen extends StatefulWidget {
  const UploadVenueScreen({super.key, this.picker});
  final ImagePicker? picker;

  @override
  State<UploadVenueScreen> createState() => _UploadVenueScreenState();
}

class _UploadVenueScreenState extends State<UploadVenueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _price = TextEditingController();
  final List<XFile> _images = [];
  final List<Uint8List> _previews = [];

  // Loại thể thao được đọc từ bảng sport_types trong SQLite.
  List<Map<String, Object?>> _sportTypes = const [];
  bool _loadingSports = true;
  String? _sportError;
  String? _sportType;
  int _openHour = 6;
  int _closeHour = 22;

  String _fingerprint(Uint8List bytes) =>
      '${bytes.length}:${Object.hashAll(bytes)}';
  bool _picking = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSportTypes();
  }

  // Đọc danh sách loại thể thao từ SQLite.
  Future<void> _loadSportTypes() async {
    try {
      final rows = await VenueRepository.loadSportTypes();
      if (!mounted) return;
      setState(() {
        _sportTypes = rows
            .map(
              (row) => <String, Object?>{
                'id': row['sportTypeId'],
                'name': row['name'],
              },
            )
            .toList();
        _loadingSports = false;
        _sportError = null;
        if (_sportType != null &&
            !_sportTypes.any((sport) => sport['name'] == _sportType)) {
          _sportType = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingSports = false;
        _sportError = 'Không thể tải danh sách loại thể thao.';
      });
    }
  }

  void _retryLoadSportTypes() {
    setState(() {
      _loadingSports = true;
      _sportError = null;
    });
    _loadSportTypes();
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _price.dispose();
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.error,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Row(
            children: [
              const Icon(Icons.cancel_outlined, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      );
  }

  Future<void> _pickImages() async {
    if (_images.length >= _maxImages) {
      _message('Chỉ được thêm tối đa $_maxImages ảnh.');
      return;
    }
    setState(() => _picking = true);
    try {
      final picked = await (widget.picker ?? ImagePicker()).pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      final remaining = _maxImages - _images.length;
      final images = <XFile>[];
      final previews = <Uint8List>[];
      final seen = _previews.map(_fingerprint).toSet();
      var overLimit = false;
      var duplicates = 0;
      var tooLarge = 0;
      var invalid = 0;
      for (final image in picked) {
        final Uint8List bytes;
        try {
          bytes = await image.readAsBytes();
        } catch (_) {
          invalid++;
          continue;
        }
        if (bytes.length > _maxImageBytes) {
          tooLarge++;
          continue;
        }
        if (!seen.add(_fingerprint(bytes))) {
          duplicates++;
          continue;
        }
        if (images.length >= remaining) {
          overLimit = true;
          break;
        }
        try {
          final codec = await ui.instantiateImageCodec(bytes);
          codec.dispose();
        } catch (_) {
          invalid++;
          continue;
        }
        images.add(image);
        previews.add(bytes);
      }
      if (!mounted) return;
      setState(() {
        _images.addAll(images);
        _previews.addAll(previews);
      });

      final notes = <String>[
        if (overLimit) 'Chỉ giữ tối đa $_maxImages ảnh.',
        if (duplicates > 0) 'Đã bỏ qua $duplicates ảnh trùng.',
        if (tooLarge > 0)
          'Đã bỏ qua $tooLarge ảnh quá ${_maxImageBytes ~/ (1024 * 1024)} MB.',
        if (invalid > 0)
          'Đã bỏ qua $invalid ảnh lỗi hoặc không đúng định dạng.',
      ];
      if (notes.isNotEmpty) _message(notes.join(' '));
    } catch (_) {
      if (mounted) {
        _message(
          'Không thể chọn ảnh. Vui lòng kiểm tra quyền truy cập và thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
      _previews.removeAt(index);
    });
  }

  // Đưa ảnh được chọn lên đầu danh sách để làm ảnh bìa.
  void _makeCover(int index) {
    if (index == 0) return;
    setState(() {
      _images.insert(0, _images.removeAt(index));
      _previews.insert(0, _previews.removeAt(index));
    });
  }

  Future<void> _showSuccessDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: AppTheme.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppTheme.primary,
                size: 42,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Đã gửi duyệt',
              style: TextStyle(
                color: AppTheme.primaryDark,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sân của bạn sẽ hiển thị sau khi Admin duyệt.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        actions: [
          // Kiểu nút lấy từ elevatedButtonTheme trong AppTheme.
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Xong'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_openHour >= _closeHour) {
      _message('Giờ đóng cửa phải sau giờ mở cửa.');
      return;
    }
    if (_images.length < _minImages) {
      _message('Vui lòng chọn tối thiểu $_minImages ảnh khác nhau.');
      return;
    }
    final user = MockStore.currentUser;
    if (user == null || user.role != 'owner') {
      _message('Chỉ chủ sân được đăng ký sân mới.');
      return;
    }

    final sportType = _sportType!;
    final sportTypeId =
        _sportTypes.firstWhere((sport) => sport['name'] == sportType)['id']
            as int?;

    final venue = Venue(
      id: 'venue${DateTime.now().microsecondsSinceEpoch}',
      ownerId: user.id,
      name: _normalizeSpaces(_name.text),
      address: _normalizeSpaces(_address.text),
      sportType: sportType,
      sportTypeId: sportTypeId,
      pricePerHour: _parsePrice(_price.text)!.toDouble(),
      imageUrls: _images.map((image) => image.path).toList(),
      latitude: 0,
      longitude: 0,
    );

    setState(() => _saving = true);
    try {
      await VenueRepository.saveVenue(
        venue,
        openHour: _openHour,
        closeHour: _closeHour,
      );
    } catch (_) {
      if (mounted) {
        _message('Không thể lưu sân vào cơ sở dữ liệu. Vui lòng thử lại.');
        setState(() => _saving = false);
      }
      return;
    }

    if (!mounted) return;
    setState(() => _saving = false);
    await _showSuccessDialog();
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  String? _validateName(String? value) {
    final name = _normalizeSpaces(value ?? '');
    if (name.isEmpty) return 'Vui lòng nhập tên sân';
    if (name.length < _minNameLength) {
      return 'Tên sân tối thiểu $_minNameLength ký tự';
    }
    if (name.length > _maxNameLength) {
      return 'Tên sân tối đa $_maxNameLength ký tự';
    }
    if (!RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(name)) {
      return 'Tên sân phải chứa chữ hoặc số';
    }
    return null;
  }

  String? _validateAddress(String? value) {
    final address = _normalizeSpaces(value ?? '');
    if (address.isEmpty) return 'Vui lòng nhập địa chỉ';
    if (address.length < _minAddressLength) {
      return 'Địa chỉ quá ngắn (tối thiểu $_minAddressLength ký tự)';
    }
    if (address.length > _maxAddressLength) {
      return 'Địa chỉ tối đa $_maxAddressLength ký tự';
    }
    if (!RegExp(r'[\p{L}]', unicode: true).hasMatch(address)) {
      return 'Địa chỉ phải chứa chữ cái';
    }
    return null;
  }

  String? _validatePrice(String? value) {
    final price = _parsePrice(value);
    if (price == null) return 'Vui lòng nhập giá thuê';
    if (price < _minPrice) return 'Giá tối thiểu ${_formatMoney(_minPrice)} đ';
    if (price > _maxPrice) return 'Giá tối đa ${_formatMoney(_maxPrice)} đ';
    return null;
  }

  // Viền, màu nền, màu chữ... của ô nhập đã nằm trong inputDecorationTheme
  // của AppTheme, ở đây chỉ khai báo phần riêng của từng ô.
  InputDecoration _decoration({
    required String label,
    required String hint,
    String? suffixText,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffixText,
      prefixIcon: prefixIcon,
      floatingLabelBehavior: FloatingLabelBehavior.always,
    );
  }

  // Khu vực ảnh
  Widget _buildCover() {
    final hasCover = _previews.isNotEmpty;
    return AspectRatio(
      aspectRatio: 2.2,
      child: hasCover
          ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    _previews.first,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Center(child: Text('Ảnh lỗi')),
                  ),
                  const Positioned(
                    left: 10,
                    top: 10,
                    child: _Badge(label: 'Ảnh bìa'),
                  ),
                ],
              ),
            )
          : _DashedBox(
              radius: 16,
              onTap: _picking ? null : _pickImages,
              child: Center(
                child: _picking
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, color: AppTheme.primary, size: 20),
                          SizedBox(width: 6),
                          Text(
                            'Thêm ảnh bìa',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
    );
  }

  Widget _buildThumbnail(int index) {
    final isCover = index == 0;
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => _makeCover(index),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isCover ? AppTheme.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _previews[index],
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Center(child: Text('Ảnh lỗi')),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: Semantics(
              button: true,
              label: 'Xóa ảnh ${index + 1}',
              child: GestureDetector(
                onTap: _picking || _saving ? null : () => _removeImage(index),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: AppTheme.cardColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 3),
                    ],
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryRow() {
    final canAdd = _images.length < _maxImages;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(0, 8, 8, 4),
              itemCount: _images.length + (canAdd ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                if (canAdd && i == 0) {
                  return SizedBox(
                    width: 84,
                    height: 84,
                    child: _DashedBox(
                      radius: 14,
                      onTap: _picking ? null : _pickImages,
                      child: const Center(
                        child: Icon(
                          Icons.add,
                          color: AppTheme.primary,
                          size: 26,
                        ),
                      ),
                    ),
                  );
                }
                return _buildThumbnail(canAdd ? i - 1 : i);
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${_images.length} / $_maxImages ảnh',
          style: TextStyle(
            color: _images.length >= _minImages
                ? AppTheme.primary
                : AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Ô chọn loại thể thao (dữ liệu từ SQLite)
  Widget _buildSportTypeField() {
    if (_sportError != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.error),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _sportError!,
                style: const TextStyle(color: AppTheme.error),
              ),
            ),
            TextButton(
              onPressed: _retryLoadSportTypes,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _sportType,
      isExpanded: true,
      borderRadius: BorderRadius.circular(12),
      icon: const Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary),
      decoration: _decoration(
        label: 'Loại thể thao',
        hint: _loadingSports ? 'Đang tải...' : 'Chọn loại thể thao',
      ),
      hint: Text(
        _loadingSports ? 'Đang tải...' : 'Chọn loại thể thao',
        style: const TextStyle(color: AppTheme.textSecondary),
      ),
      items: [
        for (final sport in _sportTypes)
          DropdownMenuItem(
            value: sport['name'] as String,
            child: Text(sport['name'] as String),
          ),
      ],
      validator: (value) =>
          value == null ? 'Vui lòng chọn loại thể thao' : null,
      onChanged: _loadingSports || _sportTypes.isEmpty
          ? null
          : (value) => setState(() => _sportType = value),
    );
  }

  Widget _buildHoursFields() {
    String formatHour(int hour) => '${hour.toString().padLeft(2, '0')}:00';

    return Column(
      children: [
        DropdownButtonFormField<int>(
            initialValue: _openHour,
            decoration: _decoration(label: 'Mở cửa', hint: 'Chọn giờ mở cửa'),
            items: [
              for (var hour = 0; hour < 24; hour++)
                DropdownMenuItem(value: hour, child: Text(formatHour(hour))),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _openHour = value);
            },
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
            initialValue: _closeHour,
            decoration: _decoration(label: 'Đóng cửa', hint: 'Chọn giờ đóng cửa'),
            items: [
              for (var hour = 1; hour <= 24; hour++)
                DropdownMenuItem(value: hour, child: Text(formatHour(hour))),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _closeHour = value);
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Nền Scaffold, AppBar và các nút lấy từ AppTheme.lightTheme.
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Đăng ký sân mới',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _buildCover(),
            const SizedBox(height: 12),
            _buildGalleryRow(),
            const Padding(
              padding: EdgeInsets.only(top: 2, bottom: 14),
              child: Text(
                'Cần tối thiểu $_minImages ảnh. Chạm vào ảnh nhỏ để đặt làm ảnh bìa.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
              ),
            ),
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: _decoration(label: 'Tên sân', hint: 'Nhập tên sân'),
              validator: _validateName,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              textInputAction: TextInputAction.next,
              decoration: _decoration(label: 'Địa chỉ', hint: 'Nhập địa chỉ'),
              validator: _validateAddress,
            ),
            const SizedBox(height: 12),
            _buildSportTypeField(),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              keyboardType: TextInputType.number,
              inputFormatters: [_ThousandsFormatter()],
              decoration: _decoration(
                label: 'Giá thuê / giờ',
                hint: 'Nhập giá thuê',
                suffixText: 'đ',
              ),
              validator: _validatePrice,
            ),
            const SizedBox(height: 12),
            _buildHoursFields(),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.primaryDark,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sân sẽ được Admin duyệt trước khi hiển thị',
                      style: TextStyle(
                        color: AppTheme.primaryDark,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _picking || _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  disabledBackgroundColor: AppTheme.primary.withValues(
                    alpha: 0.4,
                  ),
                  disabledForegroundColor: Colors.white,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Gửi duyệt'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Nhãn nhỏ bo tròn (vd. "Ảnh bìa") đặt chồng lên ảnh.
class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Ô viền nét đứt màu xanh, chạm được (dùng cho ảnh bìa và nút thêm ảnh).
class _DashedBox extends StatelessWidget {
  const _DashedBox({required this.child, required this.radius, this.onTap});
  final Widget child;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedRRectPainter(radius: radius),
      child: Material(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: child),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.radius});
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(0.8);
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) => old.radius != radius;
}
