import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sportfield_booking/data/mock_store.dart';
import 'package:sportfield_booking/models/booking.dart';
import 'package:sportfield_booking/models/promotion.dart';
import 'package:sportfield_booking/utils/app_routes.dart';
import 'package:sportfield_booking/utils/app_theme.dart';
import 'package:sportfield_booking/screens/customer/home_screen.dart';
import 'test_helpers.dart';
import 'widget_test.dart' show press;
import 'package:sportfield_booking/screens/customer/payment_screen.dart';

Future<void> openRoute(
  WidgetTester tester,
  String route, {
  Object? args,
  String role = 'customer',
}) async {
  MockStore.login('$role@gmail.com', '123456');
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      routes: AppRoutes.routes,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.pushNamed(context, route, arguments: args),
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  final venues = List.of(MockStore.venues);
  final bookings = List.of(MockStore.bookings);
  final payments = List.of(MockStore.payments);
  final promotions = List.of(MockStore.promotions);
  final services = {
    for (final entry in MockStore.servicesByVenue.entries)
      entry.key: List.of(entry.value),
  };
  final future = DateTime.now().add(const Duration(days: 7));
  final venue = venues.first;
  tearDown(() {
    MockStore.venues
      ..clear()
      ..addAll(venues);
    MockStore.bookings
      ..clear()
      ..addAll(bookings);
    MockStore.payments
      ..clear()
      ..addAll(payments);
    MockStore.promotions
      ..clear()
      ..addAll(promotions);
    MockStore.servicesByVenue
      ..clear()
      ..addAll({
        for (final entry in services.entries) entry.key: List.of(entry.value),
      });
    MockStore.logout();
  });

  test('Approval and editing preserve district, city, sport ID and photos', () {
    final pending = venues.firstWhere((v) => v.status == 'pending');
    final edited = pending.copyWith(status: 'approved', name: 'Sân đổi tên');
    expect(edited.sportTypeId, pending.sportTypeId);
    expect(edited.district, pending.district);
    expect(edited.city, pending.city);
    expect(edited.imageUrls, pending.imageUrls);
    expect(MockStore.updateVenue(edited), isTrue);
    expect(MockStore.approvedVenues, contains(edited));
  });

  test(
    'Booking rejects past time, invalid hours and overlapping intervals',
    () {
      expect(
        MockStore.isRangeAvailable(
          venue.id,
          DateTime.now().subtract(const Duration(days: 1)),
          '18:00',
          '19:00',
        ),
        isFalse,
      );
      for (final (start, end) in [
        ('05:00', '06:00'),
        ('21:00', '23:00'),
        ('19:00', '18:00'),
        ('aa', '19:00'),
      ]) {
        expect(
          MockStore.isRangeAvailable(venue.id, future, start, end),
          isFalse,
        );
      }
      final existing = Booking(
        id: 'overlap',
        venueId: venue.id,
        userId: 'customer1',
        date: future,
        startTime: '18:00',
        endTime: '20:00',
        totalPrice: 100000,
        paymentId: 'test-pay',
        status: 'confirmed',
      );
      MockStore.bookings.add(existing);
      expect(
        MockStore.isRangeAvailable(venue.id, future, '17:00', '19:00'),
        isFalse,
      );
      expect(
        MockStore.isRangeAvailable(venue.id, future, '19:00', '21:00'),
        isFalse,
      );
      expect(
        MockStore.isRangeAvailable(venue.id, future, '20:00', '22:00'),
        isTrue,
      );
      MockStore.bookings.remove(existing);
      MockStore.bookings.add(
        Booking(
          id: existing.id,
          venueId: existing.venueId,
          userId: existing.userId,
          date: existing.date,
          startTime: existing.startTime,
          endTime: existing.endTime,
          totalPrice: existing.totalPrice,
          paymentId: existing.paymentId,
          status: 'cancelled',
        ),
      );
      expect(
        MockStore.isRangeAvailable(venue.id, future, '18:00', '20:00'),
        isTrue,
      );
    },
  );

  test(
    'Promotion is valid through expiry day and rejects non-finite discount',
    () {
      final expiry = DateTime(2026, 10, 7);
      final p = Promotion(
        id: 'today',
        code: 'TODAY',
        discountPercent: 10,
        expiryDate: expiry,
      );
      expect(p.isValidAt(DateTime(2026, 10, 7, 23, 59)), isTrue);
      expect(p.isValidAt(DateTime(2026, 10, 8)), isFalse);
      expect(
        Promotion(
          id: 'bad',
          code: 'BAD',
          discountPercent: double.nan,
          expiryDate: future,
        ).isValidAt(DateTime.now()),
        isFalse,
      );
    },
  );

  testWidgets(
    'Editing promo clears applied discount and invalid code is not stored',
    (tester) async {
      await openRoute(tester, AppRoutes.booking, args: venue);
      await chooseFutureDate(tester);
      await tapVisible(tester, find.byKey(const ValueKey('start_18:00')));
      await tapVisible(tester, find.byKey(const ValueKey('end_20:00')));
      final serviceName = MockStore.servicesFor(venue.id).first.name;
      final serviceText = find.text(serviceName);
      expect(serviceText, findsOneWidget);

      final serviceContainer = find
          .ancestor(of: serviceText, matching: find.byType(Container))
          .first;

      final addButton = find.descendant(
        of: serviceContainer,
        matching: find.byIcon(Icons.add_circle_outline),
      );

      expect(addButton, findsOneWidget);
      final addBox = tester.renderObject<RenderBox>(addButton);
      debugPrint(
        'ADD BUTTON: size=${addBox.size} '
        'offset=${addBox.localToGlobal(Offset.zero)}',
      );

      await tester.ensureVisible(addButton);
      await tester.tap(addButton);
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      await tester.ensureVisible(field);
      await tester.enterText(field, 'SAN10');
      await tapVisible(tester, find.text('Áp dụng'));
      expect(find.text('Đã áp dụng giảm 10%.'), findsOneWidget);
      await tester.enterText(field, 'INVALID');
      await tapVisible(tester, find.text('Áp dụng'));
      expect(find.text('Mã không hợp lệ hoặc đã hết hạn.'), findsOneWidget);
      await press(tester, 'Tiếp tục');
      await press(tester, 'Chọn phương thức thanh toán');

await tester.scrollUntilVisible(
  find.byType(CheckboxListTile),
  200,
  scrollable: find.byType(Scrollable).last,
);
await tester.pumpAndSettle();

await tapVisible(tester, find.byType(CheckboxListTile));
      await press(tester, 'Xác nhận thanh toán');
      expect(MockStore.bookings.last.promotionCode, isNull);
      expect(
        MockStore.bookings.last.totalPrice,
        venue.pricePerHour * 2 + MockStore.servicesFor(venue.id).first.price,
      );
      expect(
        MockStore.payments.last['amount'],
        MockStore.bookings.last.totalPrice,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Valid promo discounts court and services through confirmation', (
    tester,
  ) async {
    await openRoute(tester, AppRoutes.booking, args: venue);
    await chooseFutureDate(tester);
    await tapVisible(tester, find.byKey(const ValueKey('start_21:00')));
    await tapVisible(tester, find.byKey(const ValueKey('end_22:00')));
    await tapVisible(tester, find.byIcon(Icons.add_circle_outline).first);
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'san10');
    await tapVisible(tester, find.text('Áp dụng'));
    await press(tester, 'Tiếp tục');
    await press(tester, 'Chọn phương thức thanh toán');
    expect(find.text('Thông tin đơn đặt sân không hợp lệ.'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('VNPay'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tapVisible(tester, find.text('VNPay'));
    await tester.pumpAndSettle();

    final agreement = find.text('Tôi xác nhận thông tin đặt sân là chính xác');

    await tester.ensureVisible(agreement);
    await tester.pumpAndSettle();

    await tester.tap(agreement);
    await tester.pumpAndSettle();

    await press(tester, 'Xác nhận thanh toán');
    debugPrint(
      'BOOKINGS AFTER PAYMENT: ${MockStore.bookings.map((b) => '${b.id}:${b.startTime}-${b.endTime}:${b.promotionCode}').toList()}',
    );
    expect(MockStore.bookings.last.endTime, '22:00');
    expect(MockStore.bookings.last.promotionCode, 'SAN10');
    expect(
      MockStore.bookings.last.totalPrice,
      (venue.pricePerHour + MockStore.servicesFor(venue.id).first.price) * .9,
    );
    expect(MockStore.payments.last['method'], 'vnpay');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Payment rechecks changed availability and does not add a duplicate',
    (tester) async {
      await openRoute(
        tester,
        AppRoutes.payment,
        args: {
          'venue': venue,
          'date': future,
          'startTime': '18:00',
          'endTime': '20:00',
          'total': 100000,
        },
      );
      expect(tester.takeException(), isNull);

      MockStore.bookings.add(
        Booking(
          id: 'other',
          venueId: venue.id,
          userId: 'customer2',
          date: future,
          startTime: '19:00',
          endTime: '20:00',
          totalPrice: 100000,
          paymentId: 'other-pay',
          status: 'confirmed',
        ),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      await tester.tap(
        find.text('Tôi xác nhận thông tin đặt sân là chính xác'),
      );
      await tester.pumpAndSettle();

      await press(tester, 'Xác nhận thanh toán');
      expect(find.text('Khung giờ không còn trống'), findsOneWidget);
      expect(MockStore.bookings.length, bookings.length + 1);
      expect(MockStore.payments.length, payments.length);
      expect(find.text('Đặt sân thành công'), findsNothing);
    },
  );

  for (final (route, args, message) in [
    (AppRoutes.customerShell, 10, 'Tab không hợp lệ.'),
    (
      AppRoutes.bookingConfirmation,
      <String, dynamic>{},
      'Thông tin thanh toán không hợp lệ.',
    ),
    (
      AppRoutes.payment,
      {'venue': venue, 'date': future, 'time': '18:00', 'total': double.nan},
      'Thông tin thanh toán không hợp lệ.',
    ),
  ]) {
    testWidgets('Invalid arguments for $route are rejected', (tester) async {
      await openRoute(tester, route, args: args);
      expect(find.text(message), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Admin rejects NaN and duplicate codes then creates edits deletes promo',
    (tester) async {
      await openRoute(tester, AppRoutes.managePromotion, role: 'admin');
      await tapVisible(tester, find.byTooltip('Thêm khuyến mãi mới'));
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'MERGE25');
      await tester.enterText(fields.at(1), 'NaN');
      await press(tester, 'Tạo khuyến mãi');
      expect(
        find.text('Mức giảm giá phải nằm trong khoảng từ 1% đến 100%.'),
        findsOneWidget,
      );
      await tester.enterText(fields.at(0), 'san10');
      await tester.enterText(fields.at(1), '25');
      await press(tester, 'Tạo khuyến mãi');
      expect(
        find.text('Mã "SAN10" đã tồn tại trong hệ thống.'),
        findsOneWidget,
      );
      await tester.enterText(fields.at(0), 'merge25');
      await press(tester, 'Tạo khuyến mãi');
      expect(MockStore.promotions.last.code, 'MERGE25');
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      final card = find.ancestor(
        of: find.text('MERGE25'),
        matching: find.byType(Card),
      );
      await tapVisible(
        tester,
        find.descendant(of: card, matching: find.text('Chỉnh sửa')),
      );
      await tester.enterText(find.byType(TextField).at(1), '30');
      await press(tester, 'Lưu thay đổi');
      expect(MockStore.promotions.last.discountPercent, 30);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tapVisible(
        tester,
        find.descendant(of: card, matching: find.byTooltip('Xóa mã')),
      );
      await press(tester, 'Xác nhận xóa');
      expect(MockStore.promotions.any((p) => p.code == 'MERGE25'), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Editing expired promo opens calendar without assertion', (
    tester,
  ) async {
    MockStore.promotions
      ..clear()
      ..add(
        Promotion(
          id: 'expired',
          code: 'OLD',
          discountPercent: 10,
          expiryDate: DateTime.now().subtract(const Duration(days: 30)),
        ),
      );
    await openRoute(tester, AppRoutes.managePromotion, role: 'admin');
    await tapVisible(tester, find.text('Chỉnh sửa'));
    await tapVisible(tester, find.byIcon(Icons.calendar_today_rounded));
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Owner rejects non-finite service price and can add edit delete service',
    (tester) async {
      MockStore.servicesByVenue[venue.id] = [];
      await openRoute(
        tester,
        AppRoutes.manageService,
        args: venue.id,
        role: 'owner',
      );
      await tapVisible(tester, find.text('Thêm dịch vụ'));
      await tester.enterText(find.byType(TextField).at(0), 'Thuê bóng');
      await tester.enterText(find.byType(TextField).at(1), 'Infinity');
      await press(tester, 'Thêm');
      expect(MockStore.servicesFor(venue.id), isEmpty);
      await tapVisible(tester, find.text('Thêm dịch vụ'));
      await tester.enterText(find.byType(TextField).at(0), 'Thuê bóng');
      await tester.enterText(find.byType(TextField).at(1), '20000');
      await press(tester, 'Thêm');
      expect(MockStore.servicesFor(venue.id).single.price, 20000);
      await tapVisible(tester, find.byTooltip('Sửa'));
      await tester.enterText(find.byType(TextField).at(1), '25000');
      await press(tester, 'Lưu');
      expect(MockStore.servicesFor(venue.id).single.price, 25000);
      await tapVisible(tester, find.byTooltip('Xóa'));
      expect(MockStore.servicesFor(venue.id), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Detail booking confirmation and payment fit 360 pixel screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await openRoute(tester, AppRoutes.venueDetail, args: venue);
      await tester.scrollUntilVisible(
        find.text('Khách hàng thân thiết'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      await tapVisible(tester, find.text('Đặt sân ngay'));
      await chooseFutureDate(tester);
      await tapVisible(tester, find.byKey(const ValueKey('start_18:00')));
      await tapVisible(tester, find.byKey(const ValueKey('end_19:00')));
      await press(tester, 'Tiếp tục');
      await press(tester, 'Chọn phương thức thanh toán');
      await tester.scrollUntilVisible(
  find.text('Tôi xác nhận thông tin đặt sân là chính xác'),
  200,
  scrollable: find.byType(Scrollable).last,
);
await tester.pumpAndSettle();

await tester.tap(
  find.text('Tôi xác nhận thông tin đặt sân là chính xác'),
);
await tester.pumpAndSettle();
      await press(tester, 'Xác nhận thanh toán');
      expect(find.text('Thanh toán thành công'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    tags: ['viewport'],
  );

  testWidgets('Home sport filter changes venues and All restores the list', (
    tester,
  ) async {
    await openRoute(tester, AppRoutes.customerShell);
    await tapVisible(
      tester,
      find
          .descendant(
            of: find.byType(HomeScreen),
            matching: find.text('Cầu lông'),
          )
          .first,
    );
    expect(find.text('Sân bóng đá Thành Công'), findsNothing);
    expect(find.text('Sân cầu lông Phú Nhuận'), findsOneWidget);
    await tapVisible(
      tester,
      find
          .descendant(
            of: find.byType(HomeScreen),
            matching: find.text('Tất cả'),
          )
          .first,
    );
    expect(find.text('Sân bóng đá Thành Công'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Main search still handles no result and sport filtering', (
    tester,
  ) async {
    await openRoute(tester, AppRoutes.search);
    final search = find.byType(TextField);
    await tester.enterText(search, 'not-an-existing-venue');
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy sân phù hợp'), findsOneWidget);
    await tester.enterText(search, '');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.widgetWithText(ChoiceChip, 'Cầu lông'));
    expect(find.text('Sân bóng đá Thành Công'), findsNothing);
    expect(find.text('Sân cầu lông Phú Nhuận'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Statistics refreshes pending count after approval and Back', (
    tester,
  ) async {
    await openRoute(tester, AppRoutes.statistics, role: 'admin');
    Finder pendingCard() => find.ancestor(
      of: find.text('Sân chờ duyệt'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: pendingCard(), matching: find.text('1')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duyệt sân'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Duyệt'));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: pendingCard(), matching: find.text('0')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Owner admin and customer promotion screens fit 360 pixels',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final (route, role) in [
        (AppRoutes.manageVenue, 'owner'),
        (AppRoutes.managePromotion, 'admin'),
        (AppRoutes.statistics, 'admin'),
        (AppRoutes.customerPromotion, 'customer'),
      ]) {
        await tester.pumpWidget(const SizedBox());
        await openRoute(tester, route, role: role);
        expect(tester.takeException(), isNull, reason: route);
      }
    },
    tags: ['viewport'],
  );
}
