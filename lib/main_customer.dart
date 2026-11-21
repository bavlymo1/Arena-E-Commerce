import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/customer/customer_app.dart';
import 'app/di/customer_registration.dart';
import 'features/customer_auth/data/repositories/firebase_customer_auth_repository.dart';
import 'firebase_options_customer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    runApp(createCustomerApp());
    return;
  }
  final app = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    createCustomerApp(
      services: createAuthenticatedCustomerServices(
        authRepository: FirebaseCustomerAuthRepository(
          FirebaseAuth.instanceFor(app: app),
        ),
      ),
    ),
  );
}
