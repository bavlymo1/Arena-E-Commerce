import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show SemanticsAction, Tristate;

import 'package:e_commerce_project/features/vendor_shows/domain/models/new_show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session_time.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/repositories/shows_repository.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/cubit/vendor_show_details_cubit.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/screens/vendor_show_details_screen.dart';
import 'package:e_commerce_project/shared/seating/widgets/seat_map_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

Show _show({
  String id = 'apex',
  String vendorId = 'vendor-1',
  ShowStatus status = ShowStatus.active,
  int bookedCount = 5,
}) {
  return Show(
    id: id,
    vendorId: vendorId,
    title: 'Apex Finals',
    description: 'Live championship matches.',
    showDate: '2026-11-18',
    imageId: id,
    status: status,
    bookedCount: bookedCount,
    lastBookingId: '',
    createdAt: DateTime.utc(2026, 11, 17),
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

final class _ControllableVendorDetailsRepository implements ShowsRepository {
  StreamController<Show?> showController = StreamController<Show?>();
  StreamController<List<Session>> sessionsController =
      StreamController<List<Session>>();
  final deletedShowIds = <String>[];
  Future<void> Function(String showId)? deleteShowHandler;

  @override
  Stream<Show?> watchShow(String showId) => showController.stream;

  @override
  Stream<List<Session>> watchSessions(String showId) =>
      sessionsController.stream;

  Future<void> resetForRetry() async {
    await showController.close();
    await sessionsController.close();
    showController = StreamController<Show?>();
    sessionsController = StreamController<List<Session>>();
  }

  @override
  Future<Uint8List?> loadPoster(String showId) async => null;

  @override
  void invalidatePoster(String showId) {}

  @override
  void clearPosterCache() {}

  @override
  Stream<List<Show>> watchActiveShows({int limit = 100}) =>
      const Stream<List<Show>>.empty();

  @override
  Stream<List<Show>> watchVendorShows(String vendorId) =>
      const Stream<List<Show>>.empty();

  @override
  Future<void> addShow(NewShow show, Uint8List poster) async {}

  @override
  Future<void> deleteShow(String showId) async {
    deletedShowIds.add(showId);
    if (deleteShowHandler != null) {
      await deleteShowHandler!(showId);
    }
  }

  @override
  Future<void> resumeDeletes(String vendorId) async {}

  @override
  void dispose() {
    unawaited(showController.close());
    unawaited(sessionsController.close());
  }
}

Widget _buildApp(
  VendorShowDetailsCubit cubit, {
  Brightness brightness = Brightness.light,
  VoidCallback? onBackToShows,
  ValueChanged<String>? onDeleteShow,
}) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xffd52f65),
        brightness: brightness,
      ),
    ),
    home: BlocProvider<VendorShowDetailsCubit>.value(
      value: cubit,
      child: VendorShowDetailsScreen(
        onBackToShows: onBackToShows,
        onDeleteShow: onDeleteShow,
      ),
    ),
  );
}

void main() {
  testWidgets(
    'switches sessions cleanly on read-only SeatMapView without customer selection controls',
    (tester) async {
      final repo = _ControllableVendorDetailsRepository();
      addTearDown(repo.dispose);
      final cubit = VendorShowDetailsCubit(
        repo,
        vendorId: 'vendor-1',
        showId: 'apex',
      );
      var backTapped = 0;

      try {
        await tester.pumpWidget(
          _buildApp(cubit, onBackToShows: () => backTapped++),
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey<String>('vendor-show-details-loading')),
          findsOneWidget,
        );

        repo.showController.add(_show(bookedCount: 3));
        repo.sessionsController.add(<Session>[
          _session('16:00', label: 'Matinee', bookedSeats: <int>[1, 2]),
          _session('19:00', label: 'Evening', bookedSeats: <int>[10]),
        ]);
        await tester.pump();

        expect(find.text('Apex Finals'), findsOneWidget);
        expect(find.text('3 booked total'), findsOneWidget);
        expect(find.text('2 / 47 booked'), findsOneWidget);
        expect(find.text('1 / 47 booked'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.byKey(const ValueKey<String>('vendor-session-seat-map')),
          200,
          scrollable: find.byType(Scrollable).first,
        );

        final seatMapWidget = tester.widget<SeatMapView>(
          find.byKey(const ValueKey<String>('vendor-session-seat-map')),
        );
        expect(seatMapWidget.vendorMode, isTrue);
        expect(seatMapWidget.bookedSeats, <int>{1, 2});

        expect(find.text('2 / 47'), findsOneWidget);
        expect(find.bySemanticsLabel('Seat 1, row 1, Booked'), findsOneWidget);
        expect(find.text('Selected seats'), findsNothing);

        // Tapping an available seat in vendorMode must not select it.
        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('seat-grid-3')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey<String>('seat-grid-3')));
        await tester.pump();
        expect(
          find.bySemanticsLabel('Seat 3, row 1, Available'),
          findsOneWidget,
        );

        // Switch to Evening session and verify seat map updates immediately.
        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('vendor-session-option-1900')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('vendor-session-option-1900')),
        );
        await tester.pump();

        final switchedSeatMap = tester.widget<SeatMapView>(
          find.byKey(const ValueKey<String>('vendor-session-seat-map')),
        );
        expect(switchedSeatMap.bookedSeats, <int>{10});
        expect(find.text('1 / 47'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Seat 1, row 1, Available'),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('Seat 10, row 2, Booked'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey<String>('vendor-show-details-back-button')),
        );
        await tester.pump();
        expect(backTapped, 1);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(cubit.close);
      }
    },
  );

  testWidgets(
    'renders error+retry and wrong-vendor unavailable views cleanly',
    (tester) async {
      final repo = _ControllableVendorDetailsRepository();
      addTearDown(repo.dispose);
      final cubit = VendorShowDetailsCubit(
        repo,
        vendorId: 'vendor-1',
        showId: 'apex',
      );
      var backTapped = 0;

      try {
        await tester.pumpWidget(
          _buildApp(cubit, onBackToShows: () => backTapped++),
        );
        await tester.pump();

        repo.showController.addError(StateError('network lost'));
        await tester.pump();
        expect(
          find.byKey(const ValueKey<String>('vendor-show-details-error-state')),
          findsOneWidget,
        );

        await repo.resetForRetry();
        await tester.tap(
          find.byKey(
            const ValueKey<String>('vendor-show-details-retry-button'),
          ),
        );
        await tester.pump();

        repo.showController.add(_show(vendorId: 'other-vendor'));
        repo.sessionsController.add(<Session>[
          _session('19:00', bookedSeats: <int>[1]),
        ]);
        await tester.pump();

        expect(
          find.byKey(
            const ValueKey<String>('vendor-show-details-unavailable-state'),
          ),
          findsOneWidget,
        );
        expect(find.byType(SeatMapView), findsNothing);

        await tester.tap(
          find.byKey(
            const ValueKey<String>(
              'vendor-show-details-unavailable-back-button',
            ),
          ),
        );
        await tester.pump();
        expect(backTapped, 1);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(cubit.close);
      }
    },
  );

  testWidgets(
    'renders without overflow on dark 300x640 viewport at 2.0x scale',
    (tester) async {
      tester.view.physicalSize = const Size(300, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final repo = _ControllableVendorDetailsRepository();
      addTearDown(repo.dispose);
      final cubit = VendorShowDetailsCubit(
        repo,
        vendorId: 'vendor-1',
        showId: 'apex',
      );

      try {
        repo.showController.add(_show(bookedCount: 12));
        repo.sessionsController.add(<Session>[
          _session('19:00', label: 'Main Evening', bookedSeats: <int>[1, 2, 3]),
        ]);

        await tester.pumpWidget(
          _buildApp(cubit, brightness: Brightness.dark, onDeleteShow: (_) {}),
        );
        await tester.pump();

        await tester.scrollUntilVisible(
          find.byKey(const ValueKey<String>('vendor-session-seat-map')),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byType(SeatMapView), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(cubit.close);
      }
    },
  );

  testWidgets(
    'built-in delete confirmation shows progress without flipping to unavailable, retries on error, and pops on completion',
    (tester) async {
      final firstAttempt = Completer<void>();
      final secondAttempt = Completer<void>();
      var attempts = 0;
      final repo = _ControllableVendorDetailsRepository()
        ..deleteShowHandler = (_) {
          attempts++;
          return attempts == 1 ? firstAttempt.future : secondAttempt.future;
        };
      addTearDown(repo.dispose);
      final cubit = VendorShowDetailsCubit(
        repo,
        vendorId: 'vendor-1',
        showId: 'apex',
      );
      var backTapped = 0;

      try {
        repo.showController.add(_show(bookedCount: 5));
        repo.sessionsController.add(<Session>[
          _session('19:00', label: 'Evening', bookedSeats: <int>[1, 2]),
        ]);

        await tester.pumpWidget(
          _buildApp(cubit, onBackToShows: () => backTapped++),
        );
        await tester.pump();

        // Tap Delete show button -> confirm dialog -> Cancel first.
        await tester.ensureVisible(
          find.byKey(
            const ValueKey<String>('vendor-show-details-delete-button'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(
            const ValueKey<String>('vendor-show-details-delete-button'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('delete-show-confirm-dialog')),
          findsOneWidget,
        );
        expect(find.text('Delete Apex Finals?'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey<String>('delete-show-cancel-button')),
        );
        await tester.pumpAndSettle();
        expect(repo.deletedShowIds, isEmpty);

        // Tap Delete and confirm.
        await tester.tap(
          find.byKey(
            const ValueKey<String>('vendor-show-details-delete-button'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('delete-show-confirm-button')),
        );
        await tester.pump();

        expect(repo.deletedShowIds, <String>['apex']);
        expect(
          find.byKey(
            const ValueKey<String>('vendor-show-details-deleting-progress'),
          ),
          findsOneWidget,
        );

        // Snapshot emits status: deleting mid-delete -> must stay on progress screen, NOT unavailable!
        repo.showController.add(_show(status: ShowStatus.deleting));
        await tester.pump();
        expect(
          find.byKey(
            const ValueKey<String>('vendor-show-details-unavailable-state'),
          ),
          findsNothing,
        );
        expect(
          find.byKey(
            const ValueKey<String>('vendor-show-details-deleting-progress'),
          ),
          findsOneWidget,
        );

        // Fail first attempt -> shows retryable error banner.
        firstAttempt.completeError(StateError('batch failed'));
        await tester.pump();
        expect(
          find.byKey(
            const ValueKey<String>('vendor-show-details-delete-error'),
          ),
          findsOneWidget,
        );
        expect(backTapped, 0);

        // Tap Retry delete -> parent deleted (null snapshot) -> completes -> BlocListener pops back to My Shows.
        await tester.ensureVisible(
          find.byKey(
            const ValueKey<String>('vendor-show-details-delete-retry-button'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(
            const ValueKey<String>('vendor-show-details-delete-retry-button'),
          ),
        );
        await tester.pump();
        repo.showController.add(null);
        await tester.pump();
        secondAttempt.complete();
        await tester.pump();

        expect(backTapped, 1);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(cubit.close);
      }
    },
  );

  testWidgets(
    'disables session selection controls and semantics while show is deleting',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      final deleteGate = Completer<void>();
      final repo = _ControllableVendorDetailsRepository()
        ..deleteShowHandler = (_) => deleteGate.future;
      addTearDown(repo.dispose);
      final cubit = VendorShowDetailsCubit(
        repo,
        vendorId: 'vendor-1',
        showId: 'apex',
      );

      try {
        repo.showController.add(_show(bookedCount: 3));
        repo.sessionsController.add(<Session>[
          _session('16:00', label: 'Matinee', bookedSeats: <int>[1, 2]),
          _session('19:00', label: 'Evening', bookedSeats: <int>[10]),
        ]);

        await tester.pumpWidget(_buildApp(cubit, onBackToShows: () {}));
        await tester.pumpAndSettle();

        final eveningTileFinder = find.byKey(
          const ValueKey<String>('vendor-session-option-1900'),
        );
        final eveningInkWellBefore = tester.widget<InkWell>(
          find.descendant(
            of: eveningTileFinder,
            matching: find.byType(InkWell),
          ),
        );
        expect(eveningInkWellBefore.onTap, isNotNull);
        final semanticsBefore = tester
            .getSemantics(eveningTileFinder)
            .getSemanticsData();
        expect(semanticsBefore.hasAction(SemanticsAction.tap), isTrue);
        expect(semanticsBefore.flagsCollection.isEnabled, Tristate.isTrue);

        // Start delete without completing it so state.isDeletingShow stays true.
        await tester.tap(
          find.byKey(
            const ValueKey<String>('vendor-show-details-delete-button'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('delete-show-confirm-button')),
        );
        await tester.pump();
        expect(cubit.state.isDeletingShow, isTrue);

        await tester.ensureVisible(eveningTileFinder);
        await tester.pump();

        final eveningInkWellDeleting = tester.widget<InkWell>(
          find.descendant(
            of: eveningTileFinder,
            matching: find.byType(InkWell),
          ),
        );
        expect(eveningInkWellDeleting.onTap, isNull);

        final semanticsDeleting = tester
            .getSemantics(eveningTileFinder)
            .getSemanticsData();
        expect(semanticsDeleting.hasAction(SemanticsAction.tap), isFalse);
        expect(semanticsDeleting.flagsCollection.isEnabled, Tristate.isFalse);

        // Tapping the disabled session tile does not change selected session.
        await tester.tap(eveningTileFinder);
        await tester.pump();
        expect(cubit.state.selectedSessionId, '1600');

        deleteGate.complete();
        await tester.pump();
      } finally {
        semanticsHandle.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(cubit.close);
      }
    },
  );
}
