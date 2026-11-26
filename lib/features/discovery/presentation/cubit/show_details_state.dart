import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../../../vendor_shows/domain/models/session.dart';
import '../../../vendor_shows/domain/models/show.dart';

enum ShowDetailsStatus { loading, ready, unavailable, error }

final class ShowDetailsState extends Equatable {
  ShowDetailsState({
    required this.showId,
    this.status = ShowDetailsStatus.loading,
    this.show,
    Iterable<Session> sessions = const <Session>[],
    this.posterBytes,
    this.posterLoading = false,
    this.errorMessage,
  }) : sessions = List<Session>.unmodifiable(sessions);

  const ShowDetailsState._({
    required this.showId,
    required this.status,
    required this.show,
    required this.sessions,
    required this.posterBytes,
    required this.posterLoading,
    required this.errorMessage,
  });

  final String showId;
  final ShowDetailsStatus status;
  final Show? show;
  final List<Session> sessions;
  final Uint8List? posterBytes;
  final bool posterLoading;
  final String? errorMessage;

  bool get isLoading => status == ShowDetailsStatus.loading;
  bool get isReady => status == ShowDetailsStatus.ready;
  bool get isUnavailable => status == ShowDetailsStatus.unavailable;
  bool get hasError => status == ShowDetailsStatus.error;
  bool get isAllSessionsSoldOut =>
      isReady &&
      sessions.isNotEmpty &&
      sessions.every((session) => session.isSoldOut);

  ShowDetailsState copyWith({
    ShowDetailsStatus? status,
    Show? show,
    bool clearShow = false,
    Iterable<Session>? sessions,
    Uint8List? posterBytes,
    bool clearPosterBytes = false,
    bool? posterLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ShowDetailsState._(
      showId: showId,
      status: status ?? this.status,
      show: clearShow ? null : (show ?? this.show),
      sessions: sessions == null
          ? this.sessions
          : List<Session>.unmodifiable(sessions),
      posterBytes: clearPosterBytes ? null : (posterBytes ?? this.posterBytes),
      posterLoading: posterLoading ?? this.posterLoading,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    showId,
    status,
    show,
    sessions,
    posterBytes,
    posterLoading,
    errorMessage,
  ];
}
