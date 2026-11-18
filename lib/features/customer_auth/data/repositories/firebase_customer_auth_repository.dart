import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/models/app_user.dart';
import '../../domain/repositories/customer_auth_repository.dart';

/// Owns no SDK singleton. Its composition root owns Firebase and subscriptions.
final class FirebaseCustomerAuthRepository implements CustomerAuthRepository {
  FirebaseCustomerAuthRepository(this._auth);
  final FirebaseAuth _auth;

  @override
  Stream<AppUser?> authChanges() => _auth.authStateChanges().map((user) {
    if (user == null ||
        user.isAnonymous ||
        !user.providerData.any(
          (provider) => provider.providerId == 'password',
        )) {
      return null;
    }
    final email = user.email;
    if (email == null || email.trim().isEmpty) return null;
    return AppUser(uid: user.uid, email: email);
  });

  @override
  Future<void> register(String email, String password) => _perform(() async {
    await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  });

  @override
  Future<void> login(String email, String password) => _perform(() async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  });

  @override
  Future<void> logout() => _perform(_auth.signOut);

  Future<void> _perform(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException {
      // The domain has no typed failure contract. Never expose SDK payloads.
      throw StateError('Customer authentication failed.');
    }
  }
}
