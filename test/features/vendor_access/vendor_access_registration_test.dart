import 'package:e_commerce_project/features/vendor_access/domain/models/vendor_access.dart';
import 'package:e_commerce_project/features/vendor_access/domain/repositories/vendor_access_repository.dart';
import 'package:e_commerce_project/features/vendor_access/presentation/cubit/vendor_access_cubit.dart';
import 'package:e_commerce_project/features/vendor_access/vendor_access_registration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

final class _FakeRepo implements VendorAccessRepository {
  @override
  Future<VendorAccess> check() async =>
      VendorAllowed(uid: 'u1', vendorId: 'arena');
}

void main() {
  test('registerVendorAccess registers repository singleton and factory cubits into passed container', () async {
    final services = GetIt.asNewInstance();
    final repo = _FakeRepo();

    registerVendorAccess(services, repository: repo);

    expect(identical(services<VendorAccessRepository>(), repo), isTrue);
    final first = services<VendorAccessCubit>();
    final second = services<VendorAccessCubit>();
    expect(identical(first, second), isFalse);

    await first.close();
    await second.close();
    await services.reset();
  });
}
