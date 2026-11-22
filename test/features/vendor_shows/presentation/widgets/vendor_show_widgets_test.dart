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

  testWidgets('VendorButtonContent renders icon and label without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: VendorButtonContent(
            icon: Icons.add_outlined,
            label: 'Add show',
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.add_outlined), findsOneWidget);
    expect(find.text('Add show'), findsOneWidget);
  });
}
