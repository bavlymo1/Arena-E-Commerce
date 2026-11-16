import 'session_time.dart';

enum ShowStatus { active, deleting }

final class Show {
  Show({
    required this.id,
    required this.vendorId,
    required this.title,
    required this.description,
    required this.showDate,
    required this.imageId,
    required this.status,
    required this.bookedCount,
    required this.lastBookingId,
    this.createdAt,
    this.updatedAt,
  }) {
    if ([id, vendorId, title, imageId].any((value) => value.trim().isEmpty) ||
        imageId != id ||
        bookedCount < 0 ||
        bookedCount > 235) {
      throw ArgumentError('Invalid show identity, image or seat total');
    }
    validateShowDate(showDate);
  }

  final String id;
  final String vendorId;
  final String title;
  final String description;
  final String showDate;
  final String imageId;
  final ShowStatus status;
  final int bookedCount;
  final String lastBookingId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  String get titleSearch => title.toLowerCase();
}
