import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_commerce_project/app/di/customer_registration.dart';
import 'package:e_commerce_project/features/customer_auth/data/repositories/firebase_customer_auth_repository.dart';
import 'package:e_commerce_project/features/customer_auth/domain/repositories/customer_auth_repository.dart';
import 'package:e_commerce_project/features/vendor_shows/data/repositories/firestore_shows_repository.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/repositories/shows_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

const String kEmulatorHost = String.fromEnvironment(
  'EMULATOR_HOST',
  defaultValue: '127.0.0.1',
);
const int kAuthEmulatorPort = int.fromEnvironment(
  'AUTH_EMULATOR_PORT',
  defaultValue: 9099,
);
const int kFirestoreEmulatorPort = int.fromEnvironment(
  'FIRESTORE_EMULATOR_PORT',
  defaultValue: 8180,
);

const FirebaseOptions kDemoEmulatorOptions = FirebaseOptions(
  apiKey: 'ADemoProjectApiKey000000000000000000000',
  appId: '1:1:android:1',
  messagingSenderId: '1',
  projectId: 'demo-arenapass',
);

/// Initializes the default demo Firebase app against the local Auth emulator.
/// On a physical USB device, forward ports via `adb reverse tcp:9099 tcp:9099`.
Future<CustomerAuthRepository> createLocalAuthRepository() async {
  final app = Firebase.apps.isEmpty
      ? await Firebase.initializeApp(options: kDemoEmulatorOptions)
      : Firebase.app();
  final auth = FirebaseAuth.instanceFor(app: app);
  await auth.useAuthEmulator(
    kEmulatorHost,
    kAuthEmulatorPort,
    automaticHostMapping: false,
  );
  return FirebaseCustomerAuthRepository(auth);
}

/// Initializes a Firestore-backed [ShowsRepository] against the local emulator.
/// Call after local Firebase initialization.
ShowsRepository createLocalShowsRepository() {
  final firestore = FirebaseFirestore.instance;
  firestore.settings = const Settings(persistenceEnabled: false);
  firestore.useFirestoreEmulator(
    kEmulatorHost,
    kFirestoreEmulatorPort,
    automaticHostMapping: false,
  );
  return FirestoreShowsRepository(firestore);
}

/// Registers the full local Customer emulator graph for integration tests.
Future<GetIt> createLocalCustomerServices() async {
  final authRepository = await createLocalAuthRepository();
  final shows = createLocalShowsRepository();
  return createLiveCustomerServices(
    auth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
    authRepository: authRepository,
    showsRepository: shows,
  );
}

/// Creates a named secondary Firebase app wired to local Auth + Firestore emulators.
Future<(FirebaseAuth, FirebaseFirestore)> createNamedEmulatorClient(
  String name,
) async {
  final options = Firebase.apps.isEmpty
      ? kDemoEmulatorOptions
      : Firebase.app().options;
  final app = Firebase.apps.any((existing) => existing.name == name)
      ? Firebase.app(name)
      : await Firebase.initializeApp(name: name, options: options);
  final auth = FirebaseAuth.instanceFor(app: app);
  await auth.useAuthEmulator(
    kEmulatorHost,
    kAuthEmulatorPort,
    automaticHostMapping: false,
  );
  final db = FirebaseFirestore.instanceFor(app: app);
  db.settings = const Settings(persistenceEnabled: false);
  db.useFirestoreEmulator(
    kEmulatorHost,
    kFirestoreEmulatorPort,
    automaticHostMapping: false,
  );
  return (auth, db);
}

/// Administrative fixture provisioning for a Vendor device document on the
/// local Firestore emulator.
Future<void> enrollVendorDeviceOnEmulator(String uid, String vendorId) async {
  final http = HttpClient();
  try {
    final req = await http.patchUrl(
      Uri.parse(
        'http://$kEmulatorHost:$kFirestoreEmulatorPort/v1/projects/demo-arenapass/databases/(default)/documents/vendorDevices/$uid',
      ),
    );
    req.headers.set('Authorization', 'Bearer owner');
    req.headers.contentType = ContentType.json;
    req.write(
      jsonEncode(<String, Object?>{
        'fields': <String, Object?>{
          'vendorId': <String, Object?>{'stringValue': vendorId},
          'enabled': <String, Object?>{'booleanValue': true},
        },
      }),
    );
    final res = await req.close();
    expect(res.statusCode, 200, reason: await utf8.decoder.bind(res).join());
  } finally {
    http.close(force: true);
  }
}
