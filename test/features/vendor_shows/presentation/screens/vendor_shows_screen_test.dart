import 'dart:async';
import 'dart:typed_data';

import 'package:e_commerce_project/features/vendor_shows/domain/models/new_show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/repositories/shows_repository.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/cubit/vendor_shows_cubit.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/screens/vendor_shows_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

Show _show({
  required String id,
  String vendorId = 'vendor-1',
  required String title,
  ShowStatus status = ShowStatus.active,
  int bookedCount = 0,
  DateTime? createdAt,
}) {
  return Show(
    id: id,
    vendorId: vendorId,
    title: title,
    description: 'Live stage championship',
    showDate: '2026-11-18',
    imageId: id,
    status: status,
    bookedCount: bookedCount,
    lastBookingId: '',
    createdAt: createdAt,
  );
}

final class _ControllableVendorShowsRepository implements ShowsRepository {
  StreamController<List<Show>> controller = StreamController<List<Show>>();
  bool failWithError = false;
  final showsToEmit = <Show>[];
  int cacheClears = 0;
  final deletedShowIds = <String>[];
  Future<void> Function(String showId)? deleteShowHandler;

  @override
  Stream<List<Show>> watchVendorShows(String vendorId) => controller.stream;

  void emitCurrent() {
    if (failWithError) {
      controller.addError(StateError('Failed to fetch shows'));
    } else {
      controller.add(List<Show>.from(showsToEmit));
    }
  }

  Future<void> resetForRetry() async {
    await controller.close();
    controller = StreamController<List<Show>>();
  }

  @override
  Future<Uint8List?> loadPoster(String showId) async => null;

  @override
  void invalidatePoster(String showId) {}

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
    unawaited(controller.close());
  }
}

Widget _buildApp(
  VendorShowsCubit cubit, {
  Brightness brightness = Brightness.light,
  required ValueChanged<String> onShowSelected,
  VoidCallback? onAddShow,
  ValueChanged<String>? onDeleteShow,
  VoidCallback? onOpenUpdates,
  int unreadUpdatesCount = 0,
}) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xffd52f65),
        brightness: brightness,
      ),
    ),
    home: BlocProvider<VendorShowsCubit>.value(
      value: cubit,
      child: VendorShowsScreen(
        onShowSelected: onShowSelected,
        onAddShow: onAddShow,
        onDeleteShow: onDeleteShow,
        onOpenUpdates: onOpenUpdates,
        unreadUpdatesCount: unreadUpdatesCount,
      ),
    ),
  );
}

void main() {
  testWidgets(
    'shows loading, empty, error+retry, and ready newest-first states',
    (tester) async {
      final repo = _ControllableVendorShowsRepository();
      addTearDown(repo.dispose);
      final cubit = VendorShowsCubit(repo, vendorId: 'vendor-1');
      final selected = <String>[];

      try {
        await tester.pumpWidget(_buildApp(cubit, onShowSelected: selected.add));
        await tester.pump();
        expect(
          find.byKey(const ValueKey<String>('vendor-shows-loading')),
          findsOneWidget,
        );

        // Stream error -> Retry -> Empty -> Populated.
        repo.failWithError = true;
        repo.emitCurrent();
        await tester.pump();
        expect(
          find.byKey(const ValueKey<String>('vendor-shows-error-state')),
          findsOneWidget,
        );

        repo.failWithError = false;
        await repo.resetForRetry();
        await tester.tap(
          find.byKey(const ValueKey<String>('vendor-shows-retry-button')),
        );
        await tester.pump();
        repo.emitCurrent();
        await tester.pump();
        expect(
          find.byKey(const ValueKey<String>('vendor-shows-empty-state')),
          findsOneWidget,
        );

        repo.controller.add(<Show>[
          _show(
            id: 'older',
            title: 'Older Show',
            bookedCount: 12,
            createdAt: DateTime.utc(2026, 11, 10),
          ),
          _show(
            id: 'newest',
            title: 'Newest Show',
            bookedCount: 33,
            createdAt: DateTime.utc(2026, 11, 20),
          ),
          _show(
            id: 'deleting',
            title: 'Interrupted Show',
            status: ShowStatus.deleting,
            bookedCount: 7,
            createdAt: DateTime.utc(2026, 11, 15),
          ),
        ]);
        await tester.pump();

        expect(find.text('Newest Show'), findsOneWidget);
        expect(find.text('33 booked total'), findsOneWidget);
        expect(
          find.text('Deletion interrupted. Bookings closed.'),
          findsOneWidget,
        );

        final newestTop = tester
            .getTopLeft(
              find.byKey(const ValueKey<String>('vendor-show-card-newest')),
            )
            .dy;
        final deletingTop = tester
            .getTopLeft(
              find.byKey(const ValueKey<String>('vendor-show-card-deleting')),
            )
            .dy;
        expect(newestTop, lessThan(deletingTop));

        // Tapping deleting card must not open show details.
        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('vendor-show-card-deleting')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('vendor-show-card-deleting')),
        );
        await tester.pump();
        expect(selected, isEmpty);

        // Tapping active card invokes onShowSelected.
        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('vendor-show-card-newest')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Newest Show'));
        await tester.pump();
        expect(selected, <String>['newest']);

        // Subsequent stream error preserves existing shows and offers inline retry.
        repo.controller.addError(StateError('transient stream drop'));
        await tester.pump();
        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('vendor-shows-inline-error')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('vendor-shows-inline-error')),
          findsOneWidget,
        );
        expect(find.text('Newest Show'), findsOneWidget);

        await repo.resetForRetry();
        await tester.tap(
          find.byKey(
            const ValueKey<String>('vendor-shows-inline-retry-button'),
          ),
        );
        await tester.pump();
        repo.controller.add(<Show>[
          _show(
            id: 'newest',
            title: 'Newest Show',
            bookedCount: 34,
            createdAt: DateTime.utc(2026, 11, 20),
          ),
        ]);
        await tester.pump();
        expect(find.text('34 booked total'), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('vendor-shows-inline-error')),
          findsNothing,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(cubit.close);
      }
    },
  );

  testWidgets(
    'invokes optional add, delete, and updates callbacks without faking mutations',
    (tester) async {
      final repo = _ControllableVendorShowsRepository();
      addTearDown(repo.dispose);
      final cubit = VendorShowsCubit(repo, vendorId: 'vendor-1');
      var addTapped = 0;
      var updatesTapped = 0;
      final deleteTapped = <String>[];

      try {
        repo.controller.add(<Show>[
          _show(
            id: 'show-1',
            title: 'Arena Finals',
            bookedCount: 19,
            createdAt: DateTime.utc(2026, 11, 18),
          ),
        ]);

        await tester.pumpWidget(
          _buildApp(
            cubit,
            onShowSelected: (_) {},
            onAddShow: () => addTapped++,
            onDeleteShow: deleteTapped.add,
            onOpenUpdates: () => updatesTapped++,
            unreadUpdatesCount: 3,
          ),
        );
        await tester.pump();

        await tester.tap(
          find.byKey(const ValueKey<String>('vendor-shows-add-button')),
        );
        await tester.tap(
          find.byKey(
            const ValueKey<String>('vendor-shows-appbar-updates-button'),
          ),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('vendor-show-delete-show-1')),
        );
        await tester.pump();

        expect(addTapped, 1);
        expect(updatesTapped, 1);
        expect(deleteTapped, <String>['show-1']);
        expect(find.text('Arena Finals'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(cubit.close);
      }
    },
  );

  testWidgets(
    'renders without overflow on dark narrow 300x640 viewport at 2.0x text scale',
    (tester) async {
      tester.view.physicalSize = const Size(300, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final repo = _ControllableVendorShowsRepository();
      addTearDown(repo.dispose);
      final cubit = VendorShowsCubit(repo, vendorId: 'vendor-1');

      try {
        repo.controller.add(<Show>[
          _show(
            id: 'show-1',
            title: 'World Arena Finals Championship',
            bookedCount: 41,
            createdAt: DateTime.utc(2026, 11, 18),
          ),
        ]);

        await tester.pumpWidget(
          _buildApp(
            cubit,
            brightness: Brightness.dark,
            onShowSelected: (_) {},
            onAddShow: () {},
            onDeleteShow: (_) {},
            onOpenUpdates: () {},
            unreadUpdatesCount: 4,
          ),
        );
        await tester.pump();

        await tester.scrollUntilVisible(
          find.text('41 booked total'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('41 booked total'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(cubit.close);
      }
    },
  );

  testWidgets(
    'built-in delete confirmation dialog cancels or deletes with progress and retryable error state',
    (tester) async {
      final firstAttempt = Completer<void>();
      final secondAttempt = Completer<void>();
      var attempts = 0;
      final repo = _ControllableVendorShowsRepository()
        ..deleteShowHandler = (_) {
          attempts++;
          return attempts == 1 ? firstAttempt.future : secondAttempt.future;
        };
      addTearDown(repo.dispose);
      final cubit = VendorShowsCubit(repo, vendorId: 'vendor-1');

      try {
        repo.controller.add(<Show>[
          _show(
            id: 'show-1',
            title: 'Arena Finals',
            bookedCount: 19,
            createdAt: DateTime.utc(2026, 11, 18),
          ),
        ]);

        await tester.pumpWidget(_buildApp(cubit, onShowSelected: (_) {}));
        await tester.pump();

        // Tap Delete -> opens confirm dialog naming the show and warning bookings/seats will be removed.
        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('vendor-show-delete-show-1')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('vendor-show-delete-show-1')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('delete-show-confirm-dialog')),
          findsOneWidget,
        );
        expect(find.text('Delete Arena Finals?'), findsOneWidget);
        expect(
          find.textContaining('bookings, and seat records for "Arena Finals"'),
          findsOneWidget,
        );

        // Cancel dismisses dialog without calling deleteShow.
        await tester.tap(
          find.byKey(const ValueKey<String>('delete-show-cancel-button')),
        );
        await tester.pumpAndSettle();
        expect(repo.deletedShowIds, isEmpty);

        // Tap Delete again and confirm.
        await tester.tap(
          find.byKey(const ValueKey<String>('vendor-show-delete-show-1')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('delete-show-confirm-button')),
        );
        await tester.pump();

        expect(repo.deletedShowIds, <String>['show-1']);
        expect(
          find.byKey(
            const ValueKey<String>('vendor-show-deleting-progress-show-1'),
          ),
          findsOneWidget,
        );
        expect(find.text('Finishing delete'), findsOneWidget);

        // Fail first attempt -> shows retryable error banner while preserving card.
        firstAttempt.completeError(StateError('cleanup interrupted'));
        await tester.pump();

        expect(
          find.byKey(const ValueKey<String>('vendor-show-delete-error-show-1')),
          findsOneWidget,
        );
        expect(find.text('Arena Finals'), findsOneWidget);

        // Retry delete -> succeeds -> card disappears only when stream removes parent doc.
        await tester.tap(
          find.byKey(const ValueKey<String>('vendor-show-retry-delete-show-1')),
        );
        await tester.pump();
        expect(
          find.byKey(
            const ValueKey<String>('vendor-show-deleting-progress-show-1'),
          ),
          findsOneWidget,
        );

        secondAttempt.complete();
        repo.controller.add(const <Show>[]);
        await tester.pump();

        expect(find.text('Arena Finals'), findsNothing);
        expect(
          find.byKey(const ValueKey<String>('vendor-shows-empty-state')),
          findsOneWidget,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(cubit.close);
      }
    },
  );
}
