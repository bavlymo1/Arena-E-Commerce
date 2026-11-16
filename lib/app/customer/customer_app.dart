import '../di/customer_registration.dart';
import '../startup/arena_pass_app.dart';

ArenaPassApp createCustomerApp() =>
    ArenaPassApp(services: createCustomerServices());
