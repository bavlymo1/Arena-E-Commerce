import 'dart:async';
import 'dart:typed_data';

import 'package:e_commerce_project/app/theme/app_theme.dart';
import 'package:e_commerce_project/features/discovery/presentation/cubit/discovery_cubit.dart';
import 'package:e_commerce_project/features/discovery/presentation/screens/discovery_screen.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/new_show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/repositories/shows_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_shows_repository.dart';

final Uint8List _validPng = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

Show _show({
  required String id,
  required String title,
  required String showDate,
  required DateTime createdAt,
}) {
  return Show(
    id: id,
    vendorId: 'arena',
    title: title,
    description: '$title live at Arena Central.',
    showDate: showDate,
    imageId: id,
    status: ShowStatus.active,
    bookedCount: 0,
    lastBookingId: '',
    createdAt: createdAt,
  );
}

final class _ControllableShowsRepository implements ShowsRepository {
  StreamController<List<Show>> controller = StreamController<List<Show>>();
  bool shouldError = false;

  @override
  Stream<List<Show>> watchActiveShows({int limit = 100}) {
    if (shouldError) {
      return Stream<List<Show>>.error(StateError('Network failure'));
    }
    return controller.stream;
  }

  @override
  Future<Uint8List?> loadPoster(String showId) async => null;

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
  void invalidatePoster(String showId) {}

  @override
  void clearPosterCache() {}

  @override
  void dispose() {
    unawaited(controller.close());
  }
}

Widget _wrapScreen({
  required DiscoveryCubit cubit,
  required ValueChanged<String> onShowSelected,
  ThemeData? theme,
  Size size = const Size(390, 812),
  double textScale = 1.0,
}) {
  return MediaQuery(
    data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
    child: MaterialApp(
      theme: theme ?? buildAppTheme(brightness: Brightness.light),
      home: BlocProvider<DiscoveryCubit>.value(
        value: cubit,
        child: DiscoveryScreen(onShowSelected: onShowSelected),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'renders loading state before stream emits, then shows newest-first and invokes callback',
    (tester) async {
      final repo = _ControllableShowsRepository();
      addTearDown(repo.dispose);
      final cubit = DiscoveryCubit(repo);
      final selected = <String>[];

      try {
        await tester.pumpWidget(
          _wrapScreen(cubit: cubit, onShowSelected: selected.add),
        );
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Loading…'), findsOneWidget);

        repo.controller.add(<Show>[
          _show(
            id: 'older',
            title: 'Autumn Finals',
            showDate: '2026-11-10',
            createdAt: DateTime.utc(2026, 11, 10),
          ),
          _show(
            id: 'newer',
            title: 'Apex Legends Invitational',
            showDate: '2026-11-18',
            createdAt: DateTime.utc(2026, 11, 18),
          ),
        ]);
        await tester.pumpAndSettle();

        final newerTop = tester
            .getTopLeft(
              find.byKey(const ValueKey<String>('discover-show-card-newer')),
            )
            .dy;
        final olderTop = tester
            .getTopLeft(
              find.byKey(const ValueKey<String>('discover-show-card-older')),
            )
            .dy;
        expect(newerTop, lessThan(olderTop));
        expect(find.text('Nov 18, 2026'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey<String>('discover-show-card-newer')),
        );
        await tester.pump();
        expect(selected, <String>['newer']);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(cubit.close);
      }
    },
  );

  testWidgets('filters shows by title, displays no-match, and clears search', (
    tester,
  ) async {
    final fake = FakeShowsRepository();
    fake.shows['apex'] = _show(
      id: 'apex',
      title: 'Apex Legends Invitational',
      showDate: '2026-11-18',
      createdAt: DateTime.utc(2026, 11, 18),
    );
    fake.shows['neon'] = _show(
      id: 'neon',
      title: 'Neon Horizon',
      showDate: '2026-11-20',
      createdAt: DateTime.utc(2026, 11, 17),
    );
    fake.posters['apex'] = _validPng;

    final cubit = DiscoveryCubit(fake);

    try {
      await tester.pumpWidget(
        _wrapScreen(cubit: cubit, onShowSelected: (_) {}),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('discovery-search-field')),
        'neon',
      );
      await tester.pumpAndSettle();

      expect(find.text('Neon Horizon'), findsOneWidget);
      expect(find.text('Apex Legends Invitational'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey<String>('discovery-search-field')),
        'zzzz',
      );
      await tester.pumpAndSettle();

      expect(find.text('No matching shows'), findsOneWidget);
      await tester.ensureVisible(find.text('Clear search'));
      await tester.tap(find.text('Clear search'));
      await tester.pumpAndSettle();

      expect(find.text('Apex Legends Invitational'), findsOneWidget);
      expect(find.text('Neon Horizon'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(cubit.close);
    }
  });

  testWidgets('renders empty state and error+retry state cleanly', (
    tester,
  ) async {
    final fake = FakeShowsRepository();
    final emptyCubit = DiscoveryCubit(fake);
    try {
      await tester.pumpWidget(
        _wrapScreen(cubit: emptyCubit, onShowSelected: (_) {}),
      );
      await tester.pumpAndSettle();
      expect(find.text('No shows here yet'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(emptyCubit.close);
    }

    final repo = _ControllableShowsRepository()..shouldError = true;
    addTearDown(repo.dispose);
    final errorCubit = DiscoveryCubit(repo);
    try {
      await tester.pumpWidget(
        _wrapScreen(cubit: errorCubit, onShowSelected: (_) {}),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unable to load'), findsOneWidget);

      repo.shouldError = false;
      await tester.tap(find.text('Try again'));
      await tester.pump();

      repo.controller.add(<Show>[
        _show(
          id: 'recovered',
          title: 'Recovered Arena Show',
          showDate: '2026-12-01',
          createdAt: DateTime.utc(2026, 11, 18),
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Recovered Arena Show'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(errorCubit.close);
    }
  });

  for (final brightness in <Brightness>[Brightness.light, Brightness.dark]) {
    testWidgets(
      'fits narrow 300px screen with 2.0x text scale without overflow in ${brightness.name} mode',
      (tester) async {
        tester.view.physicalSize = const Size(300, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fake = FakeShowsRepository();
        fake.shows['apex'] = _show(
          id: 'apex',
          title: 'Apex Legends International Arena Invitational Championship',
          showDate: '2026-11-18',
          createdAt: DateTime.utc(2026, 11, 18),
        );
        fake.posters['apex'] = _validPng;
        final cubit = DiscoveryCubit(fake);

        try {
          await tester.pumpWidget(
            _wrapScreen(
              cubit: cubit,
              onShowSelected: (_) {},
              theme: buildAppTheme(brightness: brightness),
              size: const Size(300, 640),
              textScale: 2.0,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final cardFinder = find.byKey(
            const ValueKey<String>('discover-show-card-apex'),
          );
          await tester.scrollUntilVisible(
            cardFinder,
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(cardFinder, findsOneWidget);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(cubit.close);
        }
      },
    );
  }
}
