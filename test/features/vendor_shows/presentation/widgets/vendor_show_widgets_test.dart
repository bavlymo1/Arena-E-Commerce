import 'package:e_commerce_project/app/theme/app_theme.dart';
import 'package:e_commerce_project/core/formatting/date_time_formatting.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session_time.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/show.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/widgets/vendor_show_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatting helpers format calendar date, 12h time, and totals', () {
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

    final show = Show(
      id: 'apex',
      vendorId: 'vendor-1',
      title: 'Apex Finals',
      description: 'Desc',
      showDate: '2026-11-18',
      imageId: 'apex',
      status: ShowStatus.active,
      bookedCount: 14,
      lastBookingId: '',
    );
    expect(formatVendorShowBookedSummary(show), '14 booked total');
    expect(
      show.posterRevision,
      Show(
        id: 'apex',
        vendorId: 'vendor-1',
        title: 'Apex Finals',
        description: 'Desc',
        showDate: '2026-11-18',
        imageId: 'apex',
        status: ShowStatus.active,
        bookedCount: 14,
        lastBookingId: '',
      ).posterRevision,
    );
  });

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
}
