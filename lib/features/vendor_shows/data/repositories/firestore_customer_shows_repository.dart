import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/new_show.dart';
import '../../domain/models/session.dart';
import '../../domain/models/session_time.dart';
import '../../domain/models/show.dart';
import '../../domain/repositories/shows_repository.dart';

final class FirestoreCustomerShowsRepository implements ShowsRepository {
  FirestoreCustomerShowsRepository(this._firestore);

  final FirebaseFirestore _firestore;
  final _posters = <String, Uint8List>{};
  int _posterGeneration = 0;
  bool _disposed = false;

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
                updatedAt: (data['updatedAt'] as Timestamp).toDate(),
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
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
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
  Stream<List<Show>> watchVendorShows(String vendorId) =>
      Stream.error(UnsupportedError('Customer show reads only'));

  @override
  Future<void> addShow(NewShow show, Uint8List poster) async =>
      throw UnsupportedError('Customer show reads only');

  @override
  Future<void> deleteShow(String showId) async =>
      throw UnsupportedError('Customer show reads only');

  @override
  Future<void> resumeDeletes(String vendorId) async =>
      throw UnsupportedError('Customer show reads only');
}
