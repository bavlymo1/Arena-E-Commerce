import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../../domain/models/session.dart';
import '../../domain/models/show.dart';

/// Lifecycle states for the vendor show details and read-only map screen.
enum VendorShowDetailsStatus { loading, ready, unavailable, error }

/// Immutable state for [VendorShowDetailsCubit].
final class VendorShowDetailsState extends Equatable {
  VendorShowDetailsState({
    required this.vendorId,
    required this.showId,
    this.status = VendorShowDetailsStatus.loading,
    this.show,
    List<Session> sessions = const <Session>[],
    this.selectedSessionId,
    this.posterBytes,
    this.posterLoading = false,
    this.errorMessage,
  }) : sessions = List<Session>.unmodifiable(sessions);

  final String vendorId;
  final String showId;
  final VendorShowDetailsStatus status;
  final Show? show;
  final List<Session> sessions;
  final String? selectedSessionId;
  final Uint8List? posterBytes;
  final bool posterLoading;
  final String? errorMessage;

  bool get isLoading => status == VendorShowDetailsStatus.loading;
  bool get isReady => status == VendorShowDetailsStatus.ready;
  bool get isUnavailable => status == VendorShowDetailsStatus.unavailable;
  bool get hasError => status == VendorShowDetailsStatus.error;

  /// Currently selected session in [sessions], or `null` if none matches.
  Session? get selectedSession {
    final targetId = selectedSessionId;
    if (targetId == null) return null;
    for (final session in sessions) {
      if (session.id == targetId) return session;
    }
    return null;
  }

  VendorShowDetailsState copyWith({
    VendorShowDetailsStatus? status,
    Show? show,
    bool clearShow = false,
    List<Session>? sessions,
    String? selectedSessionId,
    bool clearSelectedSessionId = false,
    Uint8List? posterBytes,
    bool clearPosterBytes = false,
    bool? posterLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return VendorShowDetailsState(
      vendorId: vendorId,
      showId: showId,
      status: status ?? this.status,
      show: clearShow ? null : (show ?? this.show),
      sessions: sessions ?? this.sessions,
      selectedSessionId: clearSelectedSessionId
          ? null
          : (selectedSessionId ?? this.selectedSessionId),
      posterBytes: clearPosterBytes ? null : (posterBytes ?? this.posterBytes),
      posterLoading: posterLoading ?? this.posterLoading,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    vendorId,
    showId,
    status,
    show,
    sessions,
    selectedSessionId,
    posterBytes,
    posterLoading,
    errorMessage,
  ];
}
