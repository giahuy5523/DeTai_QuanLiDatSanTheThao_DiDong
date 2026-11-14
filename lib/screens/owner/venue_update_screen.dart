import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/venue_repository.dart';
import '../../models/venue.dart';
import '../../utils/app_theme.dart';

// Hằng số riêng của màn hình
const _fieldRadius = 14.0;
const _maxImages = 8;
const _minImages = 3;
const _minNameLength = 3;
const _maxNameLength = 60;
const _minAddressLength = 5;
const _maxAddressLength = 120;
const _minPrice = 10000;
const _maxPrice = 10000000;
const _maxPriceDigits = 8;
const _maxImageBytes = 5 * 1024 * 1024; // 5 MB

String _normalizeSpaces(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

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
    int.tryParse((raw ?? '').replaceAll(RegExp(r'[^0-9]'), ''));

class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    if (digits.length > _maxPriceDigits) return oldValue;
    final text = _formatMoney(int.parse(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

// Một ảnh của sân: có thể là ảnh cũ (đường dẫn/URL đã lưu) hoặc ảnh mới chọn.
class _VenueImage {
  _VenueImage({required this.source, this.bytes});
  final String source; // đường dẫn file, URL hoặc asset
  Uint8List? bytes; // có bytes thì hiển thị bằng Image.memory
  bool broken = false; // đọc file thất bại
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
  bool _saving = false;

  // Danh sách loại thể thao đọc từ SQLite. Ban đầu chỉ có loại hiện tại của
  // sân để dropdown luôn có giá trị hợp lệ trong lúc chờ tải.
  late List<String> _sports;

  @override
  void initState() {
    super.initState();
    final venue = widget.venue;
    _name = TextEditingController(text: venue.name);
    _address = TextEditingController(text: venue.address);
    _price = TextEditingController(text: _formatMoney(venue.pricePerHour));
    _sportType = venue.sportType;
    _sports = [venue.sportType];
    // Venue truyền vào được đọc từ SQLite nên imageUrls đã có đủ ảnh.
    _images = venue.imageUrls.map((s) => _VenueImage(source: s)).toList();
    _loadExistingBytes();
    _loadSportTypes();
  }

  // Đọc danh sách loại thể thao từ bảng sport_types.
  Future<void> _loadSportTypes() async {
    try {
      final rows = await VenueRepository.loadSportTypes();
      final sports = rows.map((row) => row['name'] as String).toList();
      if (!sports.contains(widget.venue.sportType)) {
        sports.add(widget.venue.sportType);
      }
      if (mounted) setState(() => _sports = sports);
    } catch (_) {
      // Giữ lại loại thể thao hiện tại nếu không đọc được từ DB.
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _price.dispose();
    super.dispose();
  }

  // Đọc nội dung ảnh cũ (file cục bộ) để có thể chống trùng với ảnh mới chọn.
  Future<void> _loadExistingBytes() async {
    for (final img in List.of(_images)) {
      if (_isRemote(img.source)) continue;
      try {
        img.bytes = img.source.startsWith('assets/')
            ? (await rootBundle.load(img.source)).buffer.asUint8List()
            : await XFile(img.source).readAsBytes();
      } catch (_) {
        img.broken = true;
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
      final added = <_VenueImage>[];
      final seen = {
        for (final img in _images)
          if (img.bytes != null) _fingerprint(img.bytes!),
      };
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
        if (added.length >= remaining) {
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
        added.add(_VenueImage(source: image.path, bytes: bytes));
      }
      if (!mounted) return;
      setState(() => _images.addAll(added));
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

  void _removeImage(int index) => setState(() => _images.removeAt(index));

  // Đưa ảnh được chọn lên đầu danh sách để làm ảnh bìa.
  void _makeCover(int index) {
    if (index == 0) return;
    setState(() => _images.insert(0, _images.removeAt(index)));
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_images.length < _minImages) {
      _message('Vui lòng chọn tối thiểu $_minImages ảnh.');
      return;
    }
    if (_images.any((img) => img.broken)) {
      _message('Có ảnh không đọc được. Vui lòng xóa ảnh lỗi và thêm ảnh khác.');
      return;
    }

    setState(() => _saving = true);
    try {
      final sportTypeId = await VenueRepository.sportTypeIdFor(_sportType);
      final updatedVenue = widget.venue.copyWith(
        name: _normalizeSpaces(_name.text),
        address: _normalizeSpaces(_address.text),
        sportType: _sportType,
        sportTypeId: sportTypeId,
        pricePerHour: _parsePrice(_price.text)!.toDouble(),
        imageUrls: _images.map((img) => img.source).toList(),
      );
      // saveVenue copy ảnh mới vào thư mục app, ghi DB rồi làm mới cache.
      await VenueRepository.saveVenue(updatedVenue);
    } catch (_) {
      if (mounted) {
        _message('Không thể lưu thay đổi vào cơ sở dữ liệu. Vui lòng thử lại.');
        setState(() => _saving = false);
      }
      return;
    }

    if (!mounted) return;
    setState(() => _saving = false);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context, true);
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.success,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 10),
            Expanded(child: Text('Đã cập nhật thông tin sân.')),
          ],
        ),
      ),
    );
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

  InputDecoration _decoration({
    required String label,
    required String hint,
    String? suffixText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffixText,
      floatingLabelBehavior: FloatingLabelBehavior.always,
    );
  }

  // Hiển thị ảnh (bytes / URL / file / asset)
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Cập nhật thông tin sân',
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
              inputFormatters: [
                LengthLimitingTextInputFormatter(_maxNameLength),
              ],
              decoration: _decoration(label: 'Tên sân', hint: 'Nhập tên sân'),
              validator: _validateName,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              textInputAction: TextInputAction.next,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              inputFormatters: [
                LengthLimitingTextInputFormatter(_maxAddressLength),
              ],
              decoration: _decoration(label: 'Địa chỉ', hint: 'Nhập địa chỉ'),
              validator: _validateAddress,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _sportType,
              isExpanded: true,
              borderRadius: BorderRadius.circular(_fieldRadius),
              icon: const Icon(
                Icons.arrow_drop_down,
                color: AppTheme.textSecondary,
              ),
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
              autovalidateMode: AutovalidateMode.onUserInteraction,
              inputFormatters: [_ThousandsFormatter()],
              decoration: _decoration(
                label: 'Giá thuê / giờ',
                hint: 'Nhập giá thuê',
                suffixText: 'đ',
              ),
              validator: _validatePrice,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _picking || _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  disabledBackgroundColor: AppTheme.primary.withValues(
                    alpha: 0.4,
                  ),
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
                    : const Text('Lưu thay đổi'),
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
