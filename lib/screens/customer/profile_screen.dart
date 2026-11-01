import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/avatar_storage.dart';
import '../../data/mock_store.dart';
import '../../utils/app_routes.dart';
import '../../utils/auth_validation.dart';

const _green = Color(0xFF0F8B5F);
const _ink = Color(0xFF172B3A);
const _muted = Color(0xFF778799);
const _border = Color(0xFFDFE6EB);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.picker, this.avatarStorage});
  final ImagePicker? picker;
  final AvatarStorage? avatarStorage;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final String? _userId;
  late final _name = TextEditingController(
    text: MockStore.currentUser?.name ?? '',
  );
  late final _email = TextEditingController(
    text: MockStore.currentUser?.email ?? '',
  );
  late final _phone = TextEditingController(
    text: MockStore.currentUser?.phone ?? '',
  );
  late final _storage = widget.avatarStorage ?? AvatarStorage();
  String? _avatarPath;
  Uint8List? _preview;
  bool _avatarChanged = false;
  bool _picking = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _userId = MockStore.currentUser?.id;
    _avatarPath = MockStore.currentUser?.avatarPath;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _chooseAvatar() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Ảnh đại diện',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: _green,
                ),
                title: const Text('Chọn ảnh từ thư viện'),
                onTap: () => Navigator.pop(context, 'pick'),
              ),
              if (_preview != null || _avatarPath != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFC83D3D),
                  ),
                  title: const Text(
                    'Xóa ảnh đại diện',
                    style: TextStyle(color: Color(0xFFC83D3D)),
                  ),
                  onTap: () => Navigator.pop(context, 'remove'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'remove') {
      setState(() {
        _preview = null;
        _avatarPath = null;
        _avatarChanged = true;
      });
      return;
    }
    setState(() => _picking = true);
    try {
      final image = await (widget.picker ?? ImagePicker()).pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) {
        throw const FormatException('Image too large');
      }
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 512);
      Uint8List? png;
      try {
        final frame = await codec.getNextFrame();
        try {
          png = (await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          ))?.buffer.asUint8List();
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
      if (png == null) throw const FormatException('Invalid image');
      if (!mounted) return;
      setState(() {
        _preview = png;
        _avatarChanged = true;
      });
    } catch (_) {
      if (mounted) {
        _message(
          'Không thể đọc ảnh. Hãy chọn ảnh khác hoặc kiểm tra quyền truy cập.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _picking || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    final user = MockStore.currentUser;
    if (user == null || user.id != _userId) {
      _message('Phiên đăng nhập không còn hợp lệ.');
      return;
    }
    setState(() => _saving = true);
    String? newFile;
    try {
      var path = _avatarPath;
      if (_avatarChanged && _preview != null) {
        newFile = await _storage.save(_preview!);
        path = newFile;
      }
      if (!mounted) {
        if (newFile != null) await _storage.remove(newFile);
        return;
      }
      final updated = MockStore.updateCurrentProfile(
        userId: user.id,
        name: _name.text,
        phone: _phone.text,
        avatarPath: path,
      );
      if (updated == null) {
        if (newFile != null) await _storage.remove(newFile);
        if (mounted) _message('Phiên đăng nhập không còn hợp lệ.');
        return;
      }
      setState(() {
        _avatarPath = updated.avatarPath;
        _preview = null;
        _avatarChanged = false;
      });
      _message('Đã cập nhật thông tin cá nhân');
      if (user.avatarPath != path) {
        try {
          await _storage.remove(user.avatarPath);
        } catch (_) {
          /* Cleanup is best effort after a successful save. */
        }
      }
    } catch (_) {
      if (mounted) _message('Không thể lưu ảnh đại diện. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Đăng xuất tài khoản?'),
        content: const Text('Bạn có chắc muốn đăng xuất khỏi ứng dụng?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    MockStore.logout();
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  Widget _avatar() {
    const fallback = ColoredBox(
      color: Color(0xFFE7F5EF),
      child: Center(child: Icon(Icons.person, size: 56, color: _green)),
    );
    Widget image = fallback;
    if (_preview != null) {
      image = Image.memory(
        _preview!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    } else if (_avatarPath != null) {
      image = Image.file(
        File(_avatarPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return SizedBox(
      width: 112,
      height: 112,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 8,
            width: 96,
            height: 96,
            child: ClipOval(child: image),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _saving || _picking ? null : _chooseAvatar,
                child: Semantics(
                  button: true,
                  label: 'Đổi ảnh đại diện',
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 12,
            child: IgnorePointer(
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: _picking
                    ? const Padding(
                        padding: EdgeInsets.all(6),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.camera_alt_outlined,
                        size: 18,
                        color: Colors.white,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool readOnly = false,
    String? Function(String?)? validator,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: _ink,
        ),
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        readOnly: readOnly,
        enabled: !_saving,
        validator: validator,
        style: const TextStyle(fontSize: 14, color: _ink),
        keyboardType: label == 'Số điện thoại'
            ? TextInputType.phone
            : TextInputType.text,
        textInputAction: label == 'Số điện thoại'
            ? TextInputAction.done
            : TextInputAction.next,
        onFieldSubmitted: label == 'Số điện thoại' ? (_) => _save() : null,
        decoration: InputDecoration(
          filled: true,
          fillColor: readOnly ? const Color(0xFFF5F7FA) : Colors.white,
          prefixIcon: Icon(icon, color: _muted, size: 20),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          isDense: true,
          errorMaxLines: 2,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _green, width: 1.5),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      if (readOnly)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Email dùng để đăng nhập',
            style: TextStyle(fontSize: 11, color: _muted),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final user = MockStore.currentUser;
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(primary: _green),
        textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: const Text(
            'Thông tin cá nhân',
            style: TextStyle(
              color: _ink,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: _avatar()),
                      Text(
                        user?.name ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7F5EF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            user?.role == 'owner'
                                ? 'Chủ sân'
                                : user?.role == 'admin'
                                ? 'Quản trị viên'
                                : 'Khách hàng',
                            style: const TextStyle(
                              color: _green,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Thông tin tài khoản',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _field(
                              'Họ và tên',
                              _name,
                              Icons.person_outline,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Họ và tên không được để trống'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            _field(
                              'Email',
                              _email,
                              Icons.mail_outline,
                              readOnly: true,
                            ),
                            const SizedBox(height: 16),
                            _field(
                              'Số điện thoại',
                              _phone,
                              Icons.phone_outlined,
                              validator: AuthValidation.phone,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _saving || _picking ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined, size: 20),
                        label: Text(_saving ? 'Đang lưu...' : 'Lưu thay đổi'),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _saving || _picking ? null : _logout,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFC83D3D),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: _border),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.logout, size: 20),
                        label: const Text('Đăng xuất'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
