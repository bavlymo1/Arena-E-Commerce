import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'app/di/vendor_registration.dart';
import 'app/vendor/vendor_enrolled_app.dart';

const String _emulatorHost = String.fromEnvironment(
  'EMULATOR_HOST',
  defaultValue: '127.0.0.1',
);
const int _authPort = int.fromEnvironment(
  'AUTH_EMULATOR_PORT',
  defaultValue: 9099,
);
const int _firestorePort = int.fromEnvironment(
  'FIRESTORE_EMULATOR_PORT',
  defaultValue: 8180,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    VendorEnrolledApp(services: await createLocalVendorEmulatorServices()),
  );
}

Future<GetIt> createLocalVendorEmulatorServices() async {
  final app = Firebase.apps.isEmpty
      ? await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: 'ADemoProjectApiKey000000000000000000000',
            appId: '1:1:android:1',
            messagingSenderId: '1',
            projectId: 'demo-arenapass',
          ),
        )
      : Firebase.app();
  final auth = FirebaseAuth.instanceFor(app: app);
  await auth.useAuthEmulator(
    _emulatorHost,
    _authPort,
    automaticHostMapping: false,
  );
  final firestore = FirebaseFirestore.instanceFor(app: app);
  firestore.settings = const Settings(persistenceEnabled: false);
  firestore.useFirestoreEmulator(
    _emulatorHost,
    _firestorePort,
    automaticHostMapping: false,
  );
  return createLiveVendorServices(auth: auth, firestore: firestore);
}
