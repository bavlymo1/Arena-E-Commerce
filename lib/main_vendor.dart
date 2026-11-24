import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/di/shared_registration.dart';
import 'app/di/vendor_registration.dart';
import 'app/startup/app_variant.dart';
import 'app/startup/arena_pass_app.dart';
import 'app/vendor/vendor_app.dart';
import 'app/vendor/vendor_enrolled_app.dart';
import 'firebase_options_vendor.dart';

/// D01 startup gate: remains false until doctor approves anonymous identity +
/// admin allowlist enrollment and live deployment is authorized.
///
/// Removal path once live prerequisites are verified:
/// 1. Set `kVendorD01Approved` default to `true` (or remove the gate branch).
/// 2. Remove `lib/app/startup/` + `createVendorServices()` only when no startup
///    gate or fallback uses `ArenaPassApp`, keeping a minimal retryable startup
///    error widget for `Firebase.initializeApp` failures.
const bool kVendorD01Approved = bool.fromEnvironment(
  'VENDOR_D01_APPROVED',
  defaultValue: false,
);

const String _vendorStartupErrorMessage =
    'ArenaPass Vendor could not initialize cloud services. '
    'Check your connection and retry.';

Future<String> _launchVendor() async {
  try {
    final app = Firebase.apps.isEmpty
        ? await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          )
        : Firebase.app();
    final auth = FirebaseAuth.instanceFor(app: app);
    final firestore = FirebaseFirestore.instanceFor(app: app);
    runApp(
      VendorEnrolledApp(
        services: createLiveVendorServices(auth: auth, firestore: firestore),
      ),
    );
    return '';
  } catch (_) {
    return _vendorStartupErrorMessage;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kVendorD01Approved ||
      kIsWeb ||
      defaultTargetPlatform != TargetPlatform.android) {
    runApp(createVendorApp());
    return;
  }
  final errorMessage = await _launchVendor();
  if (errorMessage.isNotEmpty) {
    runApp(
      ArenaPassApp(
        startupTitle: 'Startup failed',
        services: createStartupErrorServices(
          AppVariant.vendor,
          initialError: errorMessage,
          retryLaunch: _launchVendor,
        ),
      ),
    );
  }
}
