import 'package:e_commerce_project/features/customer_auth/data/local_auth_emulator.dart';
import 'package:e_commerce_project/features/customer_auth/domain/models/app_user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real FlutterFire adapter register stream logout login invalid credentials',
    (tester) async {
      final repository = await createLocalAuthRepository();
      await repository.logout();
      final events = <AppUser?>[];
      final subscription = repository.authChanges().listen(events.add);
      try {
        expect(
          await repository.authChanges().first.timeout(
            const Duration(seconds: 10),
          ),
          isNull,
        );
        final email =
            'adapter-${DateTime.now().microsecondsSinceEpoch}@example.test';
        const password = 'Local-adapter-test-47';
        await repository.register(email, password);
        final registered = await repository
            .authChanges()
            .firstWhere((user) => user != null)
            .timeout(const Duration(seconds: 10));
        expect(registered!.email, email);
        await repository.logout();
        expect(
          await repository.authChanges().first.timeout(
            const Duration(seconds: 10),
          ),
          isNull,
        );
        await expectLater(
          repository.login(email, 'incorrect-local-test'),
          throwsStateError,
        );
        expect(
          await repository.authChanges().first.timeout(
            const Duration(seconds: 10),
          ),
          isNull,
        );
        await repository.login(email, password);
        final loggedIn = await repository
            .authChanges()
            .firstWhere((user) => user != null)
            .timeout(const Duration(seconds: 10));
        expect(loggedIn, registered);
        await repository.logout();
        expect(
          await repository.authChanges().first.timeout(
            const Duration(seconds: 10),
          ),
          isNull,
        );
        expect(
          events.whereType<AppUser>().map((user) => user.uid),
          contains(registered.uid),
        );
        expect(events.last, isNull);
      } finally {
        await subscription.cancel();
        await repository.logout();
      }
    },
  );
}
