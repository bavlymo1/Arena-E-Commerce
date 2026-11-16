import 'package:e_commerce_project/app/di/customer_registration.dart';
import 'package:e_commerce_project/app/di/vendor_registration.dart';
import 'package:e_commerce_project/app/startup/app_variant.dart';
import 'package:e_commerce_project/app/startup/arena_pass_app.dart';
import 'package:e_commerce_project/app/startup/startup_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('containers are separate and startup cubits are factories', () async {
    final customer = createCustomerServices();
    final vendor = createVendorServices();
    expect(customer<AppVariant>(), AppVariant.customer);
    expect(vendor<AppVariant>(), AppVariant.vendor);
    final first = customer<StartupCubit>();
    final second = customer<StartupCubit>();
    expect(identical(first, second), isFalse);
    await first.close();
    await second.close();
    await customer.reset();
    await vendor.reset();
  });
  testWidgets('route provider closes its factory cubit when app leaves', (
    tester,
  ) async {
    final services = createCustomerServices();
    await services.unregister<StartupCubit>();
    late StartupCubit created;
    services.registerFactory<StartupCubit>(
      () => created = StartupCubit(() async => 'Pending'),
    );
    await tester.pumpWidget(ArenaPassApp(services: services));
    await tester.pumpAndSettle();
    expect(created.isClosed, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(created.isClosed, isTrue);
    expect(services.isRegistered<AppVariant>(), isFalse);
  });
}
