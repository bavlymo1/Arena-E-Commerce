import 'session_time.dart';

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
        this.sessions.length > 5 ||
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
