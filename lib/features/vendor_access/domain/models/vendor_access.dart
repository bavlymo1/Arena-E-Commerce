/// The identity/enrollment proposal does not itself grant backend access.
sealed class VendorAccess {
  VendorAccess({required this.uid}) {
    if (uid.trim().isEmpty) throw ArgumentError.value(uid, 'uid');
  }

  final String uid;
}

final class VendorAllowed extends VendorAccess {
  VendorAllowed({required super.uid, required this.vendorId}) {
    if (vendorId.trim().isEmpty) {
      throw ArgumentError.value(vendorId, 'vendorId');
    }
  }

  final String vendorId;
}

final class VendorNotEnrolled extends VendorAccess {
  VendorNotEnrolled({required super.uid});
}
