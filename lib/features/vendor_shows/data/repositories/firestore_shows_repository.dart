import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../vendor_access/domain/models/vendor_access.dart';
import '../../../vendor_access/domain/repositories/vendor_access_repository.dart';
import '../../domain/models/new_show.dart';
import '../../domain/models/session.dart';
import '../../domain/models/session_time.dart';
import '../../domain/models/show.dart';
import '../../domain/repositories/shows_repository.dart';

final class FirestoreShowsRepository implements ShowsRepository {
  FirestoreShowsRepository(
    this._firestore, {
    this._vendorAccess,
    @visibleForTesting this.onDeletePairBatchCommitted,
  });

  /// Maximum `(bookings/{id}, bookingEvents/{id})` pairs deleted per batch.
  ///
  /// Each pair requires 6 uncached Security Rules checks (3 per document),
  /// keeping every batch within the 20-call limit (`<= 18 <= 20`) per D14.
  static const int maxDeletePairsPerBatch = 3;
  static const int _maxChildDeletesPerBatch = 8;
  static const GetOptions _server = GetOptions(source: Source.server);

  final FirebaseFirestore _firestore;
  final VendorAccessRepository? _vendorAccess;
  final _posters = <String, Uint8List>{};
  final _inFlightDeletes = <String, Future<void>>{};
  int _posterGeneration = 0;
  bool _disposed = false;

  /// Optional test hook invoked after each committed booking/event pair batch.
  @visibleForTesting
  Future<void> Function(int batchIndex, int pairCount)?
  onDeletePairBatchCommitted;

  CollectionReference<Map<String, dynamic>> get _shows =>
      _firestore.collection('shows');

  @override
  Stream<List<Show>> watchActiveShows({int limit = 100}) {
    if (limit < 1) throw ArgumentError.value(limit, 'limit');
    return _shows
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(_decodeShow).toList(growable: false),
        );
  }

  @override
  Stream<Show?> watchShow(String showId) => _shows
      .doc(showId)
      .snapshots(includeMetadataChanges: true)
      .where((snapshot) => snapshot.exists || !snapshot.metadata.isFromCache)
      .map((snapshot) => snapshot.exists ? _decodeShow(snapshot) : null);

  @override
  Stream<List<Session>> watchSessions(String showId) => _shows
      .doc(showId)
      .collection('sessions')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) {
              final data = doc.data();
              if (data['capacity'] != 47) {
                throw FormatException('Invalid session capacity');
              }
              return Session(
                id: doc.id,
                time: SessionTime(data['time'] as String),
                label: data['label'] as String?,
                bookedSeats: (data['bookedSeats'] as List).cast<int>(),
                lastBookingId: data['lastBookingId'] as String,
                updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
              );
            })
            .toList(growable: false),
      );

  static Show _decodeShow(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Show(
      id: doc.id,
      vendorId: data['vendorId'] as String,
      title: data['title'] as String,
      description: data['description'] as String,
      showDate: data['showDate'] as String,
      imageId: data['imageId'] as String,
      status: ShowStatus.values.byName(data['status'] as String),
      bookedCount: data['bookedCount'] as int,
      lastBookingId: data['lastBookingId'] as String,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  @override
  Future<Uint8List?> loadPoster(String showId) async {
    if (_disposed) return null;
    if (_posters.remove(showId) case final bytes?) {
      _posters[showId] = bytes;
      return Uint8List.fromList(bytes);
    }
    final generation = _posterGeneration;
    final snapshot = await _firestore
        .collection('showImages')
        .doc(showId)
        .get(const GetOptions(source: Source.server));
    if (generation != _posterGeneration) return null;
    final bytes = (snapshot.data()?['poster'] as Blob?)?.bytes;
    if (bytes == null || bytes.isEmpty) return null;
    _posters[showId] = Uint8List.fromList(bytes);
    if (_posters.length > 32) _posters.remove(_posters.keys.first);
    return Uint8List.fromList(bytes);
  }

  @override
  void clearPosterCache() {
    _posterGeneration++;
    _posters.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    clearPosterCache();
  }

  @override
  Stream<List<Show>> watchVendorShows(String vendorId) async* {
    await _requireVendor(vendorId);
    yield* _shows
        .where('vendorId', isEqualTo: vendorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(_decodeShow).toList(growable: false),
        );
  }

  @override
  Future<void> addShow(NewShow show, Uint8List poster) async {
    if (show.title.length > 80 || show.description.length > 1000) {
      throw ArgumentError('Show title or description exceeds its limit');
    }
    if (poster.length < 3 ||
        poster.length > 204800 ||
        poster[0] != 0xff ||
        poster[1] != 0xd8 ||
        poster[2] != 0xff) {
      throw ArgumentError('Expected a JPEG poster up to 200 KiB');
    }
    final bytes = Uint8List.fromList(poster);
    final (width, height) = await _jpegDimensions(bytes);
    final access = await _requireVendor(show.vendorId);
    final vendorId = access.vendorId;
    final document = _shows.doc();
    final timestamp = FieldValue.serverTimestamp();

    // A transaction waits for the server and avoids exposing pending timestamps.
    await _firestore.runTransaction<void>((transaction) async {
      transaction.set(document, {
        'vendorId': vendorId,
        'title': show.title,
        'titleSearch': show.title.toLowerCase(),
        'description': show.description,
        'showDate': show.showDate,
        'imageId': document.id,
        'sessionIds': [for (final slot in show.sessions) slot.id],
        'status': 'active',
        'bookedCount': 0,
        'lastBookingId': '',
        'createdAt': timestamp,
        'updatedAt': timestamp,
      });
      transaction.set(_firestore.collection('showImages').doc(document.id), {
        'vendorId': vendorId,
        'poster': Blob(bytes),
        'mimeType': 'image/jpeg',
        'width': width,
        'height': height,
      });
      for (final slot in show.sessions) {
        transaction.set(document.collection('sessions').doc(slot.id), {
          'time': slot.value,
          'capacity': 47,
          'bookedSeats': <int>[],
          'lastBookingId': '',
          'updatedAt': timestamp,
        });
      }
    });
  }

  static Future<(int, int)> _jpegDimensions(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      try {
        return (frame.image.width, frame.image.height);
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  Future<VendorAllowed> _requireVendor([String? expectedVendorId]) async {
    final repository = _vendorAccess;
    if (repository == null) throw UnsupportedError('Customer show reads only');
    final access = await repository.check();
    if (access is VendorAllowed &&
        (expectedVendorId == null || access.vendorId == expectedVendorId)) {
      return access;
    }
    throw StateError('Vendor is not enrolled for this account');
  }

  Future<void> _coalesceDelete(String showId, Future<void> Function() action) {
    final existing = _inFlightDeletes[showId];
    if (existing != null) return existing;
    var finished = false;
    late final Future<void> future;
    future = () async {
      try {
        await action();
      } finally {
        finished = true;
        if (identical(_inFlightDeletes[showId], future)) {
          _inFlightDeletes.remove(showId);
        }
      }
    }();
    if (!finished) {
      _inFlightDeletes[showId] = future;
    }
    return future;
  }

  @override
  Future<void> deleteShow(String showId) {
    if (showId.trim().isEmpty) {
      throw ArgumentError.value(showId, 'showId', 'Must not be empty');
    }
    if (_vendorAccess == null) {
      return Future<void>.error(UnsupportedError('Customer show reads only'));
    }
    return _coalesceDelete(showId, () async {
      final access = await _requireVendor();
      await _deleteShowInternal(showId, access.vendorId);
    });
  }

  @override
  Future<void> resumeDeletes(String vendorId) async {
    if (vendorId.trim().isEmpty) {
      throw ArgumentError.value(vendorId, 'vendorId', 'Must not be empty');
    }
    final access = await _requireVendor(vendorId);
    final deletingShows = await _shows
        .where('vendorId', isEqualTo: access.vendorId)
        .where('status', isEqualTo: 'deleting')
        .get(_server);
    Object? firstError;
    StackTrace? firstStackTrace;
    for (final showDoc in deletingShows.docs) {
      try {
        await _coalesceDelete(
          showDoc.id,
          () => _deleteShowInternal(showDoc.id, access.vendorId),
        );
      } catch (error, stackTrace) {
        if (firstError == null) {
          firstError = error;
          firstStackTrace = stackTrace;
        }
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }

  Future<void> _deleteShowInternal(String showId, String vendorId) async {
    final showRef = _shows.doc(showId);
    final showSnap = await showRef.get(_server);
    if (!showSnap.exists) {
      _posters.remove(showId);
      return;
    }

    final data = showSnap.data()!;
    if (data['vendorId'] != vendorId) {
      throw StateError('Show belongs to another vendor');
    }
    if (data['status'] != 'deleting') {
      await showRef.update({
        'status': 'deleting',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    var batchIndex = 0;
    while (true) {
      final eventsSnap = await _firestore
          .collection('bookingEvents')
          .where('vendorId', isEqualTo: vendorId)
          .where('showId', isEqualTo: showId)
          .get(_server);
      if (eventsSnap.docs.isEmpty) break;

      final docs = eventsSnap.docs;
      for (var i = 0; i < docs.length; i += maxDeletePairsPerBatch) {
        final end = (i + maxDeletePairsPerBatch <= docs.length)
            ? i + maxDeletePairsPerBatch
            : docs.length;
        final chunk = docs.sublist(i, end);
        final batch = _firestore.batch();
        for (final eventDoc in chunk) {
          batch.delete(_firestore.collection('bookings').doc(eventDoc.id));
          batch.delete(eventDoc.reference);
        }
        await batch.commit();
        final hook = onDeletePairBatchCommitted;
        if (hook != null) {
          await hook(batchIndex, chunk.length);
        }
        batchIndex++;
      }
    }

    final manifestIds =
        (data['sessionIds'] as List?)?.whereType<String>() ?? const <String>[];
    final sessionsSnap = await showRef.collection('sessions').get(_server);
    final sessionIds = <String>{
      ...manifestIds,
      for (final doc in sessionsSnap.docs) doc.id,
    };
    final imageRef = _firestore.collection('showImages').doc(showId);
    final imageSnap = await imageRef.get(_server);

    final childRefs = <DocumentReference<Map<String, dynamic>>>[
      for (final sessionId in sessionIds)
        showRef.collection('sessions').doc(sessionId),
      if (imageSnap.exists) imageRef,
    ];
    for (var i = 0; i < childRefs.length; i += _maxChildDeletesPerBatch) {
      final end = (i + _maxChildDeletesPerBatch <= childRefs.length)
          ? i + _maxChildDeletesPerBatch
          : childRefs.length;
      final batch = _firestore.batch();
      for (final ref in childRefs.sublist(i, end)) {
        batch.delete(ref);
      }
      await batch.commit();
    }

    await showRef.delete();
    _posters.remove(showId);
  }
}
