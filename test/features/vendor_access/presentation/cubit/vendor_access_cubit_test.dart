import 'dart:async';

import 'package:e_commerce_project/features/vendor_access/domain/models/vendor_access.dart';
import 'package:e_commerce_project/features/vendor_access/domain/repositories/vendor_access_repository.dart';
import 'package:e_commerce_project/features/vendor_access/presentation/cubit/vendor_access_cubit.dart';
import 'package:e_commerce_project/features/vendor_access/presentation/cubit/vendor_access_state.dart';
import 'package:e_commerce_project/features/vendor_access/presentation/vendor_access_strings.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeVendorAccessRepository implements VendorAccessRepository {
  int checkCalls = 0;
  Future<VendorAccess> Function()? onCheck;

  @override
  Future<VendorAccess> check() {
    checkCalls++;
    final handler = onCheck;
    if (handler != null) {
      return handler();
    }
    return Future<VendorAccess>.value(VendorNotEnrolled(uid: 'default-uid'));
  }
}

void main() {
  test(
    'autoStart: false stays in AccessChecking without calling check',
    () async {
      final repo = _FakeVendorAccessRepository();
      final cubit = VendorAccessCubit(repo, autoStart: false);
      addTearDown(cubit.close);

      expect(cubit.state, const AccessChecking());
      await pumpEventQueue();
      expect(repo.checkCalls, 0);
    },
  );

  test('autoStart transitions AccessChecking -> AccessAllowed', () async {
    final gate = Completer<VendorAccess>();
    final repo = _FakeVendorAccessRepository()..onCheck = () => gate.future;
    final cubit = VendorAccessCubit(repo);
    addTearDown(cubit.close);

    expect(cubit.state, const AccessChecking());
    expect(repo.checkCalls, 1);

    gate.complete(VendorAllowed(uid: 'vendor-uid-1', vendorId: 'arena'));
    await pumpEventQueue();

    expect(cubit.state, const AccessAllowed('arena'));
  });

  test(
    'transitions AccessChecking -> AccessNotEnrolled and retries to allowed',
    () async {
      var attempt = 0;
      final repo = _FakeVendorAccessRepository()
        ..onCheck = () async {
          attempt++;
          if (attempt == 1) {
            return VendorNotEnrolled(uid: 'device-uid-42');
          }
          return VendorAllowed(uid: 'device-uid-42', vendorId: 'arena');
        };
      final cubit = VendorAccessCubit(repo, autoStart: false);
      addTearDown(cubit.close);

      final emitted = <VendorAccessState>[];
      final sub = cubit.stream.listen(emitted.add);
      addTearDown(sub.cancel);

      await cubit.check();
      expect(cubit.state, const AccessNotEnrolled('device-uid-42'));

      await cubit.retry();
      await pumpEventQueue();
      expect(cubit.state, const AccessAllowed('arena'));
      expect(emitted, const <VendorAccessState>[
        AccessNotEnrolled('device-uid-42'),
        AccessChecking(),
        AccessAllowed('arena'),
      ]);
    },
  );

  test('maps repository exceptions to safe constant error and supports retry from error and allowed', () async {
    var mode = 'throw-state';
    final repo = _FakeVendorAccessRepository()
      ..onCheck = () {
        return switch (mode) {
          'throw-state' => Future<VendorAccess>.error(
            StateError('firebase-secret-stack-detail'),
          ),
          'throw-sync' => throw Exception('raw socket failure'),
          'not-enrolled' => Future<VendorAccess>.value(
            VendorNotEnrolled(uid: 'uid-retry'),
          ),
          _ => Future<VendorAccess>.value(
            VendorAllowed(uid: 'uid-retry', vendorId: 'arena'),
          ),
        };
      };
    final cubit = VendorAccessCubit(repo, autoStart: false);
    addTearDown(cubit.close);

    await cubit.check();
    expect(
      cubit.state,
      const AccessError(VendorAccessStrings.checkErrorMessage),
    );
    expect((cubit.state as AccessError).message, isNot(contains('firebase')));

    // Retry from error (including synchronous throw path).
    mode = 'throw-sync';
    await cubit.retry();
    expect(
      cubit.state,
      const AccessError(VendorAccessStrings.checkErrorMessage),
    );
    expect((cubit.state as AccessError).message, isNot(contains('socket')));

    // Retry from error -> allowed.
    mode = 'allowed';
    await cubit.retry();
    await pumpEventQueue();
    expect(cubit.state, const AccessAllowed('arena'));

    // Retry from allowed -> not enrolled.
    mode = 'not-enrolled';
    await cubit.retry();
    expect(cubit.state, const AccessNotEnrolled('uid-retry'));
  });

  test(
    'ignores concurrent check() and retry() calls while check is in flight',
    () async {
      final gate1 = Completer<VendorAccess>();
      final gate2 = Completer<VendorAccess>();
      var call = 0;
      final repo = _FakeVendorAccessRepository()
        ..onCheck = () {
          call++;
          return call == 1 ? gate1.future : gate2.future;
        };
      final cubit = VendorAccessCubit(repo);
      addTearDown(cubit.close);

      expect(repo.checkCalls, 1);

      // Concurrent check() and retry() while still checking must be ignored.
      await cubit.check();
      await cubit.retry();
      expect(repo.checkCalls, 1);
      expect(cubit.state, const AccessChecking());

      gate1.complete(VendorNotEnrolled(uid: 'uid-1'));
      await pumpEventQueue();
      expect(cubit.state, const AccessNotEnrolled('uid-1'));

      // Once settled, a new retry triggers another check.
      final retryFuture = cubit.retry();
      expect(repo.checkCalls, 2);
      expect(cubit.state, const AccessChecking());
      // Another call while second check is in flight is ignored.
      await cubit.retry();
      expect(repo.checkCalls, 2);

      gate2.complete(VendorAllowed(uid: 'uid-1', vendorId: 'arena'));
      await retryFuture;
      expect(cubit.state, const AccessAllowed('arena'));
    },
  );

  test('ignores late success or error completion after close()', () async {
    final successGate = Completer<VendorAccess>();
    final repoSuccess = _FakeVendorAccessRepository()
      ..onCheck = () => successGate.future;
    final cubit1 = VendorAccessCubit(repoSuccess);
    final emitted1 = <VendorAccessState>[];
    final sub1 = cubit1.stream.listen(emitted1.add);
    addTearDown(sub1.cancel);

    await cubit1.close();
    successGate.complete(VendorAllowed(uid: 'uid-late', vendorId: 'arena'));
    await pumpEventQueue();
    expect(emitted1, isEmpty);

    // Also verify late error after close does not emit or throw.
    final errorGate = Completer<VendorAccess>();
    final repoError = _FakeVendorAccessRepository()
      ..onCheck = () => errorGate.future;
    final cubit2 = VendorAccessCubit(repoError);
    final emitted2 = <VendorAccessState>[];
    final sub2 = cubit2.stream.listen(emitted2.add);
    addTearDown(sub2.cancel);

    await cubit2.close();
    errorGate.completeError(StateError('late error'));
    await pumpEventQueue();
    expect(emitted2, isEmpty);

    // Calling check/retry after close is a safe no-op.
    await cubit2.check();
    await cubit2.retry();
    expect(repoError.checkCalls, 1);
  });

  test('VendorAccessState subclasses implement value equality', () {
    expect(const AccessChecking(), equals(const AccessChecking()));
    expect(const AccessAllowed('a'), equals(const AccessAllowed('a')));
    expect(const AccessAllowed('a'), isNot(equals(const AccessAllowed('b'))));
    expect(
      const AccessNotEnrolled('u1'),
      equals(const AccessNotEnrolled('u1')),
    );
    expect(
      const AccessNotEnrolled('u1'),
      isNot(equals(const AccessNotEnrolled('u2'))),
    );
    expect(const AccessError('e1'), equals(const AccessError('e1')));
    expect(const AccessError('e1'), isNot(equals(const AccessError('e2'))));
  });

  test('close() during pending check() blocks immediate and late emissions on success or error', () async {
    final successGate = Completer<VendorAccess>();
    final repoSuccess = _FakeVendorAccessRepository()
      ..onCheck = () => successGate.future;
    final cubit1 = VendorAccessCubit(repoSuccess);
    final emitted1 = <VendorAccessState>[];
    final sub1 = cubit1.stream.listen(emitted1.add);
    addTearDown(sub1.cancel);

    // Unawaited close() synchronously marks cubit closed before check resolves.
    final closing1 = cubit1.close();
    expect(cubit1.isClosed, isTrue);
    successGate.complete(VendorAllowed(uid: 'uid-mid', vendorId: 'arena'));
    await closing1;
    await pumpEventQueue();
    expect(emitted1, isEmpty);

    final errorGate = Completer<VendorAccess>();
    final repoError = _FakeVendorAccessRepository()
      ..onCheck = () => errorGate.future;
    final cubit2 = VendorAccessCubit(repoError);
    final emitted2 = <VendorAccessState>[];
    final sub2 = cubit2.stream.listen(emitted2.add);
    addTearDown(sub2.cancel);

    final closing2 = cubit2.close();
    expect(cubit2.isClosed, isTrue);
    errorGate.completeError(StateError('mid-flight error'));
    await closing2;
    await pumpEventQueue();
    expect(emitted2, isEmpty);
  });
}
