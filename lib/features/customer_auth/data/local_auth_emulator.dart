import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../domain/repositories/customer_auth_repository.dart';
import 'repositories/firebase_customer_auth_repository.dart';

/// Explicit local-only bootstrap. On a USB device, use adb reverse tcp:9099.
Future<CustomerAuthRepository> createLocalAuthRepository() async {
  // FlutterFire Firestore's platform delegate requires a default Firebase app.
  final app = await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'ADemoProjectApiKey000000000000000000000',
      appId: '1:1:android:1',
      messagingSenderId: '1',
      projectId: 'demo-arenapass',
    ),
  );
  final auth = FirebaseAuth.instanceFor(app: app);
  await auth.useAuthEmulator('127.0.0.1', 9099, automaticHostMapping: false);
  return FirebaseCustomerAuthRepository(auth);
}
