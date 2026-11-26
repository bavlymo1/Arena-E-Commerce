import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../../../vendor_shows/domain/models/show.dart';

enum DiscoveryStatus { loading, ready, error }

final class DiscoveryState extends Equatable {
  DiscoveryState({
    this.status = DiscoveryStatus.loading,
    Iterable<Show> shows = const <Show>[],
    Iterable<Show> filteredShows = const <Show>[],
    this.searchQuery = '',
    Map<String, Uint8List?> posters = const <String, Uint8List?>{},
    Iterable<String> loadingPosterIds = const <String>{},
    this.errorMessage,
  }) : shows = List<Show>.unmodifiable(shows),
       filteredShows = List<Show>.unmodifiable(filteredShows),
       posters = Map<String, Uint8List?>.unmodifiable(posters),
       loadingPosterIds = Set<String>.unmodifiable(loadingPosterIds);

  const DiscoveryState._({
    required this.status,
    required this.shows,
    required this.filteredShows,
    required this.searchQuery,
    required this.posters,
    required this.loadingPosterIds,
    required this.errorMessage,
  });

  final DiscoveryStatus status;
  final List<Show> shows;
  final List<Show> filteredShows;
  final String searchQuery;
  final Map<String, Uint8List?> posters;
  final Set<String> loadingPosterIds;
  final String? errorMessage;

  bool get isLoading => status == DiscoveryStatus.loading;
  bool get hasError => status == DiscoveryStatus.error;
  bool get isEmpty => status == DiscoveryStatus.ready && shows.isEmpty;
  bool get isNoMatch =>
      status == DiscoveryStatus.ready &&
      shows.isNotEmpty &&
      filteredShows.isEmpty;

  DiscoveryState copyWith({
    DiscoveryStatus? status,
    Iterable<Show>? shows,
    Iterable<Show>? filteredShows,
    String? searchQuery,
    Map<String, Uint8List?>? posters,
    Iterable<String>? loadingPosterIds,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return DiscoveryState._(
      status: status ?? this.status,
      shows: shows == null ? this.shows : List<Show>.unmodifiable(shows),
      filteredShows: filteredShows == null
          ? this.filteredShows
          : List<Show>.unmodifiable(filteredShows),
      searchQuery: searchQuery ?? this.searchQuery,
      posters: posters == null
          ? this.posters
          : Map<String, Uint8List?>.unmodifiable(posters),
      loadingPosterIds: loadingPosterIds == null
          ? this.loadingPosterIds
          : Set<String>.unmodifiable(loadingPosterIds),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    shows,
    filteredShows,
    searchQuery,
    posters,
    loadingPosterIds,
    errorMessage,
  ];
}
