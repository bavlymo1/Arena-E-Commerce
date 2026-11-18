import 'dart:async';
import 'dart:typed_data';

import 'package:e_commerce_project/features/vendor_shows/domain/models/new_show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session_time.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/repositories/shows_repository.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/cubit/vendor_show_details_cubit.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/cubit/vendor_show_details_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_shows_repository.dart';

Show _show({
  String id = 'show-1',
  String vendorId = 'vendor-1',
  ShowStatus status = ShowStatus.active,
  String title = 'Apex Finals',
  DateTime? updatedAt,
}) {
  return Show(
    id: id,
    vendorId: vendorId,
    title: title,
    description: 'Arena Central Finals',
    showDate: '2026-11-18',
    imageId: id,
    status: status,
    bookedCount: 5,
    lastBookingId: '',
    createdAt: DateTime.utc(2026, 11, 17),
    updatedAt: updatedAt,
  );
}

Session _session(
  String time, {
  String? label,
  Iterable<int> bookedSeats = const <int>[],
}) {
  final parsed = SessionTime(time);
  return Session(
    id: parsed.id,
    time: parsed,
    label: label,
    bookedSeats: bookedSeats,
  );
}

final class _StreamingVendorDetailsRepository implements ShowsRepository {
  _StreamingVendorDetailsRepository({
    Future<void> Function()? onShowCancel,
    Future<void> Function()? onSessionsCancel,
    this.loadPosterHandler,
  }) : showController = StreamController<Show?>(onCancel: onShowCancel),
       sessionsController = StreamController<List<Session>>(
         onCancel: onSessionsCancel,
       );

  StreamController<Show?> showController;
  StreamController<List<Session>> sessionsController;
  Future<Uint8List?> Function(String showId)? loadPosterHandler;
  int watchShowCalls = 0;
  int watchSessionsCalls = 0;
  int cacheClears = 0;

  @override
  Stream<Show?> watchShow(String showId) {
    watchShowCalls++;
    return showController.stream;
  }

  @override
  Stream<List<Session>> watchSessions(String showId) {
    watchSessionsCalls++;
    return sessionsController.stream;
  }

  @override
  Future<Uint8List?> loadPoster(String showId) async {
    if (loadPosterHandler != null) return loadPosterHandler!(showId);
    return null;
  }

  @override
  void clearPosterCache() => cacheClears++;

  @override
  Stream<List<Show>> watchActiveShows({int limit = 100}) =>
      const Stream<List<Show>>.empty();

  @override
  Stream<List<Show>> watchVendorShows(String vendorId) =>
      const Stream<List<Show>>.empty();

  @override
  Future<void> addShow(NewShow show, Uint8List poster) async {}

  @override
  Future<void> deleteShow(String showId) async {}

  @override
  Future<void> resumeDeletes(String vendorId) async {}

  @override
  void dispose() {
    unawaited(showController.close());
    unawaited(sessionsController.close());
  }
}

void main() {
  test(
    'restored show offers refresh instead of waiting for unchanged sessions',
    () async {
      final repo = _StreamingVendorDetailsRepository();
      final cubit = VendorShowDetailsCubit(
        repo,
        vendorId: 'vendor-1',
        showId: 'show-1',
      );
      addTearDown(repo.dispose);
      addTearDown(cubit.close);
      repo.showController.add(_show());
      repo.sessionsController.add([
        _session('19:00', bookedSeats: [1]),
      ]);
      await pumpEventQueue();
      expect(cubit.state.isReady, isTrue);
      repo.showController.add(null);
      await pumpEventQueue();
      expect(cubit.state.isUnavailable, isTrue);
      expect(cubit.state.sessions, isEmpty);
      repo.showController.add(_show());
      await pumpEventQueue();
      expect(cubit.state.hasError, isTrue);
      expect(cubit.state.errorMessage, contains('Refresh'));
      expect(cubit.state.sessions, isEmpty);
      repo.sessionsController.add([
        _session('14:00', bookedSeats: [7]),
      ]);
      await pumpEventQueue();
      expect(cubit.state.isReady, isTrue);
      expect(cubit.state.selectedSession!.bookedSeats, {7});
    },
  );

  test('throws ArgumentError when vendorId or showId is empty', () {
    final repo = FakeShowsRepository();
    expect(
      () => VendorShowDetailsCubit(
        repo,
        vendorId: '',
        showId: 'show-1',
        autoStart: false,
      ),
      throwsArgumentError,
    );
    expect(
      () => VendorShowDetailsCubit(
        repo,
        vendorId: 'vendor-1',
        showId: ' ',
        autoStart: false,
      ),
      throwsArgumentError,
    );
  });

  test('guards wrong-vendor, missing, and deleting shows as unavailable without leaking sessions', () async {
    final repo = _StreamingVendorDetailsRepository();
    addTearDown(repo.dispose);
    final cubit = VendorShowDetailsCubit(
      repo,
      vendorId: 'vendor-1',
      showId: 'show-1',
    );
    addTearDown(cubit.close);

    // Wrong vendor show must never leak session map.
    repo.sessionsController.add(<Session>[
      _session('19:00', bookedSeats: <int>[1, 2, 3]),
    ]);
    repo.showController.add(_show(vendorId: 'vendor-other'));
    await pumpEventQueue();

    expect(cubit.state.status, VendorShowDetailsStatus.unavailable);
    expect(cubit.state.show, isNull);
    expect(cubit.state.sessions, isEmpty);
    expect(cubit.state.selectedSession, isNull);

    // Deleting show transitions to unavailable and clears sessions.
    repo.showController.add(
      _show(vendorId: 'vendor-1', status: ShowStatus.active),
    );
    repo.sessionsController.add(<Session>[
      _session('19:00', bookedSeats: <int>[1, 2, 3]),
    ]);
    await pumpEventQueue();
    expect(cubit.state.status, VendorShowDetailsStatus.ready);
    expect(cubit.state.selectedSessionId, '1900');

    repo.showController.add(
      _show(vendorId: 'vendor-1', status: ShowStatus.deleting),
    );
    await pumpEventQueue();
    expect(cubit.state.status, VendorShowDetailsStatus.unavailable);
    expect(cubit.state.sessions, isEmpty);
    expect(cubit.state.selectedSessionId, isNull);

    // Missing show also reports unavailable.
    repo.showController.add(null);
    await pumpEventQueue();
    expect(cubit.state.status, VendorShowDetailsStatus.unavailable);
  });

  test(
    'sorts up to 5 sessions and updates selectedSession on selectSession',
    () async {
      final repo = FakeShowsRepository()
        ..shows['show-1'] = _show()
        ..sessions['show-1'] = <Session>[
          _session('22:00', label: 'Late', bookedSeats: <int>[10]),
          _session('12:00', label: 'Matinee', bookedSeats: <int>[1]),
          _session('15:00', bookedSeats: <int>[2, 3]),
          _session('18:00', bookedSeats: <int>[4]),
          _session('20:00', bookedSeats: <int>[5]),
          _session('23:00', label: 'Overflow', bookedSeats: <int>[9]),
        ]
        ..posters['show-1'] = Uint8List.fromList(<int>[4, 5, 6]);

      final cubit = VendorShowDetailsCubit(
        repo,
        vendorId: 'vendor-1',
        showId: 'show-1',
        initialSessionId: '1800',
      );
      addTearDown(cubit.close);
      await pumpEventQueue();

      expect(cubit.state.status, VendorShowDetailsStatus.ready);
      expect(cubit.state.sessions.map((s) => s.id).toList(), <String>[
        '1200',
        '1500',
        '1800',
        '2000',
        '2200',
      ]);
      expect(cubit.state.selectedSessionId, '1800');
      expect(cubit.state.selectedSession?.bookedSeats, <int>{4});

      cubit.selectSession('1500');
      expect(cubit.state.selectedSessionId, '1500');
      expect(cubit.state.selectedSession?.bookedSeats, <int>{2, 3});

      // Ignoring unknown session id keeps current selection.
      cubit.selectSession('9999');
      expect(cubit.state.selectedSessionId, '1500');
    },
  );

  test(
    'keeps error state if one stream fails and the other emits an update',
    () async {
      final repo = _StreamingVendorDetailsRepository();
      addTearDown(repo.dispose);
      final cubit = VendorShowDetailsCubit(
        repo,
        vendorId: 'vendor-1',
        showId: 'show-1',
      );
      addTearDown(cubit.close);

      repo.showController.add(_show());
      repo.sessionsController.addError(StateError('sessions denied'));
      await pumpEventQueue();

      expect(cubit.state.status, VendorShowDetailsStatus.error);

      repo.showController.add(_show(title: 'Updated While Sessions Errored'));
      await pumpEventQueue();
      expect(cubit.state.status, VendorShowDetailsStatus.error);
    },
  );

  test('awaits prior subscriptions cancellation on retry and close', () async {
    final showCancel = Completer<void>();
    final sessionsCancel = Completer<void>();
    var showCancels = 0;
    var sessionsCancels = 0;

    final repo = _StreamingVendorDetailsRepository(
      onShowCancel: () {
        showCancels++;
        return showCancels == 1 ? showCancel.future : Future<void>.value();
      },
      onSessionsCancel: () {
        sessionsCancels++;
        return sessionsCancels == 1
            ? sessionsCancel.future
            : Future<void>.value();
      },
    );
    addTearDown(repo.dispose);

    final cubit = VendorShowDetailsCubit(
      repo,
      vendorId: 'vendor-1',
      showId: 'show-1',
    );
    await pumpEventQueue();

    final retryFuture = cubit.retry();
    expect(repo.watchShowCalls, 1);

    await repo.showController.close();
    await repo.sessionsController.close();
    repo.showController = StreamController<Show?>();
    repo.sessionsController = StreamController<List<Session>>();

    showCancel.complete();
    sessionsCancel.complete();
    await retryFuture;

    expect(repo.watchShowCalls, 2);
    expect(repo.watchSessionsCalls, 2);
    expect(repo.cacheClears, 1);

    await cubit.close();
    expect(cubit.isClosed, isTrue);
  });

  test(
    'reloads poster on metadata revision change and discards stale completion',
    () async {
      final firstPoster = Completer<Uint8List?>();
      final secondPoster = Completer<Uint8List?>();
      var calls = 0;

      final repo = _StreamingVendorDetailsRepository(
        loadPosterHandler: (_) {
          calls++;
          return calls == 1 ? firstPoster.future : secondPoster.future;
        },
      );
      addTearDown(repo.dispose);
      final cubit = VendorShowDetailsCubit(
        repo,
        vendorId: 'vendor-1',
        showId: 'show-1',
      );
      addTearDown(cubit.close);

      repo.showController.add(_show(title: 'V1'));
      repo.sessionsController.add(<Session>[_session('19:00')]);
      await pumpEventQueue();
      expect(calls, 1);

      repo.showController.add(
        _show(title: 'V2', updatedAt: DateTime.utc(2026, 11, 18, 12)),
      );
      await pumpEventQueue();
      expect(calls, 2);
      expect(repo.cacheClears, 1);

      secondPoster.complete(Uint8List.fromList(<int>[8, 8]));
      await pumpEventQueue();
      expect(cubit.state.posterBytes, Uint8List.fromList(<int>[8, 8]));

      firstPoster.complete(Uint8List.fromList(<int>[1, 1]));
      await pumpEventQueue();
      expect(cubit.state.posterBytes, Uint8List.fromList(<int>[8, 8]));
    },
  );
}
