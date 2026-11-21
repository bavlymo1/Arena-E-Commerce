import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../di/vendor_registration.dart';
import '../startup/arena_pass_app.dart';
import 'vendor_enrolled_app.dart';

ArenaPassApp createVendorApp() =>
    ArenaPassApp(services: createVendorServices());

/// Composes the enrolled Vendor app with explicit root DI and optional banner.
Widget createEnrolledVendorApp({
  required GetIt services,
  String? banner,
  bool canAddShow = true,
}) => VendorEnrolledApp(
  services: services,
  banner: banner,
  canAddShow: canAddShow,
);
