import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';

import '../../features/booking/data/repositories/firestore_booking_repository.dart';
import '../../features/booking/domain/repositories/booking_repository.dart';
import '../../features/customer_auth/data/repositories/firebase_customer_auth_repository.dart';
import '../../features/customer_auth/domain/repositories/customer_auth_repository.dart';
import '../../features/customer_auth/presentation/cubit/customer_auth_cubit.dart';
import '../../features/vendor_shows/data/repositories/firestore_shows_repository.dart';
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

/// Registers the full live Firebase Auth + Firestore Shows + Booking customer graph.
GetIt createLiveCustomerServices({
  required FirebaseAuth auth,
  required FirebaseFirestore firestore,
  CustomerAuthRepository? authRepository,
  ShowsRepository? showsRepository,
  BookingRepository? bookingRepository,
  String Function()? currentCustomerUid,
}) {
  final resolvedAuthRepository =
      authRepository ?? FirebaseCustomerAuthRepository(auth);
  final resolvedShowsRepository =
      showsRepository ?? FirestoreShowsRepository(firestore);
  final services = createAuthenticatedCustomerServices(
    authRepository: resolvedAuthRepository,
    showsRepository: resolvedShowsRepository,
  );
  services.registerSingleton<BookingRepository>(
    bookingRepository ??
        FirestoreBookingRepository(firestore, auth, resolvedShowsRepository),
  );
  registerCustomerBooking(
    services,
    customerUid: currentCustomerUid ?? () => auth.currentUser!.uid,
  );
  return services;
}
