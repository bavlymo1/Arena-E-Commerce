import 'dart:async';
import 'dart:typed_data';

import 'package:e_commerce_project/features/vendor_shows/domain/models/new_show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session_time.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/repositories/shows_repository.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/services/show_poster_coordination.dart';
import 'package:flutter_test/flutter_test.dart';

Show _show({
  required String id,
  String title = 'Apex Finals',
  DateTime? updatedAt,
}) => Show(
  id: id,
  vendorId: 'vendor-1',
  title: title,
  description: 'Desc',
  showDate: '2026-11-25',
  imageId: id,
  status: ShowStatus.active,
  bookedCount: 0,
  lastBookingId: '',
  createdAt: DateTime.utc(2026, 11, 20),
  updatedAt: updatedAt ?? DateTime.utc(2026, 11, 20),
);

Session _session(String value) {
  final time = SessionTime(value);
  return Session(id: time.id, time: time);
}

final class _StubShowsRepository implements ShowsRepository {
  _StubShowsRepository({this.loadPosterHandler});

  Future<Uint8List?> Function(String showId)? loadPosterHandler;
  final List<String> invalidatedPosters = <String>[];

  @override
  Future<Uint8List?> loadPoster(String showId) async {
    if (loadPosterHandler != null) return loadPosterHandler!(showId);
    return null;
  }

  @override
  void invalidatePoster(String showId) {
    invalidatedPosters.add(showId);
  }

  @override
  Future<void> addShow(NewShow show, Uint8List poster) async {}

  @override
  void clearPosterCache() {}

  @override
  Future<void> deleteShow(String showId) async {}

  @override
  void dispose() {}

  @override
  Future<void> resumeDeletes(String vendorId) async {}

  @override
  Stream<List<Show>> watchActiveShows({int limit = 100}) =>
      const Stream<List<Show>>.empty();

  @override
  Stream<List<Session>> watchSessions(String showId) =>
      const Stream<List<Session>>.empty();

  @override
  Stream<Show?> watchShow(String showId) => const Stream<Show?>.empty();

  @override
  Stream<List<Show>> watchVendorShows(String vendorId) =>
      const Stream<List<Show>>.empty();
}

void main() {
  test('sortAndBoundSessions sorts chronologically, caps at 5, and returns unmodifiable copy', () {
    final input = <Session>[
      _session('23:59'),
      _session('09:00'),
      _session('19:00'),
      _session('14:00'),
      _session('11:00'),
      _session('22:00'),
    ];

    final bounded = sortAndBoundSessions(input);

    expect(bounded.map((s) => s.id).toList(), <String>[
      '0900',
      '1100',
      '1400',
      '1900',
      '2200',
    ]);
    expect(input.map((s) => s.id).toList(), <String>[
      '2359',
      '0900',
      '1900',
      '1400',
      '1100',
      '2200',
    ]);
    expect(() => bounded.add(_session('23:59')), throwsUnsupportedError);
  });

  test('ShowFeedPosterCoordinator diffs revisions/removals, invalidates affected shows, and cleans up tokens', () async {
    final completers = <String, List<Completer<Uint8List?>>>{};
    final repo = _StubShowsRepository(
      loadPosterHandler: (showId) {
        final c = Completer<Uint8List?>();
        completers.putIfAbsent(showId, () => <Completer<Uint8List?>>[]).add(c);
        return c.future;
      },
    );
    final coordinator = ShowFeedPosterCoordinator(repo);

    final s1v1 = _show(id: 's1', title: 'S1 V1');
    final s2 = _show(id: 's2', title: 'S2');

    // Initial snapshot schedules s1 and s2.
    final plan1 = coordinator.reconcileSnapshot(
      previousShows: const <Show>[],
      nextShows: <Show>[s1v1, s2],
      currentPosters: const <String, Uint8List?>{},
      currentLoadingIds: const <String>{},
    );
    expect(plan1.retainedPosters, isEmpty);
    expect(plan1.loadingPosterIds, <String>{'s1', 's2'});
    expect(plan1.idsToLoad, <String>['s1', 's2']);
    expect(repo.invalidatedPosters, isEmpty);

    final f1 = coordinator.loadPoster(showId: 's1', isActive: () => true);
    final f2 = coordinator.loadPoster(showId: 's2', isActive: () => true);
    expect(coordinator.pendingRequestCount, 2);
    expect(coordinator.hasPendingRequest('s1'), isTrue);
    expect(coordinator.hasPendingRequest('s2'), isTrue);

    // Complete s2 -> token removed automatically.
    completers['s2']!.single.complete(Uint8List.fromList(<int>[2]));
    final res2 = await f2;
    expect(res2?.showId, 's2');
    expect(res2?.bytes, <int>[2]);
    expect(coordinator.hasPendingRequest('s2'), isFalse);
    expect(coordinator.pendingRequestCount, 1);

    // Next snapshot revises s1 while s1 load is in flight and adds s3.
    final s1v2 = _show(id: 's1', title: 'S1 V2');
    final s3 = _show(id: 's3', title: 'S3');
    final plan2 = coordinator.reconcileSnapshot(
      previousShows: <Show>[s1v1, s2],
      nextShows: <Show>[s1v2, s2, s3],
      currentPosters: <String, Uint8List?>{'s2': res2!.bytes},
      currentLoadingIds: const <String>{'s1'},
    );
    expect(repo.invalidatedPosters, <String>['s1']);
    expect(plan2.retainedPosters.keys, <String>['s2']);
    expect(plan2.loadingPosterIds, <String>{'s1', 's3'});
    expect(plan2.idsToLoad, <String>['s1', 's3']);
    // Old s1 token was cleared by reconcileSnapshot.
    expect(coordinator.hasPendingRequest('s1'), isFalse);

    final f1Revised = coordinator.loadPoster(
      showId: 's1',
      isActive: () => true,
    );
    final f3 = coordinator.loadPoster(showId: 's3', isActive: () => true);
    expect(coordinator.pendingRequestCount, 2);

    // Stale s1v1 finishes -> returns null AND leaves s1v2 token intact.
    completers['s1']![0].complete(Uint8List.fromList(<int>[1]));
    expect(await f1, isNull);
    expect(coordinator.hasPendingRequest('s1'), isTrue);

    // Newer s1v2 finishes -> returns bytes and removes token.
    completers['s1']![1].complete(Uint8List.fromList(<int>[11]));
    final res1 = await f1Revised;
    expect(res1?.bytes, <int>[11]);
    expect(coordinator.hasPendingRequest('s1'), isFalse);

    // Error on s3 maps to bytes=null and still removes token.
    completers['s3']!.single.completeError(StateError('decode error'));
    final res3 = await f3;
    expect(res3?.showId, 's3');
    expect(res3?.bytes, isNull);
    expect(coordinator.pendingRequestCount, 0);

    // Removing s2 invalidates only s2; reset() clears inactive tokens;
    // inactive load completion removes its own token and returns null.
    final plan3 = coordinator.reconcileSnapshot(
      previousShows: <Show>[s1v2, s2, s3],
      nextShows: <Show>[s1v2, s3],
      currentPosters: <String, Uint8List?>{
        's1': res1!.bytes,
        's2': res2.bytes,
        's3': res3!.bytes,
      },
      currentLoadingIds: const <String>{},
    );
    expect(repo.invalidatedPosters, <String>['s1', 's2']);
    expect(plan3.retainedPosters.keys.toSet(), <String>{'s1', 's3'});

    final fInactive = coordinator.loadPoster(
      showId: 's1',
      isActive: () => false,
    );
    expect(coordinator.pendingRequestCount, 1);
    completers['s1']![2].complete(Uint8List.fromList(<int>[99]));
    expect(await fInactive, isNull);
    expect(coordinator.pendingRequestCount, 0);

    final fReset = coordinator.loadPoster(showId: 's1', isActive: () => true);
    coordinator.reset();
    expect(coordinator.pendingRequestCount, 0);
    completers['s1']![3].complete(Uint8List.fromList(<int>[88]));
    expect(await fReset, isNull);
  });

  test('SingleShowPosterCoordinator manages revisions, stale responses, errors, and invalid shows', () async {
    final pending = <Completer<Uint8List?>>[];
    final repo = _StubShowsRepository(
      loadPosterHandler: (_) {
        final c = Completer<Uint8List?>();
        pending.add(c);
        return c.future;
      },
    );
    final coordinator = SingleShowPosterCoordinator(repo, showId: 'show-1');

    // First active revision starts load.
    final req1 = coordinator.prepareLoadForRevision('rev-1');
    expect(req1, isNotNull);
    expect(coordinator.isLoading, isTrue);
    expect(coordinator.bytes, isNull);

    // Same revision while in flight does not schedule duplicate load.
    expect(coordinator.prepareLoadForRevision('rev-1'), isNull);

    final done1 = coordinator.completeLoad(
      req1!,
      isActive: () => true,
      isShowValid: () => true,
    );

    // Revision changes while req1 is in flight -> invalidates & returns req2.
    final req2 = coordinator.prepareLoadForRevision('rev-2');
    expect(req2, isNotNull);
    expect(repo.invalidatedPosters, <String>['show-1']);

    final done2 = coordinator.completeLoad(
      req2!,
      isActive: () => true,
      isShowValid: () => true,
    );

    // Newer req2 finishes, older req1 finishes later and is ignored.
    pending[1].complete(Uint8List.fromList(<int>[2, 2]));
    expect(await done2, isTrue);
    expect(coordinator.isLoading, isFalse);
    expect(coordinator.bytes, <int>[2, 2]);

    pending[0].complete(Uint8List.fromList(<int>[1, 1]));
    expect(await done1, isFalse);
    expect(coordinator.bytes, <int>[2, 2]);

    // Same revision with loaded bytes skips reload.
    expect(coordinator.prepareLoadForRevision('rev-2'), isNull);

    // Stream error helper clears loading flag without discarding cached bytes.
    final req3 = coordinator.prepareLoadForRevision('rev-3')!;
    expect(coordinator.isLoading, isTrue);
    coordinator.cancelLoadingState();
    expect(coordinator.isLoading, isFalse);

    // Show became invalid before req3 resolved -> clears loading, returns false.
    final done3 = coordinator.completeLoad(
      req3,
      isActive: () => true,
      isShowValid: () => false,
    );
    pending[2].complete(Uint8List.fromList(<int>[3, 3]));
    expect(await done3, isFalse);
    expect(coordinator.bytes, isNull);

    // Error on load maps to bytes=null and returns true when active & valid.
    coordinator.reset(invalidateCache: true);
    expect(repo.invalidatedPosters, <String>['show-1', 'show-1', 'show-1']);
    final req4 = coordinator.prepareLoadForRevision('rev-4')!;
    final done4 = coordinator.completeLoad(
      req4,
      isActive: () => true,
      isShowValid: () => true,
    );
    pending[3].completeError(StateError('network'));
    expect(await done4, isTrue);
    expect(coordinator.isLoading, isFalse);
    expect(coordinator.bytes, isNull);
  });
}
