import 'package:get_it/get_it.dart';

import '../../features/vendor_shows/domain/repositories/shows_repository.dart';
import '../../features/vendor_shows/presentation/adapters/image_picker_show_poster_adapter.dart';
import '../../features/vendor_shows/presentation/cubit/show_form_cubit.dart';
import '../../features/vendor_shows/presentation/cubit/show_form_state.dart';
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

void registerVendorJourney(
  GetIt services, {
  required String vendorId,
  ShowPosterPicker? posterPicker,
  ShowPosterRecovery? recoverPoster,
}) {
  services.registerFactory<ShowFormCubit>(() {
    final nativePicker = posterPicker == null
        ? ImagePickerShowPosterAdapter()
        : null;
    return ShowFormCubit(
      services<ShowsRepository>(),
      vendorId: vendorId,
      posterPicker: posterPicker ?? nativePicker?.call,
      recoverPoster: recoverPoster ?? nativePicker?.retrieveLostPoster,
    );
  });
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
