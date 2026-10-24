import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sportfield_booking/data/avatar_storage.dart';
import 'package:sportfield_booking/data/mock_store.dart';
import 'package:sportfield_booking/screens/customer/profile_screen.dart';
import 'package:sportfield_booking/screens/auth/login_screen.dart';
import 'package:sportfield_booking/utils/app_routes.dart';
import 'package:sportfield_booking/utils/app_theme.dart';

class ProfilePicker extends ImagePicker {
  XFile? result;
  bool fail = false;
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    if (fail) throw Exception('Permission denied');
    return result;
  }
}

class ProfileStorage extends AvatarStorage {
  Uint8List? saved;
  bool fail = false;
  final removed = <String?>[];
  @override
  Future<String> save(Uint8List png) async {
    if (fail) throw const FileSystemException('Disk full');
    saved = png;
    return '/missing/avatar.png';
  }

  @override
  Future<void> remove(String? path) async {
    removed.add(path);
  }
}

Future<void> open(
  WidgetTester tester, {
  ProfilePicker? picker,
  ProfileStorage? storage,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      routes: {AppRoutes.login: (_) => const LoginScreen()},
      home: ProfileScreen(picker: picker, avatarStorage: storage),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> pick(WidgetTester tester) async {
  await tap(tester, find.bySemanticsLabel('Đổi ảnh đại diện'));
  // Image decoding completes through the engine rather than the fake clock.
  await tester.tap(find.text('Chọn ảnh từ thư viện'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  final save = find.widgetWithText(ElevatedButton, 'Lưu thay đổi');
  for (
    var attempt = 0;
    attempt < 100 && tester.widget<ElevatedButton>(save).onPressed == null;
    attempt++
  ) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
  }
  expect(
    tester.widget<ElevatedButton>(save).onPressed,
    isNotNull,
    reason: 'Image decoding must finish before interacting with the form.',
  );
  await tester.pumpAndSettle();
}

void main() {
  final users = List.of(MockStore.users);
  setUp(() {
    MockStore.users
      ..clear()
      ..addAll(users);
    MockStore.login('customer@gmail.com', '123456');
  });
  tearDown(() {
    MockStore.users
      ..clear()
      ..addAll(users);
    MockStore.logout();
  });

  testWidgets(
    'Profile saves trimmed name and phone while preserving identity and login',
    (tester) async {
      final before = MockStore.currentUser!;
      await open(tester);
      expect(tester.widget<AppBar>(find.byType(AppBar)).centerTitle, isTrue);
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).readOnly,
        isTrue,
      );
      await tester.enterText(find.byType(TextFormField).first, ' Gia Huy ');
      await tester.enterText(find.byType(TextFormField).last, ' 0912345678 ');
      await tap(tester, find.widgetWithText(ElevatedButton, 'Lưu thay đổi'));
      final updated = MockStore.currentUser!;
      expect(updated.name, 'Gia Huy');
      expect(updated.phone, '0912345678');
      expect(updated.id, before.id);
      expect(updated.email, before.email);
      expect(updated.role, before.role);
      expect(updated.password, before.password);
      MockStore.logout();
      expect(MockStore.login(before.email, before.password)?.name, 'Gia Huy');
    },
  );

  testWidgets('Profile rejects blank name and invalid phone on small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final before = MockStore.currentUser;
    await open(tester);
    await tester.enterText(find.byType(TextFormField).first, ' ');
    await tester.enterText(find.byType(TextFormField).last, 'abc');
    await tap(tester, find.widgetWithText(ElevatedButton, 'Lưu thay đổi'));
    expect(find.text('Họ và tên không được để trống'), findsOneWidget);
    expect(MockStore.currentUser, same(before));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Avatar preview is committed only on save and can be removed', (
    tester,
  ) async {
    final picker = ProfilePicker()
      ..result = XFile.fromData(
        File('assets/images/auth_banners/san_bong_1.jpg').readAsBytesSync(),
        name: 'avatar.jpg',
      );
    final storage = ProfileStorage();
    await open(tester, picker: picker, storage: storage);
    await pick(tester);
    expect(MockStore.currentUser!.avatarPath, isNull);
    expect(find.byType(Image), findsOneWidget);
    await tap(tester, find.widgetWithText(ElevatedButton, 'Lưu thay đổi'));
    expect(storage.saved, isNotNull);
    expect(MockStore.currentUser!.avatarPath, '/missing/avatar.png');
    await tap(tester, find.bySemanticsLabel('Đổi ảnh đại diện'));
    await tap(tester, find.text('Xóa ảnh đại diện'));
    expect(MockStore.currentUser!.avatarPath, isNotNull);
    await tap(tester, find.widgetWithText(ElevatedButton, 'Lưu thay đổi'));
    expect(MockStore.currentUser!.avatarPath, isNull);
    expect(storage.removed, contains('/missing/avatar.png'));
  });

  testWidgets('Cancelled, denied and invalid picks do not change the profile', (
    tester,
  ) async {
    final picker = ProfilePicker();
    final before = MockStore.currentUser;
    await open(tester, picker: picker);
    await pick(tester);
    expect(MockStore.currentUser, same(before));
    picker.fail = true;
    await pick(tester);
    expect(
      find.text(
        'Không thể đọc ảnh. Hãy chọn ảnh khác hoặc kiểm tra quyền truy cập.',
      ),
      findsOneWidget,
    );
    picker.fail = false;
    picker.result = XFile.fromData(
      Uint8List.fromList([1, 2, 3]),
      name: 'bad.jpg',
    );
    await pick(tester);
    expect(MockStore.currentUser, same(before));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Failed file save leaves profile unchanged', (tester) async {
    final before = MockStore.currentUser;
    final picker = ProfilePicker()
      ..result = XFile.fromData(
        File('assets/images/auth_banners/san_bong_1.jpg').readAsBytesSync(),
        name: 'avatar.jpg',
      );
    await open(tester, picker: picker, storage: ProfileStorage()..fail = true);
    await pick(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Tên chưa lưu');
    await tap(tester, find.widgetWithText(ElevatedButton, 'Lưu thay đổi'));
    expect(MockStore.currentUser, same(before));
    expect(
      find.text('Không thể lưu ảnh đại diện. Vui lòng thử lại.'),
      findsOneWidget,
    );
  });

  testWidgets('Logout supports cancel and confirmed clearing of navigator', (
    tester,
  ) async {
    await open(tester);
    await tap(tester, find.widgetWithText(OutlinedButton, 'Đăng xuất'));
    await tap(tester, find.text('Ở lại'));
    expect(MockStore.currentUser, isNotNull);
    await tap(tester, find.widgetWithText(OutlinedButton, 'Đăng xuất'));
    await tap(tester, find.widgetWithText(FilledButton, 'Đăng xuất'));
    expect(MockStore.currentUser, isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(ProfileScreen), findsNothing);
  });

  test(
    'Avatar storage writes an owned PNG and refuses to delete source images',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sport_profile_test_',
      );
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => directory.path);
      try {
        final storage = AvatarStorage();
        final bytes = Uint8List.fromList([137, 80, 78, 71]);
        final path = await storage.save(bytes);
        expect(await File(path).readAsBytes(), bytes);
        final source = await File(
          '${directory.path}${Platform.pathSeparator}source.jpg',
        ).writeAsBytes([1]);
        await storage.remove(source.path);
        expect(await source.exists(), isTrue);
        await storage.remove(path);
        expect(await File(path).exists(), isFalse);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        await directory.delete(recursive: true);
      }
    },
  );
}
