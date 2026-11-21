import 'package:get_it/get_it.dart';

import 'domain/repositories/vendor_access_repository.dart';
import 'presentation/cubit/vendor_access_cubit.dart';

/// Registers vendor access dependencies into [services].
///
/// Registers [repository] as a singleton [VendorAccessRepository] and
/// [VendorAccessCubit] as a factory so root `BlocProvider(create: ...)` owns
/// its lifecycle and closes it on teardown.
void registerVendorAccess(
  GetIt services, {
  required VendorAccessRepository repository,
}) {
  services.registerSingleton<VendorAccessRepository>(repository);
  services.registerFactory<VendorAccessCubit>(
    () => VendorAccessCubit(services<VendorAccessRepository>()),
  );
}
