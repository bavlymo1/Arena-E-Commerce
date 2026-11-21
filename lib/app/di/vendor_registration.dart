import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';

import '../../features/vendor_access/data/firebase_vendor_access_repository.dart';
import '../../features/vendor_access/domain/repositories/vendor_access_repository.dart';
import '../../features/vendor_access/vendor_access_registration.dart';
import '../../features/vendor_notifications/data/repositories/firestore_booking_events_repository.dart';
import '../../features/vendor_notifications/data/repositories/flutter_local_alert_presenter.dart';
import '../../features/vendor_notifications/data/repositories/shared_preferences_watermark_store.dart';
import '../../features/vendor_notifications/domain/repositories/booking_events_repository.dart';
import '../../features/vendor_notifications/domain/repositories/local_alert_presenter.dart';
import '../../features/vendor_notifications/domain/repositories/watermark_store.dart';
import '../../features/vendor_notifications/presentation/cubit/vendor_notifications_cubit.dart';
import '../../features/vendor_shows/data/repositories/firestore_shows_repository.dart';
import '../../features/vendor_shows/domain/repositories/shows_repository.dart';
import '../../features/vendor_shows/presentation/adapters/image_picker_show_poster_adapter.dart';
import '../../features/vendor_shows/presentation/cubit/show_form_cubit.dart';
import '../../features/vendor_shows/presentation/cubit/show_form_state.dart';
import '../../features/vendor_shows/presentation/cubit/vendor_show_details_cubit.dart';
import '../../features/vendor_shows/presentation/cubit/vendor_shows_cubit.dart';
import '../customer/demo_customer_repository.dart';
import '../startup/app_variant.dart';
import 'shared_registration.dart';

GetIt createVendorServices() {
  final services = GetIt.asNewInstance();
  registerShared(services, AppVariant.vendor);
  return services;
}

ShowFormCubit _buildShowFormCubit(
  GetIt services, {
  required String vendorId,
  ShowPosterPicker? posterPicker,
  ShowPosterRecovery? recoverPoster,
}) {
  final nativePicker = posterPicker == null
      ? ImagePickerShowPosterAdapter()
      : null;
  return ShowFormCubit(
    services<ShowsRepository>(),
    vendorId: vendorId,
    posterPicker: posterPicker ?? nativePicker?.call,
    recoverPoster: recoverPoster ?? nativePicker?.retrieveLostPoster,
  );
}

VendorNotificationsCubit _buildVendorNotificationsCubit(
  GetIt services, {
  required String vendorId,
}) => VendorNotificationsCubit(
  services<BookingEventsRepository>(),
  vendorId: vendorId,
  watermarkStore: services.isRegistered<WatermarkStore>()
      ? services<WatermarkStore>()
      : null,
  alertPresenter: services.isRegistered<LocalAlertPresenter>()
      ? services<LocalAlertPresenter>()
      : null,
);

void registerVendorJourney(
  GetIt services, {
  required String vendorId,
  ShowPosterPicker? posterPicker,
  ShowPosterRecovery? recoverPoster,
}) {
  services.registerFactory<ShowFormCubit>(
    () => _buildShowFormCubit(
      services,
      vendorId: vendorId,
      posterPicker: posterPicker,
      recoverPoster: recoverPoster,
    ),
  );
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
  if (services.isRegistered<BookingEventsRepository>()) {
    services.registerFactory<VendorNotificationsCubit>(
      () => _buildVendorNotificationsCubit(services, vendorId: vendorId),
    );
  }
}

void registerVendorEnrolledJourney(
  GetIt services, {
  ShowPosterPicker? posterPicker,
  ShowPosterRecovery? recoverPoster,
}) {
  services.registerFactoryParam<ShowFormCubit, String, Object?>(
    (vendorId, _) => _buildShowFormCubit(
      services,
      vendorId: vendorId,
      posterPicker: posterPicker,
      recoverPoster: recoverPoster,
    ),
  );
  services.registerFactoryParam<VendorShowsCubit, String, Object?>(
    (vendorId, _) =>
        VendorShowsCubit(services<ShowsRepository>(), vendorId: vendorId),
  );
  services.registerFactoryParam<VendorShowDetailsCubit, String, String>(
    (vendorId, showId) => VendorShowDetailsCubit(
      services<ShowsRepository>(),
      vendorId: vendorId,
      showId: showId,
    ),
  );
  services.registerFactoryParam<VendorNotificationsCubit, String, Object?>(
    (vendorId, _) =>
        _buildVendorNotificationsCubit(services, vendorId: vendorId),
  );
}

GetIt createLocalVendorServices({
  required FirebaseAuth auth,
  required FirebaseFirestore firestore,
  VendorAccessRepository? accessRepository,
  WatermarkStore? watermarkStore,
  LocalAlertPresenter? alertPresenter,
  ShowPosterPicker? posterPicker,
  ShowPosterRecovery? recoverPoster,
}) {
  final services = createVendorServices();
  final vendorAccess =
      accessRepository ?? FirebaseVendorAccessRepository(auth, firestore);
  registerVendorAccess(services, repository: vendorAccess);
  services.registerSingleton<ShowsRepository>(
    FirestoreShowsRepository(firestore, vendorAccess: vendorAccess),
    dispose: (repository) => repository.dispose(),
  );
  services.registerSingleton<BookingEventsRepository>(
    FirestoreBookingEventsRepository(firestore, vendorAccess),
  );
  services.registerSingleton<WatermarkStore>(
    watermarkStore ?? SharedPreferencesWatermarkStore(),
  );
  services.registerSingleton<LocalAlertPresenter>(
    alertPresenter ?? FlutterLocalAlertPresenter(),
  );
  registerVendorEnrolledJourney(
    services,
    posterPicker: posterPicker,
    recoverPoster: recoverPoster,
  );
  return services;
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
