import '../../domain/models/show.dart';

/// Revision token for vendor show poster cache invalidation.
///
/// The current contract has no image-only revision. Poster writers must also
/// update show metadata; repository implementations own internal cache races.
Object vendorPosterRevision(Show show) => (
  show.imageId,
  show.createdAt,
  show.updatedAt,
  show.title,
  show.description,
  show.showDate,
);
