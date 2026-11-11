import 'package:flutter/material.dart';
import '../../data/account_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_routes.dart';

class AdminDrawer extends StatefulWidget {
  final int selectedIndex;
  final VoidCallback? onReturn;

  /// Số sân đang chờ duyệt, hiển thị dạng badge cạnh mục "Duyệt sân".
  /// Truyền từ màn hình gọi (ví dụ: số sân có trạng thái pending).
  final int pendingVenueCount;

  const AdminDrawer({
    super.key,
    required this.selectedIndex,
    this.onReturn,
    this.pendingVenueCount = 0,
  });

  @override
  State<AdminDrawer> createState() => _AdminDrawerState();
}

class _AdminDrawerState extends State<AdminDrawer> {
  bool _loggingOut = false;

  Future<void> _goTo(BuildContext context, String route) async {
    if (_loggingOut) return;
    final navigator = Navigator.of(context);
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final onReturn = widget.onReturn;
    navigator.pop();
    if (currentRoute == route) return;
    await navigator.pushNamed(route);
    onReturn?.call();
  }

  Future<void> _logout(BuildContext context) async {
    if (_loggingOut) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    _loggingOut = true;
    try {
      await AccountService.logout();
    } catch (_) {
      _loggingOut = false;
      if (messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Không thể đăng xuất. Vui lòng thử lại.'),
          ),
        );
      }
      return;
    }
    if (!navigator.mounted) return;
    navigator.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.background,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const _SoftDivider(),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  _DrawerItem(
                    label: 'Tổng quan',
                    icon: Icons.dashboard_outlined,
                    selected: widget.selectedIndex == 0,
                    onTap: () => _goTo(context, AppRoutes.statistics),
                  ),
                  _DrawerItem(
                    label: 'Duyệt sân',
                    icon: Icons.approval,
                    selected: widget.selectedIndex == 1,
                    badgeCount: widget.pendingVenueCount,
                    onTap: () => _goTo(context, AppRoutes.approveVenue),
                  ),
                  _DrawerItem(
                    label: 'Quản lý khuyến mãi',
                    icon: Icons.discount_outlined,
                    selected: widget.selectedIndex == 2,
                    onTap: () => _goTo(context, AppRoutes.managePromotion),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _SoftDivider(),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _DrawerItem(
                label: 'Đăng xuất',
                icon: Icons.logout,
                color: AppTheme.error,
                onTap: () => _logout(context),
              ),
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.fromLTRB(28, 0, 24, 20),
              child: Text(
                'Phiên bản 1.0.0',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(28, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppTheme.primary,
            child: Text(
              'QT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Quản trị viên',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Quản trị hệ thống',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SoftDivider extends StatelessWidget {
  const _SoftDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 26),
      child: Divider(height: 1, thickness: 1, color: AppTheme.border),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final int badgeCount;
  final Color? color;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
    this.badgeCount = 0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg =
        color ?? (selected ? AppTheme.primaryDark : AppTheme.textPrimary);
    final FontWeight weight = (selected || color != null)
        ? FontWeight.w800
        : FontWeight.w500;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: selected ? AppTheme.primaryLight : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(icon, size: 22, color: fg),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: weight,
                      color: fg,
                    ),
                  ),
                ),
                if (badgeCount > 0)
                  Container(
                    constraints: const BoxConstraints(minWidth: 28),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
