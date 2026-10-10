import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/mock_store.dart';
import '../../models/venue.dart';

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
  String _sportType = 'Bóng đá';
  bool _picking = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _price.dispose();
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pickImages() async {
    setState(() => _picking = true);
    try {
      final picked = await (widget.picker ?? ImagePicker()).pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      final images = <XFile>[];
      final previews = <Uint8List>[];
      final paths = _images.map((image) => image.path).toSet();
      for (final image in picked) {
        if (!paths.add(image.path)) continue;
        final bytes = await image.readAsBytes();
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

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_images.length < 3) {
      _message('Vui lòng chọn tối thiểu 3 ảnh khác nhau.');
      return;
    }
    final user = MockStore.currentUser;
    if (user == null || user.role != 'owner') {
      _message('Chỉ chủ sân được đăng ký sân mới.');
      return;
    }
    MockStore.addVenue(
      Venue(
        id: 'venue${DateTime.now().microsecondsSinceEpoch}',
        ownerId: user.id,
        name: _name.text.trim(),
        address: _address.text.trim(),
        sportType: _sportType,
        sportTypeId: MockStore.sportTypeIdFor(_sportType),
        pricePerHour: double.parse(_price.text.trim()),
        imageUrls: _images.map((image) => image.path).toList(),
        latitude: 0,
        longitude: 0,
      ),
    );
    Navigator.pop(context, true);
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Không được để trống' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký sân mới')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Tên sân'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Địa chỉ'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _sportType,
              decoration: const InputDecoration(labelText: 'Loại sân'),
              items: const [
                DropdownMenuItem(value: 'Bóng đá', child: Text('Bóng đá')),
                DropdownMenuItem(value: 'Cầu lông', child: Text('Cầu lông')),
                DropdownMenuItem(value: 'Tennis', child: Text('Tennis')),
              ],
              onChanged: (value) =>
                  setState(() => _sportType = value ?? 'Bóng đá'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Giá / giờ (đ)'),
              validator: (value) {
                final price = double.tryParse(value?.trim() ?? '');
                return price == null || !price.isFinite || price <= 0
                    ? 'Nhập giá lớn hơn 0'
                    : null;
              },
            ),
            const SizedBox(height: 18),
            Text(
              'Ảnh sân: ${_images.length} / tối thiểu 3',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                _images.length,
                (index) => SizedBox(
                  width: 96,
                  height: 96,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(
                        _previews[index],
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Center(child: Text('Ảnh lỗi')),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          tooltip: 'Xóa ảnh ${index + 1}',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                          ),
                          onPressed: _picking
                              ? null
                              : () => setState(() {
                                  _images.removeAt(index);
                                  _previews.removeAt(index);
                                }),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _picking ? null : _pickImages,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(_picking ? 'Đang chọn ảnh...' : 'Chọn ảnh từ máy'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _picking ? null : _submit,
              child: const Text('Gửi duyệt'),
            ),
          ],
        ),
      ),
    );
  }
}
