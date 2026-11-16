import 'package:get_it/get_it.dart';

import '../startup/app_variant.dart';
import 'shared_registration.dart';

GetIt createVendorServices() {
  final services = GetIt.asNewInstance();
  registerShared(services, AppVariant.vendor);
  return services;
}
