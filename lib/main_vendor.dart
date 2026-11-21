import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/di/vendor_registration.dart';
import 'app/vendor/vendor_app.dart';

/// D01 startup gate: remains false until doctor approves anonymous identity +
/// admin allowlist enrollment and Vendor Firebase registration is completed.
const bool kVendorD01Approved = bool.fromEnvironment(
  'VENDOR_D01_APPROVED',
  defaultValue: false,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kVendorD01Approved ||
      kIsWeb ||
      defaultTargetPlatform != TargetPlatform.android) {
    runApp(createVendorApp());
    return;
  }
  try {
    final app = Firebase.apps.isEmpty
        ? await Firebase.initializeApp()
        : Firebase.app();
    final auth = FirebaseAuth.instanceFor(app: app);
    final firestore = FirebaseFirestore.instanceFor(app: app);
    runApp(
      createEnrolledVendorApp(
        services: createLocalVendorServices(auth: auth, firestore: firestore),
        banner: null,
      ),
    );
  } catch (_) {
    runApp(createVendorApp());
  }
}
