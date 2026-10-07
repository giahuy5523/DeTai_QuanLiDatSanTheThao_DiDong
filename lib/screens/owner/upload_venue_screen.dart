import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/mock_store.dart';
import '../../models/venue.dart';

class UploadVenueScreen extends StatefulWidget {
  const UploadVenueScreen({super.key});

  @override
  State<UploadVenueScreen> createState() => _UploadVenueScreenState();
}

class _UploadVenueScreenState extends State<UploadVenueScreen> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _price = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _images = [];

  String _sportType = 'Bóng đá';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = 9 - _images.length;

    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn chỉ có thể chọn tối đa 9 ảnh.'),
        ),
      );
      return;
    }

    final selected = await _picker.pickMultiImage(
      imageQuality: 85,
    );

    if (!mounted || selected.isEmpty) return;

    setState(() {
      _images.addAll(selected.take(remaining));
    });
  }

  Future<void> _takePhoto() async {
    if (_images.length >= 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn chỉ có thể chọn tối đa 9 ảnh.'),
        ),
      );
      return;
    }

    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (!mounted || photo == null) return;

      setState(() {
        _images.add(photo);
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể chụp ảnh: $e'),
        ),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  void _submit() {
    final name = _name.text.trim();
    final address = _address.text.trim();
    final price = double.tryParse(
      _price.text.trim().replaceAll(',', ''),
    );
    final owner = MockStore.currentUser;

    if (owner == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không xác định được tài khoản chủ sân.'),
        ),
      );
      return;
    }

    if (name.isEmpty ||
        address.isEmpty ||
        price == null ||
        price <= 0 ||
        _images.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng nhập đầy đủ thông tin và chọn tối thiểu 3 ảnh.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final venueId = 'v${DateTime.now().millisecondsSinceEpoch}';

    final imagePaths = _images.map((image) => image.path).toList();

    final venue = Venue(
      id: venueId,
      ownerId: owner.id,
      name: name,
      address: address,
      sportType: _sportType,
      pricePerHour: price,
      imageUrls: imagePaths,
      latitude: 0,
      longitude: 0,
      status: 'pending',
      rating: 0,
    );

    MockStore.addVenue(venue);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Đăng ký sân thành công, đang chờ quản trị viên duyệt.',
        ),
      ),
    );

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng ký sân mới'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Tên sân',
              hintText: 'Ví dụ: Sân bóng đá Thành Công',
              prefixIcon: Icon(Icons.stadium_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Địa chỉ',
              hintText: 'Ví dụ: 12 Lý Thường Kiệt, Tân Bình',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _sportType,
            decoration: const InputDecoration(
              labelText: 'Loại sân',
              prefixIcon: Icon(Icons.sports_soccer),
            ),
            items: const [
              DropdownMenuItem(
                value: 'Bóng đá',
                child: Text('Bóng đá'),
              ),
              DropdownMenuItem(
                value: 'Cầu lông',
                child: Text('Cầu lông'),
              ),
              DropdownMenuItem(
                value: 'Tennis',
                child: Text('Tennis'),
              ),
              DropdownMenuItem(
                value: 'Bóng rổ',
                child: Text('Bóng rổ'),
              ),
              DropdownMenuItem(
                value: 'Bóng chuyền',
                child: Text('Bóng chuyền'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _sportType = value;
                });
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: const InputDecoration(
              labelText: 'Giá / giờ',
              suffixText: 'đ',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ảnh sân: ${_images.length} / tối thiểu 3',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_images.isEmpty)
                    Container(
                      height: 130,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade300,
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 42,
                          ),
                          SizedBox(height: 8),
                          Text('Chưa có ảnh'),
                        ],
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _images.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                File(_images[index].path),
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: InkWell(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSubmitting ? null : _takePhoto,
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Chụp ảnh'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSubmitting ? null : _pickImages,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Thư viện'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Gửi duyệt'),
            ),
          ),
        ],
      ),
    );
  }
}
