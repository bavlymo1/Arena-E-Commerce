import 'dart:async';

import 'package:e_commerce_project/features/vendor_notifications/domain/models/booking_event.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/repositories/booking_events_repository.dart';
import 'package:e_commerce_project/features/vendor_notifications/presentation/cubit/vendor_notifications_cubit.dart';
import 'package:e_commerce_project/features/vendor_notifications/presentation/cubit/vendor_notifications_state.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session_time.dart';
import 'package:flutter_test/flutter_test.dart';

BookingEvent _event({
  required String bookingId,
  String vendorId = 'vendor-a',
  String showId = 'show-1',
  String slot = '19:00',
  Iterable<int> seats = const <int>[1],
  int slotTotal = 1,
  int showTotal = 1,
  required DateTime createdAt,
}) {
  final parsedSlot = SessionTime(slot);
  return BookingEvent(
    bookingId: bookingId,
    vendorId: vendorId,
    showId: showId,
    sessionId: parsedSlot.id,
    seats: seats,
    showTitle: 'Apex Finals',
    slotTime: parsedSlot,
    slotTotal: slotTotal,
    showTotal: showTotal,
    createdAt: createdAt,
  );
}

final class _StreamingBookingEventsRepository
    implements BookingEventsRepository {
  _StreamingBookingEventsRepository({Future<void> Function()? onCancel})
    : controller = StreamController<List<BookingEvent>>(onCancel: onCancel);

  StreamController<List<BookingEvent>> controller;
  int watchCalls = 0;
  String? lastVendorId;

  @override
  Stream<List<BookingEvent>> watchEvents(String vendorId) {
    watchCalls++;
    lastVendorId = vendorId;
    return controller.stream;
  }

  void dispose() {
    unawaited(controller.close());
  }
}

void main() {
  test('throws ArgumentError when vendorId is empty', () {
    final repo = _StreamingBookingEventsRepository();
    addTearDown(repo.dispose);
    expect(
      () => VendorNotificationsCubit(repo, vendorId: '  ', autoStart: false),
      throwsArgumentError,
    );
  });

  test('seeds initial historical snapshot without unread count, then marks live arrivals and timestamp ties unread', () async {
    final repo = _StreamingBookingEventsRepository();
    addTearDown(repo.dispose);
    final cubit = VendorNotificationsCubit(repo, vendorId: 'vendor-a');
    addTearDown(cubit.close);

    expect(cubit.state.status, VendorNotificationsStatus.loading);
    await pumpEventQueue();
    expect(repo.lastVendorId, 'vendor-a');

    final t0 = DateTime.utc(2026, 11, 20, 12, 0, 0);
    final t1 = DateTime.utc(2026, 11, 20, 12, 1, 0);
    repo.controller.add(<BookingEvent>[
      _event(bookingId: 'hist-1', createdAt: t0, slotTotal: 1, showTotal: 1),
    ]);
    await pumpEventQueue();

    expect(cubit.state.status, VendorNotificationsStatus.ready);
    expect(cubit.state.events.map((e) => e.bookingId), <String>['hist-1']);
    expect(cubit.state.unreadCount, 0);

    // Same-millisecond tie event + newer event arrive live.
    repo.controller.add(<BookingEvent>[
      _event(bookingId: 'hist-1', createdAt: t0, slotTotal: 1, showTotal: 1),
      _event(
        bookingId: 'live-tie',
        seats: const <int>[2],
        createdAt: t0,
        slotTotal: 2,
        showTotal: 2,
      ),
      _event(
        bookingId: 'live-new',
        slot: '14:00',
        seats: const <int>[3, 4],
        createdAt: t1,
        slotTotal: 2,
        showTotal: 4,
      ),
    ]);
    await pumpEventQueue();

    expect(cubit.state.events.map((e) => e.bookingId).toList(), <String>[
      'live-new',
      'hist-1',
      'live-tie',
    ]);
    expect(cubit.state.unreadEventIds, <String>{'live-tie', 'live-new'});
    expect(cubit.state.unreadCount, 2);

    // Re-emitting existing events does not re-flag read events.
    cubit.markEventRead('live-tie');
    expect(cubit.state.unreadEventIds, <String>{'live-new'});

    repo.controller.add(<BookingEvent>[
      _event(bookingId: 'hist-1', createdAt: t0, slotTotal: 1, showTotal: 1),
      _event(
        bookingId: 'live-tie',
        seats: const <int>[2],
        createdAt: t0,
        slotTotal: 2,
        showTotal: 2,
      ),
      _event(
        bookingId: 'live-new',
        slot: '14:00',
        seats: const <int>[3, 4],
        createdAt: t1,
        slotTotal: 2,
        showTotal: 4,
      ),
    ]);
    await pumpEventQueue();
    expect(cubit.state.unreadEventIds, <String>{'live-new'});

    cubit.markAllRead();
    expect(cubit.state.unreadCount, 0);
    expect(cubit.state.events, hasLength(3));
  });

  test('marks first live booking unread after an empty initial snapshot and isolates vendors', () async {
    final repo = _StreamingBookingEventsRepository();
    addTearDown(repo.dispose);
    final cubit = VendorNotificationsCubit(repo, vendorId: 'vendor-a');
    addTearDown(cubit.close);

    repo.controller.add(const <BookingEvent>[]);
    await pumpEventQueue();
    expect(cubit.state.isEmpty, isTrue);
    expect(cubit.state.unreadCount, 0);

    final t0 = DateTime.utc(2026, 11, 20, 14, 0, 0);
    repo.controller.add(<BookingEvent>[
      _event(
        bookingId: 'other-vendor-event',
        vendorId: 'vendor-b',
        createdAt: t0,
        slotTotal: 9,
        showTotal: 12,
      ),
      _event(
        bookingId: 'own-event',
        vendorId: 'vendor-a',
        seats: const <int>[5, 6],
        slotTotal: 2,
        showTotal: 8,
        createdAt: t0,
      ),
      _event(
        bookingId: 'own-event',
        vendorId: 'vendor-a',
        seats: const <int>[5, 6],
        slotTotal: 2,
        showTotal: 8,
        createdAt: t0,
      ),
    ]);
    await pumpEventQueue();

    expect(cubit.state.events.single.bookingId, 'own-event');
    expect(cubit.state.events.single.slotTotal, 2);
    expect(cubit.state.events.single.showTotal, 8);
    expect(cubit.state.unreadEventIds, <String>{'own-event'});
  });

  test('preserves events on stream error, awaits prior subscription cancel on retry, and closes cleanly', () async {
    final cancelCompleter = Completer<void>();
    var cancels = 0;
    late _StreamingBookingEventsRepository repo;
    repo = _StreamingBookingEventsRepository(
      onCancel: () {
        cancels++;
        if (cancels == 1) return cancelCompleter.future;
        return Future<void>.value();
      },
    );
    addTearDown(repo.dispose);

    final cubit = VendorNotificationsCubit(repo, vendorId: 'vendor-a');
    final t0 = DateTime.utc(2026, 11, 20, 15, 0, 0);
    repo.controller.add(<BookingEvent>[
      _event(bookingId: 'b1', createdAt: t0, slotTotal: 1, showTotal: 1),
    ]);
    await pumpEventQueue();

    repo.controller.addError(StateError('network error'));
    await pumpEventQueue();
    expect(cubit.state.hasError, isTrue);
    expect(cubit.state.events.single.bookingId, 'b1');

    final retry1 = cubit.retry();
    final retry2 = cubit.retry();
    expect(identical(retry1, retry2), isTrue);
    expect(repo.watchCalls, 1);

    await repo.controller.close();
    repo.controller = StreamController<List<BookingEvent>>();
    cancelCompleter.complete();
    await retry1;

    expect(cancels, 1);
    expect(repo.watchCalls, 2);

    var closed = false;
    final closeFuture = cubit.close().then((_) => closed = true);
    await pumpEventQueue();
    await closeFuture;
    expect(closed, isTrue);

    repo.controller.add(<BookingEvent>[
      _event(bookingId: 'late', createdAt: t0.add(const Duration(minutes: 1))),
    ]);
    await pumpEventQueue();
    expect(cubit.isClosed, isTrue);
  });
}
