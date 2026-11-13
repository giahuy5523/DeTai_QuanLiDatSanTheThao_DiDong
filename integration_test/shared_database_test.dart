import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sportfield_booking/data/account_repository.dart';
import 'package:sportfield_booking/data/booking_repository.dart';
import 'package:sportfield_booking/data/mock_store.dart';
import 'package:sportfield_booking/data/venue_repository.dart';
import 'package:sportfield_booking/models/booking.dart';
import 'package:sportfield_booking/models/service.dart';
import 'package:sportfield_booking/models/user.dart';
import 'package:sportfield_booking/models/venue.dart';
import 'package:sportfield_booking/utils/database_helper.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Cross-role booking persists in shared Android SQLite', (
    _,
  ) async {
    final path = p.join(
      await getDatabasesPath(),
      'shared_database_test_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final schema = DatabaseHelper();
    Future<Database> openTestDatabase() => openDatabase(
      path,
      version: DatabaseHelper.databaseVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) => schema.createSchema(db),
    );

    AppUser fixture(String role, String phone) => AppUser(
      id: 'test-$role',
      name: 'SQLite $role',
      email: '$role@example.test',
      phone: phone,
      password: 'Shared-SQLite-Fixture-2026!',
      role: role,
    );
    final owner = fixture('owner', '0900000001');
    final admin = fixture('admin', '0900000002');
    final customer = fixture('customer', '0900000003');

    Database? database;
    try {
      final initial = await openTestDatabase();
      database = initial;
      final accounts = await AccountRepository.open(
        seed: [owner, admin, customer],
        database: initial,
      );
      await VenueRepository.initialize(initial);
      BookingRepository.setDatabaseForTesting(initial);

      Future<AppUser> signIn(AppUser user) async {
        final signedIn = await accounts.login(user.email, user.password);
        expect(signedIn?.id, user.id);
        expect(signedIn?.role, user.role);
        return signedIn!;
      }

      final ownerSession = await signIn(owner);
      final venue = Venue(
        id: 'test-venue',
        ownerId: ownerSession.id,
        sportTypeId: 1,
        sportType: 'Tennis',
        name: 'SQLite test court',
        address: 'Test court address',
        pricePerHour: 100000,
        imageUrls: const ['assets/sports_dataset/tennis/tennis_010.jpg'],
        latitude: 10.73,
        longitude: 106.72,
      );
      final service = VenueService(
        id: 'test-racket',
        venueId: venue.id,
        name: 'Racket rental',
        price: 15000,
      );
      await VenueRepository.saveVenue(venue);
      await VenueRepository.saveService(service);

      await signIn(admin);
      expect((await VenueRepository.loadVenues()).single.status, 'pending');
      expect(await VenueRepository.loadVenues(approvedOnly: true), isEmpty);
      final contacts = await VenueRepository.loadOwnerContacts([owner.id]);
      expect(contacts[owner.id]?.email, owner.email);
      await VenueRepository.updateStatus(venue.id, 'approved');

      final customerSession = await signIn(customer);
      final approved = (await VenueRepository.loadVenues(
        approvedOnly: true,
      )).single;
      expect(approved.id, venue.id);
      final availableService = (await VenueRepository.loadServicesFor(
        approved.id,
      )).single;
      expect(availableService.id, service.id);
      final item = BookingServiceItem(
        serviceId: availableService.id,
        serviceName: availableService.name,
        quantity: 2,
        unitPrice: availableService.price,
      );
      final future = DateTime.now().add(const Duration(days: 7));
      final booking = Booking(
        id: 'test-booking',
        venueId: approved.id,
        userId: customerSession.id,
        date: DateTime(future.year, future.month, future.day),
        startTime: '10:00',
        endTime: '11:00',
        originalAmount: approved.pricePerHour,
        serviceAmount: item.subtotal,
        discountAmount: 0,
        totalPrice: approved.pricePerHour + item.subtotal,
        serviceItems: [item],
      );
      final result = await BookingRepository.processBookingPayment(
        booking: booking,
        method: 'momo',
        transactionCode: 'TEST-SHARED-SQLITE',
      );
      expect(result.isSuccess, isTrue, reason: result.failureReason);

      await signIn(owner);
      final entries = await VenueRepository.loadBookingsForVenue(venue.id);
      expect(entries.single.id, booking.id);
      expect(entries.single.customerName, customer.name);
      expect(entries.single.status, 'confirmed');

      await signIn(admin);
      final stats = await VenueRepository.loadSystemStatistics();
      expect(stats.venues('approved'), 1);
      expect(stats.bookings('confirmed'), 1);
      expect(stats.revenue, 130000);

      await initial.close();
      database = null;
      final reopened = await openTestDatabase();
      database = reopened;
      final restoredAccounts = AccountRepository(reopened);
      await VenueRepository.initialize(reopened);
      BookingRepository.setDatabaseForTesting(reopened);
      await BookingRepository.refreshCache();
      expect(MockStore.bookings.single.id, booking.id);

      expect((await restoredAccounts.restoreSession())?.id, admin.id);
      expect(
        (await restoredAccounts.allUsers()).map((user) => user.id),
        unorderedEquals([owner.id, admin.id, customer.id]),
      );
      final restoredVenue = (await VenueRepository.loadVenues(
        approvedOnly: true,
      )).single;
      expect(restoredVenue.ownerId, owner.id);
      expect(restoredVenue.imageUrls, venue.imageUrls);
      final restoredService = (await VenueRepository.loadServicesFor(
        restoredVenue.id,
      )).single;
      expect(restoredService.id, service.id);
      expect(restoredService.price, 15000);
      final restoredBooking = (await BookingRepository.getBookingsForUser(
        customer.id,
      )).single;
      expect(restoredBooking.id, booking.id);
      expect(restoredBooking.venueId, venue.id);
      expect(restoredBooking.paymentStatus, 'paid');
      expect(restoredBooking.serviceItems.single.serviceId, service.id);
      expect(restoredBooking.serviceItems.single.quantity, 2);
      final payment = await BookingRepository.getPaymentForBooking(booking.id);
      expect(payment?.paymentId, restoredBooking.paymentId);
      expect(payment?.status, 'success');
      expect(payment?.transactionCode, 'TEST-SHARED-SQLITE');
      expect(payment?.amount, 130000);
      Future<bool> slotIsAvailable() => BookingRepository.isRangeAvailable(
        venueId: venue.id,
        date: restoredBooking.date,
        startTime: restoredBooking.startTime,
        endTime: restoredBooking.endTime,
      );
      expect(await slotIsAvailable(), isFalse);
      expect(
        (await restoredAccounts.login(customer.email, customer.password))?.id,
        customer.id,
      );
      expect(await BookingRepository.cancelBooking(booking.id), isTrue);
      expect(await BookingRepository.cancelBooking(booking.id), isFalse);
      expect(await slotIsAvailable(), isTrue);
      final refund = await BookingRepository.getPaymentForBooking(booking.id);
      expect(refund?.refundStatus, 'processing');
      expect(await BookingRepository.completeRefund(booking.id), isTrue);
      expect(await BookingRepository.completeRefund(booking.id), isFalse);
      expect(
        (await BookingRepository.getBookingById(booking.id))?.paymentStatus,
        'refunded',
      );
      expect(
        (await BookingRepository.getPaymentForBooking(
          booking.id,
        ))?.refundStatus,
        'succeeded',
      );
      await reopened.close();
      database = null;
      final afterRefund = await openTestDatabase();
      database = afterRefund;
      BookingRepository.setDatabaseForTesting(afterRefund);
      await BookingRepository.refreshCache();
      expect(MockStore.bookings.single.status, 'cancelled');
      expect(MockStore.bookings.single.paymentStatus, 'refunded');
      expect(
        (await BookingRepository.getPaymentForBooking(
          booking.id,
        ))?.refundStatus,
        'succeeded',
      );
      expect(await afterRefund.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    } finally {
      BookingRepository.setDatabaseForTesting(null);
      await database?.close();
      await deleteDatabase(path);
    }
  });
}
