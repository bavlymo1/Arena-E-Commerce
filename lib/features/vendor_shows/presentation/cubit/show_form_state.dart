import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../../domain/models/new_show.dart';

/// Image input source for show poster selection.
enum ShowPosterSource { gallery, camera }

/// Injectable poster acquisition callback so presentation remains decoupled from plugins.
typedef ShowPosterPicker = Future<Uint8List?> Function(ShowPosterSource source);
typedef ShowPosterRecovery = Future<Uint8List?> Function();

/// Lifecycle states for [ShowFormCubit].
enum ShowFormStatus { editing, pickingPoster, submitting, submitted, failure }

/// Immutable state for creating a vendor show and its 1–5 daily sessions.
final class ShowFormState extends Equatable {
  ShowFormState({
    required this.vendorId,
    this.title = '',
    this.description = '',
    this.showDate = '',
    Iterable<String> sessionTimes = const <String>[''],
    Uint8List? posterBytes,
    this.status = ShowFormStatus.editing,
    this.titleError,
    this.descriptionError,
    this.showDateError,
    this.posterError,
    this.sessionsError,
    this.submitErrorMessage,
    this.submissionCount = 0,
  }) : sessionTimes = List<String>.unmodifiable(sessionTimes),
       posterBytes = posterBytes == null
           ? null
           : Uint8List.fromList(posterBytes).asUnmodifiableView();

  const ShowFormState._({
    required this.vendorId,
    required this.title,
    required this.description,
    required this.showDate,
    required this.sessionTimes,
    required this.posterBytes,
    required this.status,
    required this.titleError,
    required this.descriptionError,
    required this.showDateError,
    required this.posterError,
    required this.sessionsError,
    required this.submitErrorMessage,
    required this.submissionCount,
  });

  static const int maxSessions = maxShowSessions;
  static const int maxTitleLength = maxShowTitleLength;
  static const int maxDescriptionLength = maxShowDescriptionLength;
  static const int maxPosterBytes = maxShowPosterBytes;

  final String vendorId;
  final String title;
  final String description;
  final String showDate;
  final List<String> sessionTimes;
  final Uint8List? posterBytes;
  final ShowFormStatus status;
  final String? titleError;
  final String? descriptionError;
  final String? showDateError;
  final String? posterError;
  final String? sessionsError;
  final String? submitErrorMessage;
  final int submissionCount;

  bool get isPickingPoster => status == ShowFormStatus.pickingPoster;
  bool get isSubmitting => status == ShowFormStatus.submitting;
  bool get isBusy => isPickingPoster || isSubmitting;
  bool get isSubmitted => status == ShowFormStatus.submitted;
  bool get hasFailure => status == ShowFormStatus.failure;
  bool get hasPoster => posterBytes != null && posterBytes!.isNotEmpty;
  bool get canAddSession => sessionTimes.length < maxSessions && !isBusy;

  ShowFormState copyWith({
    String? title,
    String? description,
    String? showDate,
    Iterable<String>? sessionTimes,
    Uint8List? posterBytes,
    bool clearPosterBytes = false,
    ShowFormStatus? status,
    String? titleError,
    bool clearTitleError = false,
    String? descriptionError,
    bool clearDescriptionError = false,
    String? showDateError,
    bool clearShowDateError = false,
    String? posterError,
    bool clearPosterError = false,
    String? sessionsError,
    bool clearSessionsError = false,
    String? submitErrorMessage,
    bool clearSubmitErrorMessage = false,
    int? submissionCount,
  }) {
    final nextPoster = clearPosterBytes
        ? null
        : (posterBytes != null
              ? Uint8List.fromList(posterBytes).asUnmodifiableView()
              : this.posterBytes);

    return ShowFormState._(
      vendorId: vendorId,
      title: title ?? this.title,
      description: description ?? this.description,
      showDate: showDate ?? this.showDate,
      sessionTimes: sessionTimes == null
          ? this.sessionTimes
          : List<String>.unmodifiable(sessionTimes),
      posterBytes: nextPoster,
      status: status ?? this.status,
      titleError: clearTitleError ? null : (titleError ?? this.titleError),
      descriptionError: clearDescriptionError
          ? null
          : (descriptionError ?? this.descriptionError),
      showDateError: clearShowDateError
          ? null
          : (showDateError ?? this.showDateError),
      posterError: clearPosterError ? null : (posterError ?? this.posterError),
      sessionsError: clearSessionsError
          ? null
          : (sessionsError ?? this.sessionsError),
      submitErrorMessage: clearSubmitErrorMessage
          ? null
          : (submitErrorMessage ?? this.submitErrorMessage),
      submissionCount: submissionCount ?? this.submissionCount,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    vendorId,
    title,
    description,
    showDate,
    sessionTimes,
    posterBytes,
    status,
    titleError,
    descriptionError,
    showDateError,
    posterError,
    sessionsError,
    submitErrorMessage,
    submissionCount,
  ];
}
