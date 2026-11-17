import 'dart:async';
import 'dart:typed_data';

import 'package:e_commerce_project/features/vendor_shows/domain/models/new_show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/repositories/shows_repository.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/cubit/vendor_shows_cubit.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/cubit/vendor_shows_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_shows_repository.dart';

Show _show({
  required String id,
  String vendorId = 'vendor-1',
  String title = 'Apex Finals',
  ShowStatus status = ShowStatus.active,
  int bookedCount = 0,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return Show(
    id: id,
    vendorId: vendorId,
    title: title,
    description: 'Championship event',
    showDate: '2026-11-18',
    imageId: id,
    status: status,
    bookedCount: bookedCount,
    lastBookingId: '',
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

final class _StreamingVendorShowsRepository implements ShowsRepository {
  _StreamingVendorShowsRepository({
    Future<void> Function()? onCancel,
    this.loadPosterHandler,
  }) : controller = StreamController<List<Show>>(onCancel: onCancel);

  StreamController<List<Show>> controller;
  Future<Uint8List?> Function(String showId)? loadPosterHandler;
  int watchVendorShowsCalls = 0;
  int cacheClears = 0;
  String? lastVendorId;

  @override
  Stream<List<Show>> watchVendorShows(String vendorId) {
    watchVendorShowsCalls++;
    lastVendorId = vendorId;
    return controller.stream;
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
  void dispose() {
    unawaited(controller.close());
  }
}

void main() {
  test('throws ArgumentError when vendorId is empty', () {
    final repo = FakeShowsRepository();
    expect(
      () => VendorShowsCubit(repo, vendorId: '  ', autoStart: false),
      throwsArgumentError,
    );
  });

  test(
    'filters by vendorId, includes active and deleting, sorts newest-first',
    () async {
      final repo = FakeShowsRepository()
        ..shows['old'] = _show(
          id: 'old',
          vendorId: 'vendor-1',
          title: 'Old Active',
          createdAt: DateTime.utc(2026, 11, 1),
        )
        ..shows['deleting'] = _show(
          id: 'deleting',
          vendorId: 'vendor-1',
          title: 'Interrupted Deleting',
          status: ShowStatus.deleting,
          createdAt: DateTime.utc(2026, 11, 20),
        )
        ..shows['new'] = _show(
          id: 'new',
          vendorId: 'vendor-1',
          title: 'Newest Active',
          createdAt: DateTime.utc(2026, 11, 15),
        )
        ..shows['other'] = _show(
          id: 'other',
          vendorId: 'vendor-other',
          title: 'Other Vendor Show',
          createdAt: DateTime.utc(2026, 11, 25),
        )
        ..posters['new'] = Uint8List.fromList(<int>[1, 2, 3]);

      final cubit = VendorShowsCubit(repo, vendorId: 'vendor-1');
      addTearDown(cubit.close);
      await pumpEventQueue();

      expect(cubit.state.status, VendorShowsStatus.ready);
      expect(cubit.state.shows.map((show) => show.id).toList(), <String>[
        'deleting',
        'new',
        'old',
      ]);
      expect(cubit.state.posters['new'], Uint8List.fromList(<int>[1, 2, 3]));
      expect(cubit.state.shows.any((show) => show.id == 'other'), isFalse);
    },
  );

  test(
    'emits error on stream error and clears poster cache on retry',
    () async {
      final repo = _StreamingVendorShowsRepository();
      addTearDown(repo.dispose);
      final cubit = VendorShowsCubit(repo, vendorId: 'vendor-1');
      addTearDown(cubit.close);

      repo.controller.addError(StateError('permission denied'));
      await pumpEventQueue();

      expect(cubit.state.status, VendorShowsStatus.error);
      expect(cubit.state.errorMessage, isNotNull);

      await repo.controller.close();
      repo.controller = StreamController<List<Show>>();

      await cubit.retry();
      expect(repo.cacheClears, 1);
      expect(repo.watchVendorShowsCalls, 2);

      repo.controller.add(<Show>[
        _show(id: 'recovered', createdAt: DateTime.utc(2026, 11, 18)),
      ]);
      await pumpEventQueue();

      expect(cubit.state.status, VendorShowsStatus.ready);
      expect(cubit.state.shows.single.id, 'recovered');
    },
  );

  test('invalidates and reloads poster when metadata revision changes and ignores stale response', () async {
    final firstPoster = Completer<Uint8List?>();
    final secondPoster = Completer<Uint8List?>();
    var calls = 0;

    final repo = _StreamingVendorShowsRepository(
      loadPosterHandler: (showId) {
        calls++;
        return calls == 1 ? firstPoster.future : secondPoster.future;
      },
    );
    addTearDown(repo.dispose);
    final cubit = VendorShowsCubit(repo, vendorId: 'vendor-1');
    addTearDown(cubit.close);

    final initial = _show(
      id: 'show-1',
      title: 'Title V1',
      updatedAt: DateTime.utc(2026, 11, 18, 10),
    );
    repo.controller.add(<Show>[initial]);
    await pumpEventQueue();
    expect(calls, 1);

    final revised = _show(
      id: 'show-1',
      title: 'Title V2',
      updatedAt: DateTime.utc(2026, 11, 18, 11),
    );
    repo.controller.add(<Show>[revised]);
    await pumpEventQueue();
    expect(calls, 2);
    expect(repo.cacheClears, 1);

    // Finish newer request first, then older stale request.
    secondPoster.complete(Uint8List.fromList(<int>[9, 9]));
    await pumpEventQueue();
    expect(cubit.state.posters['show-1'], Uint8List.fromList(<int>[9, 9]));

    firstPoster.complete(Uint8List.fromList(<int>[1, 1]));
    await pumpEventQueue();
    expect(cubit.state.posters['show-1'], Uint8List.fromList(<int>[9, 9]));
  });

  test('awaits prior subscription cancellation on retry and coalesces concurrent retries', () async {
    final cancelCompleter = Completer<void>();
    var cancels = 0;
    late _StreamingVendorShowsRepository repo;
    repo = _StreamingVendorShowsRepository(
      onCancel: () {
        cancels++;
        if (cancels == 1) return cancelCompleter.future;
        return Future<void>.value();
      },
    );
    addTearDown(repo.dispose);

    final cubit = VendorShowsCubit(repo, vendorId: 'vendor-1');
    addTearDown(cubit.close);
    await pumpEventQueue();
    expect(repo.watchVendorShowsCalls, 1);

    final retry1 = cubit.retry();
    final retry2 = cubit.retry();
    expect(identical(retry1, retry2), isTrue);
    expect(repo.watchVendorShowsCalls, 1);

    await repo.controller.close();
    repo.controller = StreamController<List<Show>>();
    cancelCompleter.complete();
    await retry1;

    expect(cancels, 1);
    expect(repo.watchVendorShowsCalls, 2);
  });

  test(
    'close awaits subscription cancellation and ignores late poster loads',
    () async {
      final posterCompleter = Completer<Uint8List?>();
      final cancelCompleter = Completer<void>();
      final repo = _StreamingVendorShowsRepository(
        onCancel: () => cancelCompleter.future,
        loadPosterHandler: (_) => posterCompleter.future,
      );
      addTearDown(repo.dispose);

      final cubit = VendorShowsCubit(repo, vendorId: 'vendor-1');
      repo.controller.add(<Show>[
        _show(id: 'show-1', createdAt: DateTime.utc(2026, 11, 18)),
      ]);
      await pumpEventQueue();

      var closed = false;
      final closeFuture = cubit.close().then((_) => closed = true);
      await pumpEventQueue();
      expect(closed, isFalse);

      cancelCompleter.complete();
      await closeFuture;
      expect(closed, isTrue);

      posterCompleter.complete(Uint8List.fromList(<int>[7, 8]));
      await pumpEventQueue();
      expect(cubit.isClosed, isTrue);
    },
  );
}
