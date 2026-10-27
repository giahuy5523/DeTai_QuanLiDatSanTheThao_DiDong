import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/mock_store.dart';
import '../../models/venue.dart';
import '../../utils/app_theme.dart';

// ---- Bảng màu & hằng số của màn hình ----
const _primary = Color(0xFF0F8B5F);
const _primaryDark = Color(0xFF065F46);
const _primarySoft = Color(0xFFA8EBCB);
const _background = Color(0xFFF5F7FA);
const _hintColor = Color(0xFF6B7385);
const _fieldRadius = 14.0;
const _maxImages = 8;
const _minImages = 3;

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
  String? _sportType;
  String _fingerprint(Uint8List bytes) =>
      '${bytes.length}:${Object.hashAll(bytes)}';
  bool _picking = false;

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
        // SnackBar(content: Text(text))
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
      final images = <XFile>[];
      final previews = <Uint8List>[];
      final seen = _previews.map(_fingerprint).toSet();
      var overLimit = false;
      var duplicates = 0;
      for (final image in picked) {
        final bytes = await image.readAsBytes();
        if (!seen.add(_fingerprint(bytes))) {
          duplicates++;
          continue;
        }
        if (images.length >= remaining) {
          overLimit = true;
          break;
        }
        final codec = await ui.instantiateImageCodec(bytes);
        codec.dispose();
        images.add(image);
        previews.add(bytes);
      }
      if (!mounted) return;
      setState(() {
        _images.addAll(images);
        _previews.addAll(previews);
      });
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

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
      _previews.removeAt(index);
    });
  }

  /// Đưa ảnh được chọn lên đầu danh sách để làm ảnh bìa.
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: _primary, size: 42),
            ),
            const SizedBox(height: 16),
            const Text(
              'Đã gửi duyệt',
              style: TextStyle(
                color: _primaryDark,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sân của bạn sẽ hiển thị sau khi Admin duyệt.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _hintColor, height: 1.4),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Xong',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
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
    final venueId = 'venue${DateTime.now().microsecondsSinceEpoch}';
    final imageUrls = _images.map((image) => image.path).toList();
    MockStore.addVenue(
      Venue(
        id: venueId,
        ownerId: user.id,
        name: _name.text.trim(),
        address: _address.text.trim(),
        sportType: sportType,
        sportTypeId: MockStore.sportTypeIdFor(sportType),
        pricePerHour: double.parse(_price.text.trim()),
        imageUrls: imageUrls,
        latitude: 0,
        longitude: 0,
      ),
    );
    MockStore.setVenueImages(venueId, imageUrls);
    await _showSuccessDialog();
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Không được để trống' : null;

  // ---- Style cho các ô nhập ----
  InputDecoration _decoration({
    required String label,
    required String hint,
    String? suffixText,
    Widget? prefixIcon,
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
      prefixIcon: prefixIcon,
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

  // ---- Khu vực ảnh ----
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
          'Đăng ký sân mới',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
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
              hint: const Text(
                'Chọn loại thể thao',
                style: TextStyle(color: _hintColor),
              ),
              items: [
                for (final sport in MockStore.sportTypes)
                  DropdownMenuItem(
                    value: sport['name'] as String,
                    child: Text(sport['name'] as String),
                  ),
              ],
              validator: (value) =>
                  value == null ? 'Vui lòng chọn loại thể thao' : null,
              onChanged: (value) => setState(() => _sportType = value),
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
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: _primaryDark, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sân sẽ được Admin duyệt trước khi hiển thị',
                      style: TextStyle(color: _primaryDark, fontSize: 14.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _picking ? null : _submit,
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
                child: const Text('Gửi duyệt'),
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
