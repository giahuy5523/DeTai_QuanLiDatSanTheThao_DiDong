import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sportfield_booking/data/mock_store.dart';
import 'package:sportfield_booking/main.dart';
import 'package:sportfield_booking/screens/owner/manage_venue_screen.dart';

// This test uses the real Android photo picker. An operator must cancel the
// first picker, then select three different gallery images in the second.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native picker cancel, three previews and pending venue', (
    tester,
  ) async {
    final originalVenues = List.of(MockStore.venues);
    addTearDown(() {
      MockStore.venues
        ..clear()
        ..addAll(originalVenues);
      MockStore.logout();
    });
    await tester.pumpWidget(const SportFieldBookingApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'owner@gmail.com');
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng ký sân'));
    await tester.pumpAndSettle();
    for (final (index, value) in [
      'Sân Android Gia Huy',
      '123 Đường kiểm thử',
      '200000',
    ].indexed) {
      final field = find.byType(TextFormField).at(index);
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    Future<void> pickAndWait() async {
      final button = find.text('Chọn ảnh từ máy');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      final deadline = DateTime.now().add(const Duration(minutes: 2));
      while (find.text('Đang chọn ảnh...').evaluate().isNotEmpty) {
        if (DateTime.now().isAfter(deadline)) {
          fail('Photo picker did not return within two minutes.');
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 500)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    debugPrint('NATIVE_PICKER: cancel the first picker');
    await pickAndWait();
    expect(find.text('Ảnh sân: 0 / tối thiểu 3'), findsOneWidget);
    expect(find.text('Sân Android Gia Huy'), findsOneWidget);

    debugPrint('NATIVE_PICKER: select three different photos');
    await pickAndWait();
    expect(find.text('Ảnh sân: 3 / tối thiểu 3'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(3));
    expect(find.text('Ảnh lỗi'), findsNothing);
    final submit = find.text('Gửi duyệt');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.byType(ManageVenueScreen), findsOneWidget);
    final created = MockStore.venues.singleWhere(
      (venue) => venue.name == 'Sân Android Gia Huy',
    );
    expect(created.ownerId, 'owner1');
    expect(created.status, 'pending');
    expect(created.imageUrls.toSet().length, 3);
    expect(created.pricePerHour, 200000);
    expect(tester.takeException(), isNull);
  }, skip: !const bool.fromEnvironment('NATIVE_PICKER_TEST'));
}
