import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/mock_store.dart';
import '../../models/service.dart';

const _kGreen = Color(0xFF118C5F);
const _kGreenDark = Color(0xFF0A6B49);
const _kRed = Color(0xFFEF4444);
const _kBackground = Color(0xFFF5F7FB);
const _kInk = Color(0xFF10231B);
const _kMuted = Color(0xFF64748B);
const _kPlaceholder = Color(0xFFEFF4F0);
const _kFieldBorder = Color(0xFFA7EBD0);

const _quickUnits = ['chai', 'bộ', 'giờ', 'lần'];

/// 30000 -> "30.000"
String _formatMoney(num value) {
  final digits = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Tự thêm dấu chấm ngăn cách hàng nghìn khi nhập giá.
class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final text = _formatMoney(int.parse(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

IconData _iconForUnit(String unit) {
  switch (unit.toLowerCase()) {
    case 'chai':
      return Icons.local_drink_outlined;
    case 'bộ':
      return Icons.checkroom_outlined;
    case 'giờ':
      return Icons.schedule_outlined;
    default:
      return Icons.room_service_outlined;
  }
}

class ManageServiceScreen extends StatefulWidget {
  final String venueId;

  const ManageServiceScreen({super.key, required this.venueId});

  @override
  State<ManageServiceScreen> createState() => _ManageServiceScreenState();
}

class _ManageServiceScreenState extends State<ManageServiceScreen> {
  List<VenueService> get _services =>
      MockStore.servicesByVenue[widget.venueId] ?? [];

  @override
  Widget build(BuildContext context) {
    final venue = MockStore.venueById(widget.venueId);
    final services = _services;

    return Scaffold(
      backgroundColor: _kBackground,
      appBar: AppBar(
        backgroundColor: _kGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        title: Text(
          venue == null
              ? 'Quản lý dịch vụ kèm theo'
              : 'Dịch vụ - ${venue.name}',
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editService(),
        backgroundColor: _kGreen,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        icon: const Icon(Icons.add),
        label: const Text(
          'Thêm dịch vụ',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: services.isEmpty
          ? _buildEmpty()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: services.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 0),
                    child: Text(
                      '${services.length} dịch vụ',
                      style: const TextStyle(
                        color: _kGreenDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }
                return _buildServiceCard(services[i - 1]);
              },
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: _kPlaceholder,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.room_service_outlined,
                size: 40,
                color: _kGreen,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chưa có dịch vụ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _kInk,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Nhấn "Thêm dịch vụ" để tạo dịch vụ kèm theo cho sân.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _kMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(VenueService service) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _kPlaceholder,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _iconForUnit(service.unit),
              color: _kGreen.withValues(alpha: 0.6),
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _kInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_formatMoney(service.price)} đ / ${service.unit}',
                  style: const TextStyle(
                    color: _kGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _SmallButton(
                      label: 'Sửa',
                      color: _kGreen,
                      onPressed: () => _editService(service: service),
                    ),
                    const SizedBox(width: 8),
                    _SmallButton(
                      label: 'Xóa',
                      color: _kRed,
                      onPressed: () => _deleteService(service),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    String? suffix,
    String? errorText,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffix,
      errorText: errorText,
      errorBorder: border(_kRed),
      focusedErrorBorder: border(_kRed, 1.6),
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: _kMuted),
      hintStyle: const TextStyle(color: _kMuted),
      suffixStyle: const TextStyle(color: _kMuted, fontSize: 16),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: border(_kFieldBorder),
      focusedBorder: border(_kGreen, 1.6),
    );
  }

  Future<void> _editService({VenueService? service}) async {
    final nameController = TextEditingController(text: service?.name ?? '');
    final priceController = TextEditingController(
      text: service == null ? '' : _formatMoney(service.price),
    );
    final unitController = TextEditingController(text: service?.unit ?? 'lần');

    String? nameError;
    String? priceError;
    String? unitError;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _kBackground,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              actionsPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              title: Text(
                service == null ? 'Thêm dịch vụ' : 'Sửa dịch vụ',
                style: const TextStyle(
                  color: _kInk,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      onChanged: (_) {
                        if (nameError != null) {
                          setDialogState(() => nameError = null);
                        }
                      },
                      decoration: _fieldDecoration(
                        label: 'Tên dịch vụ',
                        hint: 'Nhập tên dịch vụ',
                        errorText: nameError,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_ThousandsFormatter()],
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      onChanged: (_) {
                        if (priceError != null) {
                          setDialogState(() => priceError = null);
                        }
                      },
                      decoration: _fieldDecoration(
                        label: 'Giá',
                        hint: 'Nhập giá',
                        suffix: 'đ',
                        errorText: priceError,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: unitController,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      onChanged: (_) => setDialogState(() => unitError = null),
                      decoration: _fieldDecoration(
                        label: 'Đơn vị',
                        hint: 'Ví dụ: lần, chai, giờ...',
                        errorText: unitError,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Chọn nhanh đơn vị',
                      style: TextStyle(color: _kMuted, fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final u in _quickUnits)
                          ChoiceChip(
                            label: Text(u),
                            selected: unitController.text.trim() == u,
                            showCheckmark: false,
                            backgroundColor: Colors.white,
                            selectedColor: _kGreen,
                            side: BorderSide.none,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: unitController.text.trim() == u
                                  ? Colors.white
                                  : _kMuted,
                            ),
                            onSelected: (_) => setDialogState(() {
                              unitController.text = u;
                              unitError = null;
                            }),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: _DialogButton(
                        label: 'Hủy',
                        color: _kRed,
                        onPressed: () => Navigator.pop(dialogContext, false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DialogButton(
                        label: service == null ? 'Thêm' : 'Lưu',
                        color: _kGreen,
                        onPressed: () {
                          final name = nameController.text.trim();
                          final price = double.tryParse(
                            priceController.text
                                .trim()
                                .replaceAll('.', '')
                                .replaceAll(',', ''),
                          );
                          final unit = unitController.text.trim();
                          final nameInvalid = name.isEmpty;
                          final priceInvalid =
                              price == null || !price.isFinite || price <= 0;
                          final unitInvalid = unit.isEmpty;

                          if (nameInvalid || priceInvalid || unitInvalid) {
                            setDialogState(() {
                              nameError = nameInvalid
                                  ? 'Vui lòng nhập tên dịch vụ'
                                  : null;
                              priceError = priceInvalid
                                  ? 'Vui lòng nhập giá hợp lệ'
                                  : null;
                              unitError = unitInvalid
                                  ? 'Vui lòng nhập đơn vị'
                                  : null;
                            });
                            return;
                          }
                          Navigator.pop(dialogContext, true);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );

    final name = nameController.text.trim();
    final priceText = priceController.text.trim();
    final unit = unitController.text.trim();

    nameController.dispose();
    priceController.dispose();
    unitController.dispose();

    if (result != true || !mounted) return;

    // Đã được kiểm tra hợp lệ ngay trong dialog.
    final price = double.parse(
      priceText.replaceAll('.', '').replaceAll(',', ''),
    );

    setState(() {
      final list = MockStore.servicesByVenue[widget.venueId] ??= [];
      final normalizedUnit = unit; // đã validate không rỗng trong dialog

      if (service == null) {
        list.add(
          VenueService(
            id: 's${DateTime.now().microsecondsSinceEpoch}',
            venueId: widget.venueId,
            name: name,
            price: price,
            unit: normalizedUnit,
          ),
        );
      } else {
        final index = list.indexWhere((item) => item.id == service.id);
        if (index >= 0) {
          list[index] = VenueService(
            id: service.id,
            venueId: widget.venueId,
            name: name,
            price: price,
            unit: normalizedUnit,
          );
        }
      }
    });

    _showSnack(
      service == null ? 'Đã thêm dịch vụ.' : 'Đã cập nhật dịch vụ.',
      success: true,
    );
  }

  Future<void> _deleteService(VenueService service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _kBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Xóa dịch vụ',
          style: TextStyle(color: _kInk, fontWeight: FontWeight.w800),
        ),
        content: Text('Bạn có chắc muốn xóa "${service.name}"?'),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        actions: [
          Row(
            children: [
              Expanded(
                child: _DialogButton(
                  label: 'Hủy',
                  color: _kMuted,
                  onPressed: () => Navigator.pop(dialogContext, false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DialogButton(
                  label: 'Xóa',
                  color: _kRed,
                  onPressed: () => Navigator.pop(dialogContext, true),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      MockStore.servicesByVenue[widget.venueId]?.removeWhere(
        (item) => item.id == service.id,
      );
    });

    _showSnack('Đã xóa "${service.name}".', success: false);
  }

  /// success = true: nền xanh + icon check; false: nền đỏ + icon cancel.
  void _showSnack(String message, {required bool success}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: success ? _kGreen : _kRed,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle_outline : Icons.cancel_outlined,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}

/// Nút nhỏ (Sửa / Xóa) trên thẻ dịch vụ.
class _SmallButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _SmallButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size(54, 34),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      child: Text(label),
    );
  }
}

/// Nút lớn trong dialog (Hủy / Thêm / Lưu).
class _DialogButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _DialogButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
      child: Text(label),
    );
  }
}