import 'package:e_commerce_project/features/vendor_access/domain/models/vendor_access.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
