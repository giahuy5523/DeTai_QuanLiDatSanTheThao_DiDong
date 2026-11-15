import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sportfield_booking/data/mock_store.dart';
import 'package:sportfield_booking/models/venue.dart';
import 'package:sportfield_booking/screens/customer/search_screen.dart';

void main() {
  testWidgets('catalog searches sport names and applies only selected prices', (
    tester,
  ) async {
    final original = List<Venue>.of(MockStore.venues);
    addTearDown(() => MockStore.venues
      ..clear()
      ..addAll(original));

    final venue = Venue.mockList()[1];
    MockStore.venues
      ..clear()
      ..addAll([
        venue.copyWith(name: 'Phoenix Arena', pricePerHour: 1250000),
        Venue.mockList().first.copyWith(
          name: 'Budget Field',
          pricePerHour: 50000,
        ),
        Venue.mockList().last.copyWith(name: 'Pending Court'),
      ]);

    await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
    expect(find.text('Phoenix Arena'), findsOneWidget);
    expect(find.text('Pending Court'), findsNothing);

    final search = find.byType(TextField);
    await tester.enterText(search, 'bong da');
    await tester.pumpAndSettle();
    expect(find.text('Budget Field'), findsOneWidget);
    expect(find.text('Phoenix Arena'), findsNothing);

    await tester.enterText(search, 'cau long');
    await tester.pumpAndSettle();
    expect(find.text('Phoenix Arena'), findsOneWidget);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.text('Bộ lọc'));
    await tester.pumpAndSettle();
    final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
    expect(slider.max, greaterThanOrEqualTo(1250000));
    slider.onChanged!(const RangeValues(0, 500000));
    await tester.pump();
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();
    expect(find.text('Phoenix Arena'), findsNothing);
    await tester.tap(find.text('Xóa tất cả bộ lọc'));
    await tester.pumpAndSettle();
    expect(find.text('Phoenix Arena'), findsOneWidget);
  });
}
