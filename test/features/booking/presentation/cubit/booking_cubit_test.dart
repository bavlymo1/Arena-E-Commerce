import 'dart:async';

import 'package:e_commerce_project/features/booking/domain/models/booking.dart';
import 'package:e_commerce_project/features/booking/domain/models/booking_recovery.dart';
import 'package:e_commerce_project/features/booking/domain/models/booking_request.dart';
import 'package:e_commerce_project/features/booking/domain/models/booking_result.dart';
import 'package:e_commerce_project/features/booking/presentation/cubit/booking_cubit.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session_time.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_booking_repository.dart';

void main() {
  late FakeBookingRepository repo;
  late BookingCubit cubit;
  var generated = 0;
  setUp(() {
    repo = FakeBookingRepository();
    generated = 0;
    cubit = BookingCubit(
      repository: repo,
      customerUid: 'alice',
      showId: 'show',
      sessionId: '1900',
      newBookingId: () => 'request-${++generated}',
    );
  });
  tearDown(() async => cubit.close());

  test('duplicate taps while submitting produce one stable request', () async {
    final response = Completer<BookingResult>();
    repo.onConfirm = (_) => response.future;
    final pending = cubit.submit({1, 2});
    await cubit.submit({3});
    expect(repo.requests, hasLength(1));
    expect(generated, 1);
    response.complete(BookingConfirmed(repo.requests.single));
    await pending;
    expect(cubit.state.phase, BookingPhase.confirmed);
    cubit.newAttempt();
    await cubit.submit({4});
    expect(repo.requests, hasLength(1));
  });

  test(
    'thrown response stays uncertain and blocks new IDs and resubmits',
    () async {
      repo.onConfirm = (_) async => throw TimeoutException('lost response');
      await cubit.submit({1});
      final request = repo.requests.single;
      expect(cubit.state.phase, BookingPhase.unconfirmed);
      cubit.newAttempt();
      await cubit.submit({2});
      await cubit.recover();
      expect(cubit.state.phase, BookingPhase.unconfirmed);
      expect(identical(cubit.state.request, request), isTrue);
      expect(generated, 1);
      expect(repo.requests, hasLength(1));
    },
  );

  test('only authoritative absence permits a deliberate new attempt', () async {
    await cubit.submit({1});
    repo.recoveries[('request-1', 'alice')] = RecoveryAuthoritativelyAbsent(
      bookingId: 'request-1',
      customerUid: 'alice',
    );
    await cubit.recover();
    expect(cubit.state.phase, BookingPhase.absent);
    cubit.newAttempt();
    repo.onConfirm = (r) async => BookingConfirmed(r);
    await cubit.submit({2});
    expect(cubit.state.request!.bookingId, 'request-2');
    expect(cubit.state.phase, BookingPhase.confirmed);
  });

  test(
    'recovery requires matching owner, reference, show, session and seats',
    () async {
      await cubit.submit({1});
      repo.recoveries[('request-1', 'alice')] = RecoveryConfirmed(
        bookingId: 'request-1',
        customerUid: 'alice',
        booking: Booking(
          request: BookingRequest(
            bookingId: 'request-1',
            customerUid: 'alice',
            showId: 'other',
            sessionId: '1900',
            seats: {1},
          ),
          showTitle: 'Show',
          showDate: '2026-11-17',
          slotTime: SessionTime('19:00'),
          vendorId: 'vendor',
          createdAt: DateTime.utc(2026),
        ),
      );
      await cubit.recover();
      expect(cubit.state.phase, BookingPhase.unconfirmed);
      repo.recoveries[('request-1', 'alice')] = RecoveryConfirmed(
        bookingId: 'request-1',
        customerUid: 'alice',
        booking: Booking(
          request: repo.requests.single,
          showTitle: 'Show',
          showDate: '2026-11-17',
          slotTime: SessionTime('19:00'),
          vendorId: 'vendor',
          createdAt: DateTime.utc(2026),
        ),
      );
      await cubit.recover();
      expect(cubit.state.phase, BookingPhase.confirmed);
    },
  );

  test('mismatched committed response cannot confirm this request', () async {
    repo.onConfirm = (_) async => BookingConfirmed(
      BookingRequest(
        bookingId: 'wrong',
        customerUid: 'alice',
        showId: 'show',
        sessionId: '1900',
        seats: {1},
      ),
    );
    await cubit.submit({1});
    expect(cubit.state.phase, BookingPhase.unconfirmed);
  });

  test(
    'conflict, unavailable and definitive refusal remain distinct',
    () async {
      repo.onConfirm = (r) async => BookingConflict(r, {1});
      await cubit.submit({1, 2});
      expect(cubit.state.phase, BookingPhase.conflict);
      expect(cubit.state.conflicts, {1});
      cubit.newAttempt();
      repo.onConfirm = (r) async => BookingUnavailable(r);
      await cubit.submit({2});
      expect(cubit.state.phase, BookingPhase.unavailable);
      cubit.newAttempt();
      repo.onConfirm = (r) async => BookingRejected(r, reason: 'Refused');
      await cubit.submit({2});
      expect(cubit.state.phase, BookingPhase.rejected);
    },
  );

  test('late confirmation after route close emits nothing', () async {
    final response = Completer<BookingResult>();
    repo.onConfirm = (_) => response.future;
    final pending = cubit.submit({1});
    await cubit.close();
    response.complete(BookingConfirmed(repo.requests.single));
    await pending;
    expect(cubit.state.phase, BookingPhase.submitting);
  });
}
