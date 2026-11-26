import 'dart:typed_data';

import '../../../../shared/seating/seat_numbers.dart';
import 'session_time.dart';

const int maxShowSessions = 5;
const int maxShowTitleLength = 80;
const int maxShowDescriptionLength = 1000;
const int maxShowPosterBytes = 204800;
const int maxShowBookedCount = seatCapacity * maxShowSessions;

/// Returns whether [bytes] begins with the 3-byte JPEG SOI/marker signature.
bool hasJpegHeader(Uint8List bytes) =>
    bytes.length >= 3 &&
    bytes[0] == 0xff &&
    bytes[1] == 0xd8 &&
    bytes[2] == 0xff;

final class NewShow {
  NewShow({
    required this.vendorId,
    required this.title,
    required this.description,
    required this.showDate,
    required Iterable<SessionTime> sessions,
  }) : sessions = List.unmodifiable(sessions) {
    if (vendorId.trim().isEmpty || title.trim().isEmpty) {
      throw ArgumentError('Vendor and title are required');
    }
    validateShowDate(showDate);
    if (this.sessions.isEmpty ||
        this.sessions.length > maxShowSessions ||
        this.sessions.toSet().length != this.sessions.length) {
      throw ArgumentError('Expected one to five distinct daily sessions');
    }
  }

  final String vendorId;
  final String title;
  final String description;
  final String showDate;
  final List<SessionTime> sessions;
}
