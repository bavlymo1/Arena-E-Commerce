import 'package:e_commerce_project/features/customer_auth/domain/models/app_user.dart';
import 'package:e_commerce_project/features/vendor_access/domain/models/vendor_access.dart';
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

  test('vendor identity alone cannot be mistaken for enrollment', () {
    final pending = VendorNotEnrolled(uid: 'device-a');
    expect(pending.uid, 'device-a');
    expect(pending, isNot(isA<VendorAllowed>()));
    final allowed = VendorAllowed(uid: 'device-a', vendorId: 'arena');
    expect(allowed.vendorId, 'arena');
    expect(() => VendorNotEnrolled(uid: ''), throwsArgumentError);
    expect(
      () => VendorAllowed(uid: 'device-a', vendorId: ' '),
      throwsArgumentError,
    );
  });
}
