import 'package:e_commerce_project/features/customer_auth/domain/models/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'customer identity requires both UID and email and compares by value',
    () {
      final user = AppUser(uid: 'customer-a', email: 'a@example.test');
      expect(user, AppUser(uid: 'customer-a', email: 'a@example.test'));
      expect(
        user.hashCode,
        AppUser(uid: 'customer-a', email: 'a@example.test').hashCode,
      );
      expect(user, isNot(AppUser(uid: 'customer-b', email: user.email)));
      expect(() => AppUser(uid: ' ', email: user.email), throwsArgumentError);
      expect(() => AppUser(uid: user.uid, email: ''), throwsArgumentError);
    },
  );
}
