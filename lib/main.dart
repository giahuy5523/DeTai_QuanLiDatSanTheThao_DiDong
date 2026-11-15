import 'dart:async';

import 'package:flutter/material.dart';
import 'utils/app_routes.dart';
import 'data/account_service.dart';
import 'data/mock_store.dart';
import 'utils/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _AccountBootstrap());
}

class _AccountBootstrap extends StatefulWidget {
  const _AccountBootstrap();
  @override
  State<_AccountBootstrap> createState() => _AccountBootstrapState();
}

class _AccountBootstrapState extends State<_AccountBootstrap> {
  late Future<void> _ready = AccountService.initialize();
  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _ready,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError) {
        return const SportFieldBookingApp(restoreSession: true);
      }
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!snapshot.hasError) const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    snapshot.hasError
                        ? 'Không thể mở dữ liệu tài khoản. Hãy thử lại.'
                        : 'Đang chuẩn bị dữ liệu tài khoản…',
                  ),
                  if (snapshot.hasError)
                    FilledButton(
                      onPressed: () =>
                          setState(() => _ready = AccountService.initialize()),
                      child: const Text('Thử lại'),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class SportFieldBookingApp extends StatefulWidget {
  const SportFieldBookingApp({super.key, this.restoreSession = false});
  final bool restoreSession;

  @override
  State<SportFieldBookingApp> createState() => _SportFieldBookingAppState();
}

class _SportFieldBookingAppState extends State<SportFieldBookingApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final AppLifecycleListener _lifecycle;
  Timer? _sessionTimer;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _checkSession);
    AccountService.sessionRevision.addListener(_scheduleSessionCheck);
    _scheduleSessionCheck();
  }

  void _scheduleSessionCheck() {
    _sessionTimer?.cancel();
    if (MockStore.currentUser == null) return;
    final remaining = AccountService.repository?.sessionTimeRemaining;
    if (remaining != null) _sessionTimer = Timer(remaining, _checkSession);
  }

  void _checkSession() {
    if (AccountService.expireSessionIfNeeded()) {
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.login,
        (_) => false,
      );
    } else {
      _scheduleSessionCheck();
    }
  }

  @override
  void dispose() {
    AccountService.sessionRevision.removeListener(_scheduleSessionCheck);
    _sessionTimer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nhom1_DatSanTheThao',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: _navigatorKey,
      initialRoute: widget.restoreSession && MockStore.currentUser != null
          ? switch (MockStore.currentUser!.role) {
              'owner' => AppRoutes.manageVenue,
              'admin' => AppRoutes.statistics,
              _ => AppRoutes.customerShell,
            }
          : AppRoutes.login,
      routes: AppRoutes.routes,
    );
  }
}
