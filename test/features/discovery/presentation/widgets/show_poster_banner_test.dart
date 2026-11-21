import 'dart:typed_data';

import 'package:e_commerce_project/core/formatting/date_time_formatting.dart';
import 'package:e_commerce_project/features/discovery/presentation/widgets/show_poster_banner.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session_time.dart';
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

  testWidgets(
    'renders valid Image.memory poster and falls back on null or corrupt bytes',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShowPosterBanner(
              title: 'Apex Legends',
              posterBytes: _validPng,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.gaplessPlayback, isTrue);
      expect(image.image, isA<ResizeImage>());
      final resized = image.image as ResizeImage;
      expect(resized.width, 720);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShowPosterBanner(title: 'Apex Legends', posterBytes: null),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text('LIVE AT ARENA CENTRAL'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShowPosterBanner(
              title: 'Apex Legends',
              posterBytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('LIVE AT ARENA CENTRAL'), findsOneWidget);
    },
  );
}
