import 'dart:typed_data';

import '../models/new_show.dart';
import '../models/session.dart';
import '../models/show.dart';

abstract interface class ShowsRepository {
  /// Newest first; implementations enforce a positive query limit.
  Stream<List<Show>> watchActiveShows({int limit = 100});
  Stream<List<Show>> watchVendorShows(String vendorId);
  Stream<Show?> watchShow(String showId);
  Stream<List<Session>> watchSessions(String showId);

  /// Requires a nonempty validated poster; writes show/image/sessions atomically.
  Future<void> addShow(NewShow show, Uint8List poster);

  /// Completes only after restart-safe child/paired-record cleanup and removal.
  Future<void> deleteShow(String showId);
  Future<void> resumeDeletes(String vendorId);
  Future<Uint8List?> loadPoster(String showId);

  /// Evicts a single show's cached poster and drops matching in-flight loads.
  void invalidatePoster(String showId);

  /// Session cleanup must leave this app-scoped repository usable.
  void clearPosterCache();

  /// Application/test teardown only, not logout or route disposal.
  void dispose();
}
