import 'package:get_it/get_it.dart';

import '../../features/booking/domain/repositories/booking_repository.dart';
import '../../features/vendor_shows/domain/repositories/shows_repository.dart';
import '../di/customer_registration.dart';
import 'customer_journey_app.dart';
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
