import 'dart:async';
import 'dart:typed_data';

import 'package:e_commerce_project/app/theme/app_theme.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/new_show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session_time.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/repositories/shows_repository.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/cubit/show_form_cubit.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/cubit/show_form_state.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/screens/add_show_screen.dart';
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

final class _ScriptedAddShowRepository implements ShowsRepository {
  Future<void> Function(NewShow show, Uint8List poster)? onAddShow;
  final List<(NewShow, Uint8List)> added = <(NewShow, Uint8List)>[];

  @override
  Future<void> addShow(NewShow show, Uint8List poster) {
    if (onAddShow != null) {
      return onAddShow!(show, poster);
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
  void clearPosterCache() {}

  @override
  void dispose() {}
}

Widget _wrapScreen({
  required ShowFormCubit cubit,
  required Widget child,
  ThemeData? theme,
  double textScale = 1.0,
}) {
  return MaterialApp(
    theme: theme ?? buildAppTheme(brightness: Brightness.light),
    builder: (context, appChild) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: appChild!,
    ),
    home: BlocProvider<ShowFormCubit>.value(value: cubit, child: child),
  );
}

void main() {
  testWidgets(
    'displays inline validation errors and manages 1-5 slots plus duplicate-time rejection',
    (tester) async {
      final repo = FakeShowsRepository();
      addTearDown(repo.dispose);
      final cubit = ShowFormCubit(repo, vendorId: 'arena');
      var backTaps = 0;

      try {
        await tester.pumpWidget(
          _wrapScreen(
            cubit: cubit,
            child: AddShowScreen(onBackToShows: () => backTaps++),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('47 seats per session · 1 of 5 slots'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('add-show-poster-placeholder')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('add-show-back-button')),
        );
        await tester.pump();
        expect(backTaps, 1);

        // Submit empty form to surface all required field validations.
        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('add-show-submit-button')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('add-show-submit-button')),
        );
        await tester.pumpAndSettle();

        expect(find.text(ShowFormCubit.titleRequiredMessage), findsOneWidget);
        expect(
          find.text(ShowFormCubit.descriptionRequiredMessage),
          findsOneWidget,
        );
        expect(
          find.text(ShowFormCubit.showDateRequiredMessage),
          findsOneWidget,
        );
        expect(find.text(ShowFormCubit.posterRequiredMessage), findsOneWidget);
        expect(find.text(ShowFormCubit.sessionsInvalidMessage), findsOneWidget);
        expect(repo.added, isEmpty);

        // Add up to 5 slots and verify Add session button disables at 5.
        for (var expectedCount = 2; expectedCount <= 5; expectedCount++) {
          await tester.ensureVisible(
            find.byKey(const ValueKey<String>('add-show-add-session-button')),
          );
          await tester.tap(
            find.byKey(const ValueKey<String>('add-show-add-session-button')),
          );
          await tester.pumpAndSettle();
          expect(
            find.text('47 seats per session · $expectedCount of 5 slots'),
            findsOneWidget,
          );
        }

        expect(
          tester
              .widget<OutlinedButton>(
                find.byKey(
                  const ValueKey<String>('add-show-add-session-button'),
                ),
              )
              .onPressed,
          isNull,
        );

        // Enter values into first three slots, remove slot 0 and slots 3..4,
        // and verify remaining controllers keep synced values and reject duplicates.
        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('add-show-session-time-0')),
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('add-show-session-time-0')),
          '09:00',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('add-show-session-time-1')),
          '19:00',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('add-show-session-time-2')),
          '19:00',
        );
        await tester.pump();

        // Remove slot 4, slot 3, and slot 0 -> leaves ['19:00', '19:00'].
        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('add-show-remove-session-4')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('add-show-remove-session-4')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('add-show-remove-session-3')),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('add-show-remove-session-0')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('add-show-remove-session-0')),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('47 seats per session · 2 of 5 slots'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey<String>('add-show-session-time-0')),
              )
              .controller
              ?.text,
          '19:00',
        );

        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('add-show-submit-button')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('add-show-submit-button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(ShowFormCubit.sessionsDuplicateMessage),
          findsOneWidget,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(cubit.close);
      }
    },
  );

  testWidgets(
    'selects poster from gallery and camera, handles cancellation, preserves draft on submit failure, and retries cleanly',
    (tester) async {
      final gate = Completer<void>();
      var failSubmit = true;
      final repo = _ScriptedAddShowRepository()
        ..onAddShow = (show, poster) async {
          await gate.future;
          if (failSubmit) throw StateError('Write unavailable');
        };
      final pickedSources = <ShowPosterSource>[];
      Uint8List? pickerReturn = _validPng;

      final cubit = ShowFormCubit(repo, vendorId: 'arena');
      var savedCallbacks = 0;

      try {
        await tester.pumpWidget(
          _wrapScreen(
            cubit: cubit,
            child: AddShowScreen(
              onShowSaved: () => savedCallbacks++,
              onPickPoster: (source) async {
                pickedSources.add(source);
                return pickerReturn;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey<String>('add-show-title-field')),
          'Skyline Jam',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('add-show-description-field')),
          'Acoustic arena night.',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('add-show-date-field')),
          '2026-12-05',
        );

        // Gallery selection shows preview banner.
        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('add-show-gallery-button')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('add-show-gallery-button')),
        );
        await tester.pumpAndSettle();
        expect(pickedSources, <ShowPosterSource>[ShowPosterSource.gallery]);
        expect(
          find.byKey(const ValueKey<String>('add-show-poster-preview')),
          findsOneWidget,
        );

        // Camera cancellation (null) preserves existing poster preview without error.
        pickerReturn = null;
        await tester.tap(
          find.byKey(const ValueKey<String>('add-show-camera-button')),
        );
        await tester.pumpAndSettle();
        expect(pickedSources, <ShowPosterSource>[
          ShowPosterSource.gallery,
          ShowPosterSource.camera,
        ]);
        expect(
          find.byKey(const ValueKey<String>('add-show-poster-preview')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('add-show-poster-error')),
          findsNothing,
        );

        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('add-show-session-time-0')),
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('add-show-session-time-0')),
          '14:00',
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('add-show-add-session-button')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('add-show-add-session-button')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey<String>('add-show-session-time-1')),
          '19:00',
        );
        await tester.pump();

        // Submit enters busy loading state and disables duplicate submit.
        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('add-show-submit-button')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('add-show-submit-button')),
        );
        await tester.pump();
        expect(find.text('Saving show…'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey<String>('add-show-submit-button')),
              )
              .onPressed,
          isNull,
        );

        gate.complete();
        await tester.pumpAndSettle();

        // Recoverable failure keeps all form inputs and exposes Try again.
        expect(
          find.byKey(const ValueKey<String>('add-show-submit-error-banner')),
          findsOneWidget,
        );
        expect(find.text(ShowFormCubit.submitFailedMessage), findsOneWidget);
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey<String>('add-show-title-field')),
              )
              .controller
              ?.text,
          'Skyline Jam',
        );
        expect(
          find.byKey(const ValueKey<String>('add-show-poster-preview')),
          findsOneWidget,
        );
        expect(savedCallbacks, 0);

        // Retry succeeds and triggers onShowSaved exactly once.
        failSubmit = false;
        final saved = <(NewShow, Uint8List)>[];
        repo.onAddShow = (show, poster) async => saved.add((show, poster));

        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('add-show-retry-submit-button')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('add-show-retry-submit-button')),
        );
        await tester.pumpAndSettle();

        expect(savedCallbacks, 1);
        expect(saved, hasLength(1));
        expect(saved.single.$1.title, 'Skyline Jam');
        expect(saved.single.$1.sessions, <SessionTime>[
          SessionTime('14:00'),
          SessionTime('19:00'),
        ]);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(cubit.close);
      }
    },
  );

  for (final brightness in <Brightness>[Brightness.light, Brightness.dark]) {
    testWidgets(
      'fits narrow 300px viewport at 2.0x text scale without overflow in ${brightness.name} mode',
      (tester) async {
        tester.view.physicalSize = const Size(300, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = FakeShowsRepository();
        addTearDown(repo.dispose);
        final cubit = ShowFormCubit(repo, vendorId: 'arena');
        cubit.addSessionSlot();
        cubit.setPosterBytes(_validPng);

        try {
          await tester.pumpWidget(
            _wrapScreen(
              cubit: cubit,
              theme: buildAppTheme(brightness: brightness),
              textScale: 2.0,
              child: AddShowScreen(onBackToShows: () {}),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Trigger inline errors and verify scrolled narrow layout stays clean.
          await tester.ensureVisible(
            find.byKey(const ValueKey<String>('add-show-submit-button')),
          );
          await tester.tap(
            find.byKey(const ValueKey<String>('add-show-submit-button')),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          await tester.drag(
            find.byType(SingleChildScrollView),
            const Offset(0, 400),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(cubit.close);
        }
      },
    );
  }
}
