import 'package:e_commerce_project/app/di/customer_registration.dart';
import 'package:e_commerce_project/features/customer_auth/domain/repositories/customer_auth_repository.dart';
import 'package:e_commerce_project/features/customer_auth/presentation/cubit/customer_auth_cubit.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/repositories/shows_repository.dart';
import 'package:get_it/get_it.dart';

/// Registers test-only authenticated Customer services without booking writes.
GetIt createAuthenticatedCustomerServices({
  required CustomerAuthRepository authRepository,
  ShowsRepository? showsRepository,
}) {
  final services = createCustomerServices();
  services.registerSingleton<CustomerAuthRepository>(authRepository);
  services.registerFactory<CustomerAuthCubit>(
    () => CustomerAuthCubit(services<CustomerAuthRepository>()),
  );
  if (showsRepository != null) {
    services.registerSingleton<ShowsRepository>(
      showsRepository,
      dispose: (repository) => repository.dispose(),
    );
    registerCustomerDiscovery(services);
  }
  return services;
}

/// Registers fixed-UID discovery and booking Cubits for fixture journey tests.
void registerCustomerJourney(
  GetIt services, {
  required String customerUid,
  String Function()? newBookingId,
}) {
  registerCustomerDiscovery(services);
  registerCustomerBooking(
    services,
    customerUid: () => customerUid,
    newBookingId: newBookingId,
  );
}
