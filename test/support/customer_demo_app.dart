import 'package:e_commerce_project/app/customer/customer_journey_app.dart';
import 'package:e_commerce_project/features/booking/domain/repositories/booking_repository.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/repositories/shows_repository.dart';
import 'package:get_it/get_it.dart';

import 'customer_test_services.dart';
import 'demo_customer_repository.dart';

const String _defaultDemoBanner =
    'LOCAL DEMO · sample account and data · resets on restart';

/// Creates an isolated demo GetIt container backed by [DemoCustomerRepository].
GetIt createDemoCustomerServices() {
  final services = GetIt.asNewInstance();
  final demo = DemoCustomerRepository();
  services.registerSingleton<ShowsRepository>(
    demo,
    dispose: (repository) => repository.dispose(),
  );
  services.registerSingleton<BookingRepository>(demo);
  registerCustomerJourney(
    services,
    customerUid: DemoCustomerRepository.customerUid,
  );
  return services;
}

/// Explicit local fixtures; the normal Customer entry point stays unavailable.
CustomerJourneyApp createCustomerDemoApp({
  GetIt? services,
  String? banner = _defaultDemoBanner,
}) => CustomerJourneyApp(
  services: services ?? createDemoCustomerServices(),
  banner: banner,
);
