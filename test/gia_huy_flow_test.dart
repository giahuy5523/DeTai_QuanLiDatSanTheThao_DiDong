import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sportfield_booking/data/mock_store.dart';
import 'package:sportfield_booking/screens/owner/upload_venue_screen.dart';
import 'package:sportfield_booking/screens/customer/home_screen.dart';
import 'package:sportfield_booking/screens/customer/venue_list_screen.dart';
import 'package:sportfield_booking/screens/customer/venue_detail_screen.dart';
import 'package:sportfield_booking/screens/admin/statistics_screen.dart';
import 'package:sportfield_booking/screens/owner/manage_venue_screen.dart';
import 'package:sportfield_booking/utils/app_routes.dart';
import 'package:sportfield_booking/utils/app_theme.dart';
import 'widget_test.dart' show start, press;
import 'test_helpers.dart';

class FakePicker extends ImagePicker {
  List<XFile> files = [];
  bool fail = false;
  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    if (fail) throw Exception('Permission denied');
    return files;
  }
}

XFile photo(int index) => XFile.fromData(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
  ),
  name: 'photo$index.png',
  path: 'photo$index.png',
);

Future<void> login(WidgetTester tester, String role) async {
  await start(tester);
  await tester.enterText(find.byType(TextFormField).first, '$role@gmail.com');
  await press(tester, 'Đăng nhập');
}

Future<void> openUpload(WidgetTester tester, FakePicker picker) async {
  MockStore.login('owner@gmail.com', '123456');
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UploadVenueScreen(picker: picker),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  final fields = find.byType(TextFormField);
  for (final (index, value) in [
    'Sân Gia Huy',
    '123 TP.HCM',
    '200000',
  ].indexed) {
    await tester.enterText(fields.at(index), value);
  }
}

Future<void> pick(WidgetTester tester) async {
  final button = find.text('Chọn ảnh từ máy');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  final originalVenues = List.of(MockStore.venues);
  final originalBookings = List.of(MockStore.bookings);
  final originalPayments = List.of(MockStore.payments);
  setUp(() {
    MockStore.logout();
  });
  tearDown(() {
    MockStore.logout();
    MockStore.venues
      ..clear()
      ..addAll(originalVenues);
    MockStore.bookings
      ..clear()
      ..addAll(originalBookings);
    MockStore.payments
      ..clear()
      ..addAll(originalPayments);
  });

  testWidgets(
    'Home opens list, filters approved venues, and passes venue to detail',
    (tester) async {
      await login(tester, 'customer');
      final listButton = find.text('Xem tất cả sân');
      await tester.ensureVisible(listButton);
      await tester.tap(listButton);
      await tester.pumpAndSettle();
      expect(find.byType(VenueListScreen), findsOneWidget);
      expect(find.text(MockStore.venueById('v8')!.name), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Cầu lông'));
      await tester.pumpAndSettle();
      expect(find.text('Sân bóng đá Thành Công'), findsNothing);
      await tester.tap(find.text('Sân cầu lông Phú Nhuận'));
      await tester.pumpAndSettle();
      expect(find.byType(VenueDetailScreen), findsOneWidget);
      expect(find.text('Sân cầu lông Phú Nhuận'), findsOneWidget);
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      expect(find.byType(VenueListScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Home and list handle no approved venues', (tester) async {
    MockStore.venues.clear();
    await login(tester, 'customer');
    expect(find.text('Hiện chưa có sân nào được duyệt.'), findsOneWidget);
    await tester.tap(find.text('Xem tất cả sân'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có sân phù hợp.'), findsOneWidget);
  });

  testWidgets(
    'Owner upload refreshes own list and service route uses selected venue',
    (tester) async {
      MockStore.login('owner@gmail.com', '123456');
      final picker = FakePicker()..files = [photo(1), photo(2), photo(3)];
      final routes = AppRoutes.routes;
      routes[AppRoutes.uploadVenue] = (_) => UploadVenueScreen(picker: picker);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          initialRoute: AppRoutes.manageVenue,
          routes: routes,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đăng ký sân'));
      await tester.pumpAndSettle();
      for (final (index, value) in [
        'Sân mới Huy',
        'TP.HCM',
        '150000',
      ].indexed) {
        await tester.enterText(find.byType(TextFormField).at(index), value);
      }
      await pick(tester);
      await press(tester, 'Gửi duyệt');
      expect(find.byType(ManageVenueScreen), findsOneWidget);
      final newVenue = find.text('Sân mới Huy');
      await tester.scrollUntilVisible(newVenue, 150);
      await tester.pumpAndSettle();
      expect(newVenue, findsOneWidget);
      final card = find.ancestor(of: newVenue, matching: find.byType(Card));
      final services = find.descendant(
        of: card,
        matching: find.text('Quản lý dịch vụ kèm theo'),
      );
      await tester.ensureVisible(services);
      await tester.pumpAndSettle();
      await tester.tap(services);
      await tester.pumpAndSettle();
      expect(find.text('Chưa có dịch vụ.'), findsOneWidget);
      expect(find.text('Nước suối'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Home list and upload fit a 360 pixel mobile screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await login(tester, 'customer');
    await tester.ensureVisible(find.text('Xem tất cả sân'));
    await tester.tap(find.text('Xem tất cả sân'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await openUpload(
      tester,
      FakePicker()..files = [photo(1), photo(2), photo(3)],
    );
    await pick(tester);
    await press(tester, 'Gửi duyệt');
    expect(tester.takeException(), isNull);
  }, tags: ['viewport']);

  testWidgets('Upload rejects empty fields and unreadable image', (
    tester,
  ) async {
    final picker = FakePicker()
      ..files = [
        XFile.fromData(base64Decode('YWJj'), name: 'bad.png', path: 'bad.png'),
      ];
    await openUpload(tester, picker);
    await tester.enterText(find.byType(TextFormField).first, '   ');
    await press(tester, 'Gửi duyệt');
    expect(find.text('Không được để trống'), findsOneWidget);
    await pick(tester);
    expect(find.text('Ảnh sân: 0 / tối thiểu 3'), findsOneWidget);
    expect(
      find.text(
        'Không thể chọn ảnh. Vui lòng kiểm tra quyền truy cập và thử lại.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Upload previews 3 photos, adds pending venue and returns', (
    tester,
  ) async {
    final picker = FakePicker()..files = [photo(1), photo(2), photo(3)];
    await openUpload(tester, picker);
    await pick(tester);
    expect(find.byType(Image), findsNWidgets(3));
    await press(tester, 'Gửi duyệt');
    expect(find.byType(UploadVenueScreen), findsNothing);
    final venue = MockStore.venues.last;
    expect(venue.name, 'Sân Gia Huy');
    expect(venue.ownerId, 'owner1');
    expect(venue.status, 'pending');
    expect(venue.imageUrls.length, 3);
    expect(venue.pricePerHour, 200000);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Duplicate photos and fewer than 3 photos are rejected; remove works',
    (tester) async {
      final picker = FakePicker()..files = [photo(1), photo(1), photo(2)];
      await openUpload(tester, picker);
      await pick(tester);
      await pick(tester);
      expect(find.text('Ảnh sân: 2 / tối thiểu 3'), findsOneWidget);
      await press(tester, 'Gửi duyệt');
      expect(
        find.text('Vui lòng chọn tối thiểu 3 ảnh khác nhau.'),
        findsOneWidget,
      );
      final remove = find.byTooltip('Xóa ảnh 1');
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(find.text('Ảnh sân: 1 / tối thiểu 3'), findsOneWidget);
      expect(MockStore.venues.length, originalVenues.length);
    },
  );

  testWidgets('Picker cancellation and failure leave form usable', (
    tester,
  ) async {
    final picker = FakePicker();
    await openUpload(tester, picker);
    await pick(tester);
    expect(find.text('Ảnh sân: 0 / tối thiểu 3'), findsOneWidget);
    picker.fail = true;
    await pick(tester);
    expect(
      find.text(
        'Không thể chọn ảnh. Vui lòng kiểm tra quyền truy cập và thử lại.',
      ),
      findsOneWidget,
    );
    picker.fail = false;
    picker.files = [photo(1), photo(2), photo(3)];
    await pick(tester);
    expect(find.text('Ảnh sân: 3 / tối thiểu 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final price in ['abc', '-1', '0', 'NaN', 'Infinity']) {
    testWidgets('Upload rejects price $price', (tester) async {
      await openUpload(tester, FakePicker());
      await tester.enterText(find.byType(TextFormField).last, price);
      await press(tester, 'Gửi duyệt');
      expect(find.text('Nhập giá lớn hơn 0'), findsOneWidget);
      expect(MockStore.venues.length, originalVenues.length);
    });
  }

  testWidgets(
    'Customer cannot open owner route and invalid detail args do not crash',
    (tester) async {
      await login(tester, 'customer');
      final context = tester.element(find.byType(HomeScreen));
      Navigator.of(context).pushNamed(AppRoutes.uploadVenue);
      await tester.pumpAndSettle();
      expect(
        find.text('Bạn không có quyền truy cập màn hình này.'),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      Navigator.of(
        tester.element(find.byType(HomeScreen)),
      ).pushNamed(AppRoutes.venueDetail);
      await tester.pumpAndSettle();
      expect(find.text('Thông tin sân không hợp lệ.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Customer navigates detail to booking to payment to history and cancels',
    (tester) async {
      await login(tester, 'customer');
      final card = find.text('Sân bóng đá Thành Công');
      await tester.scrollUntilVisible(
        card,
        200,
        scrollable: find
            .descendant(
              of: find.byType(HomeScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(card);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Đặt sân ngay'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đặt sân ngay'));
      await tester.pumpAndSettle();
      await chooseFutureDate(tester);
      await tapVisible(tester, find.byKey(const ValueKey('start_18:00')));
      await tapVisible(tester, find.byKey(const ValueKey('end_19:00')));
      await press(tester, 'Tiếp tục');
await press(tester, 'Chọn phương thức thanh toán');

await tapVisible(tester, find.text('Ví MoMo'));
await tester.pumpAndSettle();

await tapVisible(tester, find.text('Tôi xác nhận thông tin đặt sân là chính xác'));
await tester.pumpAndSettle();

await press(tester, 'Xác nhận thanh toán');
expect(find.text('Thanh toán thành công'), findsOneWidget);
      expect(MockStore.bookings.length, originalBookings.length + 1);
      expect(MockStore.payments.last['method'], 'momo');
      await tester.tap(find.text('Về trang chủ'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      await tester.tap(find.text('Lịch sử'));
      await tester.pumpAndSettle();
      final cancel = find.byKey(
        ValueKey('cancel_${MockStore.bookings.last.id}'),
      );
      await tester.scrollUntilVisible(cancel, 150);
      await tester.pumpAndSettle();
      await tester.ensureVisible(cancel);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(MockStore.bookings.last.status, 'cancelled');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Admin can open approve and promotions then return to statistics',
    (tester) async {
      await login(tester, 'admin');
      for (final label in ['Duyệt sân', 'Quản lý khuyến mãi']) {
        await tester.tap(find.byTooltip('Open navigation menu'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(StatisticsScreen), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );
}
