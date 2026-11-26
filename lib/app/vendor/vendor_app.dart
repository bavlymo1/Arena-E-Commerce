import '../di/vendor_registration.dart';
import '../startup/arena_pass_app.dart';

ArenaPassApp createVendorApp() =>
    ArenaPassApp(services: createVendorServices());
