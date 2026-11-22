import 'dart:async';
import 'dart:typed_data';

import 'package:e_commerce_project/core/formatting/date_time_formatting.dart';
import 'package:e_commerce_project/features/discovery/presentation/cubit/show_details_cubit.dart';
import 'package:e_commerce_project/features/discovery/presentation/screens/show_details_screen.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/new_show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session_time.dart';
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

Show _show({ShowStatus status = ShowStatus.active}) {
  return Show(
    id: 'apex',
    vendorId: 'arena',
    title: 'Apex Legends Invitational',
    description: 'The region leading squads compete live for the championship.',
    showDate: '2026-11-18',
    imageId: 'apex',
    status: status,
    bookedCount: 49,
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

final class _ControllableDetailsRepository implements ShowsRepository {
  final showController = StreamController<Show?>();
  final sessionsController = StreamController<List<Session>>();
  bool shouldError = false;

  @override
  Stream<Show?> watchShow(String showId) => shouldError
      ? Stream<Show?>.error(StateError('Show fetch failed'))
      : showController.stream;

  @override
  Stream<List<Session>> watchSessions(String showId) => shouldError
      ? Stream<List<Session>>.error(StateError('Sessions fetch failed'))
      : sessionsController.stream;

  @override
  Future<Uint8List?> loadPoster(String showId) async => null;

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
  void clearPosterCache() {}

  @override
  void dispose() {
    unawaited(showController.close());
    unawaited(sessionsController.close());
  }
}

Widget _wrapScreen({
  required ShowDetailsCubit cubit,
  required ValueChanged<String> onSessionSelected,
  VoidCallback? onBackToDiscover,
  ThemeData? theme,
  Size size = const Size(390, 812),
  double textScale = 1.0,
}) {
  return MediaQuery(
    data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
    child: MaterialApp(
      theme: theme ?? ThemeData.light(),
      home: BlocProvider<ShowDetailsCubit>.value(
        value: cubit,
        child: ShowDetailsScreen(
          onSessionSelected: onSessionSelected,
          onBackToDiscover: onBackToDiscover,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'renders show details, session availability, and blocks sold-out selection',
    (tester) async {
      final fake = FakeShowsRepository();
      fake.shows['apex'] = _show();
      fake.posters['apex'] = _validPng;
      fake.sessions['apex'] = <Session>[
        _session(
          '14:00',
          label: 'Matinee',
          bookedSeats: List<int>.generate(47, (i) => i + 1),
        ),
        _session('19:00', label: 'Evening', bookedSeats: <int>{14, 21}),
      ];

      final cubit = ShowDetailsCubit(fake, showId: 'apex');
      final selectedSessions = <String>[];

      try {
        await tester.pumpWidget(
          _wrapScreen(cubit: cubit, onSessionSelected: selectedSessions.add),
        );
        await tester.pumpAndSettle();

        expect(find.text('Apex Legends Invitational'), findsOneWidget);
        expect(find.text('Nov 18, 2026'), findsOneWidget);
        expect(find.text('2:00 PM'), findsOneWidget);
        expect(find.text('7:00 PM'), findsOneWidget);
        expect(find.text('· Matinee'), findsOneWidget);
        expect(find.text('· Evening'), findsOneWidget);
        expect(find.text('0 seats left'), findsOneWidget);
        expect(find.text('45 seats left'), findsOneWidget);
        expect(find.text('Sold out'), findsOneWidget);

        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('session-chip-1400')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('session-chip-1400')),
        );
        await tester.pump();
        expect(selectedSessions, isEmpty);

        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('session-chip-1900')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('session-chip-1900')),
        );
        await tester.pump();
        expect(selectedSessions, <String>['1900']);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(cubit.close);
      }
    },
  );

  testWidgets('displays all-sessions-sold-out banner when no seats remain', (
    tester,
  ) async {
    final fake = FakeShowsRepository();
    fake.shows['apex'] = _show();
    fake.sessions['apex'] = <Session>[
      _session('19:00', bookedSeats: List<int>.generate(47, (i) => i + 1)),
    ];

    final cubit = ShowDetailsCubit(fake, showId: 'apex');
    try {
      await tester.pumpWidget(
        _wrapScreen(cubit: cubit, onSessionSelected: (_) {}),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sold out. All seats booked.'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(cubit.close);
    }
  });

  testWidgets('renders unavailable state when show is missing or deleting', (
    tester,
  ) async {
    final fake = FakeShowsRepository();
    fake.shows['apex'] = _show(status: ShowStatus.deleting);
    final cubit = ShowDetailsCubit(fake, showId: 'apex');
    var wentBack = false;

    try {
      await tester.pumpWidget(
        _wrapScreen(
          cubit: cubit,
          onSessionSelected: (_) {},
          onBackToDiscover: () => wentBack = true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Show unavailable'), findsOneWidget);
      await tester.tap(find.text('Back to Discover'));
      await tester.pump();
      expect(wentBack, isTrue);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(cubit.close);
    }
  });

  testWidgets('renders loading then error+retry and recovers cleanly', (
    tester,
  ) async {
    final repo = _ControllableDetailsRepository()..shouldError = true;
    addTearDown(repo.dispose);
    final cubit = ShowDetailsCubit(repo, showId: 'apex');

    try {
      await tester.pumpWidget(
        _wrapScreen(cubit: cubit, onSessionSelected: (_) {}),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unable to load'), findsOneWidget);

      repo.shouldError = false;
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      repo.showController.add(_show());
      repo.sessionsController.add(<Session>[
        _session('19:00', label: 'Evening'),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Apex Legends Invitational'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(cubit.close);
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
        fake.shows['apex'] = _show();
        fake.posters['apex'] = _validPng;
        fake.sessions['apex'] = <Session>[
          _session('14:00', label: 'Afternoon Qualifier Session'),
          _session(
            '19:00',
            label: 'Championship Main Event',
            bookedSeats: List<int>.generate(47, (i) => i + 1),
          ),
        ];
        final cubit = ShowDetailsCubit(fake, showId: 'apex');

        try {
          await tester.pumpWidget(
            _wrapScreen(
              cubit: cubit,
              onSessionSelected: (_) {},
              onBackToDiscover: () {},
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xffd52f65),
                  brightness: brightness,
                ),
              ),
              size: const Size(300, 640),
              textScale: 2.0,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final session1400 = find.byKey(
            const ValueKey<String>('session-chip-1400'),
          );
          await tester.scrollUntilVisible(
            session1400,
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(session1400, findsOneWidget);

          final session1900 = find.byKey(
            const ValueKey<String>('session-chip-1900'),
          );
          await tester.scrollUntilVisible(
            session1900,
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(session1900, findsOneWidget);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(cubit.close);
        }
      },
    );
  }

  test(
    'formatting helpers format dates, 12-hour times, and remaining seats',
    () {
      expect(formatShowDateLabel('2026-11-18'), 'Nov 18, 2026');
      expect(formatShowDateLabel('2026-02-30'), '2026-02-30');
      expect(formatShowDateLabel('invalid'), 'invalid');

      expect(formatTime12Hour('00:30'), '12:30 AM');
      expect(formatTime12Hour('12:00'), '12:00 PM');
      expect(formatTime12Hour('14:00'), '2:00 PM');
      expect(formatTime12Hour('19:00'), '7:00 PM');
      expect(formatTime12Hour('99:00'), '99:00');

      expect(
        formatRemainingSeatsLabel(
          Session(
            id: '1900',
            time: SessionTime('19:00'),
            bookedSeats: List<int>.generate(46, (i) => i + 1),
          ),
        ),
        '1 seat left',
      );
      expect(
        formatRemainingSeatsLabel(
          Session(
            id: '1900',
            time: SessionTime('19:00'),
            bookedSeats: List<int>.generate(47, (i) => i + 1),
          ),
        ),
        '0 seats left',
      );
      expect(
        formatRemainingSeatsLabel(
          Session(
            id: '1900',
            time: SessionTime('19:00'),
            bookedSeats: const <int>[14, 21],
          ),
        ),
        '45 seats left',
      );
    },
  );
}
