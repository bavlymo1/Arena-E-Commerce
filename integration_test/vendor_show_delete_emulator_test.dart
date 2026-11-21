import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_commerce_project/features/booking/data/repositories/firestore_booking_repository.dart';
import 'package:e_commerce_project/features/booking/domain/models/booking_request.dart';
import 'package:e_commerce_project/features/booking/domain/models/booking_result.dart';
import 'package:e_commerce_project/features/booking/presentation/cubit/seat_selection_cubit.dart';
import 'package:e_commerce_project/features/booking/presentation/cubit/seat_selection_state.dart';
import 'package:e_commerce_project/features/discovery/presentation/cubit/discovery_cubit.dart';
import 'package:e_commerce_project/features/discovery/presentation/cubit/show_details_cubit.dart';
import 'package:e_commerce_project/features/discovery/presentation/cubit/show_details_state.dart';
import 'package:e_commerce_project/features/vendor_access/data/repositories/firebase_vendor_access_repository.dart';
import 'package:e_commerce_project/features/vendor_shows/data/repositories/firestore_shows_repository.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/new_show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session_time.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/show.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/cubit/vendor_shows_cubit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const int _authPort = int.fromEnvironment(
  'AUTH_EMULATOR_PORT',
  defaultValue: 9099,
);
const int _firestorePort = int.fromEnvironment(
  'FIRESTORE_EMULATOR_PORT',
  defaultValue: 8180,
);

const FirebaseOptions _demoOptions = FirebaseOptions(
  apiKey: 'ADemoProjectApiKey000000000000000000000',
  appId: '1:1:android:1',
  messagingSenderId: '1',
  projectId: 'demo-arenapass',
);

Future<(FirebaseAuth, FirebaseFirestore)> _client(String name) async {
  final app = await Firebase.initializeApp(name: name, options: _demoOptions);
  final auth = FirebaseAuth.instanceFor(app: app);
  await auth.useAuthEmulator(
    '127.0.0.1',
    _authPort,
    automaticHostMapping: false,
  );
  final db = FirebaseFirestore.instanceFor(app: app);
  db.settings = const Settings(persistenceEnabled: false);
  db.useFirestoreEmulator(
    '127.0.0.1',
    _firestorePort,
    automaticHostMapping: false,
  );
  return (auth, db);
}

Future<void> _enrollVendorDevice(String uid, String vendorId) async {
  final http = HttpClient();
  try {
    final req = await http.patchUrl(
      Uri.parse(
        'http://127.0.0.1:$_firestorePort/v1/projects/demo-arenapass/databases/(default)/documents/vendorDevices/$uid',
      ),
    );
    req.headers.set('Authorization', 'Bearer owner');
    req.headers.contentType = ContentType.json;
    req.write(
      jsonEncode(<String, Object?>{
        'fields': <String, Object?>{
          'vendorId': <String, Object?>{'stringValue': vendorId},
          'enabled': <String, Object?>{'booleanValue': true},
        },
      }),
    );
    final res = await req.close();
    expect(res.statusCode, 200, reason: await utf8.decoder.bind(res).join());
  } finally {
    http.close(force: true);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'deletes >3 booking pairs in <=3 batches, transitions customer views to unavailable, resumes interrupted delete, and is idempotent',
    (tester) async {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: _demoOptions);
      }

      final tag = DateTime.now().microsecondsSinceEpoch.toString();
      final (customerAuth, customerDb) = await _client('customer-$tag');
      final customerUid = (await customerAuth.createUserWithEmailAndPassword(
        email: 'customer-$tag@example.test',
        password: 'Local-demo-47',
      )).user!.uid;
      final customerShowsRepo = FirestoreShowsRepository(customerDb);
      final customerBookingRepo = FirestoreBookingRepository(
        customerDb,
        customerAuth,
        customerShowsRepo,
      );

      final (vendorAuth, vendorDb) = await _client('vendor-$tag');
      final vendorUid = (await vendorAuth.signInAnonymously()).user!.uid;
      final vendorId = 'vendor-$tag';
      await _enrollVendorDevice(vendorUid, vendorId);
      final vendorAccess = FirebaseVendorAccessRepository(vendorAuth, vendorDb);

      final committedBatches = <int>[];
      final vendorShowsRepo = FirestoreShowsRepository(
        vendorDb,
        vendorAccess: vendorAccess,
        onDeletePairBatchCommitted: (batchIndex, pairCount) async {
          committedBatches.add(pairCount);
        },
      );

      final jpeg = await rootBundle.load('assets/demo/skyline_jam.jpg');
      final posterBytes = jpeg.buffer.asUint8List(
        jpeg.offsetInBytes,
        jpeg.lengthInBytes,
      );

      // --- 1. Create Show 1 with 7 confirmed bookings across 2 sessions ---
      final title1 = 'Batch Delete Show $tag';
      await vendorShowsRepo.addShow(
        NewShow(
          vendorId: vendorId,
          title: title1,
          description: 'Show with 7 booking/event pairs',
          showDate: '2026-12-22',
          sessions: <SessionTime>[SessionTime('16:00'), SessionTime('19:00')],
        ),
        posterBytes,
      );

      final show1 =
          (await vendorShowsRepo
                  .watchVendorShows(vendorId)
                  .firstWhere((shows) => shows.any((s) => s.title == title1)))
              .singleWhere((s) => s.title == title1);

      for (var i = 1; i <= 7; i++) {
        final sessionId = i <= 4 ? '1900' : '1600';
        final result = await customerBookingRepo.confirm(
          BookingRequest(
            bookingId: 'b1-$tag-$i',
            customerUid: customerUid,
            showId: show1.id,
            sessionId: sessionId,
            seats: <int>[i],
          ),
        );
        expect(result, isA<BookingConfirmed>(), reason: 'Booking $i failed');
      }

      // Attach live Customer Cubits watching Show 1 before deletion starts.
      final discoveryCubit = DiscoveryCubit(customerShowsRepo);
      final showDetailsCubit = ShowDetailsCubit(
        customerShowsRepo,
        showId: show1.id,
      );
      final seatSelectionCubit = SeatSelectionCubit(
        bookingRepository: customerBookingRepo,
        customerUid: customerUid,
        showId: show1.id,
        sessionId: '1900',
      );
      addTearDown(discoveryCubit.close);
      addTearDown(showDetailsCubit.close);
      addTearDown(seatSelectionCubit.close);

      await discoveryCubit.stream.firstWhere(
        (s) => s.shows.any((item) => item.id == show1.id),
      );
      if (!showDetailsCubit.state.isReady) {
        await showDetailsCubit.stream.firstWhere((s) => s.isReady);
      }
      if (seatSelectionCubit.state.status != SeatSelectionStatus.ready) {
        await seatSelectionCubit.stream.firstWhere(
          (s) => s.status == SeatSelectionStatus.ready,
        );
      }
      expect(seatSelectionCubit.state.myConfirmedSeats, <int>{1, 2, 3, 4});

      // Execute deleteShow on Show 1 (7 pairs -> batches of 3, 3, 1).
      await vendorShowsRepo.deleteShow(show1.id);

      expect(committedBatches, <int>[3, 3, 1]);
      expect(
        committedBatches.every(
          (batchSize) =>
              batchSize <= FirestoreShowsRepository.maxDeletePairsPerBatch,
        ),
        isTrue,
      );

      // Verify Customer transitions on Show 1 deletion.
      if (discoveryCubit.state.shows.any((item) => item.id == show1.id)) {
        await discoveryCubit.stream.firstWhere(
          (s) => !s.shows.any((item) => item.id == show1.id),
        );
      }
      if (showDetailsCubit.state.status != ShowDetailsStatus.unavailable) {
        await showDetailsCubit.stream.firstWhere(
          (s) => s.status == ShowDetailsStatus.unavailable,
        );
      }
      if (seatSelectionCubit.state.status != SeatSelectionStatus.unavailable) {
        await seatSelectionCubit.stream.firstWhere(
          (s) => s.status == SeatSelectionStatus.unavailable,
        );
      }
      expect(
        discoveryCubit.state.shows.any((item) => item.id == show1.id),
        isFalse,
      );
      expect(showDetailsCubit.state.status, ShowDetailsStatus.unavailable);
      expect(seatSelectionCubit.state.status, SeatSelectionStatus.unavailable);

      // Verify all server records for Show 1 are gone.
      const server = GetOptions(source: Source.server);
      expect(
        (await vendorDb.doc('shows/${show1.id}').get(server)).exists,
        isFalse,
      );
      expect(
        (await vendorDb.doc('showImages/${show1.id}').get(server)).exists,
        isFalse,
      );
      expect(
        (await vendorDb.collection('shows/${show1.id}/sessions').get(server))
            .docs,
        isEmpty,
      );
      expect(
        (await vendorDb
                .collection('bookingEvents')
                .where('vendorId', isEqualTo: vendorId)
                .where('showId', isEqualTo: show1.id)
                .get(server))
            .docs,
        isEmpty,
      );
      for (var i = 1; i <= 7; i++) {
        expect(
          (await customerDb.doc('bookings/b1-$tag-$i').get(server)).exists,
          isFalse,
        );
      }

      // Idempotent re-run on already-deleted Show 1 must succeed as no-op.
      await vendorShowsRepo.deleteShow(show1.id);

      // --- 2. Kill-and-resume mid-cleanup on Show 2 (5 booking pairs) ---
      final title2 = 'Interrupted Delete Show $tag';
      await vendorShowsRepo.addShow(
        NewShow(
          vendorId: vendorId,
          title: title2,
          description: 'Show interrupted after batch 0',
          showDate: '2026-12-23',
          sessions: <SessionTime>[SessionTime('18:00'), SessionTime('21:00')],
        ),
        posterBytes,
      );

      final show2 =
          (await vendorShowsRepo
                  .watchVendorShows(vendorId)
                  .firstWhere((shows) => shows.any((s) => s.title == title2)))
              .singleWhere((s) => s.title == title2);

      for (var i = 1; i <= 5; i++) {
        final result = await customerBookingRepo.confirm(
          BookingRequest(
            bookingId: 'b2-$tag-$i',
            customerUid: customerUid,
            showId: show2.id,
            sessionId: '1800',
            seats: <int>[i],
          ),
        );
        expect(result, isA<BookingConfirmed>());
      }

      final interruptedBatches = <int>[];
      vendorShowsRepo.onDeletePairBatchCommitted =
          (batchIndex, pairCount) async {
            interruptedBatches.add(pairCount);
            if (batchIndex == 0) {
              throw StateError('Simulated process kill after first batch');
            }
          };

      await expectLater(
        vendorShowsRepo.deleteShow(show2.id),
        throwsA(isA<StateError>()),
      );
      expect(interruptedBatches, <int>[3]);

      // Verify Show 2 is still present on server with status == 'deleting' and 2 pairs remaining.
      final midDeleteShowSnap = await vendorDb
          .doc('shows/${show2.id}')
          .get(server);
      expect(midDeleteShowSnap.exists, isTrue);
      expect(midDeleteShowSnap.data()?['status'], ShowStatus.deleting.name);

      final remainingEvents = await vendorDb
          .collection('bookingEvents')
          .where('vendorId', isEqualTo: vendorId)
          .where('showId', isEqualTo: show2.id)
          .get(server);
      expect(remainingEvents.docs, hasLength(2));

      // Verify new bookings are blocked while show status == 'deleting'.
      final blockedBooking = await customerBookingRepo.confirm(
        BookingRequest(
          bookingId: 'b2-$tag-blocked',
          customerUid: customerUid,
          showId: show2.id,
          sessionId: '1800',
          seats: const <int>[20],
        ),
      );
      expect(blockedBooking, isA<BookingUnavailable>());

      // Resume deletes on a fresh repository / VendorShowsCubit startup.
      final resumedBatches = <int>[];
      final freshVendorRepo = FirestoreShowsRepository(
        vendorDb,
        vendorAccess: vendorAccess,
        onDeletePairBatchCommitted: (batchIndex, pairCount) async {
          resumedBatches.add(pairCount);
        },
      );
      final vendorShowsCubit = VendorShowsCubit(
        freshVendorRepo,
        vendorId: vendorId,
      );
      addTearDown(vendorShowsCubit.close);

      // Joining resumeDeletes ensures both startup resume and direct call coalesce cleanly.
      await freshVendorRepo.resumeDeletes(vendorId);

      expect(resumedBatches, <int>[2]);
      expect(
        (await vendorDb.doc('shows/${show2.id}').get(server)).exists,
        isFalse,
      );
      expect(
        (await vendorDb.doc('showImages/${show2.id}').get(server)).exists,
        isFalse,
      );
      expect(
        (await vendorDb.collection('shows/${show2.id}/sessions').get(server))
            .docs,
        isEmpty,
      );
      expect(
        (await vendorDb
                .collection('bookingEvents')
                .where('vendorId', isEqualTo: vendorId)
                .where('showId', isEqualTo: show2.id)
                .get(server))
            .docs,
        isEmpty,
      );
      for (var i = 1; i <= 5; i++) {
        expect(
          (await customerDb.doc('bookings/b2-$tag-$i').get(server)).exists,
          isFalse,
        );
      }

      // Idempotent re-run on Show 2.
      await freshVendorRepo.deleteShow(show2.id);
    },
  );
}
