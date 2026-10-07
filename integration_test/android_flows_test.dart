import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/baohuy_merge_test.dart' as booking_admin;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('Booking and admin regressions on device', booking_admin.main);
}
