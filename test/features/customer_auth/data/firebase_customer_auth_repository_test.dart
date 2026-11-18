import 'package:e_commerce_project/features/customer_auth/data/repositories/firebase_customer_auth_repository.dart';
import 'package:e_commerce_project/features/customer_auth/domain/models/app_user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth extends Fake implements FirebaseAuth {
  _Auth(this.users);
  final Stream<User?> users;
  @override
  Stream<User?> authStateChanges() => users;
  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async => throw FirebaseAuthException(
    code: 'invalid-credential',
    message: 'private SDK payload',
  );
}

class _User extends Fake implements User {
  _User({
    this.isAnonymous = false,
    this.email = 'customer@example.test',
    this.passwordProvider = true,
  });
  @override
  final bool isAnonymous;
  @override
  final String? email;
  final bool passwordProvider;
  @override
  String get uid => 'customer-a';
  @override
  List<UserInfo> get providerData => [
    _Provider(passwordProvider ? 'password' : 'google.com'),
  ];
}

class _Provider extends Fake implements UserInfo {
  _Provider(this.providerId);
  @override
  final String providerId;
}

void main() {
  test('only password-provider customers cross the data boundary', () async {
    final repository = FirebaseCustomerAuthRepository(
      _Auth(
        Stream.fromIterable([
          null,
          _User(isAnonymous: true),
          _User(passwordProvider: false),
          _User(email: null),
          _User(email: ' '),
          _User(),
        ]),
      ),
    );
    expect(await repository.authChanges().toList(), [
      null,
      null,
      null,
      null,
      null,
      AppUser(uid: 'customer-a', email: 'customer@example.test'),
    ]);
  });
  test('invalid credentials do not leak SDK exceptions or payloads', () async {
    final repository = FirebaseCustomerAuthRepository(
      _Auth(const Stream.empty()),
    );
    await expectLater(
      repository.login('customer@example.test', 'invalid'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'safe message',
          'Customer authentication failed.',
        ),
      ),
    );
  });
}
