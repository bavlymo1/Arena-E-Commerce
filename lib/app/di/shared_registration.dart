import 'package:get_it/get_it.dart';

import '../startup/app_variant.dart';
import '../startup/startup_cubit.dart';

void registerShared(GetIt services, AppVariant variant) {
  services.registerSingleton<AppVariant>(variant);
  services.registerSingleton<StartupCheck>(
    () async =>
        'ArenaPass ${variant.label} is not connected yet. '
        'Cloud setup is pending; sign-in and event services are unavailable.',
  );
  services.registerFactory<StartupCubit>(
    () => StartupCubit(services<StartupCheck>()),
  );
}

/// Registers retryable startup error state when live Firebase boot fails.
GetIt createStartupErrorServices(
  AppVariant variant, {
  required String initialError,
  required Future<String> Function() retryLaunch,
}) {
  var showInitial = true;
  final services = GetIt.asNewInstance();
  services
    ..registerSingleton<AppVariant>(variant)
    ..registerSingleton<StartupCheck>(() async {
      if (showInitial) {
        showInitial = false;
        return initialError;
      }
      return retryLaunch();
    })
    ..registerFactory<StartupCubit>(
      () => StartupCubit(services<StartupCheck>()),
    );
  return services;
}
