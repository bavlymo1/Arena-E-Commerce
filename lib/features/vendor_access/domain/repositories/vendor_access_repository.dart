import '../models/vendor_access.dart';

abstract interface class VendorAccessRepository {
  /// Identity/enrollment failures remain errors, never an allowed result.
  Future<VendorAccess> check();
}
