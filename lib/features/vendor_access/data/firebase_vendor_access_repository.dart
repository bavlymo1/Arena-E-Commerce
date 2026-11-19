import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/models/vendor_access.dart';
import '../domain/repositories/vendor_access_repository.dart';

/// Enrollment proposal for explicit local testing while D01 is open.
final class FirebaseVendorAccessRepository implements VendorAccessRepository {
  FirebaseVendorAccessRepository(this._auth, this._firestore);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  Future<VendorAccess> check() async {
    final user = _auth.currentUser ?? (await _auth.signInAnonymously()).user!;
    if (!user.isAnonymous) return VendorNotEnrolled(uid: user.uid);

    final enrollment = await _firestore
        .collection('vendorDevices')
        .doc(user.uid)
        .get(const GetOptions(source: Source.server));
    if (_auth.currentUser?.uid != user.uid) {
      throw StateError('Vendor identity changed during enrollment check');
    }
    final data = enrollment.data();
    final vendorId = data?['vendorId'];
    if (data?['enabled'] == true &&
        vendorId is String &&
        vendorId.trim().isNotEmpty) {
      return VendorAllowed(uid: user.uid, vendorId: vendorId);
    }
    return VendorNotEnrolled(uid: user.uid);
  }
}
