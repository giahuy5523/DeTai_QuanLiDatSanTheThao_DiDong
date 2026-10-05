import 'package:flutter/material.dart';
import '../../utils/app_routes.dart';

class AdminShellLayout extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? floatingActionButton;

  const AdminShellLayout({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: floatingActionButton,
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              child: Text(
                'Quản trị viên',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Thống kê'),
              onTap: () {
                Navigator.pop(context); // Đóng drawer
                Navigator.pushReplacementNamed(context, AppRoutes.statistics);
              },
            ),
            ListTile(
              leading: const Icon(Icons.approval),
              title: const Text('Duyệt sân'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, AppRoutes.approveVenue);
              },
            ),
            ListTile(
              leading: const Icon(Icons.discount_outlined),
              title: const Text('Quản lý khuyến mãi'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, AppRoutes.managePromotion);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Đăng xuất'),
              onTap: () => Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                (route) => false,
              ),
            ),
          ],
        ),
      ),
      body: body,
    );
  }
}