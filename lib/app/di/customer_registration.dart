import 'package:get_it/get_it.dart';

import '../startup/app_variant.dart';
import 'shared_registration.dart';

GetIt createCustomerServices() {
  final services = GetIt.asNewInstance();
  registerShared(services, AppVariant.customer);
  return services;
}
