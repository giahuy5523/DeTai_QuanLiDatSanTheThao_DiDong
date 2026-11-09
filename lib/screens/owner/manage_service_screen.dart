import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/venue_repository.dart';
import '../../models/service.dart';
import '../../utils/app_theme.dart';

const _quickUnits = ['chai', 'bộ', 'giờ', 'lần'];

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

// Tự thêm dấu chấm ngăn cách hàng nghìn khi nhập giá.
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
  // Toàn bộ dữ liệu đến từ SQLite (bảng venues, venue_services).
  List<VenueService> _services = const [];
  String? _venueName;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      final services = await VenueRepository.loadServicesFor(widget.venueId);
      final venueName = await VenueRepository.venueNameFor(widget.venueId);
      if (!mounted) return;
      setState(() {
        _services = services;
        _venueName = venueName;
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Không thể tải danh sách dịch vụ. Vui lòng thử lại.';
      });
    }
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    _loadServices();
  }

  @override
  Widget build(BuildContext context) {
    final services = _services;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _venueName == null
              ? 'Quản lý dịch vụ kèm theo'
              : 'Dịch vụ - $_venueName',
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading || _error != null ? null : () => _editService(),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        icon: const Icon(Icons.add),
        label: const Text(
          'Thêm dịch vụ',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError(_error!)
          : services.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
              onRefresh: _loadServices,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
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
                          color: AppTheme.primaryDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }
                  return _buildServiceCard(services[i - 1]);
                },
              ),
            ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _retry,
              style: OutlinedButton.styleFrom(minimumSize: const Size(140, 48)),
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
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
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.room_service_outlined,
                size: 40,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chưa có dịch vụ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Nhấn "Thêm dịch vụ" để tạo dịch vụ kèm theo cho sân.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(VenueService service) {
    return Card(
      key: ValueKey(service.id),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _iconForUnit(service.unit),
                color: AppTheme.primary.withValues(alpha: 0.6),
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
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_formatMoney(service.price)} đ / ${service.unit}',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _SmallButton(
                        label: 'Sửa',
                        color: AppTheme.primary,
                        onPressed: () => _editService(service: service),
                      ),
                      const SizedBox(width: 8),
                      _SmallButton(
                        label: 'Xóa',
                        color: AppTheme.error,
                        onPressed: () => _deleteService(service),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    String? suffix,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffix,
      errorText: errorText,
      suffixStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.error, width: 1.6),
      ),
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

    ModalRoute<bool>? dialogRoute;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        dialogRoute = ModalRoute.of<bool>(dialogContext);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.background,
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
                  color: AppTheme.textPrimary,
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
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
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
                            selectedColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: unitController.text.trim() == u
                                  ? Colors.white
                                  : AppTheme.textSecondary,
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
                        color: AppTheme.error,
                        onPressed: () => Navigator.pop(dialogContext, false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DialogButton(
                        label: service == null ? 'Thêm' : 'Lưu',
                        color: AppTheme.primary,
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

    await dialogRoute?.completed;
    nameController.dispose();
    priceController.dispose();
    unitController.dispose();

    if (result != true || !mounted) return;

    // Đã được kiểm tra hợp lệ ngay trong dialog.
    final price = double.parse(
      priceText.replaceAll('.', '').replaceAll(',', ''),
    );

    final saved = VenueService(
      id: service?.id ?? 's${DateTime.now().microsecondsSinceEpoch}',
      venueId: widget.venueId,
      name: name,
      price: price,
      unit: unit,
    );

    try {
      await VenueRepository.saveService(saved);
      await _loadServices();
    } catch (_) {
      if (mounted) {
        _showSnack('Không thể lưu dịch vụ. Vui lòng thử lại.', success: false);
      }
      return;
    }

    if (!mounted) return;
    _showSnack(
      service == null ? 'Đã thêm dịch vụ.' : 'Đã cập nhật dịch vụ.',
      success: true,
    );
  }

  Future<void> _deleteService(VenueService service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Xóa dịch vụ',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text('Bạn có chắc muốn xóa "${service.name}"?'),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        actions: [
          Row(
            children: [
              Expanded(
                child: _DialogButton(
                  label: 'Hủy',
                  color: AppTheme.textSecondary,
                  onPressed: () => Navigator.pop(dialogContext, false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DialogButton(
                  label: 'Xóa',
                  color: AppTheme.error,
                  onPressed: () => Navigator.pop(dialogContext, true),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final deleted = await VenueRepository.deleteService(service.id);
      if (!mounted) return;
      if (!deleted) {
        _showSnack(
          '"${service.name}" đã được dùng trong lịch đặt nên không thể xóa.',
          success: false,
        );
        return;
      }
      await _loadServices();
    } catch (_) {
      if (mounted) {
        _showSnack('Không thể xóa dịch vụ. Vui lòng thử lại.', success: false);
      }
      return;
    }

    if (!mounted) return;
    _showSnack('Đã xóa "${service.name}".', success: false);
  }

  void _showSnack(String message, {required bool success}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: success ? AppTheme.success : AppTheme.error,
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
        minimumSize: const Size(54, 34),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      child: Text(label),
    );
  }
}

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
        minimumSize: const Size.fromHeight(48),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
      child: Text(label),
    );
  }
}
