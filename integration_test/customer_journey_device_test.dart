import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:sportfield_booking/data/account_service.dart';
import 'package:sportfield_booking/main.dart';
import 'package:sportfield_booking/screens/customer/home_screen.dart';
import 'package:sportfield_booking/widgets/venue_image.dart';
import 'package:sportfield_booking/utils/database_helper.dart';

/// Chạy trên emulator/thiết bị với SQLite thật:
/// khách đăng nhập → chọn sân → đặt (7 ngày tới) → thanh toán MoMo → lịch sử → hủy.
/// Kết quả kiểm tra đọc trực tiếp từ database, không dùng cache MockStore.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Chờ I/O thật và dựng lại khung hình cho đến khi thấy [finder].
  Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    Future<String> Function()? explain,
  }) async {
    for (var i = 0; i < 300 && finder.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    final why = explain == null
        ? ''
        : (await tester.runAsync(explain)) ?? '';
    expect(finder, findsWidgets, reason: 'Không thấy: $finder. $why');
  }

  /// Cuộn tới ô giờ rồi bấm: ô nằm dưới màn hình sẽ không nhận lần bấm.
  Future<void> tapKey(WidgetTester tester, Key key) async {
    final finder = find.byKey(key);
    await waitFor(tester, finder);
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
  }

  /// Chờ I/O thật (kiểm tra khung giờ trong database) xong rồi dựng lại khung hình.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1500)),
    );
    await tester.pump();
  }

  /// Bấm nút ở mức ButtonStyleButton chứa [text].
  Future<void> pressButton(WidgetTester tester, String text) async {
    final button = find.ancestor(
      of: find.text(text),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    await waitFor(
      tester,
      button,
      explain: () async => 'Chữ đang hiển thị: ${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').where((x) => x.isNotEmpty).take(60).join(' | ')}',
    );
    await tester.ensureVisible(button.first);
    await tester.pump();
    await tester.tap(button.first);
    await tester.pump();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await waitFor(tester, finder);
    await tester.ensureVisible(finder.first);
    await tester.pump();
    await tester.tap(finder.first);
    await tester.pump();
  }

  /// Chọn ngày 7 ngày tới trong hộp thoại chọn ngày.
  Future<void> chooseFutureDate(WidgetTester tester) async {
    await tapText(tester, 'Nhấn để chọn ngày khác');
    final dialog = find.byType(DatePickerDialog);
    await waitFor(tester, dialog);
    final editButton = find.descendant(
      of: dialog,
      matching: find.byIcon(Icons.edit_outlined),
    );
    await tester.tap(editButton);
    await tester.pump();
    final dateField = find.descendant(
      of: dialog,
      matching: find.byType(TextFormField),
    );
    await waitFor(tester, dateField);
    final dialogContext = tester.element(dialog);
    final target = DateTime.now().add(const Duration(days: 7));
    await tester.enterText(
      dateField,
      MaterialLocalizations.of(dialogContext).formatCompactDate(target),
    );
    await tester.pump();
    final ok = find.descendant(
      of: dialog,
      matching: find.widgetWithText(TextButton, 'OK'),
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.ensureVisible(ok);
    await tester.tap(ok);
    await tester.pump();
  }

  testWidgets('khách đặt sân, thanh toán, hủy và kiểm tra trên SQLite thật', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await DatabaseHelper.resetForTesting();
      await AccountService.initialize();
    });

    await tester.pumpWidget(const SportFieldBookingApp());
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).first, 'customer@gmail.com');
    await tester.enterText(find.byType(TextFormField).last, '123456');
    await pressButton(tester, 'ĐĂNG NHẬP');
    await waitFor(tester, find.byType(HomeScreen));
    await waitFor(tester, find.byType(VenueImage));

    // Trang chủ vẽ mỗi sân bằng VenueImage; bấm vào sân đầu tiên đã dựng sẵn.
    final firstVenue = find.byType(VenueImage).first;
    await tester.ensureVisible(firstVenue);
    await tester.pump();
    await tester.tap(firstVenue);
    await tester.pump();
    await tapText(tester, 'Đặt sân ngay');
    await chooseFutureDate(tester);

    await tapKey(tester, const ValueKey('start_18:00'));
    await settle(tester);
    await tapKey(tester, const ValueKey('end_19:00'));
    await settle(tester);
    await pressButton(tester, 'Tiếp tục');
    await pressButton(tester, 'Chọn phương thức thanh toán');
    await waitFor(tester, find.text('Tiền thuê sân'));

    await tapText(tester, 'Ví MoMo');
    await tapText(tester, 'Tôi xác nhận thông tin đặt sân là chính xác');
    await pressButton(tester, 'Xác nhận thanh toán');
    await waitFor(tester, find.text('Thanh toán thành công'));

    // Kiểm tra trong database: đơn đã trả bằng MoMo.
    final db = await tester.runAsync(() => DatabaseHelper().database);
    final paid = await tester.runAsync(() => db!.query(
          'bookings',
          where: 'paymentStatus = ?',
          whereArgs: ['paid'],
        ));
    expect(paid, isNotEmpty);
    final bookingId = paid!.last['id'] as String;

    await tapText(tester, 'Về trang chủ');
    await waitFor(tester, find.byType(HomeScreen));
    await tapText(tester, 'Lịch sử');

    final cancel = find.byWidgetPredicate(
      (w) => w.key is ValueKey && (w.key as ValueKey).value.toString() == 'cancel_$bookingId',
    );
    await waitFor(tester, cancel);
    await tester.ensureVisible(cancel);
    await tester.pump();
    await tester.tap(cancel);
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await tester.pump();

    final row = await tester.runAsync(() => db!.query(
          'bookings',
          where: 'id = ?',
          whereArgs: [bookingId],
        ));
    expect(row!.single['status'], 'cancelled');
    expect(tester.takeException(), isNull);
  });
}
