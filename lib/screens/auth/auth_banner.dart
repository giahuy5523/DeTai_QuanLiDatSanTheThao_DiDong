import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reads the bundled directory, so adding photos only requires a new build.
class AuthBanner extends StatefulWidget {
  const AuthBanner({super.key, required this.register});
  final bool register;

  @override
  State<AuthBanner> createState() => _AuthBannerState();
}

class _AuthBannerState extends State<AuthBanner> with WidgetsBindingObserver {
  List<String> _images = [];
  PageController? _controller;
  Timer? _timer;
  int _page = 0;
  bool _visible = true;
  bool _resumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadImages();
  }

  Future<void> _loadImages() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final images = manifest.listAssets().where((path) {
        final lower = path.toLowerCase();
        return path.startsWith('assets/images/auth_banners/') &&
            ['.jpg', '.jpeg', '.png', '.webp'].any(lower.endsWith);
      }).toList()..sort();
      if (!mounted || images.isEmpty) return;
      // Start well inside the repeating sequence to allow swipes both ways.
      _page = images.length * 1000;
      setState(() {
        _images = images;
        _controller = PageController(initialPage: _page);
      });
      _restartTimer();
    } catch (error) {
      // A missing/unreadable asset bundle must not block the login form.
      debugPrint('Could not load auth banners: $error');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    _restartTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (!_visible || !_resumed || _images.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      final controller = _controller;
      if (!mounted ||
          controller == null ||
          !controller.hasClients ||
          controller.position.isScrollingNotifier.value) {
        return;
      }
      controller.animateToPage(
        _page + 1,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Widget _fallback() => const ColoredBox(color: Color(0xFFDFF1E8));

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 208,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: -22,
          child: _images.isEmpty
              ? _fallback()
              : NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollStartNotification) {
                      _timer?.cancel();
                    }
                    if (notification is ScrollEndNotification) _restartTimer();
                    return false;
                  },
                  child: PageView.builder(
                    controller: _controller,
                    onPageChanged: (page) => setState(() => _page = page),
                    itemBuilder: (context, index) => Image.asset(
                      _images[index % _images.length],
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                      errorBuilder: (_, _, _) => _fallback(),
                    ),
                  ),
                ),
        ),
        // Keep the image swipeable through the gradient and captions.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: -22,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x400B211A),
                    Color(0x200B211A),
                    Color(0xE60B211A),
                  ],
                  stops: [0, 0.35, 1],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 43,
          child: IgnorePointer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.register ? 'Tạo tài khoản' : 'Đăng nhập',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  widget.register
                      ? 'Tham gia cộng đồng thể thao.'
                      : 'Sân yêu thích, sẵn sàng đặt.',
                  style: const TextStyle(
                    color: Color(0xFFE5EEE9),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 14,
          top: 14,
          child: IconButton(
            tooltip: 'Quay lại',
            onPressed: () => Navigator.maybePop(context),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0x660B211A),
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 21),
          ),
        ),
        if (_images.length > 1)
          Positioned(
            right: 24,
            bottom: 16,
            child: IgnorePointer(
              child: Semantics(
                label:
                    'Ảnh sân ${_page % _images.length + 1} trên ${_images.length}',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    _images.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: index == _page % _images.length ? 18 : 5,
                      height: 5,
                      margin: const EdgeInsets.only(left: 5),
                      decoration: BoxDecoration(
                        color: index == _page % _images.length
                            ? Colors.white
                            : const Color(0x66FFFFFF),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
