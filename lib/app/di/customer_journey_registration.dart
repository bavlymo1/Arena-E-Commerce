import 'dart:math';

import 'package:get_it/get_it.dart';

import '../../features/booking/domain/repositories/booking_repository.dart';
import '../../features/booking/presentation/cubit/booking_cubit.dart';
import '../../features/booking/presentation/cubit/seat_selection_cubit.dart';
import '../../features/discovery/presentation/cubit/discovery_cubit.dart';
import '../../features/discovery/presentation/cubit/show_details_cubit.dart';
import '../../features/vendor_shows/domain/repositories/shows_repository.dart';
import '../customer/demo_customer_repository.dart';

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

void registerCustomerJourney(
  GetIt services, {
  required String customerUid,
  String Function()? newBookingId,
}) {
  final random = Random.secure();
  services.registerFactory<DiscoveryCubit>(
    () => DiscoveryCubit(services<ShowsRepository>()),
  );
  services.registerFactoryParam<ShowDetailsCubit, String, Object?>(
    (showId, _) =>
        ShowDetailsCubit(services<ShowsRepository>(), showId: showId),
  );
  String generateId() => List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  services.registerFactoryParam<SeatSelectionCubit, String, String>(
    (showId, sessionId) => SeatSelectionCubit(
      bookingRepository: services<BookingRepository>(),
      customerUid: customerUid,
      showId: showId,
      sessionId: sessionId,
    ),
  );
  services.registerFactoryParam<BookingCubit, String, String>(
    (showId, sessionId) => BookingCubit(
      repository: services<BookingRepository>(),
      customerUid: customerUid,
      showId: showId,
      sessionId: sessionId,
      newBookingId: newBookingId ?? generateId,
    ),
  );
}
