import 'dart:async';

import 'package:e_commerce_project/app/vendor/vendor_journey_router.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/repositories/booking_events_repository.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/repositories/local_alert_presenter.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/repositories/watermark_store.dart';
import 'package:e_commerce_project/features/vendor_notifications/presentation/cubit/vendor_notifications_cubit.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/repositories/shows_repository.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/adapters/image_picker_show_poster_adapter.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/cubit/show_form_cubit.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/cubit/show_form_state.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/cubit/vendor_show_details_cubit.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/cubit/vendor_shows_cubit.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'demo_customer_repository.dart';

/// Registers test/fixture vendor Cubit factories into [services].
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
      posterPicker: posterPicker ?? nativePicker?.pickPoster,
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
  if (services.isRegistered<BookingEventsRepository>()) {
    services.registerFactory<VendorNotificationsCubit>(
      () => VendorNotificationsCubit(
        services<BookingEventsRepository>(),
        vendorId: vendorId,
        watermarkStore: services.isRegistered<WatermarkStore>()
            ? services<WatermarkStore>()
            : null,
        alertPresenter: services.isRegistered<LocalAlertPresenter>()
            ? services<LocalAlertPresenter>()
            : null,
      ),
    );
  }
}

/// Creates an isolated demo GetIt container backed by [DemoCustomerRepository].
GetIt createDemoVendorServices() {
  final services = GetIt.asNewInstance();
  services.registerSingleton<ShowsRepository>(
    DemoCustomerRepository(),
    dispose: (repository) => repository.dispose(),
  );
  registerVendorJourney(services, vendorId: 'demo-vendor');
  return services;
}

VendorDemoApp createVendorDemoApp({GetIt? services}) =>
    VendorDemoApp(services: services ?? createDemoVendorServices());

/// Explicit local preview; enrollment and production startup remain pending.
class VendorDemoApp extends StatefulWidget {
  const VendorDemoApp({
    required this.services,
    this.banner = 'LOCAL DEMO · sample vendor and data · resets on restart',
    this.canAddShow = false,
    super.key,
  });
  final GetIt services;
  final String banner;
  final bool canAddShow;

  @override
  State<VendorDemoApp> createState() => _VendorDemoAppState();
}

class _VendorDemoAppState extends State<VendorDemoApp> {
  @override
  void dispose() {
    unawaited(widget.services.reset());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => VendorJourneyRouter(
    title: 'ArenaPass Vendor · Demo',
    banner: widget.banner,
    createShowsCubit: () => widget.services<VendorShowsCubit>(),
    createShowFormCubit: widget.canAddShow
        ? () => widget.services<ShowFormCubit>()
        : null,
    createDetailsCubit: (showId) =>
        widget.services<VendorShowDetailsCubit>(param1: showId),
  );
}
