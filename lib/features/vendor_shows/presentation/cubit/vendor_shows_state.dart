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
  }) : shows = List<Show>.unmodifiable(shows),
       posters = Map<String, Uint8List?>.unmodifiable(posters),
       loadingPosterIds = Set<String>.unmodifiable(loadingPosterIds);

  final String vendorId;
  final VendorShowsStatus status;
  final List<Show> shows;
  final Map<String, Uint8List?> posters;
  final Set<String> loadingPosterIds;
  final String? errorMessage;

  bool get isLoading => status == VendorShowsStatus.loading;
  bool get isReady => status == VendorShowsStatus.ready;
  bool get hasError => status == VendorShowsStatus.error;
  bool get isEmpty => status == VendorShowsStatus.ready && shows.isEmpty;

  VendorShowsState copyWith({
    VendorShowsStatus? status,
    List<Show>? shows,
    Map<String, Uint8List?>? posters,
    Set<String>? loadingPosterIds,
    String? errorMessage,
    bool clearErrorMessage = false,
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
  ];
}
