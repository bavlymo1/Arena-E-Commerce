import 'dart:ui' show SemanticsAction;

import 'package:e_commerce_project/app/theme/app_theme.dart';
import 'package:e_commerce_project/core/formatting/date_time_formatting.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session_time.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/show.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/widgets/vendor_show_widgets.dart';
import 'package:e_commerce_project/shared/widgets/arena_poster_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Show _show({
  String id = 'apex',
  String title = 'Apex Finals',
  ShowStatus status = ShowStatus.active,
  int bookedCount = 24,
  int? sessionCount = 3,
}) {
  return Show(
    id: id,
    vendorId: 'vendor-1',
    title: title,
    description: 'Desc',
    showDate: '2026-11-18',
    imageId: id,
    status: status,
    bookedCount: bookedCount,
    sessionCount: sessionCount,
    lastBookingId: '',
  );
}

void main() {
  test(
    'formatting and occupancy helpers compute capacity, labels, and bounds',
    () {
      expect(formatShowDateLabel('2026-11-18'), 'Nov 18, 2026');
      expect(formatShowDateLabel('2026-02-30'), '2026-02-30');
      expect(formatShowDateLabel('bad-date'), 'bad-date');

      expect(formatTime12Hour('00:05'), '12:05 AM');
      expect(formatTime12Hour('12:30'), '12:30 PM');
      expect(formatTime12Hour('19:00'), '7:00 PM');
      expect(formatTime12Hour('invalid'), 'invalid');

      final time = SessionTime('19:00');
      final session = Session(
        id: time.id,
        time: time,
        bookedSeats: <int>[1, 2, 3],
      );
      expect(formatVendorSessionBookedSummary(session), '3 / 47 booked');

      final partial = _show(bookedCount: 24, sessionCount: 3);
      expect(formatVendorShowBookedSummary(partial), '24 booked total');
      expect(computeVendorShowCapacity(partial), 141);
      expect(formatVendorShowSessionCount(partial), '3 daily sessions');
      expect(formatVendorShowOccupancyCount(partial), '24 / 141');
      expect(
        computeVendorShowOccupancyProgress(partial),
        closeTo(24 / 141, 1e-6),
      );

      final empty = _show(bookedCount: 0, sessionCount: 1);
      expect(formatVendorShowSessionCount(empty), '1 daily session');
      expect(formatVendorShowOccupancyCount(empty), '0 / 47');
      expect(computeVendorShowOccupancyProgress(empty), 0.0);

      final full = _show(bookedCount: 141, sessionCount: 3);
      expect(formatVendorShowOccupancyCount(full), '141 / 141');
      expect(computeVendorShowOccupancyProgress(full), 1.0);

      final unavailable = _show(bookedCount: 12, sessionCount: null);
      expect(computeVendorShowCapacity(unavailable), isNull);
      expect(formatVendorShowSessionCount(unavailable), 'Sessions unavailable');
      expect(formatVendorShowOccupancyCount(unavailable), '12 booked');
      expect(computeVendorShowOccupancyProgress(unavailable), 0.0);

      final zeroSessions = _show(bookedCount: 5, sessionCount: 0);
      expect(computeVendorShowCapacity(zeroSessions), isNull);
      expect(
        formatVendorShowSessionCount(zeroSessions),
        'Sessions unavailable',
      );
      expect(formatVendorShowOccupancyCount(zeroSessions), '5 booked');
      expect(computeVendorShowOccupancyProgress(zeroSessions), 0.0);

      final overbooked = _show(bookedCount: 60, sessionCount: 1);
      expect(computeVendorShowCapacity(overbooked), 47);
      expect(formatVendorShowOccupancyCount(overbooked), '60 / 47');
      expect(computeVendorShowOccupancyProgress(overbooked), 1.0);

      expect(
        partial.posterRevision,
        _show(bookedCount: 24, sessionCount: 3).posterRevision,
      );
    },
  );

  testWidgets(
    'VendorShowStatusBadge renders active and deleting pill colors in light and dark themes',
    (tester) async {
      for (final brightness in Brightness.values) {
        final theme = buildAppTheme(brightness: brightness);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(
              body: Row(
                children: <Widget>[
                  VendorShowStatusBadge(isDeleting: false),
                  VendorShowStatusBadge(isDeleting: true),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final activeText = tester.widget<Text>(find.text('Active'));
        final deletingText = tester.widget<Text>(find.text('Finishing delete'));
        expect(activeText.style?.color, theme.colorScheme.onSecondaryContainer);
        expect(deletingText.style?.color, theme.colorScheme.onErrorContainer);

        final containers = tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(VendorShowStatusBadge),
                matching: find.byType(Container),
              ),
            )
            .toList();
        expect(containers, hasLength(2));
        expect(
          (containers[0].decoration! as BoxDecoration).color,
          theme.colorScheme.secondaryContainer,
        );
        expect(
          (containers[1].decoration! as BoxDecoration).color,
          theme.colorScheme.errorContainer,
        );
      }
    },
  );

  testWidgets(
    'VendorShowCard renders operational metrics, poster fallback, and isolated >=48dp delete action',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        for (final brightness in Brightness.values) {
          final theme = buildAppTheme(brightness: brightness);
          var detailsTapped = 0;
          var deleteTapped = 0;

          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: VendorShowCard(
                    show: _show(
                      id: 'show-op',
                      title: 'Championship Finals Live Stage Special Event With A Very Long Title',
                      bookedCount: 24,
                      sessionCount: 3,
                    ),
                    posterBytes: null,
                    isDeleting: false,
                    deleteErrorMessage: null,
                    onOpenDetails: () => detailsTapped++,
                    onDeleteShow: () => deleteTapped++,
                    onRetryDelete: () {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(ArenaPosterBanner), findsOneWidget);
          expect(find.text('Nov 18, 2026'), findsOneWidget);
          expect(find.text('3 daily sessions'), findsOneWidget);
          expect(find.text('Booked seats'), findsOneWidget);
          expect(find.text('24 / 141'), findsOneWidget);
          expect(find.text('Delete'), findsNothing);

          final bar = tester.widget<LinearProgressIndicator>(
            find.byKey(
              const ValueKey<String>('vendor-show-occupancy-bar-show-op'),
            ),
          );
          expect(bar.value, closeTo(24 / 141, 1e-6));

          final deleteFinder = find.byKey(
            const ValueKey<String>('vendor-show-delete-show-op'),
          );
          final deleteButton = tester.widget<IconButton>(deleteFinder);
          expect(deleteButton.tooltip, 'Delete show');
          expect(
            deleteButton.style?.foregroundColor?.resolve(const <WidgetState>{}),
            theme.colorScheme.onSurfaceVariant,
          );
          final deleteSize = tester.getSize(deleteFinder);
          expect(deleteSize.width, greaterThanOrEqualTo(48));
          expect(deleteSize.height, greaterThanOrEqualTo(48));

          final cardSemantics = tester.getSemantics(
            find.bySemanticsLabel(RegExp('Championship Finals.*24 / 141')),
          );
          expect(
            cardSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
            isTrue,
          );

          final deleteSemantics = tester.getSemantics(
            find.byTooltip('Delete show'),
          );
          expect(
            deleteSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
            isTrue,
          );

          // Pressing Delete must not navigate to show details.
          await tester.tap(deleteFinder);
          await tester.pump();
          expect(deleteTapped, 1);
          expect(detailsTapped, 0);

          // Pressing the card opens details.
          await tester.tap(find.text('Booked seats'));
          await tester.pump();
          expect(detailsTapped, 1);
          expect(tester.takeException(), isNull);
        }
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'VendorShowCard disables repeat delete taps while isDeleting is true and renders safe unavailable fallback',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        var detailsTapped = 0;
        var deleteTapped = 0;

        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(brightness: Brightness.light),
            home: Scaffold(
              body: VendorShowCard(
                show: _show(
                  id: 'show-busy',
                  bookedCount: 12,
                  sessionCount: null,
                ),
                posterBytes: null,
                isDeleting: true,
                deleteErrorMessage: null,
                onOpenDetails: () => detailsTapped++,
                onDeleteShow: () => deleteTapped++,
                onRetryDelete: () {},
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Sessions unavailable'), findsOneWidget);
        expect(find.text('12 booked'), findsOneWidget);
        final bar = tester.widget<LinearProgressIndicator>(
          find.byKey(
            const ValueKey<String>('vendor-show-occupancy-bar-show-busy'),
          ),
        );
        expect(bar.value, 0.0);

        final deleteFinder = find.byKey(
          const ValueKey<String>('vendor-show-delete-show-busy'),
        );
        expect(tester.widget<IconButton>(deleteFinder).onPressed, isNull);
        expect(
          tester
              .getSemantics(deleteFinder)
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isFalse,
        );
        await tester.tap(deleteFinder);
        await tester.pump();
        expect(deleteTapped, 0);
        expect(detailsTapped, 0);
        expect(
          find.byKey(
            const ValueKey<String>('vendor-show-deleting-progress-show-busy'),
          ),
          findsOneWidget,
        );
      } finally {
        semantics.dispose();
      }
    },
  );
}
