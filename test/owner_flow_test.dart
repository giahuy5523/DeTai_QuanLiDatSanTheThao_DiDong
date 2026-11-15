import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sportfield_booking/data/mock_store.dart';
import 'package:sportfield_booking/data/venue_repository.dart';
import 'package:sportfield_booking/models/service.dart';
import 'package:sportfield_booking/models/venue.dart';
import 'package:sportfield_booking/screens/owner/manage_service_screen.dart';
import 'package:sportfield_booking/screens/owner/upload_venue_screen.dart';
import 'package:sportfield_booking/screens/owner/venue_update_screen.dart';
import 'package:sportfield_booking/utils/app_theme.dart';

class _FakePicker extends ImagePicker {
  _FakePicker(this.files);
  final List<XFile> files;

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async => files;
}

XFile _photo(int index) => XFile.fromData(
  File(
    'assets/sports_dataset/football/football_00$index.jpg',
  ).readAsBytesSync(),
  name: 'owner-flow-$index.jpg',
  path: 'owner-flow-$index.jpg',
);

void main() {
  const venueId = 'owner-flow-venue';
  final savedVenues = List.of(MockStore.venues);
  final savedServices = Map<String, List<VenueService>>.from(
    MockStore.servicesByVenue.map(
      (key, value) => MapEntry(key, List.of(value)),
    ),
  );

  setUp(() {
    VenueRepository.setUseMockStoreForTesting(true);
    MockStore.logout();
    MockStore.venues
      ..clear()
      ..addAll(savedVenues);
    MockStore.servicesByVenue
      ..clear()
      ..addAll(savedServices);
    MockStore.servicesByVenue[venueId] = [];
  });

  tearDown(() {
    VenueRepository.setUseMockStoreForTesting(false);
    MockStore.logout();
    MockStore.venues
      ..clear()
      ..addAll(savedVenues);
    MockStore.servicesByVenue
      ..clear()
      ..addAll(savedServices);
  });

  testWidgets('Owner adds, edits, and deletes a venue service', (tester) async {
    MockStore.venues.add(
      Venue(
        id: venueId,
        ownerId: 'owner1',
        sportType: 'Bóng đá',
        name: 'Sân owner flow',
        address: 'TP.HCM',
        pricePerHour: 100000,
        imageUrls: const [],
        latitude: 10,
        longitude: 106,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ManageServiceScreen(venueId: venueId),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa có dịch vụ'), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Thêm dịch vụ'),
      ),
      findsOneWidget,
    );

    final nameField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Tên dịch vụ',
    );
    final priceField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'Giá',
    );
    final unitField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Đơn vị',
    );
    await tester.enterText(nameField, 'Nuoc suoi');
    await tester.enterText(priceField, '12000');
    await tester.enterText(unitField, 'chai');
    await tester.tap(find.text('Thêm').last);
    await tester.pumpAndSettle();

    expect(find.text('Nuoc suoi'), findsOneWidget);
    expect(MockStore.servicesFor(venueId), hasLength(1));
    expect(MockStore.servicesFor(venueId).single.price, 12000);

    await tester.tap(find.text('Sửa').last);
    await tester.pumpAndSettle();
    expect(find.text('Sửa dịch vụ'), findsOneWidget);
    await tester.enterText(nameField, 'Nuoc suoi lanh');
    await tester.enterText(priceField, '15000');
    await tester.tap(find.text('Lưu').last);
    await tester.pumpAndSettle();

    expect(find.text('Nuoc suoi lanh'), findsOneWidget);
    expect(MockStore.servicesFor(venueId).single.price, 15000);

    await tester.tap(find.text('Xóa').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa').last);
    await tester.pumpAndSettle();

    expect(MockStore.servicesFor(venueId), isEmpty);
    expect(find.text('Chưa có dịch vụ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Owner registers a venue and updates its details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    MockStore.login('owner@gmail.com', '123456');
    final picker = _FakePicker([_photo(1), _photo(2), _photo(3)]);
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
              child: const Text('Open registration'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open registration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm ảnh bìa'));
    await tester.pumpAndSettle();
    expect(find.text('3 / 8 ảnh'), findsOneWidget);

    Future<void> enterField(String label, String value) async {
      final field = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
    }

    await enterField('Tên sân', 'Sân owner mới');
    await enterField('Địa chỉ', '123 đường Test');
    await enterField('Giá thuê / giờ', '180000');
    final sportDropdown = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(sportDropdown);
    await tester.tap(sportDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bóng đá').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Gửi duyệt'));
    await tester.tap(find.text('Gửi duyệt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xong'));
    await tester.pumpAndSettle();

    final registered = MockStore.venues.singleWhere(
      (venue) => venue.name == 'Sân owner mới',
    );
    expect(registered.ownerId, MockStore.currentUser!.id);
    expect(registered.status, 'pending');
    expect(registered.pricePerHour, 180000);
    expect(registered.imageUrls, hasLength(3));

    await tester.pumpWidget(const SizedBox());
    final editableVenue = registered.copyWith(
      imageUrls: [
        'assets/sports_dataset/football/football_001.jpg',
        'assets/sports_dataset/football/football_002.jpg',
        'assets/sports_dataset/football/football_003.jpg',
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VenueUpdateScreen(venue: editableVenue),
                ),
              ),
              child: const Text('Open venue update'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open venue update'));
    await tester.pumpAndSettle();
    final name = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Tên sân',
    );
    final price = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Giá thuê / giờ',
    );
    await tester.enterText(name, 'Sân owner đã cập nhật');
    await tester.enterText(price, '220000');
    await tester.ensureVisible(find.text('Lưu thay đổi'));
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();

    final updated = MockStore.venues.singleWhere((v) => v.id == registered.id);
    expect(updated.name, 'Sân owner đã cập nhật');
    expect(updated.pricePerHour, 220000);
    expect(updated.status, 'pending');
    expect(tester.takeException(), isNull);
    MockStore.logout();
  });
}
