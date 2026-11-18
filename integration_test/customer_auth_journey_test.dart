import 'package:e_commerce_project/features/customer_auth/data/local_auth_emulator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/customer_auth_journey.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Auth Emulator UI register discover account logout Back login and second customer',
    (tester) async {
      final repository = await createLocalAuthRepository();
      try {
        await verifyCustomerAuthJourney(tester, repository);
      } finally {
        await repository.logout();
      }
    },
  );
}
