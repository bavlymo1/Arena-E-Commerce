import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../../domain/models/show.dart';

/// Lifecycle states for the vendor "My shows" screen.
enum VendorShowsStatus { loading, ready, error }

/// Immutable state for [VendorShowsCubit].
final class VendorShowsState extends Equatable {
  VendorShowsState({
    required this.vendorId,
    this.status = VendorShowsStatus.loading,
    List<Show> shows = const <Show>[],
    Map<String, Uint8List?> posters = const <String, Uint8List?>{},
    Set<String> loadingPosterIds = const <String>{},
    this.errorMessage,
    Set<String> deletingShowIds = const <String>{},
    Map<String, String> deleteErrors = const <String, String>{},
    this.isResumingDeletes = false,
    this.resumeDeleteErrorMessage,
  }) : shows = List<Show>.unmodifiable(shows),
       posters = Map<String, Uint8List?>.unmodifiable(posters),
       loadingPosterIds = Set<String>.unmodifiable(loadingPosterIds),
       deletingShowIds = Set<String>.unmodifiable(deletingShowIds),
       deleteErrors = Map<String, String>.unmodifiable(deleteErrors);

  final String vendorId;
  final VendorShowsStatus status;
  final List<Show> shows;
  final Map<String, Uint8List?> posters;
  final Set<String> loadingPosterIds;
  final String? errorMessage;
  final Set<String> deletingShowIds;
  final Map<String, String> deleteErrors;
  final bool isResumingDeletes;
  final String? resumeDeleteErrorMessage;

  bool get isLoading => status == VendorShowsStatus.loading;
  bool get isReady => status == VendorShowsStatus.ready;
  bool get hasError => status == VendorShowsStatus.error;
  bool get isEmpty => status == VendorShowsStatus.ready && shows.isEmpty;
  bool isDeletingShow(String showId) => deletingShowIds.contains(showId);
  String? deleteErrorFor(String showId) => deleteErrors[showId];

  VendorShowsState copyWith({
    VendorShowsStatus? status,
    List<Show>? shows,
    Map<String, Uint8List?>? posters,
    Set<String>? loadingPosterIds,
    String? errorMessage,
    bool clearErrorMessage = false,
    Set<String>? deletingShowIds,
    Map<String, String>? deleteErrors,
    bool? isResumingDeletes,
    String? resumeDeleteErrorMessage,
    bool clearResumeDeleteErrorMessage = false,
  }) {
    return VendorShowsState(
      vendorId: vendorId,
      status: status ?? this.status,
      shows: shows ?? this.shows,
      posters: posters ?? this.posters,
      loadingPosterIds: loadingPosterIds ?? this.loadingPosterIds,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      deletingShowIds: deletingShowIds ?? this.deletingShowIds,
      deleteErrors: deleteErrors ?? this.deleteErrors,
      isResumingDeletes: isResumingDeletes ?? this.isResumingDeletes,
      resumeDeleteErrorMessage: clearResumeDeleteErrorMessage
          ? null
          : (resumeDeleteErrorMessage ?? this.resumeDeleteErrorMessage),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    vendorId,
    status,
    shows,
    posters,
    loadingPosterIds,
    errorMessage,
    deletingShowIds,
    deleteErrors,
    isResumingDeletes,
    resumeDeleteErrorMessage,
  ];
}
