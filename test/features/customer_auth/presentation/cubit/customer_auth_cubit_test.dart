import 'dart:async';

import 'package:e_commerce_project/features/customer_auth/domain/models/app_user.dart';
import 'package:e_commerce_project/features/customer_auth/domain/repositories/customer_auth_repository.dart';
import 'package:e_commerce_project/features/customer_auth/presentation/cubit/customer_auth_cubit.dart';
import 'package:e_commerce_project/features/customer_auth/presentation/cubit/customer_auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

final class _ScriptedCustomerAuthRepository implements CustomerAuthRepository {
  _ScriptedCustomerAuthRepository({
    Future<void> Function()? onCancel,
    this.throwOnAuthChanges = false,
  }) : controller = StreamController<AppUser?>(onCancel: onCancel);

  StreamController<AppUser?> controller;
  bool throwOnAuthChanges;
  int authChangesCalls = 0;

  final List<({String email, String password})> loginCalls =
      <({String email, String password})>[];
  final List<({String email, String password})> registerCalls =
      <({String email, String password})>[];
  int logoutCalls = 0;

  Future<void> Function(String email, String password)? loginHandler;
  Future<void> Function(String email, String password)? registerHandler;
  Future<void> Function()? logoutHandler;
  bool disposed = false;

  @override
  Stream<AppUser?> authChanges() {
    if (throwOnAuthChanges) {
      throw StateError('Auth stream unavailable');
    }
    authChangesCalls++;
    return controller.stream;
  }

  @override
  Future<void> login(String email, String password) {
    loginCalls.add((email: email, password: password));
    if (loginHandler != null) {
      return loginHandler!(email, password);
    }
    return Future<void>.value();
  }

  @override
  Future<void> register(String email, String password) {
    registerCalls.add((email: email, password: password));
    if (registerHandler != null) {
      return registerHandler!(email, password);
    }
    return Future<void>.value();
  }

  @override
  Future<void> logout() {
    logoutCalls++;
    if (logoutHandler != null) {
      return logoutHandler!();
    }
    return Future<void>.value();
  }

  void dispose() {
    disposed = true;
    unawaited(controller.close());
  }
}

void main() {
  test('starts in checking state and tracks signedOut and signedIn from auth stream', () async {
    final repo = _ScriptedCustomerAuthRepository();
    addTearDown(repo.dispose);

    final cubit = CustomerAuthCubit(repo);
    addTearDown(cubit.close);

    expect(cubit.state.status, CustomerAuthStatus.checking);
    expect(cubit.state.user, isNull);
    expect(cubit.state.busy, isFalse);

    await pumpEventQueue();
    expect(repo.authChangesCalls, 1);

    repo.controller.add(null);
    await pumpEventQueue();
    expect(cubit.state.status, CustomerAuthStatus.signedOut);
    expect(cubit.state.user, isNull);

    final user = AppUser(uid: 'cust-1', email: 'alex@example.test');
    repo.controller.add(user);
    await pumpEventQueue();
    expect(cubit.state.status, CustomerAuthStatus.signedIn);
    expect(cubit.state.user, user);

    repo.controller.add(null);
    await pumpEventQueue();
    expect(cubit.state.status, CustomerAuthStatus.signedOut);
    expect(cubit.state.user, isNull);
  });

  test('coalesces chained start() call on auto-started cubit without double listen', () async {
    final repo = _ScriptedCustomerAuthRepository();
    addTearDown(repo.dispose);

    final cubit = CustomerAuthCubit(repo)..start();
    addTearDown(cubit.close);

    await pumpEventQueue();
    expect(repo.authChangesCalls, 1);

    repo.controller.add(null);
    await pumpEventQueue();
    expect(cubit.state.status, CustomerAuthStatus.signedOut);

    await cubit.start();
    expect(repo.authChangesCalls, 1);
  });

  test('login and register trim email, keep password verbatim, and require auth stream for signedIn', () async {
    final loginCompleter = Completer<void>();
    final registerCompleter = Completer<void>();
    final repo = _ScriptedCustomerAuthRepository();
    repo.loginHandler = (_, _) => loginCompleter.future;
    repo.registerHandler = (_, _) => registerCompleter.future;
    addTearDown(repo.dispose);

    final cubit = CustomerAuthCubit(repo);
    addTearDown(cubit.close);
    await pumpEventQueue();
    repo.controller.add(null);
    await pumpEventQueue();

    final loginFuture = cubit.login('  alex@example.test ', '  secret123  ');
    expect(cubit.state.busy, isTrue);
    expect(cubit.state.errorMessage, isNull);
    expect(repo.loginCalls, <({String email, String password})>[
      (email: 'alex@example.test', password: '  secret123  '),
    ]);

    loginCompleter.complete();
    await loginFuture;
    // Completed Future alone must not invent signedIn before stream emits.
    expect(cubit.state.busy, isFalse);
    expect(cubit.state.status, CustomerAuthStatus.signedOut);
    expect(cubit.state.user, isNull);

    final user = AppUser(uid: 'cust-1', email: 'alex@example.test');
    repo.controller.add(user);
    await pumpEventQueue();
    expect(cubit.state.status, CustomerAuthStatus.signedIn);
    expect(cubit.state.user, user);

    // Register also waits for auth stream rather than inventing signedIn.
    repo.controller.add(null);
    await pumpEventQueue();
    final registerFuture = cubit.register(
      '  jordan@example.test ',
      'pass-word',
    );
    expect(cubit.state.busy, isTrue);
    expect(repo.registerCalls, <({String email, String password})>[
      (email: 'jordan@example.test', password: 'pass-word'),
    ]);

    registerCompleter.complete();
    await registerFuture;
    expect(cubit.state.busy, isFalse);
    expect(cubit.state.status, CustomerAuthStatus.signedOut);
  });

  test(
    'validation failures emit safe messages without calling repository',
    () async {
      final repo = _ScriptedCustomerAuthRepository();
      addTearDown(repo.dispose);

      final cubit = CustomerAuthCubit(repo);
      addTearDown(cubit.close);
      await pumpEventQueue();
      repo.controller.add(null);
      await pumpEventQueue();

      await cubit.login('   ', 'secret');
      expect(cubit.state.status, CustomerAuthStatus.signedOut);
      expect(cubit.state.errorMessage, CustomerAuthCubit.emailRequiredMessage);

      await cubit.login('not-an-email', 'secret');
      expect(cubit.state.errorMessage, CustomerAuthCubit.emailInvalidMessage);

      await cubit.login('alex@example.test', '');
      expect(
        cubit.state.errorMessage,
        CustomerAuthCubit.passwordRequiredMessage,
      );

      await cubit.register('bad', '');
      expect(cubit.state.errorMessage, CustomerAuthCubit.emailInvalidMessage);

      expect(repo.loginCalls, isEmpty);
      expect(repo.registerCalls, isEmpty);
    },
  );

  test('maps repository failures to safe action-specific messages without leaking secrets', () async {
    const secretPassword = 'super-secret-password-987';
    const internalDetail = 'firebase-internal-detail-token';
    final repo = _ScriptedCustomerAuthRepository();
    repo.loginHandler = (_, _) async =>
        throw Exception('$internalDetail $secretPassword');
    repo.registerHandler = (_, _) async =>
        throw StateError('$internalDetail $secretPassword');
    repo.logoutHandler = () async => throw Exception(internalDetail);
    addTearDown(repo.dispose);

    final cubit = CustomerAuthCubit(repo);
    addTearDown(cubit.close);
    await pumpEventQueue();
    repo.controller.add(null);
    await pumpEventQueue();

    await cubit.login('alex@example.test', secretPassword);
    expect(cubit.state.busy, isFalse);
    expect(cubit.state.status, CustomerAuthStatus.signedOut);
    expect(cubit.state.errorMessage, CustomerAuthCubit.loginErrorMessage);
    expect(cubit.state.errorMessage, isNot(contains(secretPassword)));
    expect(cubit.state.errorMessage, isNot(contains(internalDetail)));

    await cubit.register('alex@example.test', secretPassword);
    expect(cubit.state.busy, isFalse);
    expect(cubit.state.errorMessage, CustomerAuthCubit.registerErrorMessage);
    expect(cubit.state.errorMessage, isNot(contains(secretPassword)));
    expect(cubit.state.errorMessage, isNot(contains(internalDetail)));

    repo.controller.add(AppUser(uid: 'cust-1', email: 'alex@example.test'));
    await pumpEventQueue();

    await cubit.logout();
    expect(cubit.state.busy, isFalse);
    expect(cubit.state.status, CustomerAuthStatus.signedIn);
    expect(cubit.state.errorMessage, CustomerAuthCubit.logoutErrorMessage);
    expect(cubit.state.errorMessage, isNot(contains(internalDetail)));
  });

  test(
    'prevents duplicate submits while busy across login, register, and logout',
    () async {
      final gate = Completer<void>();
      final repo = _ScriptedCustomerAuthRepository()
        ..loginHandler = (_, _) => gate.future;
      addTearDown(repo.dispose);

      final cubit = CustomerAuthCubit(repo);
      addTearDown(cubit.close);
      await pumpEventQueue();
      repo.controller.add(null);
      await pumpEventQueue();

      final first = cubit.login('alex@example.test', 'secret');
      final duplicateLogin = cubit.login('jordan@example.test', 'other');
      final duplicateRegister = cubit.register('jordan@example.test', 'other');
      final duplicateLogout = cubit.logout();

      expect(repo.loginCalls, hasLength(1));
      expect(repo.registerCalls, isEmpty);
      expect(repo.logoutCalls, 0);

      gate.complete();
      await Future.wait<void>(<Future<void>>[
        first,
        duplicateLogin,
        duplicateRegister,
        duplicateLogout,
      ]);

      expect(cubit.state.busy, isFalse);
    },
  );

  test('auth stream error transitions to error and retry awaits cleanup and coalesces', () async {
    final released = Completer<void>();
    final repo = _ScriptedCustomerAuthRepository(
      onCancel: () => released.future,
    );
    addTearDown(repo.dispose);

    final cubit = CustomerAuthCubit(repo);
    addTearDown(cubit.close);
    await pumpEventQueue();

    repo.controller.addError(StateError('Stream dropped'));
    await pumpEventQueue();
    expect(cubit.state.status, CustomerAuthStatus.error);
    expect(cubit.state.errorMessage, CustomerAuthCubit.streamErrorMessage);

    final oldController = repo.controller;
    repo.controller = StreamController<AppUser?>();

    final retryOne = cubit.retry();
    final retryTwo = cubit.retry();
    expect(cubit.state.status, CustomerAuthStatus.checking);
    expect(cubit.state.errorMessage, isNull);
    await pumpEventQueue();

    try {
      expect(repo.authChangesCalls, 1);
    } finally {
      released.complete();
      await Future.wait<void>(<Future<void>>[retryOne, retryTwo]);
      await oldController.close();
    }

    expect(repo.authChangesCalls, 2);
    final recovered = AppUser(uid: 'cust-1', email: 'alex@example.test');
    repo.controller.add(recovered);
    await pumpEventQueue();
    expect(cubit.state.status, CustomerAuthStatus.signedIn);
    expect(cubit.state.user, recovered);
  });

  test('handles synchronous authChanges() failure cleanly', () async {
    final repo = _ScriptedCustomerAuthRepository(throwOnAuthChanges: true);
    addTearDown(repo.dispose);

    final cubit = CustomerAuthCubit(repo, autoStart: false);
    addTearDown(cubit.close);

    await cubit.start();
    expect(cubit.state.status, CustomerAuthStatus.error);
    expect(cubit.state.errorMessage, CustomerAuthCubit.streamErrorMessage);
  });

  test('ignores late operation errors and completions after newer auth events or close', () async {
    final pendingLogout = Completer<void>();
    final pendingLogin = Completer<void>();
    final released = Completer<void>();

    final repo = _ScriptedCustomerAuthRepository(
      onCancel: () => released.future,
    );
    addTearDown(repo.dispose);

    final cubit = CustomerAuthCubit(repo);
    await pumpEventQueue();

    final alice = AppUser(uid: 'alice', email: 'alice@example.test');
    final bob = AppUser(uid: 'bob', email: 'bob@example.test');
    repo.controller.add(alice);
    await pumpEventQueue();

    // 1. Logout is in flight, then stream switches directly to another user and
    // the stale logout future fails late -> must NOT overwrite signedIn bob.
    repo.logoutHandler = () => pendingLogout.future;
    final logoutFuture = cubit.logout();
    expect(cubit.state.busy, isTrue);

    repo.controller.add(bob);
    await pumpEventQueue();
    expect(cubit.state.status, CustomerAuthStatus.signedIn);
    expect(cubit.state.user, bob);
    expect(cubit.state.busy, isFalse);

    pendingLogout.completeError(StateError('Late logout failure'));
    await logoutFuture;
    expect(cubit.state.status, CustomerAuthStatus.signedIn);
    expect(cubit.state.user, bob);
    expect(cubit.state.errorMessage, isNull);

    // 2. Login is in flight, then stream signs out / emits null, then login
    // fails late -> must NOT emit stale login error after new auth event.
    repo.controller.add(null);
    await pumpEventQueue();
    repo.loginHandler = (_, _) => pendingLogin.future;
    final loginFuture = cubit.login('alice@example.test', 'password');
    expect(cubit.state.busy, isTrue);

    repo.controller.add(alice);
    await pumpEventQueue();
    expect(cubit.state.status, CustomerAuthStatus.signedIn);
    expect(cubit.state.user, alice);
    expect(cubit.state.busy, isFalse);

    pendingLogin.completeError(StateError('Late login error'));
    await loginFuture;
    expect(cubit.state.status, CustomerAuthStatus.signedIn);
    expect(cubit.state.user, alice);
    expect(cubit.state.errorMessage, isNull);

    // 2b. Register is in flight, stream emits sign-out (null), and late
    // completion arrives after stream reset -> must not emit stale state.
    final pendingRegister = Completer<void>();
    repo.registerHandler = (_, _) => pendingRegister.future;
    repo.controller.add(null);
    await pumpEventQueue();
    final registerFuture = cubit.register('alice@example.test', 'password');
    expect(cubit.state.busy, isTrue);

    repo.controller.add(null);
    await pumpEventQueue();
    expect(cubit.state.status, CustomerAuthStatus.signedOut);
    expect(cubit.state.busy, isFalse);

    pendingRegister.complete();
    await registerFuture;
    expect(cubit.state.status, CustomerAuthStatus.signedOut);
    expect(cubit.state.busy, isFalse);
    expect(cubit.state.errorMessage, isNull);

    // 3. Close waits for delayed cancellation, ignores late operations, and
    // does not dispose the app-scoped repository.
    final closeLoginCompleter = Completer<void>();
    repo.loginHandler = (_, _) => closeLoginCompleter.future;
    repo.controller.add(null);
    await pumpEventQueue();
    final inFlightAtClose = cubit.login('alice@example.test', 'password');

    var closed = false;
    final closing = cubit.close().then((_) => closed = true);
    await pumpEventQueue();
    try {
      expect(closed, isFalse);
    } finally {
      released.complete();
      await closing;
    }

    expect(closed, isTrue);
    expect(cubit.isClosed, isTrue);
    expect(repo.disposed, isFalse);

    closeLoginCompleter.completeError(StateError('After close'));
    await inFlightAtClose;
    expect(cubit.state.errorMessage, isNull);
  });

  test('close completes cleanly even when auth stream cancel fails', () async {
    final repo = _ScriptedCustomerAuthRepository(
      onCancel: () => Future<void>.error(StateError('cancel failed')),
    );
    addTearDown(repo.dispose);

    final cubit = CustomerAuthCubit(repo);
    await pumpEventQueue();

    await expectLater(cubit.close(), completes);
    expect(cubit.isClosed, isTrue);
  });

  test('retry and close recover cleanly without poisoning _cancellation when prior cancel fails', () async {
    var cancels = 0;
    final repo = _ScriptedCustomerAuthRepository(
      onCancel: () {
        cancels++;
        if (cancels == 1) {
          return Future<void>.error(StateError('cancel failed'));
        }
        return Future<void>.value();
      },
    );
    addTearDown(repo.dispose);

    final cubit = CustomerAuthCubit(repo);
    addTearDown(cubit.close);
    await pumpEventQueue();

    repo.controller.addError(StateError('Stream dropped'));
    await pumpEventQueue();
    expect(cubit.state.status, CustomerAuthStatus.error);

    final oldController = repo.controller;
    repo.controller = StreamController<AppUser?>();

    await expectLater(cubit.retry(), completes);
    await oldController.close();

    expect(repo.authChangesCalls, 2);
    final user = AppUser(uid: 'cust-1', email: 'alex@example.test');
    repo.controller.add(user);
    await pumpEventQueue();
    expect(cubit.state.status, CustomerAuthStatus.signedIn);
    expect(cubit.state.user, user);

    await expectLater(cubit.close(), completes);
  });

  test('clearError clears transient operation and validation errors while ignoring busy, null, and stream errors', () async {
    final repo = _ScriptedCustomerAuthRepository()
      ..loginHandler = ((_, _) async => throw StateError('Invalid credentials'))
      ..registerHandler = ((_, _) async =>
          throw StateError('Email already registered'))
      ..logoutHandler = (() async => throw StateError('Logout error'));
    addTearDown(repo.dispose);

    final cubit = CustomerAuthCubit(repo);
    addTearDown(cubit.close);
    final emitted = <CustomerAuthState>[];
    final sub = cubit.stream.listen(emitted.add);
    addTearDown(sub.cancel);

    await pumpEventQueue();
    repo.controller.add(null);
    await pumpEventQueue();

    // No-op when errorMessage is null.
    final countBeforeNull = emitted.length;
    cubit.clearError();
    await pumpEventQueue();
    expect(emitted, hasLength(countBeforeNull));
    expect(cubit.state.errorMessage, isNull);

    // Clears validation error.
    await cubit.login('not-an-email', 'secret');
    expect(cubit.state.errorMessage, CustomerAuthCubit.emailInvalidMessage);
    cubit.clearError();
    expect(cubit.state.errorMessage, isNull);
    expect(cubit.state.status, CustomerAuthStatus.signedOut);

    // Clears login operation error.
    await cubit.login('alex@example.test', 'secret');
    expect(cubit.state.errorMessage, CustomerAuthCubit.loginErrorMessage);
    cubit.clearError();
    expect(cubit.state.errorMessage, isNull);
    expect(cubit.state.status, CustomerAuthStatus.signedOut);

    // Clears register operation error.
    await cubit.register('alex@example.test', 'secret');
    expect(cubit.state.errorMessage, CustomerAuthCubit.registerErrorMessage);
    cubit.clearError();
    expect(cubit.state.errorMessage, isNull);
    expect(cubit.state.status, CustomerAuthStatus.signedOut);

    // Clears logout operation error while signed in.
    repo.controller.add(AppUser(uid: 'cust-1', email: 'alex@example.test'));
    await pumpEventQueue();
    await cubit.logout();
    expect(cubit.state.errorMessage, CustomerAuthCubit.logoutErrorMessage);
    cubit.clearError();
    expect(cubit.state.errorMessage, isNull);
    expect(cubit.state.status, CustomerAuthStatus.signedIn);

    // No-op while busy.
    repo.controller.add(null);
    await pumpEventQueue();
    final busyGate = Completer<void>();
    repo.loginHandler = (_, _) => busyGate.future;
    final busyLogin = cubit.login('alex@example.test', 'secret');
    await pumpEventQueue();
    expect(cubit.state.busy, isTrue);
    final countWhileBusy = emitted.length;
    cubit.clearError();
    await pumpEventQueue();
    expect(emitted, hasLength(countWhileBusy));
    expect(cubit.state.busy, isTrue);
    busyGate.complete();
    await busyLogin;

    // Leaves CustomerAuthStatus.error (streamErrorMessage) untouched.
    repo.controller.addError(StateError('Stream dropped'));
    await pumpEventQueue();
    expect(cubit.state.hasError, isTrue);
    expect(cubit.state.errorMessage, CustomerAuthCubit.streamErrorMessage);
    final countOnStreamError = emitted.length;
    cubit.clearError();
    await pumpEventQueue();
    expect(emitted, hasLength(countOnStreamError));
    expect(cubit.state.hasError, isTrue);
    expect(cubit.state.errorMessage, CustomerAuthCubit.streamErrorMessage);

    // Safe no-op after close.
    await cubit.close();
    expect(() => cubit.clearError(), returnsNormally);
  });
}
