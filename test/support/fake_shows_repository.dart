import 'dart:typed_data';

import 'package:e_commerce_project/features/vendor_shows/domain/models/new_show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/repositories/shows_repository.dart';

/// Snapshot fixtures and recorded calls, not a Firebase/cache/delete simulator.
final class FakeShowsRepository implements ShowsRepository {
  final shows = <String, Show>{};
  final sessions = <String, List<Session>>{};
  final posters = <String, Uint8List>{};
  final added = <(NewShow, Uint8List)>[];
  final deleted = <String>[];
  final resumed = <String>[];
  final invalidatedPosters = <String>[];
  int cacheClears = 0;
  bool disposed = false;

  void _checkOpen() {
    if (disposed) throw StateError('Fake repository is disposed');
  }

  @override
  Stream<List<Show>> watchActiveShows({int limit = 100}) {
    _checkOpen();
    if (limit < 1) throw ArgumentError.value(limit, 'limit');
    final active =
        shows.values.where((show) => show.status == ShowStatus.active).toList()
          ..sort(
            (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
              a.createdAt ?? DateTime(0),
            ),
          );
    return Stream.value(List.unmodifiable(active.take(limit)));
  }

  @override
  Stream<List<Show>> watchVendorShows(String vendorId) {
    _checkOpen();
    return Stream.value(
      List.unmodifiable(
        shows.values.where((show) => show.vendorId == vendorId),
      ),
    );
  }

  @override
  Stream<Show?> watchShow(String showId) {
    _checkOpen();
    return Stream.value(shows[showId]);
  }

  @override
  Stream<List<Session>> watchSessions(String showId) {
    _checkOpen();
    return Stream.value(List.unmodifiable(sessions[showId] ?? []));
  }

  @override
  Future<void> addShow(NewShow show, Uint8List poster) async {
    _checkOpen();
    if (poster.isEmpty) throw ArgumentError('Poster is required');
    added.add((show, Uint8List.fromList(poster)));
  }

  @override
  Future<void> deleteShow(String showId) async {
    _checkOpen();
    deleted.add(showId);
  }

  @override
  Future<void> resumeDeletes(String vendorId) async {
    _checkOpen();
    resumed.add(vendorId);
  }

  @override
  Future<Uint8List?> loadPoster(String showId) async {
    _checkOpen();
    final poster = posters[showId];
    return poster == null ? null : Uint8List.fromList(poster);
  }

  @override
  void invalidatePoster(String showId) {
    _checkOpen();
    invalidatedPosters.add(showId);
  }

  @override
  void clearPosterCache() {
    _checkOpen();
    cacheClears++;
  }

  @override
  void dispose() => disposed = true;
}
