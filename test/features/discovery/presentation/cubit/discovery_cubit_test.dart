import 'dart:async';
import 'dart:typed_data';

import 'package:e_commerce_project/features/discovery/presentation/cubit/discovery_cubit.dart';
import 'package:e_commerce_project/features/discovery/presentation/cubit/discovery_state.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/new_show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/repositories/shows_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_shows_repository.dart';

Show _show({
  required String id,
  required String title,
  String showDate = '2026-11-18',
  ShowStatus status = ShowStatus.active,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return Show(
    id: id,
    vendorId: 'arena',
    title: title,
    description: '$title description',
    showDate: showDate,
    imageId: id,
    status: status,
    bookedCount: 0,
    lastBookingId: '',
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

final class _StreamingShowsRepository implements ShowsRepository {
  _StreamingShowsRepository({
    Future<void> Function()? onCancel,
    this.throwOnWatch = false,
    this.loadPosterHandler,
  }) : controller = StreamController<List<Show>>(onCancel: onCancel);

  StreamController<List<Show>> controller;
  bool throwOnWatch;
  Future<Uint8List?> Function(String showId)? loadPosterHandler;
  int watchCalls = 0;
  final loadedPosterIds = <String>[];
  int cacheClears = 0;

  @override
  Stream<List<Show>> watchActiveShows({int limit = 100}) {
    if (throwOnWatch) {
      throw StateError('Failed to attach feed listener');
    }
    watchCalls++;
    return controller.stream;
  }

  @override
  Future<Uint8List?> loadPoster(String showId) async {
    loadedPosterIds.add(showId);
    if (loadPosterHandler != null) {
      return loadPosterHandler!(showId);
    }
    return null;
  }

  @override
  Stream<List<Show>> watchVendorShows(String vendorId) =>
      const Stream<List<Show>>.empty();

  @override
  Stream<Show?> watchShow(String showId) => const Stream<Show?>.empty();

  @override
  Stream<List<Session>> watchSessions(String showId) =>
      const Stream<List<Session>>.empty();

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
    unawaited(controller.close());
  }
}

void main() {
  test('unchanged metadata reuses bytes but explicit retry refreshes cached poster', () async {
    var loads = 0;
    final repo = _StreamingShowsRepository(
      loadPosterHandler: (_) async => Uint8List.fromList([++loads]),
    );
    addTearDown(repo.dispose);
    final cubit = DiscoveryCubit(repo);
    addTearDown(cubit.close);
    await pumpEventQueue();
    final show = _show(id: 's1', title: 'Same');
    repo.controller.add([show]);
    await pumpEventQueue();
    repo.controller.add([_show(id: 's1', title: 'Same')]);
    await pumpEventQueue();
    expect(loads, 1);
    expect(cubit.state.posters['s1'], [1]);
    final oldController = repo.controller;
    repo.controller = StreamController<List<Show>>();
    await cubit.retry();
    await oldController.close();
    repo.controller.add([show]);
    await pumpEventQueue();
    expect(cubit.state.posters['s1'], [2]);
    expect(repo.cacheClears, 1);
  });

  test(
    'replaces same-ID poster on changed metadata and ignores older completion',
    () async {
      final pending = <Completer<Uint8List?>>[];
      final repo = _StreamingShowsRepository(
        loadPosterHandler: (_) {
          final request = Completer<Uint8List?>();
          pending.add(request);
          return request.future;
        },
      );
      addTearDown(repo.dispose);
      final cubit = DiscoveryCubit(repo);
      addTearDown(cubit.close);
      await pumpEventQueue();
      repo.controller.add([_show(id: 's1', title: 'Original')]);
      await pumpEventQueue();
      repo.controller.add([_show(id: 's1', title: 'Replacement')]);
      await pumpEventQueue();
      expect(pending, hasLength(2));
      pending[1].complete(Uint8List.fromList([2]));
      await pumpEventQueue();
      pending[0].complete(Uint8List.fromList([1]));
      await pumpEventQueue();
      expect(cubit.state.posters['s1'], [2]);
    },
  );

  test('remove and re-add invalidates same-ID in-flight poster', () async {
    final pending = <Completer<Uint8List?>>[];
    final repo = _StreamingShowsRepository(
      loadPosterHandler: (_) {
        final request = Completer<Uint8List?>();
        pending.add(request);
        return request.future;
      },
    );
    addTearDown(repo.dispose);
    final cubit = DiscoveryCubit(repo);
    addTearDown(cubit.close);
    await pumpEventQueue();
    final show = _show(id: 's1', title: 'Same metadata');
    repo.controller.add([show]);
    await pumpEventQueue();
    repo.controller.add([]);
    await pumpEventQueue();
    repo.controller.add([show]);
    await pumpEventQueue();
    expect(pending, hasLength(2));
    pending[1].complete(Uint8List.fromList([2]));
    await pumpEventQueue();
    pending[0].complete(Uint8List.fromList([1]));
    await pumpEventQueue();
    expect(cubit.state.posters['s1'], [2]);
  });

  test('retry waits for cleanup and coalesces pending retry', () async {
    final released = Completer<void>();
    final repo = _StreamingShowsRepository(onCancel: () => released.future);
    addTearDown(repo.dispose);
    final cubit = DiscoveryCubit(repo);
    addTearDown(cubit.close);
    await pumpEventQueue();
    repo.controller.add([]);
    await pumpEventQueue();
    final oldController = repo.controller;
    repo.controller = StreamController<List<Show>>();
    final first = cubit.retry();
    final second = cubit.retry();
    await pumpEventQueue();
    try {
      expect(repo.watchCalls, 1);
    } finally {
      released.complete();
      await Future.wait([first, second]);
      await oldController.close();
    }
    expect(repo.watchCalls, 2);
    repo.controller.add([]);
    await pumpEventQueue();
    expect(cubit.state.status, DiscoveryStatus.ready);
  });

  test(
    'loads FakeShowsRepository active shows newest-first and searches by title',
    () async {
      final fake = FakeShowsRepository();
      fake.shows['old'] = _show(
        id: 'old',
        title: 'Autumn Finals',
        createdAt: DateTime.utc(2026, 11, 10),
      );
      fake.shows['new'] = _show(
        id: 'new',
        title: 'Apex Legends Invitational',
        createdAt: DateTime.utc(2026, 11, 18),
      );
      fake.shows['deleting'] = _show(
        id: 'deleting',
        title: 'Deleting Apex Show',
        status: ShowStatus.deleting,
        createdAt: DateTime.utc(2026, 11, 19),
      );
      fake.posters['new'] = Uint8List.fromList(<int>[1, 2, 3]);

      final cubit = DiscoveryCubit(fake);
      addTearDown(cubit.close);

      await pumpEventQueue();

      expect(cubit.state.status, DiscoveryStatus.ready);
      expect(cubit.state.shows.map((s) => s.id), <String>['new', 'old']);
      expect(cubit.state.filteredShows.map((s) => s.id), <String>[
        'new',
        'old',
      ]);
      expect(cubit.state.posters['new'], Uint8List.fromList(<int>[1, 2, 3]));
      expect(cubit.state.posters.containsKey('old'), isTrue);
      expect(cubit.state.posters['old'], isNull);

      cubit.updateSearchQuery('  aPeX ');
      expect(cubit.state.filteredShows.map((s) => s.id), <String>['new']);
      expect(cubit.state.isNoMatch, isFalse);

      cubit.updateSearchQuery('missing-title');
      expect(cubit.state.filteredShows, isEmpty);
      expect(cubit.state.isNoMatch, isTrue);
      expect(cubit.state.isEmpty, isFalse);

      cubit.clearSearch();
      expect(cubit.state.filteredShows.map((s) => s.id), <String>[
        'new',
        'old',
      ]);
    },
  );

  test('reports empty ready state when no active shows exist', () async {
    final fake = FakeShowsRepository();
    fake.shows['deleting'] = _show(
      id: 'deleting',
      title: 'Hidden',
      status: ShowStatus.deleting,
    );

    final cubit = DiscoveryCubit(fake);
    addTearDown(cubit.close);
    await pumpEventQueue();

    expect(cubit.state.status, DiscoveryStatus.ready);
    expect(cubit.state.isEmpty, isTrue);
    expect(cubit.state.isNoMatch, isFalse);
  });

  test('coalesces chained start() call on auto-started cubit without double listen', () async {
    final repo = _StreamingShowsRepository();
    addTearDown(repo.dispose);

    final cubit = DiscoveryCubit(repo)..start();
    addTearDown(cubit.close);

    await pumpEventQueue();
    expect(repo.watchCalls, 1);

    repo.controller.add(<Show>[
      _show(id: 's1', title: 'Apex', createdAt: DateTime.utc(2026, 11, 18)),
    ]);
    await pumpEventQueue();

    expect(cubit.state.status, DiscoveryStatus.ready);
    expect(cubit.state.shows.map((s) => s.id), <String>['s1']);
  });

  test('preserves search and shows on error and recovers on retry', () async {
    var shouldFailPoster = true;
    final repo = _StreamingShowsRepository(
      loadPosterHandler: (id) async {
        if (shouldFailPoster) {
          throw StateError('Poster unavailable');
        }
        return Uint8List.fromList(<int>[9, 8, 7]);
      },
    );
    addTearDown(repo.dispose);

    final cubit = DiscoveryCubit(repo);
    addTearDown(cubit.close);

    await pumpEventQueue();
    repo.controller.add(<Show>[
      _show(
        id: 's1',
        title: 'Neon Horizon',
        createdAt: DateTime.utc(2026, 11, 17),
      ),
    ]);
    await pumpEventQueue();

    cubit.updateSearchQuery('neon');
    expect(cubit.state.posters['s1'], isNull);

    repo.controller.addError(StateError('Feed interrupted'));
    await pumpEventQueue();

    expect(cubit.state.status, DiscoveryStatus.error);
    expect(cubit.state.searchQuery, 'neon');
    expect(cubit.state.filteredShows.map((s) => s.id), <String>['s1']);

    shouldFailPoster = false;
    await repo.controller.close();
    repo.controller = StreamController<List<Show>>();
    unawaited(cubit.retry());
    await pumpEventQueue();

    repo.controller.add(<Show>[
      _show(
        id: 's1',
        title: 'Neon Horizon',
        createdAt: DateTime.utc(2026, 11, 17),
      ),
    ]);
    await pumpEventQueue();

    expect(cubit.state.status, DiscoveryStatus.ready);
    expect(cubit.state.searchQuery, 'neon');
    expect(cubit.state.posters['s1'], Uint8List.fromList(<int>[9, 8, 7]));
  });

  test('handles synchronous watch failure cleanly', () async {
    final repo = _StreamingShowsRepository(throwOnWatch: true);
    addTearDown(repo.dispose);

    final cubit = DiscoveryCubit(repo, autoStart: false);
    addTearDown(cubit.close);

    await cubit.start();
    expect(cubit.state.status, DiscoveryStatus.error);
  });

  test('close waits for async stream cancellation and ignores late emissions and posters', () async {
    final released = Completer<void>();
    final posterCompleter = Completer<Uint8List?>();
    final repo = _StreamingShowsRepository(
      onCancel: () => released.future,
      loadPosterHandler: (_) => posterCompleter.future,
    );
    addTearDown(repo.dispose);

    final cubit = DiscoveryCubit(repo);
    await pumpEventQueue();
    repo.controller.add(<Show>[
      _show(
        id: 's1',
        title: 'Late Show',
        createdAt: DateTime.utc(2026, 11, 17),
      ),
    ]);
    await pumpEventQueue();
    expect(cubit.state.loadingPosterIds, <String>{'s1'});

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

    posterCompleter.complete(Uint8List.fromList(<int>[4, 5, 6]));
    await pumpEventQueue();

    expect(cubit.isClosed, isTrue);
    expect(cubit.state.posters.containsKey('s1'), isFalse);
  });

  test('hides show from open discovery feed immediately when its status transitions to deleting', () async {
    final repo = _StreamingShowsRepository();
    addTearDown(repo.dispose);
    final cubit = DiscoveryCubit(repo);
    addTearDown(cubit.close);

    await pumpEventQueue();
    repo.controller.add(<Show>[
      _show(
        id: 's1',
        title: 'Active Show',
        createdAt: DateTime.utc(2026, 11, 18),
      ),
      _show(
        id: 's2',
        title: 'Soon Deleting Show',
        createdAt: DateTime.utc(2026, 11, 19),
      ),
    ]);
    await pumpEventQueue();
    expect(cubit.state.shows.map((s) => s.id).toList(), <String>['s2', 's1']);

    // Show s2 transitions to ShowStatus.deleting while feed is open.
    repo.controller.add(<Show>[
      _show(
        id: 's1',
        title: 'Active Show',
        createdAt: DateTime.utc(2026, 11, 18),
      ),
      _show(
        id: 's2',
        title: 'Soon Deleting Show',
        status: ShowStatus.deleting,
        createdAt: DateTime.utc(2026, 11, 19),
      ),
    ]);
    await pumpEventQueue();

    expect(cubit.state.shows.map((s) => s.id).toList(), <String>['s1']);
    expect(cubit.state.filteredShows.map((s) => s.id).toList(), <String>['s1']);
    expect(cubit.state.posters.containsKey('s2'), isFalse);
  });
}
