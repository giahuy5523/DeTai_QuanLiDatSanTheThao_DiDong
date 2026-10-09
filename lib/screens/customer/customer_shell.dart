import 'package:flutter/material.dart';
import '../../utils/app_routes.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'customer_promotion_screen.dart';
import 'booking_history_screen.dart';
import 'profile_screen.dart';

/// Shell chứa BottomNavigationBar cho tất cả màn hình chính của Khách hàng.
/// Sử dụng IndexedStack để giữ trạng thái từng tab.
class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  late int _currentIndex;

  int _historyRefreshKey = 0;

  List<Widget> get _pages => [
    const HomeScreen(),
    const SearchScreen(),
    const CustomerPromotionScreen(),
    BookingHistoryScreen(key: ValueKey(_historyRefreshKey)),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    if (_currentIndex < 0 || _currentIndex >= _pages.length) {
      return const Scaffold(body: Center(child: Text('Tab không hợp lệ.')));
    }

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
              if (index == 3) {
                _historyRefreshKey++;
              }
            });
          },
          elevation: 0,
          backgroundColor: Colors.transparent,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Trang chủ',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined),
              activeIcon: Icon(Icons.search),
              label: 'Tìm kiếm',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_offer_outlined),
              activeIcon: Icon(Icons.local_offer),
              label: 'Ưu đãi',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'Lịch sử',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Tài khoản',
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper: điều hướng tới CustomerShell với tab cụ thể.
void navigateToCustomerTab(BuildContext context, int tabIndex) {
  Navigator.pushNamedAndRemoveUntil(
    context,
    AppRoutes.customerShell,
    (route) => false,
    arguments: tabIndex,
  );
}
