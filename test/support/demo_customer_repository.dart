import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:e_commerce_project/features/booking/domain/models/booking.dart';
import 'package:e_commerce_project/features/booking/domain/models/booking_recovery.dart';
import 'package:e_commerce_project/features/booking/domain/models/booking_request.dart';
import 'package:e_commerce_project/features/booking/domain/models/booking_result.dart';
import 'package:e_commerce_project/features/booking/domain/repositories/booking_repository.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/new_show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session_time.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/repositories/shows_repository.dart';

/// App-composed, in-memory fixtures. No authentication, disk, or Firebase writes.
/// These outcomes exercise presentation; they do not simulate server transactions.
final class DemoCustomerRepository
    implements ShowsRepository, BookingRepository {
  DemoCustomerRepository() {
    const titles = {
      'demo-success': 'Skyline Jam',
      'demo-conflict': 'Kingdom Clash · conflict demo',
      'demo-uncertain': 'Midnight Drift · lost response demo',
      'demo-sold-out': 'Overclock Cup · sold out demo',
      'demo-unavailable': 'Hellfire Moto · unavailable demo',
    };
    var index = 0;
    for (final entry in titles.entries) {
      final seats = entry.key == 'demo-sold-out'
          ? Set<int>.from(List.generate(47, (i) => i + 1))
          : <int>{9, 18};
      _shows[entry.key] = Show(
        id: entry.key,
        vendorId: 'demo-vendor',
        title: entry.value,
        description:
            'Local sample event. No real seats or payments. ${entry.key == 'demo-uncertain' ? 'Confirmation is scripted to lose its response; Check status resolves the same reference.' : ''}',
        showDate: '2026-12-20',
        imageId: entry.key,
        status: ShowStatus.active,
        bookedCount: seats.length + (entry.key == 'demo-success' ? 1 : 0),
        lastBookingId: '',
        sessionCount: entry.key == 'demo-success' ? 2 : 1,
        createdAt: DateTime.utc(
          2026,
          11,
          17,
        ).subtract(Duration(minutes: index++)),
      );
      _sessions[(entry.key, '1900')] = Session(
        id: '1900',
        time: SessionTime('19:00'),
        label: 'Evening',
        bookedSeats: seats,
      );
    }
    _sessions[('demo-success', '1400')] = Session(
      id: '1400',
      time: SessionTime('14:00'),
      label: 'Afternoon',
      bookedSeats: {7},
    );
  }

  static const customerUid = 'demo-customer';
  final _changes = StreamController<void>.broadcast(sync: true);
  final _shows = <String, Show>{};
  final _sessions = <(String, String), Session>{};
  final _bookings = <String, Booking>{};
  final _posters = <String, Uint8List>{};
  bool _closed = false;

  Stream<T> _watch<T>(T Function() snapshot) => Stream<T>.multi((sink) {
    if (_closed) {
      sink.close();
      return;
    }
    final subscription = _changes.stream.listen(
      (_) => sink.add(snapshot()),
      onDone: sink.close,
    );
    sink.onCancel = subscription.cancel;
    sink.add(snapshot());
  });

  @override
  Stream<List<Show>> watchActiveShows({int limit = 100}) {
    if (limit < 1) throw ArgumentError.value(limit, 'limit');
    return _watch(
      () => List.unmodifiable(
        _shows.values.where((s) => s.status == ShowStatus.active).take(limit),
      ),
    );
  }

  @override
  Stream<List<Show>> watchVendorShows(String vendorId) => _watch(
    () => List.unmodifiable(_shows.values.where((s) => s.vendorId == vendorId)),
  );
  @override
  Stream<Show?> watchShow(String showId) => _watch(() => _shows[showId]);
  @override
  Stream<List<Session>> watchSessions(String showId) => _watch(
    () => [
      for (final entry in _sessions.entries)
        if (entry.key.$1 == showId) entry.value,
    ],
  );
  @override
  Stream<Session?> watchSession(String showId, String sessionId) => _watch(
    () => showId == 'demo-unavailable' ? null : _sessions[(showId, sessionId)],
  );
  @override
  Stream<Set<int>> watchMySeats(String uid, String showId, String sessionId) =>
      _watch(
        () => Set.unmodifiable({
          for (final booking in _bookings.values)
            if (booking.request.customerUid == uid &&
                booking.request.showId == showId &&
                booking.request.sessionId == sessionId &&
                booking.status == 'confirmed')
              ...booking.request.seats,
        }),
      );

  @override
  Future<BookingResult> confirm(BookingRequest request) async {
    if (_closed) throw StateError('Demo repository closed');
    if (request.customerUid != customerUid) {
      return BookingRejected(
        request,
        reason: 'This sample belongs to the demo account.',
      );
    }
    final previous = _bookings[request.bookingId];
    if (previous != null) {
      final original = previous.request;
      if (original.customerUid == request.customerUid &&
          original.showId == request.showId &&
          original.sessionId == request.sessionId &&
          original.seats.length == request.seats.length &&
          original.seats.containsAll(request.seats)) {
        return BookingConfirmed(request);
      }
      return BookingUnconfirmed(
        request,
        reason: 'Reference already used for another request.',
      );
    }
    final show = _shows[request.showId];
    final session = _sessions[(request.showId, request.sessionId)];
    if (show == null ||
        show.status != ShowStatus.active ||
        session == null ||
        session.id != request.sessionId ||
        request.showId == 'demo-unavailable') {
      return BookingUnavailable(request);
    }
    if (request.showId == 'demo-conflict') {
      final racedSeat = request.seats.first;
      _sessions[(show.id, session.id)] = Session(
        id: session.id,
        time: session.time,
        label: session.label,
        bookedSeats: {...session.bookedSeats, racedSeat},
      );
      _changes.add(null);
      return BookingConflict(request, {racedSeat});
    }
    final conflicts = request.seats.intersection(session.bookedSeats);
    if (conflicts.isNotEmpty) return BookingConflict(request, conflicts);
    _bookings[request.bookingId] = Booking(
      request: request,
      showTitle: show.title,
      showDate: show.showDate,
      slotTime: session.time,
      vendorId: show.vendorId,
      createdAt: DateTime.now().toUtc(),
    );
    _sessions[(show.id, session.id)] = Session(
      id: session.id,
      time: session.time,
      label: session.label,
      bookedSeats: {...session.bookedSeats, ...request.seats},
      lastBookingId: request.bookingId,
    );
    _shows[show.id] = Show(
      id: show.id,
      vendorId: show.vendorId,
      title: show.title,
      description: show.description,
      showDate: show.showDate,
      imageId: show.imageId,
      status: show.status,
      bookedCount: show.bookedCount + request.seats.length,
      lastBookingId: request.bookingId,
      sessionCount: show.sessionCount,
      createdAt: show.createdAt,
    );
    _changes.add(null);
    return request.showId == 'demo-uncertain'
        ? BookingUnconfirmed(
            request,
            reason: 'Scripted lost response. Check status with this reference.',
          )
        : BookingConfirmed(request);
  }

  @override
  Future<BookingRecovery> recover({
    required String bookingId,
    required String customerUid,
  }) async {
    final booking = _bookings[bookingId];
    if (_closed ||
        customerUid != DemoCustomerRepository.customerUid ||
        (booking != null && booking.request.customerUid != customerUid)) {
      return RecoveryUnresolved(
        bookingId: bookingId,
        customerUid: customerUid,
        reason: 'Demo status unavailable for this account.',
      );
    }
    return booking == null
        ? RecoveryAuthoritativelyAbsent(
            bookingId: bookingId,
            customerUid: customerUid,
          )
        : RecoveryConfirmed(
            bookingId: bookingId,
            customerUid: customerUid,
            booking: booking,
          );
  }

  @override
  Future<Uint8List?> loadPoster(String showId) async {
    const names = {
      'demo-success': 'skyline_jam',
      'demo-conflict': 'kingdom_clash',
      'demo-uncertain': 'midnight_drift',
      'demo-sold-out': 'overclock_cup',
      'demo-unavailable': 'hellfire_moto',
    };
    final name = names[showId];
    if (name == null || _closed) return null;
    if (_posters[showId] case final bytes?) return bytes;
    final file = File('test/fixtures/posters/$name.jpg');
    if (!file.existsSync() || _closed) return null;
    return _posters[showId] = file.readAsBytesSync();
  }

  @override
  void invalidatePoster(String showId) => _posters.remove(showId);

  @override
  void clearPosterCache() => _posters.clear();
  @override
  void dispose() {
    _closed = true;
    clearPosterCache();
    unawaited(_changes.close());
  }

  @override
  Future<void> addShow(NewShow show, Uint8List poster) =>
      Future.error(UnsupportedError('Read-only Customer demo'));
  @override
  Future<void> deleteShow(String showId) =>
      Future.error(UnsupportedError('Read-only Customer demo'));
  @override
  Future<void> resumeDeletes(String vendorId) =>
      Future.error(UnsupportedError('Read-only Customer demo'));
}
