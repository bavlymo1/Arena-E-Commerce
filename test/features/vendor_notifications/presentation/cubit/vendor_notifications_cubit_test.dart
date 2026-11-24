import 'dart:async';

import 'package:e_commerce_project/features/vendor_notifications/domain/models/alert_permission.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/models/booking_alert.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/models/booking_event.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/models/notification_watermark.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/repositories/booking_events_repository.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/repositories/local_alert_presenter.dart';
import 'package:e_commerce_project/features/vendor_notifications/domain/repositories/watermark_store.dart';
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

final class _FakeWatermarkStore implements WatermarkStore {
  _FakeWatermarkStore({
    this.initial,
    this.trace,
    this.loadHandler,
    this.saveHandler,
  });

  NotificationWatermark? initial;
  final List<String>? trace;
  final Future<NotificationWatermark?> Function(String vendorId)? loadHandler;
  final Future<void> Function(String vendorId, NotificationWatermark watermark)?
  saveHandler;

  final List<NotificationWatermark> saved = <NotificationWatermark>[];
  int loadCalls = 0;

  @override
  Future<NotificationWatermark?> load(String vendorId) async {
    loadCalls++;
    trace?.add('load($vendorId)');
    if (loadHandler != null) return loadHandler!(vendorId);
    return initial;
  }

  @override
  Future<void> save(String vendorId, NotificationWatermark watermark) async {
    trace?.add(
      'save(${watermark.lastSeenEventAtMs},${watermark.seenEventIdsAtWatermark.join('+')})',
    );
    if (saveHandler != null) {
      await saveHandler!(vendorId, watermark);
    }
    saved.add(watermark);
    initial = watermark;
  }
}

final class _FakeLocalAlertPresenter implements LocalAlertPresenter {
  _FakeLocalAlertPresenter({
    this.permissionResult = AlertPermission.granted,
    this.trace,
    this.requestPermissionHandler,
    this.showAlertHandler,
    this.showGroupedHandler,
  });

  AlertPermission permissionResult;
  final List<String>? trace;
  final Future<AlertPermission> Function()? requestPermissionHandler;
  final Future<void> Function(BookingAlert alert)? showAlertHandler;
  final Future<void> Function(int count)? showGroupedHandler;

  int requestCalls = 0;
  final List<BookingAlert> shownAlerts = <BookingAlert>[];
  final List<int> groupedCounts = <int>[];

  @override
  Future<AlertPermission> requestPermission() async {
    requestCalls++;
    trace?.add('requestPermission');
    if (requestPermissionHandler != null) {
      return requestPermissionHandler!();
    }
    return permissionResult;
  }

  @override
  Future<void> showBookingAlert(BookingAlert alert) async {
    trace?.add('alert(${alert.bookingId})');
    if (showAlertHandler != null) {
      await showAlertHandler!(alert);
    }
    shownAlerts.add(alert);
  }

  @override
  Future<void> showGroupedAlert(int count) async {
    trace?.add('grouped($count)');
    if (showGroupedHandler != null) {
      await showGroupedHandler!(count);
    }
    groupedCounts.add(count);
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

  test('first launch historical snapshot populates list and seeds watermark with 0 alerts', () async {
    final repo = _StreamingBookingEventsRepository();
    addTearDown(repo.dispose);
    final trace = <String>[];
    final store = _FakeWatermarkStore(trace: trace);
    final presenter = _FakeLocalAlertPresenter(trace: trace);

    final cubit = VendorNotificationsCubit(
      repo,
      vendorId: 'vendor-a',
      watermarkStore: store,
      alertPresenter: presenter,
    );
    addTearDown(cubit.close);
    await pumpEventQueue();

    final t0 = DateTime.utc(2026, 11, 20, 10, 0);
    final t1 = DateTime.utc(2026, 11, 20, 11, 0);
    repo.controller.add(<BookingEvent>[
      _event(bookingId: 'h1', createdAt: t0, slotTotal: 2, showTotal: 2),
      _event(bookingId: 'h2-tie-a', createdAt: t1, slotTotal: 4, showTotal: 4),
      _event(bookingId: 'h3-tie-b', createdAt: t1, slotTotal: 5, showTotal: 5),
    ]);
    await pumpEventQueue();

    expect(cubit.state.status, VendorNotificationsStatus.ready);
    expect(cubit.state.events, hasLength(3));
    expect(cubit.state.unreadCount, 0);
    expect(cubit.state.alertPermission, AlertPermission.granted);
    expect(presenter.shownAlerts, isEmpty);
    expect(presenter.groupedCounts, isEmpty);
    expect(
      store.saved.single,
      NotificationWatermark(
        lastSeenEventAtMs: t1.millisecondsSinceEpoch,
        seenEventIdsAtWatermark: const <String>{'h2-tie-a', 'h3-tie-b'},
      ),
    );

    // Re-emitting historical events later never fires alerts.
    repo.controller.add(<BookingEvent>[
      _event(bookingId: 'h1', createdAt: t0, slotTotal: 2, showTotal: 2),
      _event(bookingId: 'h2-tie-a', createdAt: t1, slotTotal: 4, showTotal: 4),
      _event(bookingId: 'h3-tie-b', createdAt: t1, slotTotal: 5, showTotal: 5),
    ]);
    await pumpEventQueue();
    expect(presenter.shownAlerts, isEmpty);
  });

  test(
    'catch-up skips seen same-millisecond tie IDs and alerts unseen tie IDs',
    () async {
      final t0 = DateTime.utc(2026, 11, 20, 12, 0);
      final tOlder = DateTime.utc(2026, 11, 20, 11, 59);
      final repo = _StreamingBookingEventsRepository();
      addTearDown(repo.dispose);
      final store = _FakeWatermarkStore(
        initial: NotificationWatermark(
          lastSeenEventAtMs: t0.millisecondsSinceEpoch,
          seenEventIdsAtWatermark: const <String>{'tie-seen'},
        ),
      );
      final presenter = _FakeLocalAlertPresenter();

      final cubit = VendorNotificationsCubit(
        repo,
        vendorId: 'vendor-a',
        watermarkStore: store,
        alertPresenter: presenter,
      );
      addTearDown(cubit.close);
      await pumpEventQueue();

      repo.controller.add(<BookingEvent>[
        _event(bookingId: 'older', createdAt: tOlder),
        _event(bookingId: 'tie-seen', createdAt: t0),
        _event(
          bookingId: 'tie-unseen',
          createdAt: t0,
          slotTotal: 3,
          showTotal: 7,
        ),
      ]);
      await pumpEventQueue();

      expect(cubit.state.unreadEventIds, <String>{'tie-unseen'});
      expect(presenter.shownAlerts.map((a) => a.bookingId).toList(), <String>[
        'tie-unseen',
      ]);
      expect(presenter.groupedCounts, isEmpty);
      expect(
        store.saved.last,
        NotificationWatermark(
          lastSeenEventAtMs: t0.millisecondsSinceEpoch,
          seenEventIdsAtWatermark: const <String>{'tie-seen', 'tie-unseen'},
        ),
      );
    },
  );

  test('persists baseline on empty first launch and catches up 1 individual or >1 grouped bookings on reopen (including >100)', () async {
    final base = DateTime.utc(2026, 11, 20, 12, 0);

    // 1. Confirmed empty first launch saves epoch-0 baseline; 1 booking while closed alerts on reopen.
    final firstRepo = _StreamingBookingEventsRepository();
    addTearDown(firstRepo.dispose);
    final store1 = _FakeWatermarkStore();
    final first = VendorNotificationsCubit(
      firstRepo,
      vendorId: 'vendor-a',
      watermarkStore: store1,
    );
    await pumpEventQueue();
    firstRepo.controller.add(const <BookingEvent>[]);
    await pumpEventQueue();
    await first.close();
    expect(store1.initial, NotificationWatermark(lastSeenEventAtMs: 0));

    final reopenOneRepo = _StreamingBookingEventsRepository();
    addTearDown(reopenOneRepo.dispose);
    final presenter1 = _FakeLocalAlertPresenter();
    final cubitOne = VendorNotificationsCubit(
      reopenOneRepo,
      vendorId: 'vendor-a',
      watermarkStore: store1,
      alertPresenter: presenter1,
    );
    addTearDown(cubitOne.close);
    await pumpEventQueue();

    reopenOneRepo.controller.add(<BookingEvent>[
      _event(
        bookingId: 'b-single',
        createdAt: base.add(const Duration(seconds: 5)),
      ),
    ]);
    await pumpEventQueue();
    expect(presenter1.shownAlerts.map((a) => a.bookingId).toList(), <String>[
      'b-single',
    ]);
    expect(presenter1.groupedCounts, isEmpty);
    expect(cubitOne.state.unreadEventIds, <String>{'b-single'});

    // 2. Multiple bookings (including 105 unseen) while closed fire one grouped alert with all events retained.
    final store105 = _FakeWatermarkStore(
      initial: NotificationWatermark(lastSeenEventAtMs: 0),
    );
    final repo105 = _StreamingBookingEventsRepository();
    addTearDown(repo105.dispose);
    final presenter105 = _FakeLocalAlertPresenter();
    final cubit105 = VendorNotificationsCubit(
      repo105,
      vendorId: 'vendor-a',
      watermarkStore: store105,
      alertPresenter: presenter105,
    );
    addTearDown(cubit105.close);
    await pumpEventQueue();

    final missed105 = List<BookingEvent>.generate(
      105,
      (index) => _event(
        bookingId: 'u-${index + 1}',
        createdAt: base.add(Duration(seconds: index + 1)),
      ),
    );
    repo105.controller.add(missed105);
    await pumpEventQueue();

    expect(presenter105.shownAlerts, isEmpty);
    expect(presenter105.groupedCounts, <int>[105]);
    expect(cubit105.state.events, hasLength(105));
    expect(cubit105.state.unreadEventIds, hasLength(105));
    expect(
      store105.saved.last,
      NotificationWatermark(
        lastSeenEventAtMs: base
            .add(const Duration(seconds: 105))
            .millisecondsSinceEpoch,
        seenEventIdsAtWatermark: const <String>{'u-105'},
      ),
    );
  });

  test('live updates fire individual alerts even for >3 events and enforce lifetime deduplication', () async {
    final repo = _StreamingBookingEventsRepository();
    addTearDown(repo.dispose);
    final store = _FakeWatermarkStore();
    final presenter = _FakeLocalAlertPresenter();

    final cubit = VendorNotificationsCubit(
      repo,
      vendorId: 'vendor-a',
      watermarkStore: store,
      alertPresenter: presenter,
    );
    addTearDown(cubit.close);
    await pumpEventQueue();

    final t0 = DateTime.utc(2026, 11, 20, 12, 0);
    // Initial empty launch snapshot.
    repo.controller.add(const <BookingEvent>[]);
    await pumpEventQueue();

    // 4 live arrivals in a single snapshot still trigger 4 individual alerts.
    final liveBatch = <BookingEvent>[
      _event(bookingId: 'l4', createdAt: t0.add(const Duration(seconds: 4))),
      _event(bookingId: 'l1', createdAt: t0.add(const Duration(seconds: 1))),
      _event(bookingId: 'l3', createdAt: t0.add(const Duration(seconds: 3))),
      _event(bookingId: 'l2', createdAt: t0.add(const Duration(seconds: 2))),
    ];
    repo.controller.add(liveBatch);
    await pumpEventQueue();

    expect(presenter.shownAlerts.map((a) => a.bookingId).toList(), <String>[
      'l1',
      'l2',
      'l3',
      'l4',
    ]);
    expect(presenter.groupedCounts, isEmpty);

    // Re-emitting existing IDs (even with an older event or new event) never alerts twice.
    repo.controller.add(<BookingEvent>[
      ...liveBatch,
      _event(bookingId: 'l5', createdAt: t0.add(const Duration(seconds: 5))),
    ]);
    await pumpEventQueue();

    expect(presenter.shownAlerts.map((a) => a.bookingId).toList(), <String>[
      'l1',
      'l2',
      'l3',
      'l4',
      'l5',
    ]);
  });

  test(
    'sources BookingAlert slotTotal and showTotal directly from BookingEvent',
    () async {
      final repo = _StreamingBookingEventsRepository();
      addTearDown(repo.dispose);
      final presenter = _FakeLocalAlertPresenter();
      final cubit = VendorNotificationsCubit(
        repo,
        vendorId: 'vendor-a',
        alertPresenter: presenter,
      );
      addTearDown(cubit.close);
      await pumpEventQueue();

      repo.controller.add(const <BookingEvent>[]);
      await pumpEventQueue();

      repo.controller.add(<BookingEvent>[
        _event(
          bookingId: 'atomic-totals',
          slot: '19:00',
          seats: const <int>[10, 11],
          slotTotal: 17,
          showTotal: 42,
          createdAt: DateTime.utc(2026, 11, 20, 16, 0),
        ),
      ]);
      await pumpEventQueue();

      final alert = presenter.shownAlerts.single;
      expect(alert.slotTotal, 17);
      expect(alert.showTotal, 42);
      expect(alert.sessionSummary, 'Session 7:00 PM: 17/47 booked');
      expect(alert.showTotalSummary, 'Show total across slots: 42 booked');
    },
  );

  test('permission denied suppresses OS alerts while recording events, unread badges, watermark, and supporting retry', () async {
    final repo = _StreamingBookingEventsRepository();
    addTearDown(repo.dispose);
    final store = _FakeWatermarkStore();
    final presenter = _FakeLocalAlertPresenter(
      permissionResult: AlertPermission.denied,
    );

    final cubit = VendorNotificationsCubit(
      repo,
      vendorId: 'vendor-a',
      watermarkStore: store,
      alertPresenter: presenter,
    );
    addTearDown(cubit.close);
    await pumpEventQueue();

    expect(cubit.state.alertPermission, AlertPermission.denied);
    expect(cubit.state.isAlertPermissionDenied, isTrue);

    repo.controller.add(const <BookingEvent>[]);
    await pumpEventQueue();

    final t1 = DateTime.utc(2026, 11, 20, 17, 0);
    repo.controller.add(<BookingEvent>[
      _event(bookingId: 'b-denied', createdAt: t1, slotTotal: 1, showTotal: 1),
    ]);
    await pumpEventQueue();

    expect(presenter.shownAlerts, isEmpty);
    expect(presenter.groupedCounts, isEmpty);
    expect(cubit.state.events.map((e) => e.id), <String>['b-denied']);
    expect(cubit.state.unreadEventIds, <String>{'b-denied'});
    expect(
      store.saved.last,
      NotificationWatermark(
        lastSeenEventAtMs: t1.millisecondsSinceEpoch,
        seenEventIdsAtWatermark: const <String>{'b-denied'},
      ),
    );

    // Retry permission -> granted; old event stays quiet, new live event alerts.
    presenter.permissionResult = AlertPermission.granted;
    await cubit.requestAlertPermission();
    expect(cubit.state.alertPermission, AlertPermission.granted);
    expect(presenter.shownAlerts, isEmpty);

    final t2 = DateTime.utc(2026, 11, 20, 17, 5);
    repo.controller.add(<BookingEvent>[
      _event(bookingId: 'b-granted', createdAt: t2, slotTotal: 2, showTotal: 2),
      _event(bookingId: 'b-denied', createdAt: t1, slotTotal: 1, showTotal: 1),
    ]);
    await pumpEventQueue();

    expect(presenter.shownAlerts.map((a) => a.bookingId).toList(), <String>[
      'b-granted',
    ]);
  });

  test(
    'maps throwing requestPermission to denied without failing stream',
    () async {
      final repo = _StreamingBookingEventsRepository();
      addTearDown(repo.dispose);
      final presenter = _FakeLocalAlertPresenter(
        requestPermissionHandler: () => Future<AlertPermission>.error(
          StateError('permission channel unavailable'),
        ),
      );
      final cubit = VendorNotificationsCubit(
        repo,
        vendorId: 'vendor-a',
        alertPresenter: presenter,
      );
      addTearDown(cubit.close);
      await pumpEventQueue();

      expect(cubit.state.alertPermission, AlertPermission.denied);
      expect(cubit.state.hasError, isFalse);

      repo.controller.add(<BookingEvent>[
        _event(bookingId: 'b1', createdAt: DateTime.utc(2026, 11, 20, 18, 0)),
      ]);
      await pumpEventQueue();
      expect(cubit.state.status, VendorNotificationsStatus.ready);
      expect(cubit.state.events, hasLength(1));
    },
  );

  test(
    'failing WatermarkStore load and save keep stream alive and state intact',
    () async {
      final repo = _StreamingBookingEventsRepository();
      addTearDown(repo.dispose);
      final presenter = _FakeLocalAlertPresenter();
      final failingStore = _FakeWatermarkStore(
        loadHandler: (_) =>
            Future<NotificationWatermark?>.error(StateError('corrupt prefs')),
        saveHandler: (_, _) => Future<void>.error(StateError('disk full')),
      );

      final cubit = VendorNotificationsCubit(
        repo,
        vendorId: 'vendor-a',
        watermarkStore: failingStore,
        alertPresenter: presenter,
      );
      addTearDown(cubit.close);
      await pumpEventQueue();

      final t0 = DateTime.utc(2026, 11, 20, 12, 0);
      repo.controller.add(<BookingEvent>[
        _event(bookingId: 'hist-1', createdAt: t0),
      ]);
      await pumpEventQueue();

      expect(cubit.state.status, VendorNotificationsStatus.ready);
      expect(cubit.state.hasError, isFalse);
      expect(cubit.state.events.map((e) => e.id), <String>['hist-1']);
      expect(presenter.shownAlerts, isEmpty);

      // Subsequent live arrival still alerts despite failing save().
      final t1 = DateTime.utc(2026, 11, 20, 12, 5);
      repo.controller.add(<BookingEvent>[
        _event(bookingId: 'live-1', createdAt: t1, slotTotal: 2, showTotal: 2),
        _event(bookingId: 'hist-1', createdAt: t0),
      ]);
      await pumpEventQueue();

      expect(cubit.state.hasError, isFalse);
      expect(cubit.state.events.map((e) => e.id), <String>['live-1', 'hist-1']);
      expect(cubit.state.unreadEventIds, <String>{'live-1'});
      expect(presenter.shownAlerts.map((a) => a.bookingId).toList(), <String>[
        'live-1',
      ]);
    },
  );

  test('emits state immediately without waiting on I/O and awaits alerts strictly before saving watermark', () async {
    final repo = _StreamingBookingEventsRepository();
    addTearDown(repo.dispose);
    final trace = <String>[];
    final firstAlertGate = Completer<void>();
    final saveGate = Completer<void>();
    final store = _FakeWatermarkStore(
      trace: trace,
      initial: NotificationWatermark(
        lastSeenEventAtMs: DateTime.utc(
          2026,
          11,
          20,
          11,
          0,
        ).millisecondsSinceEpoch,
        seenEventIdsAtWatermark: const <String>{'seed-0'},
      ),
      saveHandler: (_, _) => saveGate.future,
    );
    final presenter = _FakeLocalAlertPresenter(
      trace: trace,
      showGroupedHandler: (_) => firstAlertGate.future,
    );

    final cubit = VendorNotificationsCubit(
      repo,
      vendorId: 'vendor-a',
      watermarkStore: store,
      alertPresenter: presenter,
    );
    addTearDown(cubit.close);
    await pumpEventQueue();

    final t1 = DateTime.utc(2026, 11, 20, 12, 0);
    final t2 = DateTime.utc(2026, 11, 20, 12, 1);
    final t3 = DateTime.utc(2026, 11, 20, 12, 2);

    // Emit catch-up snapshot while firstAlertGate is blocked.
    repo.controller.add(<BookingEvent>[
      _event(bookingId: 'e1', createdAt: t1),
      _event(bookingId: 'e2', createdAt: t2),
    ]);
    await pumpEventQueue();

    // UI state emitted immediately even though alert + save have not completed.
    expect(cubit.state.status, VendorNotificationsStatus.ready);
    expect(cubit.state.events.map((e) => e.id), <String>['e2', 'e1']);
    expect(cubit.state.unreadEventIds, <String>{'e1', 'e2'});
    expect(trace, <String>[
      'requestPermission',
      'load(vendor-a)',
      'grouped(2)',
    ]);
    expect(store.saved, isEmpty);

    // Second live snapshot arrives while first pipeline item is blocked.
    repo.controller.add(<BookingEvent>[
      _event(bookingId: 'e1', createdAt: t1),
      _event(bookingId: 'e2', createdAt: t2),
      _event(bookingId: 'e3', createdAt: t3),
    ]);
    await pumpEventQueue();
    expect(cubit.state.events.map((e) => e.id), <String>['e3', 'e2', 'e1']);
    // Serialized pipeline waits for e1+e2 alert+save before alerting e3.
    expect(trace, <String>[
      'requestPermission',
      'load(vendor-a)',
      'grouped(2)',
    ]);

    firstAlertGate.complete();
    await pumpEventQueue();
    expect(trace, <String>[
      'requestPermission',
      'load(vendor-a)',
      'grouped(2)',
      'save(${t2.millisecondsSinceEpoch},e2)',
    ]);

    saveGate.complete();
    await pumpEventQueue();
    expect(trace, <String>[
      'requestPermission',
      'load(vendor-a)',
      'grouped(2)',
      'save(${t2.millisecondsSinceEpoch},e2)',
      'alert(e3)',
      'save(${t3.millisecondsSinceEpoch},e3)',
    ]);
    expect(
      trace.indexOf('grouped(2)'),
      lessThan(trace.indexOf('save(${t2.millisecondsSinceEpoch},e2)')),
    );
    expect(
      trace.indexOf('alert(e3)'),
      lessThan(trace.indexOf('save(${t3.millisecondsSinceEpoch},e3)')),
    );
  });

  test(
    'close() cancels async work safely without calling save after close',
    () async {
      final repo = _StreamingBookingEventsRepository();
      addTearDown(repo.dispose);
      final trace = <String>[];
      final alertGate = Completer<void>();
      final store = _FakeWatermarkStore(trace: trace);
      final presenter = _FakeLocalAlertPresenter(
        trace: trace,
        showAlertHandler: (_) => alertGate.future,
      );

      final cubit = VendorNotificationsCubit(
        repo,
        vendorId: 'vendor-a',
        watermarkStore: store,
        alertPresenter: presenter,
      );
      await pumpEventQueue();

      repo.controller.add(const <BookingEvent>[]);
      await pumpEventQueue();

      repo.controller.add(<BookingEvent>[
        _event(bookingId: 'b1', createdAt: DateTime.utc(2026, 11, 20, 19, 0)),
      ]);
      await pumpEventQueue();

      await cubit.close();
      alertGate.complete();
      await pumpEventQueue();

      expect(store.saved.single, NotificationWatermark(lastSeenEventAtMs: 0));
      expect(trace.where((entry) => entry.startsWith('save(')), ['save(0,)']);
    },
  );

  test('failing LocalAlertPresenter individual and grouped calls keep watermark save and stream alive', () async {
    final repo1 = _StreamingBookingEventsRepository();
    addTearDown(repo1.dispose);
    final store1 = _FakeWatermarkStore();
    var calls1 = 0;
    final presenter1 = _FakeLocalAlertPresenter(
      showAlertHandler: (alert) async {
        calls1++;
        if (alert.bookingId == 'e1') {
          throw StateError('notification plugin error');
        }
      },
    );
    final cubit1 = VendorNotificationsCubit(
      repo1,
      vendorId: 'vendor-a',
      watermarkStore: store1,
      alertPresenter: presenter1,
    );
    addTearDown(cubit1.close);
    await pumpEventQueue();

    repo1.controller.add(const <BookingEvent>[]);
    await pumpEventQueue();

    final t1 = DateTime.utc(2026, 11, 20, 20, 0);
    final t2 = DateTime.utc(2026, 11, 20, 20, 1);
    repo1.controller.add(<BookingEvent>[
      _event(bookingId: 'e1', createdAt: t1),
      _event(bookingId: 'e2', createdAt: t2),
    ]);
    await pumpEventQueue();

    expect(calls1, 2);
    expect(presenter1.shownAlerts.map((a) => a.bookingId), <String>['e2']);
    expect(cubit1.state.hasError, isFalse);
    expect(
      store1.saved.last,
      NotificationWatermark(
        lastSeenEventAtMs: t2.millisecondsSinceEpoch,
        seenEventIdsAtWatermark: const <String>{'e2'},
      ),
    );

    final repo2 = _StreamingBookingEventsRepository();
    addTearDown(repo2.dispose);
    final base = DateTime.utc(2026, 11, 20, 20, 0);
    final store2 = _FakeWatermarkStore(
      initial: NotificationWatermark(
        lastSeenEventAtMs: base.millisecondsSinceEpoch,
        seenEventIdsAtWatermark: const <String>{'seed'},
      ),
    );
    var groupedCalls = 0;
    final presenter2 = _FakeLocalAlertPresenter(
      showGroupedHandler: (_) async {
        groupedCalls++;
        throw StateError('grouped channel failure');
      },
    );
    final cubit2 = VendorNotificationsCubit(
      repo2,
      vendorId: 'vendor-a',
      watermarkStore: store2,
      alertPresenter: presenter2,
    );
    addTearDown(cubit2.close);
    await pumpEventQueue();

    repo2.controller.add(<BookingEvent>[
      _event(bookingId: 'u1', createdAt: base.add(const Duration(seconds: 1))),
      _event(bookingId: 'u2', createdAt: base.add(const Duration(seconds: 2))),
      _event(bookingId: 'u3', createdAt: base.add(const Duration(seconds: 3))),
      _event(bookingId: 'u4', createdAt: base.add(const Duration(seconds: 4))),
    ]);
    await pumpEventQueue();

    expect(groupedCalls, 1);
    expect(cubit2.state.hasError, isFalse);
    expect(cubit2.state.events, hasLength(4));
    expect(
      store2.saved.last.lastSeenEventAtMs,
      base.add(const Duration(seconds: 4)).millisecondsSinceEpoch,
    );
  });

  test('awaits delayed requestPermission resolution before firing alert or persisting watermark', () async {
    final repo = _StreamingBookingEventsRepository();
    addTearDown(repo.dispose);
    final trace = <String>[];
    final permissionCompleter = Completer<AlertPermission>();
    final base = DateTime.utc(2026, 11, 20, 21, 0);
    final store = _FakeWatermarkStore(
      trace: trace,
      initial: NotificationWatermark(
        lastSeenEventAtMs: base.millisecondsSinceEpoch,
        seenEventIdsAtWatermark: const <String>{'seed'},
      ),
    );
    final presenter = _FakeLocalAlertPresenter(
      trace: trace,
      requestPermissionHandler: () => permissionCompleter.future,
    );

    final cubit = VendorNotificationsCubit(
      repo,
      vendorId: 'vendor-a',
      watermarkStore: store,
      alertPresenter: presenter,
    );
    addTearDown(cubit.close);
    await pumpEventQueue();

    final t1 = base.add(const Duration(minutes: 1));
    repo.controller.add(<BookingEvent>[_event(bookingId: 'b1', createdAt: t1)]);
    await pumpEventQueue();

    // State updates immediately, while alert & watermark save wait for permission.
    expect(cubit.state.status, VendorNotificationsStatus.ready);
    expect(cubit.state.unreadEventIds, <String>{'b1'});
    expect(presenter.shownAlerts, isEmpty);
    expect(store.saved, isEmpty);

    permissionCompleter.complete(AlertPermission.granted);
    await pumpEventQueue();

    expect(cubit.state.alertPermission, AlertPermission.granted);
    expect(presenter.shownAlerts.map((a) => a.bookingId), <String>['b1']);
    expect(store.saved, hasLength(1));
    expect(trace, <String>[
      'requestPermission',
      'load(vendor-a)',
      'alert(b1)',
      'save(${t1.millisecondsSinceEpoch},b1)',
    ]);
  });

  test('suppresses alerts while persisting watermark when delayed requestPermission denies', () async {
    final repo = _StreamingBookingEventsRepository();
    addTearDown(repo.dispose);
    final trace = <String>[];
    final permissionCompleter = Completer<AlertPermission>();
    final base = DateTime.utc(2026, 11, 20, 21, 5);
    final store = _FakeWatermarkStore(
      trace: trace,
      initial: NotificationWatermark(
        lastSeenEventAtMs: base.millisecondsSinceEpoch,
        seenEventIdsAtWatermark: const <String>{'seed'},
      ),
    );
    final presenter = _FakeLocalAlertPresenter(
      trace: trace,
      requestPermissionHandler: () => permissionCompleter.future,
    );

    final cubit = VendorNotificationsCubit(
      repo,
      vendorId: 'vendor-a',
      watermarkStore: store,
      alertPresenter: presenter,
    );
    addTearDown(cubit.close);
    await pumpEventQueue();

    final t1 = base.add(const Duration(minutes: 1));
    repo.controller.add(<BookingEvent>[_event(bookingId: 'b1', createdAt: t1)]);
    await pumpEventQueue();

    expect(presenter.shownAlerts, isEmpty);
    expect(store.saved, isEmpty);

    permissionCompleter.complete(AlertPermission.denied);
    await pumpEventQueue();

    expect(cubit.state.alertPermission, AlertPermission.denied);
    expect(presenter.shownAlerts, isEmpty);
    expect(presenter.groupedCounts, isEmpty);
    expect(store.saved, hasLength(1));
    expect(trace, <String>[
      'requestPermission',
      'load(vendor-a)',
      'save(${t1.millisecondsSinceEpoch},b1)',
    ]);
  });

  test(
    'close completes cleanly even when events stream cancel fails',
    () async {
      final repo = _StreamingBookingEventsRepository(
        onCancel: () => Future<void>.error(StateError('cancel failed')),
      );
      addTearDown(repo.dispose);

      final cubit = VendorNotificationsCubit(repo, vendorId: 'vendor-a');
      await pumpEventQueue();

      await expectLater(cubit.close(), completes);
      expect(cubit.isClosed, isTrue);
    },
  );

  test('retry and close recover cleanly without poisoning _cancellation when prior cancel fails', () async {
    var cancels = 0;
    final repo = _StreamingBookingEventsRepository(
      onCancel: () {
        cancels++;
        if (cancels == 1) {
          return Future<void>.error(StateError('cancel failed'));
        }
        return Future<void>.value();
      },
    );
    addTearDown(repo.dispose);

    final cubit = VendorNotificationsCubit(repo, vendorId: 'vendor-a');
    addTearDown(cubit.close);
    await pumpEventQueue();

    repo.controller.addError(StateError('network drop'));
    await pumpEventQueue();
    expect(cubit.state.hasError, isTrue);

    final oldController = repo.controller;
    repo.controller = StreamController<List<BookingEvent>>();

    await expectLater(cubit.retry(), completes);
    await oldController.close();

    expect(repo.watchCalls, 2);
    repo.controller.add(const <BookingEvent>[]);
    await pumpEventQueue();
    expect(cubit.state.status, VendorNotificationsStatus.ready);

    await expectLater(cubit.close(), completes);
  });

  test('deduplicates identical BookingEvent snapshots without alerts or saves while preserving unseen alerts and retry transitions', () async {
    final repo = _StreamingBookingEventsRepository();
    addTearDown(repo.dispose);
    final store = _FakeWatermarkStore();
    final presenter = _FakeLocalAlertPresenter();

    final cubit = VendorNotificationsCubit(
      repo,
      vendorId: 'vendor-a',
      watermarkStore: store,
      alertPresenter: presenter,
    );
    addTearDown(cubit.close);

    final emitted = <VendorNotificationsState>[];
    final sub = cubit.stream.listen(emitted.add);
    addTearDown(sub.cancel);

    await pumpEventQueue();
    emitted.clear();

    final t0 = DateTime.utc(2026, 11, 20, 12, 0);
    final t1 = DateTime.utc(2026, 11, 20, 12, 1);
    final t2 = DateTime.utc(2026, 11, 20, 12, 2);

    // Initial snapshot seeds watermark without firing alerts.
    repo.controller.add(<BookingEvent>[
      _event(
        bookingId: 'e1',
        seats: const <int>[1, 2],
        slotTotal: 2,
        showTotal: 2,
        createdAt: t0,
      ),
      _event(
        bookingId: 'e2',
        seats: const <int>[3, 4],
        slotTotal: 4,
        showTotal: 4,
        createdAt: t1,
      ),
    ]);
    await pumpEventQueue();

    final readyCount = emitted.length;
    expect(readyCount, 1);
    expect(emitted.last.status, VendorNotificationsStatus.ready);
    expect(emitted.last.events.map((e) => e.id).toList(), <String>['e2', 'e1']);
    expect(presenter.shownAlerts, isEmpty);
    expect(presenter.groupedCounts, isEmpty);
    expect(store.saved, hasLength(1));

    // (a) Duplicate snapshot (new instances, equal fields, reordered seats)
    // emits 0 new states and triggers 0 alerts or watermark saves.
    repo.controller.add(<BookingEvent>[
      _event(
        bookingId: 'e2',
        seats: const <int>[4, 3],
        slotTotal: 4,
        showTotal: 4,
        createdAt: t1,
      ),
      _event(
        bookingId: 'e1',
        seats: const <int>[2, 1],
        slotTotal: 2,
        showTotal: 2,
        createdAt: t0,
      ),
    ]);
    await pumpEventQueue();

    expect(emitted, hasLength(readyCount));
    expect(presenter.shownAlerts, isEmpty);
    expect(presenter.groupedCounts, isEmpty);
    expect(store.saved, hasLength(1));

    // (b) Subsequent unseen event still emits, alerts, and persists watermark.
    repo.controller.add(<BookingEvent>[
      _event(
        bookingId: 'e1',
        seats: const <int>[2, 1],
        slotTotal: 2,
        showTotal: 2,
        createdAt: t0,
      ),
      _event(
        bookingId: 'e2',
        seats: const <int>[4, 3],
        slotTotal: 4,
        showTotal: 4,
        createdAt: t1,
      ),
      _event(
        bookingId: 'e3',
        seats: const <int>[5, 6],
        slotTotal: 6,
        showTotal: 6,
        createdAt: t2,
      ),
    ]);
    await pumpEventQueue();

    expect(emitted, hasLength(readyCount + 1));
    expect(emitted.last.status, VendorNotificationsStatus.ready);
    expect(emitted.last.events.map((e) => e.id).toList(), <String>[
      'e3',
      'e2',
      'e1',
    ]);
    expect(emitted.last.unreadEventIds, <String>{'e3'});
    expect(presenter.shownAlerts.map((a) => a.bookingId).toList(), <String>[
      'e3',
    ]);
    expect(presenter.groupedCounts, isEmpty);
    expect(store.saved, hasLength(2));
    expect(
      store.saved.last,
      NotificationWatermark(
        lastSeenEventAtMs: t2.millisecondsSinceEpoch,
        seenEventIdsAtWatermark: const <String>{'e3'},
      ),
    );

    // Repeating the post-alert snapshot also deduplicates cleanly.
    repo.controller.add(<BookingEvent>[
      _event(
        bookingId: 'e3',
        seats: const <int>[6, 5],
        slotTotal: 6,
        showTotal: 6,
        createdAt: t2,
      ),
      _event(
        bookingId: 'e2',
        seats: const <int>[3, 4],
        slotTotal: 4,
        showTotal: 4,
        createdAt: t1,
      ),
      _event(
        bookingId: 'e1',
        seats: const <int>[1, 2],
        slotTotal: 2,
        showTotal: 2,
        createdAt: t0,
      ),
    ]);
    await pumpEventQueue();

    expect(emitted, hasLength(readyCount + 1));
    expect(presenter.shownAlerts.map((a) => a.bookingId).toList(), <String>[
      'e3',
    ]);
    expect(presenter.groupedCounts, isEmpty);
    expect(store.saved, hasLength(2));

    // (c) Stream error followed by retry() emits loading then ready when
    // identical events return, without re-alerting or re-saving.
    repo.controller.addError(StateError('stream drop'));
    await pumpEventQueue();
    expect(emitted, hasLength(readyCount + 2));
    expect(emitted.last.status, VendorNotificationsStatus.error);

    final oldController = repo.controller;
    repo.controller = StreamController<List<BookingEvent>>();
    final beforeRetry = emitted.length;
    await cubit.retry();
    await oldController.close();

    expect(emitted, hasLength(beforeRetry + 1));
    expect(emitted[beforeRetry].status, VendorNotificationsStatus.loading);
    expect(emitted[beforeRetry].errorMessage, isNull);

    repo.controller.add(<BookingEvent>[
      _event(
        bookingId: 'e1',
        seats: const <int>[1, 2],
        slotTotal: 2,
        showTotal: 2,
        createdAt: t0,
      ),
      _event(
        bookingId: 'e2',
        seats: const <int>[3, 4],
        slotTotal: 4,
        showTotal: 4,
        createdAt: t1,
      ),
      _event(
        bookingId: 'e3',
        seats: const <int>[6, 5],
        slotTotal: 6,
        showTotal: 6,
        createdAt: t2,
      ),
    ]);
    await pumpEventQueue();

    expect(emitted, hasLength(beforeRetry + 2));
    expect(emitted.last.status, VendorNotificationsStatus.ready);
    expect(emitted.last.events.map((e) => e.id).toList(), <String>[
      'e3',
      'e2',
      'e1',
    ]);
    expect(emitted.last.unreadEventIds, <String>{'e3'});
    expect(presenter.shownAlerts.map((a) => a.bookingId).toList(), <String>[
      'e3',
    ]);
    expect(presenter.groupedCounts, isEmpty);
    expect(store.saved, hasLength(2));
  });

  test('transitions to error if watchEvents closes before initial snapshot, but keeps ready on post-snapshot close', () async {
    final repo = _StreamingBookingEventsRepository();
    addTearDown(repo.dispose);
    final cubit = VendorNotificationsCubit(repo, vendorId: 'vendor-a');
    addTearDown(cubit.close);

    await pumpEventQueue();
    expect(cubit.state.status, VendorNotificationsStatus.loading);

    await repo.controller.close();
    await pumpEventQueue();

    expect(cubit.state.status, VendorNotificationsStatus.error);
    expect(cubit.state.hasError, isTrue);
    expect(
      cubit.state.errorMessage,
      'Unable to load booking updates. Try again.',
    );

    // Retry receives a snapshot then closes cleanly -> stays ready.
    repo.controller = StreamController<List<BookingEvent>>();
    await cubit.retry();
    expect(cubit.state.status, VendorNotificationsStatus.loading);

    repo.controller.add(const <BookingEvent>[]);
    await pumpEventQueue();
    expect(cubit.state.status, VendorNotificationsStatus.ready);

    await repo.controller.close();
    await pumpEventQueue();
    expect(cubit.state.status, VendorNotificationsStatus.ready);
    expect(cubit.state.hasError, isFalse);
  });
}
