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
