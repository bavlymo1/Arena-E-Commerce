import 'dart:convert';
import 'dart:io';

import 'package:e_commerce_project/app/customer/customer_app.dart';
import 'package:e_commerce_project/app/di/customer_registration.dart';
import 'package:e_commerce_project/features/customer_auth/data/local_auth_emulator.dart';
import 'package:e_commerce_project/features/discovery/presentation/cubit/discovery_cubit.dart';
import 'package:e_commerce_project/features/discovery/presentation/screens/discovery_screen.dart';
import 'package:e_commerce_project/features/vendor_shows/data/local_shows_emulator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _documents = 'projects/demo-arenapass/databases/(default)/documents';
const _older = 'customer-reads-older';
const _newer = 'customer-reads-newer';

Map<String, String> _string(String value) => {'stringValue': value};
Map<String, String> _integer(int value) => {'integerValue': '$value'};

Map<String, Object> _write(String path, Map<String, Object> fields) => {
  'update': {'name': '$_documents/$path', 'fields': fields},
};

Map<String, Object> _show(String id, String title, String date) =>
    _write('shows/$id', {
      'vendorId': _string('fixture-vendor'),
      'title': _string(title),
      'titleSearch': _string(title.toLowerCase()),
      'description': _string('Local Firestore fixture'),
      'showDate': _string('2026-12-20'),
      'imageId': _string(id),
      'status': _string('active'),
      'bookedCount': _integer(0),
      'lastBookingId': _string(''),
      'createdAt': {'timestampValue': date},
      'updatedAt': {'timestampValue': date},
    });

Map<String, Object> _session(String id, String time, String label) =>
    _write('shows/$id/sessions/${time.replaceAll(':', '')}', {
      'time': _string(time),
      'label': _string(label),
      'capacity': _integer(47),
      'bookedSeats': {
        'arrayValue': {'values': <Object>[]},
      },
      'lastBookingId': _string(''),
      'updatedAt': {'timestampValue': '2026-11-18T20:00:00Z'},
    });

// Fixture writes only. The app uses the signed-in FlutterFire SDK for every read.
Future<void> _commit(List<Map<String, Object>> writes) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final request = await client.postUrl(
      Uri.http('127.0.0.1:8180', '/v1/$_documents:commit'),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer owner');
    request.write(jsonEncode({'writes': writes}));
    final response = await request.close().timeout(const Duration(seconds: 10));
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw StateError('Fixture commit failed (${response.statusCode}): $body');
    }
  } finally {
    client.close(force: true);
  }
}

Future<void> _wait(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 100 && target.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(target, findsOneWidget);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await _wait(tester, target);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Firestore feed, search, poster, live sessions and removed show on Customer',
    (tester) async {
      const oldTitle = 'Harbor Cup';
      const newTitle = 'Summit Series';
      const updatedTitle = 'Summit Series Revised';
      const oldDate = '2026-11-16T20:00:00Z';
      const newDate = '2026-11-17T20:00:00Z';
      const posterAsset = 'assets/demo/skyline_jam.jpg';
      final data = await rootBundle.load(posterAsset);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await _commit([
        _show(_older, oldTitle, oldDate),
        _show(_newer, newTitle, newDate),
        _session(_older, '14:00', 'Harbor afternoon'),
        _session(_newer, '19:00', 'Summit evening'),
        for (final id in [_older, _newer])
          _write('showImages/$id', {
            'poster': {'bytesValue': base64Encode(bytes)},
            'mimeType': _string('image/jpeg'),
            'width': _integer(1),
            'height': _integer(1),
            'vendorId': _string('fixture-vendor'),
          }),
      ]);

      final auth = await createLocalAuthRepository();
      await auth.logout();
      await auth.register(
        'reads-${DateTime.now().microsecondsSinceEpoch}@example.test',
        'Local-reads-test-47',
      );
      final repository = createLocalShowsRepository();
      try {
        await tester.pumpWidget(
          createCustomerApp(
            services: createAuthenticatedCustomerServices(
              authRepository: auth,
              showsRepository: repository,
            ),
          ),
        );
        final discover = find.byType(DiscoveryScreen);
        await _wait(tester, find.text(newTitle));
        final cubit = tester.element(discover).read<DiscoveryCubit>();
        expect(cubit.state.shows.map((show) => show.id), [_newer, _older]);
        expect(await repository.loadPoster(_newer), bytes);
        final textField = find.byType(TextField);
        await tester.enterText(textField, 'harbor');
        FocusManager.instance.primaryFocus?.unfocus();
        await _wait(tester, find.text(oldTitle));
        expect(find.text(newTitle), findsNothing);
        await tester.enterText(textField, 'summit');
        FocusManager.instance.primaryFocus?.unfocus();
        await _tap(tester, find.text(newTitle));
        await _wait(tester, find.text('Summit evening'));
        expect(find.byKey(const ValueKey('session-chip-1900')), findsOneWidget);
        expect(find.byKey(const ValueKey('session-chip-1400')), findsNothing);

        await _commit([_session(_newer, '19:00', 'Summit live update')]);
        await _wait(tester, find.text('Summit live update'));
        await _tap(tester, find.byKey(const ValueKey('session-chip-1900')));
        await _wait(tester, find.text('Booking backend setup pending.'));
        await _commit([_show(_newer, updatedTitle, newDate)]);
        await _tap(tester, find.byTooltip('Back to Discover'));
        await _wait(tester, find.text(updatedTitle));
        await _tap(tester, find.text(updatedTitle));
        await _wait(tester, find.text('Summit live update'));
        await _commit([
          {'delete': '$_documents/shows/$_newer/sessions/1900'},
          {'delete': '$_documents/showImages/$_newer'},
          {'delete': '$_documents/shows/$_newer'},
        ]);
        await _wait(tester, find.text('Show unavailable'));
        expect(find.byKey(const ValueKey('session-chip-1900')), findsNothing);
        await _tap(tester, find.byTooltip('Back to Discover'));
        await _wait(tester, find.text(oldTitle));
        expect(find.text(updatedTitle), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await auth.logout();
        await _commit([
          {'delete': '$_documents/shows/$_older/sessions/1400'},
          {'delete': '$_documents/showImages/$_older'},
          {'delete': '$_documents/shows/$_older'},
          {'delete': '$_documents/shows/$_newer/sessions/1900'},
          {'delete': '$_documents/showImages/$_newer'},
          {'delete': '$_documents/shows/$_newer'},
        ]);
      }
    },
  );
}
