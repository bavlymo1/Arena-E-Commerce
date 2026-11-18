import 'package:get_it/get_it.dart';

import '../../features/customer_auth/domain/repositories/customer_auth_repository.dart';
import '../../features/customer_auth/presentation/cubit/customer_auth_cubit.dart';
import '../../features/vendor_shows/domain/repositories/shows_repository.dart';
import 'customer_journey_registration.dart';
import '../startup/app_variant.dart';
import 'shared_registration.dart';

GetIt createCustomerServices() {
  final services = GetIt.asNewInstance();
  registerShared(services, AppVariant.customer);
  return services;
}

GetIt createAuthenticatedCustomerServices({
  required CustomerAuthRepository authRepository,
  required ShowsRepository showsRepository,
}) {
  final services = createCustomerServices();
  services.registerSingleton<CustomerAuthRepository>(authRepository);
  services.registerSingleton<ShowsRepository>(
    showsRepository,
    dispose: (repository) => repository.dispose(),
  );
  services.registerFactory<CustomerAuthCubit>(
    () => CustomerAuthCubit(services<CustomerAuthRepository>()),
  );
  registerCustomerDiscovery(services);
  return services;
}
