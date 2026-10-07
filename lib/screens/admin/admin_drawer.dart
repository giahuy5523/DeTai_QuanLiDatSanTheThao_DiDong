import 'package:flutter/material.dart';

import '../../data/mock_store.dart';
import '../../utils/app_routes.dart';

class AdminDrawer extends StatelessWidget {
  final int selectedIndex;
  final VoidCallback? onReturn;

  const AdminDrawer({super.key, required this.selectedIndex, this.onReturn});

  Future<void> _goTo(BuildContext context, String route) async {
    Navigator.pop(context);
    if (ModalRoute.of(context)?.settings.name == route) return;
    await Navigator.pushNamed(context, route);
    onReturn?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            child: Text(
              'Quản trị viên',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_outlined),
            title: const Text('Tổng quan'),
            selected: selectedIndex == 0,
            onTap: () => _goTo(context, AppRoutes.statistics),
          ),
          ListTile(
            leading: const Icon(Icons.approval),
            title: const Text('Duyệt sân'),
            selected: selectedIndex == 1,
            onTap: () => _goTo(context, AppRoutes.approveVenue),
          ),
          ListTile(
            leading: const Icon(Icons.discount_outlined),
            title: const Text('Quản lý khuyến mãi'),
            selected: selectedIndex == 2,
            onTap: () => _goTo(context, AppRoutes.managePromotion),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Đăng xuất'),
            onTap: () {
              MockStore.logout();

              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
