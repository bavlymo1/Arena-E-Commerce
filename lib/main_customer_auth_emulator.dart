import 'package:flutter/material.dart';

import 'app/customer/customer_app.dart';
import 'app/customer/demo_customer_repository.dart';
import 'app/di/customer_registration.dart';
import 'features/customer_auth/data/local_auth_emulator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authRepository = await createLocalAuthRepository();
  runApp(
    createCustomerApp(
      services: createAuthenticatedCustomerServices(
        authRepository: authRepository,
        showsRepository: DemoCustomerRepository(),
      ),
    ),
  );
}
