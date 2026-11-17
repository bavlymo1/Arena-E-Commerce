import '../../../vendor_shows/domain/models/show.dart';

/// The current contract has no image-only revision. Poster writers must also
/// update show metadata; repository implementations own internal cache races.
Object posterRevision(Show show) => (
  show.imageId,
  show.createdAt,
  show.updatedAt,
  show.title,
  show.description,
  show.showDate,
);
