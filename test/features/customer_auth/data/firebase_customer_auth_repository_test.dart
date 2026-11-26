import 'package:e_commerce_project/features/customer_auth/data/repositories/firebase_customer_auth_repository.dart';
import 'package:e_commerce_project/features/customer_auth/domain/models/app_user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _UserCredential extends Fake implements UserCredential {}

class _Auth extends Fake implements FirebaseAuth {
  _Auth(this.users, {this.failOperations = true});
  final Stream<User?> users;
  final bool failOperations;
  (String email, String password)? lastLogin;
  (String email, String password)? lastRegister;
  int signOutCalls = 0;

  @override
  Stream<User?> authStateChanges() => users;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (failOperations) {
      throw FirebaseAuthException(
        code: 'invalid-credential',
        message: 'private SDK payload',
      );
    }
    await Future<void>.value();
    lastLogin = (email, password);
    return _UserCredential();
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (failOperations) {
      throw FirebaseAuthException(
        code: 'email-already-in-use',
        message: 'private SDK register payload',
      );
    }
    await Future<void>.value();
    lastRegister = (email, password);
    return _UserCredential();
  }

  @override
  Future<void> signOut() async {
    if (failOperations) {
      throw FirebaseAuthException(
        code: 'network-request-failed',
        message: 'private SDK logout payload',
      );
    }
    await Future<void>.value();
    signOutCalls++;
  }
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
    await expectLater(
      repository.register('customer@example.test', 'invalid'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'safe message',
          'Customer authentication failed.',
        ),
      ),
    );
    await expectLater(
      repository.logout(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'safe message',
          'Customer authentication failed.',
        ),
      ),
    );
  });

  test(
    'login, register, and logout forward arguments and await SDK calls',
    () async {
      final auth = _Auth(const Stream.empty(), failOperations: false);
      final repository = FirebaseCustomerAuthRepository(auth);

      await repository.login('customer@example.test', 'secret-pass');
      await repository.register('new@example.test', 'new-secret');
      await repository.logout();

      expect(auth.lastLogin, ('customer@example.test', 'secret-pass'));
      expect(auth.lastRegister, ('new@example.test', 'new-secret'));
      expect(auth.signOutCalls, 1);
    },
  );
}
