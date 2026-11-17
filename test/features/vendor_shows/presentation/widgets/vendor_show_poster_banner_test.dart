import 'dart:typed_data';

import 'package:e_commerce_project/features/vendor_shows/domain/models/session.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session_time.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/show.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/cubit/vendor_poster_revision.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/widgets/vendor_show_poster_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  test('formatting helpers format calendar date, 12h time, and totals', () {
    expect(formatVendorShowDateLabel('2026-11-18'), 'Nov 18, 2026');
    expect(formatVendorShowDateLabel('2026-02-30'), '2026-02-30');
    expect(formatVendorShowDateLabel('bad-date'), 'bad-date');

    expect(formatVendorSessionTime12Hour('00:05'), '12:05 AM');
    expect(formatVendorSessionTime12Hour('12:30'), '12:30 PM');
    expect(formatVendorSessionTime12Hour('19:00'), '7:00 PM');
    expect(formatVendorSessionTime12Hour('invalid'), 'invalid');

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
      vendorPosterRevision(show),
      vendorPosterRevision(
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
        ),
      ),
    );
  });

  testWidgets(
    'renders valid artwork image and falls back cleanly on null bytes',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                VendorShowPosterBanner(
                  title: 'Loaded Show',
                  posterBytes: _validPng,
                ),
                const VendorShowPosterBanner(
                  title: 'Fallback Show',
                  posterBytes: null,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('ARENA CONSOLE'), findsOneWidget);
      expect(find.bySemanticsLabel('Loaded Show artwork'), findsOneWidget);
      expect(find.bySemanticsLabel('Fallback Show artwork'), findsOneWidget);
    },
  );
}
