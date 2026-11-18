import 'dart:async';
import 'dart:typed_data';

import 'package:e_commerce_project/features/discovery/presentation/cubit/show_details_cubit.dart';
import 'package:e_commerce_project/features/discovery/presentation/cubit/show_details_state.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/new_show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session_time.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/repositories/shows_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_shows_repository.dart';

Show _show({
  String id = 'show-1',
  ShowStatus status = ShowStatus.active,
  DateTime? updatedAt,
}) {
  return Show(
    id: id,
    vendorId: 'arena',
    title: 'Apex Legends Invitational',
    description: 'Championship matches at Arena Central.',
    showDate: '2026-11-18',
    imageId: id,
    status: status,
    bookedCount: 2,
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
  final sessionTime = SessionTime(time);
  return Session(
    id: sessionTime.id,
    time: sessionTime,
    label: label,
    bookedSeats: bookedSeats,
  );
}

final class _StreamingShowDetailsRepository implements ShowsRepository {
  _StreamingShowDetailsRepository({
    Future<void> Function()? onShowCancel,
    Future<void> Function()? onSessionsCancel,
    this.throwOnWatchSessions = false,
    this.loadPosterHandler,
  }) : showController = StreamController<Show?>(onCancel: onShowCancel),
       sessionsController = StreamController<List<Session>>(
         onCancel: onSessionsCancel,
       );

  StreamController<Show?> showController;
  StreamController<List<Session>> sessionsController;
  bool throwOnWatchSessions;
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
    if (throwOnWatchSessions) {
      throw StateError('Cannot listen to sessions');
    }
    watchSessionsCalls++;
    return sessionsController.stream;
  }

  @override
  Future<Uint8List?> loadPoster(String showId) async {
    if (loadPosterHandler != null) {
      return loadPosterHandler!(showId);
    }
    return null;
  }

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
  void clearPosterCache() => cacheClears++;

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
      final repo = _StreamingShowDetailsRepository();
      final cubit = ShowDetailsCubit(repo, showId: 'show-1');
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
      expect(cubit.state.sessions.single.bookedSeats, {7});
    },
  );

  test(
    're-added show cannot reuse sessions from before it became unavailable',
    () async {
      final repo = _StreamingShowDetailsRepository();
      addTearDown(repo.dispose);
      final cubit = ShowDetailsCubit(repo, showId: 'show-1');
      addTearDown(cubit.close);
      await pumpEventQueue();
      repo.showController.add(_show());
      repo.sessionsController.add([_session('19:00')]);
      await pumpEventQueue();
      expect(cubit.state.status, ShowDetailsStatus.ready);
      repo.showController.add(null);
      await pumpEventQueue();
      repo.showController.add(_show());
      await pumpEventQueue();
      expect(cubit.state.status, ShowDetailsStatus.error);
      expect(cubit.state.sessions, isEmpty);
      repo.sessionsController.add([_session('14:00')]);
      await pumpEventQueue();
      expect(cubit.state.status, ShowDetailsStatus.ready);
      expect(cubit.state.sessions.single.id, '1400');
    },
  );

  test('unchanged metadata reuses bytes but explicit retry refreshes cached poster', () async {
    var loads = 0;
    final repo = _StreamingShowDetailsRepository(
      loadPosterHandler: (_) async => Uint8List.fromList([++loads]),
    );
    addTearDown(repo.dispose);
    final cubit = ShowDetailsCubit(repo, showId: 'show-1');
    addTearDown(cubit.close);
    await pumpEventQueue();
    repo.showController.add(_show());
    repo.sessionsController.add([_session('19:00')]);
    await pumpEventQueue();
    repo.showController.add(_show());
    await pumpEventQueue();
    expect(loads, 1);
    final oldShowController = repo.showController;
    final oldSessionsController = repo.sessionsController;
    repo.showController = StreamController<Show?>();
    repo.sessionsController = StreamController<List<Session>>();
    await cubit.retry();
    await Future.wait([
      oldShowController.close(),
      oldSessionsController.close(),
    ]);
    repo.showController.add(_show());
    repo.sessionsController.add([_session('19:00')]);
    await pumpEventQueue();
    expect(cubit.state.posterBytes, [2]);
    expect(repo.cacheClears, 1);
  });

  test('removed and re-added show rejects old in-flight poster', () async {
    final pending = <Completer<Uint8List?>>[];
    final repo = _StreamingShowDetailsRepository(
      loadPosterHandler: (_) {
        final request = Completer<Uint8List?>();
        pending.add(request);
        return request.future;
      },
    );
    addTearDown(repo.dispose);
    final cubit = ShowDetailsCubit(repo, showId: 'show-1');
    addTearDown(cubit.close);
    await pumpEventQueue();
    repo.showController.add(_show());
    repo.sessionsController.add([_session('19:00')]);
    await pumpEventQueue();
    repo.showController.add(null);
    await pumpEventQueue();
    repo.showController.add(_show());
    repo.sessionsController.add([_session('14:00')]);
    await pumpEventQueue();
    expect(pending, hasLength(2));
    pending[1].complete(Uint8List.fromList([2]));
    await pumpEventQueue();
    pending[0].complete(Uint8List.fromList([1]));
    await pumpEventQueue();
    expect(cubit.state.posterBytes, [2]);
    expect(cubit.state.sessions.single.id, '1400');
  });

  test('retry waits for cleanup and coalesces pending retry', () async {
    final released = Completer<void>();
    final repo = _StreamingShowDetailsRepository(
      onShowCancel: () => released.future,
    );
    addTearDown(repo.dispose);
    final cubit = ShowDetailsCubit(repo, showId: 'show-1');
    addTearDown(cubit.close);
    await pumpEventQueue();
    repo.showController.add(_show());
    repo.sessionsController.add([_session('19:00')]);
    await pumpEventQueue();
    final oldShowController = repo.showController;
    final oldSessionsController = repo.sessionsController;
    repo.showController = StreamController<Show?>();
    repo.sessionsController = StreamController<List<Session>>();
    final first = cubit.retry();
    final second = cubit.retry();
    await pumpEventQueue();
    try {
      expect(repo.watchShowCalls, 1);
      expect(repo.watchSessionsCalls, 1);
    } finally {
      released.complete();
      await Future.wait([
        first,
        second,
        oldShowController.close(),
        oldSessionsController.close(),
      ]);
    }
    expect(repo.watchShowCalls, 2);
    expect(repo.watchSessionsCalls, 2);
  });

  test(
    'updatedAt replacement cannot be overwritten by old poster completion',
    () async {
      final pending = <Completer<Uint8List?>>[];
      final repo = _StreamingShowDetailsRepository(
        loadPosterHandler: (_) {
          final request = Completer<Uint8List?>();
          pending.add(request);
          return request.future;
        },
      );
      addTearDown(repo.dispose);
      final cubit = ShowDetailsCubit(repo, showId: 'show-1');
      addTearDown(cubit.close);
      await pumpEventQueue();
      repo.showController.add(_show(updatedAt: DateTime.utc(2026, 11, 17, 1)));
      repo.sessionsController.add([_session('19:00')]);
      await pumpEventQueue();
      repo.showController.add(_show(updatedAt: DateTime.utc(2026, 11, 17, 2)));
      await pumpEventQueue();
      expect(pending, hasLength(2));
      pending[1].complete(Uint8List.fromList([2]));
      await pumpEventQueue();
      pending[0].complete(Uint8List.fromList([1]));
      await pumpEventQueue();
      expect(cubit.state.posterBytes, [2]);
    },
  );

  test('rejects blank showId', () {
    final fake = FakeShowsRepository();
    expect(() => ShowDetailsCubit(fake, showId: '   '), throwsArgumentError);
  });

  test(
    'loads FakeShowsRepository details, sorted max-5 sessions, and poster',
    () async {
      final fake = FakeShowsRepository();
      fake.shows['show-1'] = _show();
      fake.posters['show-1'] = Uint8List.fromList(<int>[10, 20, 30]);
      fake.sessions['show-1'] = <Session>[
        _session('21:00', label: 'Late'),
        _session('19:00', label: 'Evening', bookedSeats: <int>{14, 21}),
        _session('09:00', label: 'Morning'),
        _session('14:00', label: 'Matinee'),
        _session('16:30'),
        _session('22:00'),
      ];

      final cubit = ShowDetailsCubit(fake, showId: 'show-1');
      addTearDown(cubit.close);

      await pumpEventQueue();

      expect(cubit.state.status, ShowDetailsStatus.ready);
      expect(cubit.state.show?.title, 'Apex Legends Invitational');
      expect(cubit.state.posterBytes, Uint8List.fromList(<int>[10, 20, 30]));
      expect(cubit.state.sessions.map((s) => s.id), <String>[
        '0900',
        '1400',
        '1630',
        '1900',
        '2100',
      ]);
      expect(cubit.state.isAllSessionsSoldOut, isFalse);
    },
  );

  test(
    'marks all sessions sold out when every session reaches capacity',
    () async {
      final fake = FakeShowsRepository();
      fake.shows['show-1'] = _show();
      fake.sessions['show-1'] = <Session>[
        _session('19:00', bookedSeats: List<int>.generate(47, (i) => i + 1)),
      ];

      final cubit = ShowDetailsCubit(fake, showId: 'show-1');
      addTearDown(cubit.close);
      await pumpEventQueue();

      expect(cubit.state.status, ShowDetailsStatus.ready);
      expect(cubit.state.isAllSessionsSoldOut, isTrue);
    },
  );

  test('transitions to unavailable when show is missing or deleting', () async {
    final repo = _StreamingShowDetailsRepository();
    addTearDown(repo.dispose);

    final cubit = ShowDetailsCubit(repo, showId: 'show-1');
    addTearDown(cubit.close);
    await pumpEventQueue();

    repo.showController.add(null);
    await pumpEventQueue();
    expect(cubit.state.status, ShowDetailsStatus.unavailable);

    repo.showController.add(_show());
    repo.sessionsController.add(<Session>[_session('19:00')]);
    await pumpEventQueue();
    expect(cubit.state.status, ShowDetailsStatus.ready);

    repo.showController.add(_show(status: ShowStatus.deleting));
    await pumpEventQueue();
    expect(cubit.state.status, ShowDetailsStatus.unavailable);
    expect(cubit.state.sessions, isEmpty);
  });

  for (final failedShowChannel in <bool>[true, false]) {
    test(
      'failed ${failedShowChannel ? 'show' : 'sessions'} channel requires fresh data before ready',
      () async {
        final repo = _StreamingShowDetailsRepository();
        addTearDown(repo.dispose);

        final cubit = ShowDetailsCubit(repo, showId: 'show-1');
        addTearDown(cubit.close);
        await pumpEventQueue();

        repo.showController.add(_show());
        repo.sessionsController.add(<Session>[_session('19:00')]);
        await pumpEventQueue();
        expect(cubit.state.status, ShowDetailsStatus.ready);

        if (failedShowChannel) {
          repo.showController.addError(StateError('Show stream failed'));
        } else {
          repo.sessionsController.addError(
            StateError('Sessions stream failed'),
          );
        }
        await pumpEventQueue();
        expect(cubit.state.status, ShowDetailsStatus.error);

        if (failedShowChannel) {
          repo.sessionsController.add(<Session>[_session('14:00')]);
        } else {
          repo.showController.add(_show());
        }
        await pumpEventQueue();
        expect(cubit.state.status, ShowDetailsStatus.error);

        if (failedShowChannel) {
          repo.showController.add(_show());
        } else {
          repo.sessionsController.add(<Session>[_session('14:00')]);
        }
        await pumpEventQueue();
        expect(cubit.state.status, ShowDetailsStatus.ready);
      },
    );
  }

  test('synchronous watchSessions failure cancels open watchShow stream and recovers on retry', () async {
    final repo = _StreamingShowDetailsRepository(throwOnWatchSessions: true);
    addTearDown(repo.dispose);

    final cubit = ShowDetailsCubit(repo, showId: 'show-1', autoStart: false);
    addTearDown(cubit.close);

    await cubit.start();
    expect(cubit.state.status, ShowDetailsStatus.error);
    expect(repo.showController.hasListener, isFalse);

    repo.throwOnWatchSessions = false;
    await repo.showController.close();
    repo.showController = StreamController<Show?>();
    unawaited(cubit.retry());
    await pumpEventQueue();

    repo.showController.add(_show());
    repo.sessionsController.add(<Session>[_session('19:00')]);
    await pumpEventQueue();
    expect(cubit.state.status, ShowDetailsStatus.ready);
  });

  test(
    'coalesces chained start() call and survives poster load error',
    () async {
      final repo = _StreamingShowDetailsRepository(
        loadPosterHandler: (_) async => throw StateError('Poster unreadable'),
      );
      addTearDown(repo.dispose);

      final cubit = ShowDetailsCubit(repo, showId: 'show-1')..start();
      addTearDown(cubit.close);

      await pumpEventQueue();
      expect(repo.watchShowCalls, 1);
      expect(repo.watchSessionsCalls, 1);

      repo.showController.add(_show());
      repo.sessionsController.add(<Session>[_session('19:00')]);
      await pumpEventQueue();

      expect(cubit.state.status, ShowDetailsStatus.ready);
      expect(cubit.state.posterBytes, isNull);
      expect(cubit.state.posterLoading, isFalse);
    },
  );

  test(
    'close waits for async stream cleanup and ignores late completions',
    () async {
      final released = Completer<void>();
      final posterCompleter = Completer<Uint8List?>();
      final repo = _StreamingShowDetailsRepository(
        onShowCancel: () => released.future,
        loadPosterHandler: (_) => posterCompleter.future,
      );
      addTearDown(repo.dispose);

      final cubit = ShowDetailsCubit(repo, showId: 'show-1');
      await pumpEventQueue();
      repo.showController.add(_show());
      await pumpEventQueue();

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

      posterCompleter.complete(Uint8List.fromList(<int>[1, 2, 3]));
      await pumpEventQueue();

      expect(cubit.isClosed, isTrue);
      expect(cubit.state.status, ShowDetailsStatus.loading);
      expect(cubit.state.posterBytes, isNull);
    },
  );
}
