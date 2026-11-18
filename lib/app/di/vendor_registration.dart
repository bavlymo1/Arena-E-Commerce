import 'package:get_it/get_it.dart';

import '../../features/vendor_shows/domain/repositories/shows_repository.dart';
import '../../features/vendor_shows/presentation/cubit/vendor_shows_cubit.dart';
import '../../features/vendor_shows/presentation/cubit/vendor_show_details_cubit.dart';
import '../customer/demo_customer_repository.dart';
import '../startup/app_variant.dart';
import 'shared_registration.dart';

GetIt createVendorServices() {
  final services = GetIt.asNewInstance();
  registerShared(services, AppVariant.vendor);
  return services;
}

void registerVendorJourney(GetIt services, {required String vendorId}) {
  services.registerFactory<VendorShowsCubit>(
    () => VendorShowsCubit(services<ShowsRepository>(), vendorId: vendorId),
  );
  services.registerFactoryParam<VendorShowDetailsCubit, String, Object?>(
    (showId, _) => VendorShowDetailsCubit(
      services<ShowsRepository>(),
      vendorId: vendorId,
      showId: showId,
    ),
  );
}

GetIt createDemoVendorServices() {
  final services = GetIt.asNewInstance();
  services.registerSingleton<ShowsRepository>(
    DemoCustomerRepository(),
    dispose: (repository) => repository.dispose(),
  );
  registerVendorJourney(services, vendorId: 'demo-vendor');
  return services;
}
