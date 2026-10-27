import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/mock_store.dart';
import '../../models/venue.dart';
import '../../utils/app_theme.dart';

// ---- Bảng màu & hằng số (giống màn Đăng ký sân) ----
const _primary = Color(0xFF128C5E);
const _primarySoft = Color(0xFFA8EBCB);
const _background = Color(0xFFF4F6FA);
const _hintColor = Color(0xFF6B7385);
const _fieldRadius = 14.0;
const _maxImages = 8;
const _minImages = 3;

/// Một ảnh của sân: có thể là ảnh cũ (đường dẫn/URL đã lưu) hoặc ảnh mới chọn.
class _VenueImage {
  _VenueImage({required this.source, this.bytes});
  final String source; // đường dẫn file, URL hoặc asset
  Uint8List? bytes; // có bytes thì hiển thị bằng Image.memory
}

bool _isRemote(String s) =>
    s.startsWith('http://') ||
    s.startsWith('https://') ||
    s.startsWith('blob:');

String _fingerprint(Uint8List bytes) =>
    '${bytes.length}:${Object.hashAll(bytes)}';

class VenueUpdateScreen extends StatefulWidget {
  const VenueUpdateScreen({super.key, required this.venue, this.picker});
  final Venue venue;
  final ImagePicker? picker;

  @override
  State<VenueUpdateScreen> createState() => _VenueUpdateScreenState();
}

class _VenueUpdateScreenState extends State<VenueUpdateScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _price;
  late final List<_VenueImage> _images;
  late String _sportType;
  bool _picking = false;

  late final List<String> _sports;

  @override
  void initState() {
    super.initState();
    final venue = widget.venue;
    _name = TextEditingController(text: venue.name);
    _address = TextEditingController(text: venue.address);
    _price = TextEditingController(text: venue.pricePerHour.toStringAsFixed(0));
    _sportType = venue.sportType;
    _sports = [for (final s in MockStore.sportTypes) s['name'] as String];
    if (!_sports.contains(_sportType)) _sports.add(_sportType);
    // Sân mẫu để imageUrls rỗng, ảnh thật nằm trong MockStore.venueImages.
    final urls = venue.imageUrls.isNotEmpty
        ? venue.imageUrls
        : MockStore.imageUrlsOf(venue.id);
    _images = urls.map((s) => _VenueImage(source: s)).toList();
    _loadExistingBytes();
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _price.dispose();
    super.dispose();
  }

  /// Đọc nội dung ảnh cũ (file cục bộ) để có thể chống trùng với ảnh mới chọn.
  Future<void> _loadExistingBytes() async {
    for (final img in List.of(_images)) {
      if (_isRemote(img.source)) continue;
      try {
        img.bytes = img.source.startsWith('assets/')
            ? (await rootBundle.load(img.source)).buffer.asUint8List()
            : await XFile(img.source).readAsBytes();
      } catch (_) {
        // File không còn tồn tại: để errorBuilder hiện "Ảnh lỗi".
      }
    }
    if (mounted) setState(() {});
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
              Icon(Icons.cancel_outlined, color: Colors.white),
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
      final added = <_VenueImage>[];
      final seen = {
        for (final img in _images)
          if (img.bytes != null) _fingerprint(img.bytes!),
      };
      var overLimit = false;
      var duplicates = 0;
      for (final image in picked) {
        final bytes = await image.readAsBytes();
        if (!seen.add(_fingerprint(bytes))) {
          duplicates++;
          continue;
        }
        if (added.length >= remaining) {
          overLimit = true;
          break;
        }
        final codec = await ui.instantiateImageCodec(bytes);
        codec.dispose();
        added.add(_VenueImage(source: image.path, bytes: bytes));
      }
      if (!mounted) return;
      setState(() => _images.addAll(added));
      if (overLimit) {
        _message('Chỉ giữ tối đa $_maxImages ảnh.');
      } else if (duplicates > 0) {
        _message('Đã bỏ qua $duplicates ảnh trùng.');
      }
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

  void _removeImage(int index) => setState(() => _images.removeAt(index));

  /// Đưa ảnh được chọn lên đầu danh sách để làm ảnh bìa.
  void _makeCover(int index) {
    if (index == 0) return;
    setState(() => _images.insert(0, _images.removeAt(index)));
  }

  void _save() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_images.length < _minImages) {
      _message('Vui lòng chọn tối thiểu $_minImages ảnh.');
      return;
    }
    final updatedVenue = widget.venue.copyWith(
      name: _name.text.trim(),
      address: _address.text.trim(),
      sportType: _sportType,
      sportTypeId: MockStore.sportTypeIdFor(_sportType),
      pricePerHour: double.parse(_price.text.trim()),
      imageUrls: _images.map((img) => img.source).toList(),
    );
    final messenger = ScaffoldMessenger.of(context);
    if (!MockStore.updateVenue(updatedVenue)) {
      _message('Không thể cập nhật thông tin sân.');
      return;
    }
    MockStore.setVenueImages(updatedVenue.id, updatedVenue.imageUrls);
    Navigator.pop(context, true);
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.success,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text('Đã cập nhật thông tin sân.')),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Không được để trống' : null;

  // ---- Style cho các ô nhập ----
  InputDecoration _decoration({
    required String label,
    required String hint,
    String? suffixText,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(_fieldRadius),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffixText,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: const TextStyle(color: _hintColor),
      floatingLabelStyle: const TextStyle(
        color: _hintColor,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: const TextStyle(color: _hintColor),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      enabledBorder: border(_primarySoft),
      focusedBorder: border(_primary, 1.6),
      errorBorder: border(Colors.red.shade400),
      focusedErrorBorder: border(Colors.red.shade400, 1.6),
      border: border(_primarySoft),
    );
  }

  // ---- Hiển thị ảnh (bytes / URL / file / asset) ----
  Widget _imageView(_VenueImage img) {
    Widget error(BuildContext _, Object _, StackTrace? _) =>
        const Center(child: Text('Ảnh lỗi'));
    if (img.bytes != null) {
      return Image.memory(img.bytes!, fit: BoxFit.cover, errorBuilder: error);
    }
    if (kIsWeb || _isRemote(img.source)) {
      return Image.network(img.source, fit: BoxFit.cover, errorBuilder: error);
    }
    if (img.source.startsWith('assets/')) {
      return Image.asset(img.source, fit: BoxFit.cover, errorBuilder: error);
    }
    return Image.file(File(img.source), fit: BoxFit.cover, errorBuilder: error);
  }

  Widget _buildCover() {
    return AspectRatio(
      aspectRatio: 2.2,
      child: _images.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _imageView(_images.first),
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
              child: const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: _primary, size: 20),
                    SizedBox(width: 6),
                    Text(
                      'Thêm ảnh bìa',
                      style: TextStyle(
                        color: _primary,
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
                    color: isCover ? _primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _imageView(_images[index]),
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
                onTap: _picking ? null : () => _removeImage(index),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 3),
                    ],
                  ),
                  child: const Icon(Icons.close, size: 14),
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
      children: [
        Expanded(
          child: SizedBox(
            height: 100,
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
                        child: Icon(Icons.add, color: _primary, size: 26),
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
            color: _images.length >= _minImages ? _primary : _hintColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Cập nhật thông tin sân',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.white,
          ),
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
                style: TextStyle(color: _hintColor, fontSize: 12.5),
              ),
            ),
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: _decoration(label: 'Tên sân', hint: 'Nhập tên sân'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              textInputAction: TextInputAction.next,
              decoration: _decoration(label: 'Địa chỉ', hint: 'Nhập địa chỉ'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _sportType,
              isExpanded: true,
              borderRadius: BorderRadius.circular(_fieldRadius),
              icon: const Icon(Icons.arrow_drop_down, color: _hintColor),
              decoration: _decoration(
                label: 'Loại thể thao',
                hint: 'Chọn loại thể thao',
              ),
              items: [
                for (final sport in _sports)
                  DropdownMenuItem(value: sport, child: Text(sport)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _sportType = value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _decoration(
                label: 'Giá thuê / giờ',
                hint: 'Nhập giá thuê',
                suffixText: 'đ',
              ),
              validator: (value) {
                final price = double.tryParse(value?.trim() ?? '');
                return price == null || !price.isFinite || price <= 0
                    ? 'Nhập giá lớn hơn 0'
                    : null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _picking ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _primary.withValues(alpha: 0.4),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Lưu thay đổi'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nhãn nhỏ bo tròn (vd. "Ảnh bìa") đặt chồng lên ảnh.
class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _primary,
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

/// Ô viền nét đứt màu xanh, chạm được (dùng cho ảnh bìa và nút thêm ảnh).
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
        color: Colors.white,
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
      ..color = _primary
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
