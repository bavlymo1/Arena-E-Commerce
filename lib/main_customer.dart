import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/customer/customer_app.dart';
import 'app/di/customer_registration.dart';
import 'app/di/shared_registration.dart';
import 'app/startup/app_variant.dart';
import 'app/startup/arena_pass_app.dart';
import 'firebase_options_customer.dart';

const String _customerStartupErrorMessage =
    'ArenaPass Customer could not initialize cloud services. '
    'Check your connection and retry.';

Future<String> _launchCustomer() async {
  try {
    final app = Firebase.apps.isEmpty
        ? await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          )
        : Firebase.app();
    final auth = FirebaseAuth.instanceFor(app: app);
    final firestore = FirebaseFirestore.instanceFor(app: app);
    runApp(
      createCustomerApp(
        services: createLiveCustomerServices(auth: auth, firestore: firestore),
      ),
    );
    return '';
  } catch (_) {
    return _customerStartupErrorMessage;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    runApp(createCustomerApp());
    return;
  }
  final errorMessage = await _launchCustomer();
  if (errorMessage.isNotEmpty) {
    runApp(
      ArenaPassApp(
        startupTitle: 'Startup failed',
        services: createStartupErrorServices(
          AppVariant.customer,
          initialError: errorMessage,
          retryLaunch: _launchCustomer,
        ),
      ),
    );
  }
}
