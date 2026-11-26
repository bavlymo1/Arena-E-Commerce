import 'package:equatable/equatable.dart';

import 'new_show.dart';
import 'session_time.dart';

enum ShowStatus { active, deleting }

final class Show extends Equatable {
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
        bookedCount > maxShowBookedCount) {
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

  /// The current contract has no image-only revision. Poster writers must also
  /// update show metadata; repository implementations own internal cache races.
  Object get posterRevision =>
      (imageId, createdAt, updatedAt, title, description, showDate);

  static int compareNewestFirst(Show a, Show b) {
    final aCreated = a.createdAt;
    final bCreated = b.createdAt;
    if (aCreated == null && bCreated == null) return 0;
    if (aCreated == null) return 1;
    if (bCreated == null) return -1;
    return bCreated.compareTo(aCreated);
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    vendorId,
    title,
    description,
    showDate,
    imageId,
    status,
    bookedCount,
    lastBookingId,
    createdAt,
    updatedAt,
  ];
}
