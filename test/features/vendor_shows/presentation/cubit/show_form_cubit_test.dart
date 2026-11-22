import 'dart:async';
import 'dart:typed_data';

import 'package:e_commerce_project/features/vendor_shows/domain/models/new_show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session_time.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/repositories/shows_repository.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/cubit/show_form_cubit.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/cubit/show_form_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_shows_repository.dart';

final class _ControllableAddShowRepository implements ShowsRepository {
  final List<(NewShow, Uint8List)> added = <(NewShow, Uint8List)>[];
  Future<void> Function(NewShow show, Uint8List poster)? addShowHandler;
  bool disposed = false;

  @override
  Future<void> addShow(NewShow show, Uint8List poster) {
    if (addShowHandler != null) {
      return addShowHandler!(show, poster);
    }
    added.add((show, Uint8List.fromList(poster)));
    return Future<void>.value();
  }

  @override
  Stream<List<Show>> watchActiveShows({int limit = 100}) =>
      const Stream<List<Show>>.empty();

  @override
  Stream<List<Show>> watchVendorShows(String vendorId) =>
      const Stream<List<Show>>.empty();

  @override
  Stream<Show?> watchShow(String showId) => const Stream<Show?>.empty();

  @override
  Stream<List<Session>> watchSessions(String showId) =>
      const Stream<List<Session>>.empty();

  @override
  Future<void> deleteShow(String showId) async {}

  @override
  Future<void> resumeDeletes(String vendorId) async {}

  @override
  Future<Uint8List?> loadPoster(String showId) async => null;

  @override
  void invalidatePoster(String showId) {}

  @override
  void clearPosterCache() {}

  @override
  void dispose() => disposed = true;
}

void main() {
  test(
    'recovers startup artwork while the poster field is untouched',
    () async {
      final repo = FakeShowsRepository();
      addTearDown(repo.dispose);
      final recovery = Completer<Uint8List?>();
      final cubit = ShowFormCubit(
        repo,
        vendorId: 'arena',
        recoverPoster: () => recovery.future,
      );
      addTearDown(cubit.close);

      expect(cubit.state.isBusy, isFalse);
      final applied = cubit.stream.firstWhere((state) => state.hasPoster);
      recovery.complete(Uint8List.fromList([1, 2, 3]));
      expect((await applied).posterBytes, [1, 2, 3]);
    },
  );

  for (final source in ShowPosterSource.values) {
    test(
      'late startup recovery cannot replace a selected ${source.name} poster',
      () async {
        final repo = FakeShowsRepository();
        addTearDown(repo.dispose);
        final recovery = Completer<Uint8List?>();
        final cubit = ShowFormCubit(
          repo,
          vendorId: 'arena',
          posterPicker: (_) async => Uint8List.fromList([8, 9]),
          recoverPoster: () => recovery.future,
        );
        addTearDown(cubit.close);

        await cubit.pickPoster(source);
        recovery.complete(Uint8List.fromList([1, 2, 3]));
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.posterBytes, [8, 9]);
      },
    );
  }

  test(
    'cancelling a new pick preserves the poster already recovered',
    () async {
      final repo = FakeShowsRepository();
      addTearDown(repo.dispose);
      final cubit = ShowFormCubit(
        repo,
        vendorId: 'arena',
        posterPicker: (_) async => null,
        recoverPoster: () async => Uint8List.fromList([1, 2, 3]),
      );
      addTearDown(cubit.close);

      await cubit.stream.firstWhere((state) => state.hasPoster);
      await cubit.pickPoster(ShowPosterSource.gallery);
      expect(cubit.state.posterBytes, [1, 2, 3]);
      expect(cubit.state.posterError, isNull);
    },
  );

  test(
    'startup recovery completing after close cannot change form state',
    () async {
      final repo = FakeShowsRepository();
      addTearDown(repo.dispose);
      final recovery = Completer<Uint8List?>();
      final cubit = ShowFormCubit(
        repo,
        vendorId: 'arena',
        recoverPoster: () => recovery.future,
      );
      await cubit.close();
      recovery.complete(Uint8List.fromList([1, 2, 3]));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.posterBytes, isNull);
    },
  );

  test('rejects blank vendorId and starts with one empty session slot', () {
    final repo = FakeShowsRepository();
    addTearDown(repo.dispose);

    expect(() => ShowFormCubit(repo, vendorId: '   '), throwsArgumentError);

    final cubit = ShowFormCubit(repo, vendorId: 'arena');
    addTearDown(cubit.close);

    expect(cubit.state.vendorId, 'arena');
    expect(cubit.state.status, ShowFormStatus.editing);
    expect(cubit.state.sessionTimes, <String>['']);
    expect(cubit.state.canAddSession, isTrue);
    expect(cubit.state.hasPoster, isFalse);
  });

  test('validates required fields, max lengths, calendar dates, poster bytes, and session slots before calling addShow', () async {
    final repo = FakeShowsRepository();
    addTearDown(repo.dispose);
    final cubit = ShowFormCubit(repo, vendorId: 'arena');
    addTearDown(cubit.close);

    await cubit.submit();
    expect(cubit.state.titleError, ShowFormCubit.titleRequiredMessage);
    expect(
      cubit.state.descriptionError,
      ShowFormCubit.descriptionRequiredMessage,
    );
    expect(cubit.state.showDateError, ShowFormCubit.showDateRequiredMessage);
    expect(cubit.state.posterError, ShowFormCubit.posterRequiredMessage);
    expect(cubit.state.sessionsError, ShowFormCubit.sessionsInvalidMessage);
    expect(repo.added, isEmpty);

    cubit.updateTitle('a' * 81);
    cubit.updateDescription('b' * 1001);
    cubit.updateShowDate('2027-02-29'); // non-leap year
    cubit.updateSessionTime(0, '24:00');
    await cubit.submit();

    expect(cubit.state.titleError, ShowFormCubit.titleTooLongMessage);
    expect(
      cubit.state.descriptionError,
      ShowFormCubit.descriptionTooLongMessage,
    );
    expect(cubit.state.showDateError, ShowFormCubit.showDateInvalidMessage);
    expect(cubit.state.sessionsError, ShowFormCubit.sessionsInvalidMessage);

    // Rejects impossible calendar day 2026-02-30 and empty sessions list.
    cubit.updateTitle('Apex Finals');
    cubit.updateDescription('Live arena show');
    cubit.updateShowDate('2026-02-30');
    cubit.removeSessionSlot(0);
    await cubit.submit();

    expect(cubit.state.titleError, isNull);
    expect(cubit.state.descriptionError, isNull);
    expect(cubit.state.showDateError, ShowFormCubit.showDateInvalidMessage);
    expect(cubit.state.sessionsError, ShowFormCubit.sessionsInvalidMessage);
    expect(repo.added, isEmpty);
  });

  test('manages adding/removing slots, five-slot cap, and duplicate-time rejection', () async {
    final repo = FakeShowsRepository();
    addTearDown(repo.dispose);
    final cubit = ShowFormCubit(repo, vendorId: 'arena');
    addTearDown(cubit.close);

    cubit.updateTitle('Apex Finals');
    cubit.updateDescription('Championship live');
    cubit.updateShowDate('2028-02-29');
    cubit.setPosterBytes(Uint8List.fromList(<int>[1, 2, 3, 4]));

    cubit.updateSessionTime(0, '09:00');
    cubit.addSessionSlot();
    cubit.updateSessionTime(1, '12:00');
    cubit.addSessionSlot();
    cubit.updateSessionTime(2, '15:00');
    cubit.addSessionSlot();
    cubit.updateSessionTime(3, '18:00');
    cubit.addSessionSlot();
    cubit.updateSessionTime(4, '21:00');

    expect(cubit.state.sessionTimes, hasLength(5));
    expect(cubit.state.canAddSession, isFalse);

    // Attempting a 6th slot preserves 5 slots and emits explicit limit message.
    cubit.addSessionSlot();
    expect(cubit.state.sessionTimes, hasLength(5));
    expect(cubit.state.sessionsError, ShowFormCubit.maxSessionsReachedMessage);

    // Duplicate session times are rejected with explicit duplicate message.
    cubit.removeSessionSlot(4);
    cubit.removeSessionSlot(3);
    cubit.removeSessionSlot(2);
    expect(cubit.state.sessionTimes, <String>['09:00', '12:00']);
    cubit.updateSessionTime(1, '09:00');
    await cubit.submit();
    expect(cubit.state.sessionsError, ShowFormCubit.sessionsDuplicateMessage);
    expect(repo.added, isEmpty);

    // Fixing duplicate allows submission.
    cubit.updateSessionTime(1, '19:00');
    await cubit.submit();
    expect(cubit.state.isSubmitted, isTrue);
    expect(repo.added, hasLength(1));
    expect(repo.added.single.$1.sessions, <SessionTime>[
      SessionTime('09:00'),
      SessionTime('19:00'),
    ]);
    expect(repo.added.single.$2, <int>[1, 2, 3, 4]);
  });

  test('supports gallery and camera picking, preserves prior poster on cancel/error, and rejects invalid byte payloads', () async {
    final repo = FakeShowsRepository();
    addTearDown(repo.dispose);
    final sources = <ShowPosterSource>[];
    Uint8List? nextResult = Uint8List.fromList(<int>[10, 20, 30]);
    var shouldThrow = false;

    final cubit = ShowFormCubit(
      repo,
      vendorId: 'arena',
      posterPicker: (source) async {
        sources.add(source);
        if (shouldThrow) throw StateError('Picker error');
        return nextResult;
      },
    );
    addTearDown(cubit.close);

    // Gallery pick succeeds.
    await cubit.pickPoster(ShowPosterSource.gallery);
    expect(sources, <ShowPosterSource>[ShowPosterSource.gallery]);
    expect(cubit.state.posterBytes, <int>[10, 20, 30]);
    expect(cubit.state.posterError, isNull);

    // Camera cancellation (null) preserves existing poster bytes with no error.
    nextResult = null;
    await cubit.pickPoster(ShowPosterSource.camera);
    expect(sources, <ShowPosterSource>[
      ShowPosterSource.gallery,
      ShowPosterSource.camera,
    ]);
    expect(cubit.state.status, ShowFormStatus.editing);
    expect(cubit.state.posterBytes, <int>[10, 20, 30]);
    expect(cubit.state.posterError, isNull);

    // Empty bytes rejected while preserving prior valid poster.
    nextResult = Uint8List(0);
    await cubit.pickPoster(ShowPosterSource.gallery);
    expect(cubit.state.posterError, ShowFormCubit.posterEmptyMessage);
    expect(cubit.state.posterBytes, <int>[10, 20, 30]);

    // Oversized payload (> 204800 bytes) rejected while preserving prior valid poster.
    nextResult = Uint8List(ShowFormState.maxPosterBytes + 1);
    await cubit.pickPoster(ShowPosterSource.camera);
    expect(cubit.state.posterError, ShowFormCubit.posterTooLargeMessage);
    expect(cubit.state.posterBytes, <int>[10, 20, 30]);

    // Picker failure surfaces safe error and preserves prior valid poster.
    shouldThrow = true;
    await cubit.pickPoster(ShowPosterSource.camera);
    expect(cubit.state.posterError, ShowFormCubit.posterPickFailedMessage);
    expect(cubit.state.posterBytes, <int>[10, 20, 30]);

    // Camera replacement with valid payload succeeds.
    shouldThrow = false;
    nextResult = Uint8List.fromList(<int>[40, 50]);
    await cubit.pickPoster(ShowPosterSource.camera);
    expect(cubit.state.posterBytes, <int>[40, 50]);
    expect(cubit.state.posterError, isNull);
  });

  test('reports unavailable picker when no callback is wired and ignores mutations while picking', () async {
    final repo = FakeShowsRepository();
    addTearDown(repo.dispose);
    final cubit = ShowFormCubit(repo, vendorId: 'arena');
    addTearDown(cubit.close);

    await cubit.pickPoster(ShowPosterSource.gallery);
    expect(
      cubit.state.posterError,
      ShowFormCubit.posterPickerUnavailableMessage,
    );

    final pickGate = Completer<Uint8List?>();
    final pickingFuture = cubit.pickPoster(
      ShowPosterSource.camera,
      picker: (_) => pickGate.future,
    );
    expect(cubit.state.isPickingPoster, isTrue);

    // Submit while picking poster is ignored.
    await cubit.submit();
    expect(repo.added, isEmpty);

    pickGate.complete(Uint8List.fromList(<int>[7, 8]));
    await pickingFuture;
    expect(cubit.state.status, ShowFormStatus.editing);
    expect(cubit.state.posterBytes, <int>[7, 8]);
  });

  test('prevents duplicate submits, preserves form input on failure, and succeeds on retry', () async {
    final gate = Completer<void>();
    var failNextSubmit = true;
    var callCount = 0;

    final repo = _ControllableAddShowRepository()
      ..addShowHandler = (show, poster) async {
        callCount++;
        if (callCount == 1) {
          await gate.future;
        }
        if (failNextSubmit) {
          throw StateError('Network timeout');
        }
        return;
      };
    addTearDown(repo.dispose);

    final cubit = ShowFormCubit(repo, vendorId: 'arena');
    addTearDown(cubit.close);

    cubit.updateTitle('  Neon Horizon  ');
    cubit.updateDescription('  Evening stunt show  ');
    cubit.updateShowDate('2026-11-20');
    cubit.updateSessionTime(0, '14:00');
    cubit.addSessionSlot();
    cubit.updateSessionTime(1, '19:00');
    final poster = Uint8List.fromList(<int>[1, 3, 5, 7]);
    cubit.setPosterBytes(poster);

    final firstSubmit = cubit.submit();
    final duplicateSubmit = cubit.submit();
    expect(cubit.state.isSubmitting, isTrue);
    expect(callCount, 1);

    gate.complete();
    await Future.wait<void>(<Future<void>>[firstSubmit, duplicateSubmit]);

    // Failure retains every form input and surfaces recoverable message.
    expect(cubit.state.status, ShowFormStatus.failure);
    expect(cubit.state.submitErrorMessage, ShowFormCubit.submitFailedMessage);
    expect(cubit.state.title, '  Neon Horizon  ');
    expect(cubit.state.description, '  Evening stunt show  ');
    expect(cubit.state.showDate, '2026-11-20');
    expect(cubit.state.sessionTimes, <String>['14:00', '19:00']);
    expect(cubit.state.posterBytes, <int>[1, 3, 5, 7]);
    expect(cubit.state.submissionCount, 0);

    // Retry succeeds with retained inputs.
    failNextSubmit = false;
    final saved = <(NewShow, Uint8List)>[];
    repo.addShowHandler = (show, bytes) async {
      callCount++;
      saved.add((show, bytes));
    };

    await cubit.submit();
    expect(callCount, 2);
    expect(cubit.state.status, ShowFormStatus.submitted);
    expect(cubit.state.submissionCount, 1);
    expect(cubit.state.submitErrorMessage, isNull);
    expect(saved.single.$1.title, 'Neon Horizon');
    expect(saved.single.$1.description, 'Evening stunt show');
    expect(saved.single.$1.showDate, '2026-11-20');
    expect(saved.single.$1.sessions, <SessionTime>[
      SessionTime('14:00'),
      SessionTime('19:00'),
    ]);
    expect(saved.single.$2, <int>[1, 3, 5, 7]);
  });

  test(
    'ignores late completions after close and does not dispose repository',
    () async {
      final submitGate = Completer<void>();
      final repo = _ControllableAddShowRepository()
        ..addShowHandler = (_, _) => submitGate.future;
      addTearDown(repo.dispose);

      final cubit = ShowFormCubit(repo, vendorId: 'arena');
      cubit.updateTitle('Closing Show');
      cubit.updateDescription('Details');
      cubit.updateShowDate('2026-11-25');
      cubit.updateSessionTime(0, '19:00');
      cubit.setPosterBytes(Uint8List.fromList(<int>[9, 9]));

      final pending = cubit.submit();
      expect(cubit.state.isSubmitting, isTrue);

      await cubit.close();
      expect(cubit.isClosed, isTrue);
      expect(repo.disposed, isFalse);

      submitGate.complete();
      await pending;
      expect(cubit.state.status, ShowFormStatus.submitting);
    },
  );

  test('tracks pickingPosterSource per source and clears it across every terminal branch', () async {
    final repo = FakeShowsRepository();
    addTearDown(repo.dispose);
    final cubit = ShowFormCubit(repo, vendorId: 'arena');
    addTearDown(cubit.close);

    expect(cubit.state.pickingPosterSource, isNull);

    // Equatable props distinguish pickingPosterSource values and copyWith clears cleanly.
    final cameraState = cubit.state.copyWith(
      status: ShowFormStatus.pickingPoster,
      pickingPosterSource: ShowPosterSource.camera,
    );
    final galleryState = cubit.state.copyWith(
      status: ShowFormStatus.pickingPoster,
      pickingPosterSource: ShowPosterSource.gallery,
    );
    expect(cameraState, isNot(equals(galleryState)));
    expect(
      cameraState.copyWith(status: ShowFormStatus.editing).pickingPosterSource,
      isNull,
    );
    expect(
      cameraState.copyWith(clearPickingPosterSource: true).pickingPosterSource,
      isNull,
    );

    // Unavailable picker leaves pickingPosterSource null.
    await cubit.pickPoster(ShowPosterSource.camera);
    expect(cubit.state.isPickingPoster, isFalse);
    expect(cubit.state.pickingPosterSource, isNull);

    // Camera pick -> valid bytes clears pickingPosterSource; typing while picking preserves it.
    final validGate = Completer<Uint8List?>();
    final validFuture = cubit.pickPoster(
      ShowPosterSource.camera,
      picker: (_) => validGate.future,
    );
    expect(cubit.state.isPickingPoster, isTrue);
    expect(cubit.state.pickingPosterSource, ShowPosterSource.camera);
    cubit.updateTitle('Draft');
    expect(cubit.state.pickingPosterSource, ShowPosterSource.camera);
    validGate.complete(Uint8List.fromList(<int>[1, 2, 3]));
    await validFuture;
    expect(cubit.state.isPickingPoster, isFalse);
    expect(cubit.state.pickingPosterSource, isNull);

    // Gallery pick -> cancelled (null) clears pickingPosterSource.
    final cancelGate = Completer<Uint8List?>();
    final cancelFuture = cubit.pickPoster(
      ShowPosterSource.gallery,
      picker: (_) => cancelGate.future,
    );
    expect(cubit.state.pickingPosterSource, ShowPosterSource.gallery);
    cancelGate.complete(null);
    await cancelFuture;
    expect(cubit.state.isPickingPoster, isFalse);
    expect(cubit.state.pickingPosterSource, isNull);

    // Camera pick -> validation error clears pickingPosterSource.
    final invalidGate = Completer<Uint8List?>();
    final invalidFuture = cubit.pickPoster(
      ShowPosterSource.camera,
      picker: (_) => invalidGate.future,
    );
    expect(cubit.state.pickingPosterSource, ShowPosterSource.camera);
    invalidGate.complete(Uint8List(0));
    await invalidFuture;
    expect(cubit.state.isPickingPoster, isFalse);
    expect(cubit.state.pickingPosterSource, isNull);
    expect(cubit.state.posterError, ShowFormCubit.posterEmptyMessage);

    // Gallery pick -> exception clears pickingPosterSource.
    final errorGate = Completer<Uint8List?>();
    final errorFuture = cubit.pickPoster(
      ShowPosterSource.gallery,
      picker: (_) => errorGate.future,
    );
    expect(cubit.state.pickingPosterSource, ShowPosterSource.gallery);
    errorGate.completeError(const FormatException('bad image'));
    await errorFuture;
    expect(cubit.state.isPickingPoster, isFalse);
    expect(cubit.state.pickingPosterSource, isNull);
    expect(cubit.state.posterError, ShowFormCubit.posterFormatMessage);
  });
}
