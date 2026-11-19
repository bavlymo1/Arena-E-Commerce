import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/new_show.dart';
import '../../domain/models/session_time.dart';
import '../../domain/repositories/shows_repository.dart';
import 'show_form_state.dart';

/// Validates and submits vendor show creation drafts against [ShowsRepository].
final class ShowFormCubit extends Cubit<ShowFormState> {
  ShowFormCubit(
    this._repository, {
    required String vendorId,
    this.posterPicker,
    ShowPosterRecovery? recoverPoster,
  }) : super(ShowFormState(vendorId: _requireNonEmpty(vendorId))) {
    if (recoverPoster != null) unawaited(_recoverPoster(recoverPoster));
  }

  static const String titleRequiredMessage = 'Enter show title.';
  static const String titleTooLongMessage =
      'Show title must be 80 characters or fewer.';
  static const String descriptionRequiredMessage = 'Enter description.';
  static const String descriptionTooLongMessage =
      'Description must be 1,000 characters or fewer.';
  static const String showDateRequiredMessage = 'Choose show date.';
  static const String showDateInvalidMessage =
      'Enter a valid calendar date (yyyy-MM-dd).';
  static const String posterRequiredMessage =
      'Choose gallery image or take photo.';
  static const String posterEmptyMessage =
      'Image could not be read. Choose another file.';
  static const String posterTooLargeMessage =
      'Image exceeds the 200 KB limit. Choose a smaller image.';
  static const String posterPickFailedMessage =
      'Unable to select image. Try again.';
  static const String posterFormatMessage = 'Choose a JPEG image.';
  static const String posterPickerUnavailableMessage =
      'Image selection is not configured in this build.';
  static const String sessionsInvalidMessage =
      'Use 1–5 distinct valid slot times (HH:mm).';
  static const String sessionsDuplicateMessage =
      'Session times must be distinct.';
  static const String maxSessionsReachedMessage =
      'At most 5 daily sessions are allowed per show.';
  static const String submitFailedMessage =
      'Save failed. Form retained. Reconnect or retry.';

  final ShowsRepository _repository;
  final ShowPosterPicker? posterPicker;
  Object? _activeOperation;
  bool _acceptStartupRecovery = true;

  static String _requireNonEmpty(String value) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, 'vendorId', 'Must not be empty');
    }
    return value;
  }

  ShowFormStatus _editingStatus() {
    if (state.status == ShowFormStatus.failure ||
        state.status == ShowFormStatus.submitted) {
      return ShowFormStatus.editing;
    }
    return state.status;
  }

  /// Updates show title and clears any prior title or submit error.
  void updateTitle(String value) {
    if (isClosed || state.isSubmitting) return;
    emit(
      state.copyWith(
        title: value,
        status: _editingStatus(),
        clearTitleError: true,
        clearSubmitErrorMessage: true,
      ),
    );
  }

  /// Updates show description and clears any prior description or submit error.
  void updateDescription(String value) {
    if (isClosed || state.isSubmitting) return;
    emit(
      state.copyWith(
        description: value,
        status: _editingStatus(),
        clearDescriptionError: true,
        clearSubmitErrorMessage: true,
      ),
    );
  }

  /// Updates show date (`yyyy-MM-dd`) and clears any prior date or submit error.
  void updateShowDate(String value) {
    if (isClosed || state.isSubmitting) return;
    emit(
      state.copyWith(
        showDate: value,
        status: _editingStatus(),
        clearShowDateError: true,
        clearSubmitErrorMessage: true,
      ),
    );
  }

  /// Appends a new daily session slot up to [ShowFormState.maxSessions].
  void addSessionSlot() {
    if (isClosed || state.isBusy) return;
    if (state.sessionTimes.length >= ShowFormState.maxSessions) {
      emit(
        state.copyWith(
          status: _editingStatus(),
          sessionsError: maxSessionsReachedMessage,
          clearSubmitErrorMessage: true,
        ),
      );
      return;
    }
    final next = <String>[...state.sessionTimes, ''];
    emit(
      state.copyWith(
        sessionTimes: next,
        status: _editingStatus(),
        clearSessionsError: true,
        clearSubmitErrorMessage: true,
      ),
    );
  }

  /// Removes the session slot at [index].
  void removeSessionSlot(int index) {
    if (isClosed ||
        state.isBusy ||
        index < 0 ||
        index >= state.sessionTimes.length) {
      return;
    }
    final next = <String>[...state.sessionTimes]..removeAt(index);
    emit(
      state.copyWith(
        sessionTimes: next,
        status: _editingStatus(),
        clearSessionsError: true,
        clearSubmitErrorMessage: true,
      ),
    );
  }

  /// Updates the session time string at [index].
  void updateSessionTime(int index, String value) {
    if (isClosed ||
        state.isBusy ||
        index < 0 ||
        index >= state.sessionTimes.length) {
      return;
    }
    final next = <String>[...state.sessionTimes]..[index] = value;
    emit(
      state.copyWith(
        sessionTimes: next,
        status: _editingStatus(),
        clearSessionsError: true,
        clearSubmitErrorMessage: true,
      ),
    );
  }

  /// Applies already-obtained poster bytes; null cancels without clearing prior artwork.
  void setPosterBytes(Uint8List? bytes) {
    if (isClosed || state.isBusy || bytes == null) return;
    _acceptStartupRecovery = false;
    final validationError = _validatePosterCandidate(bytes);
    if (validationError != null) {
      emit(
        state.copyWith(
          status: _editingStatus(),
          posterError: validationError,
          clearSubmitErrorMessage: true,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        posterBytes: bytes,
        status: _editingStatus(),
        clearPosterError: true,
        clearSubmitErrorMessage: true,
      ),
    );
  }

  Future<void> _recoverPoster(ShowPosterRecovery recoverPoster) async {
    try {
      final bytes = await recoverPoster();
      if (isClosed || !_acceptStartupRecovery) return;
      setPosterBytes(bytes);
    } catch (error) {
      if (isClosed || !_acceptStartupRecovery) return;
      emit(state.copyWith(posterError: _posterPickError(error)));
    }
  }

  /// Acquires poster bytes from [source] via [picker] or the constructor-injected picker.
  Future<void> pickPoster(
    ShowPosterSource source, {
    ShowPosterPicker? picker,
  }) async {
    if (isClosed || state.isBusy) return;
    final activePicker = picker ?? posterPicker;
    if (activePicker == null) {
      emit(
        state.copyWith(
          status: _editingStatus(),
          posterError: posterPickerUnavailableMessage,
          clearSubmitErrorMessage: true,
        ),
      );
      return;
    }

    _acceptStartupRecovery = false;
    final operation = Object();
    _activeOperation = operation;
    emit(
      state.copyWith(
        status: ShowFormStatus.pickingPoster,
        clearPosterError: true,
        clearSubmitErrorMessage: true,
      ),
    );

    try {
      final bytes = await activePicker(source);
      if (isClosed || !identical(_activeOperation, operation)) return;
      _activeOperation = null;

      if (bytes == null) {
        emit(state.copyWith(status: ShowFormStatus.editing));
        return;
      }

      final validationError = _validatePosterCandidate(bytes);
      if (validationError != null) {
        emit(
          state.copyWith(
            status: ShowFormStatus.editing,
            posterError: validationError,
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          status: ShowFormStatus.editing,
          posterBytes: bytes,
          clearPosterError: true,
        ),
      );
    } catch (error) {
      if (isClosed || !identical(_activeOperation, operation)) return;
      _activeOperation = null;
      emit(
        state.copyWith(
          status: ShowFormStatus.editing,
          posterError: _posterPickError(error),
        ),
      );
    }
  }

  /// Validates all fields and submits [NewShow] + poster bytes to [ShowsRepository].
  Future<void> submit() async {
    if (isClosed || state.isBusy) return;

    final trimmedTitle = state.title.trim();
    final trimmedDescription = state.description.trim();
    final trimmedDate = state.showDate.trim();

    final titleError = _validateTitle(trimmedTitle);
    final descriptionError = _validateDescription(trimmedDescription);
    final showDateError = _validateDate(trimmedDate);
    final posterError = _validatePosterForSubmit(state.posterBytes);
    final (parsedSessions, sessionsError) = _validateSessions(
      state.sessionTimes,
    );

    if (titleError != null ||
        descriptionError != null ||
        showDateError != null ||
        posterError != null ||
        sessionsError != null ||
        parsedSessions == null) {
      emit(
        state.copyWith(
          status: ShowFormStatus.editing,
          titleError: titleError,
          clearTitleError: titleError == null,
          descriptionError: descriptionError,
          clearDescriptionError: descriptionError == null,
          showDateError: showDateError,
          clearShowDateError: showDateError == null,
          posterError: posterError,
          clearPosterError: posterError == null,
          sessionsError: sessionsError,
          clearSessionsError: sessionsError == null,
          clearSubmitErrorMessage: true,
        ),
      );
      return;
    }

    final newShow = NewShow(
      vendorId: state.vendorId,
      title: trimmedTitle,
      description: trimmedDescription,
      showDate: trimmedDate,
      sessions: parsedSessions,
    );
    final posterCopy = Uint8List.fromList(state.posterBytes!);

    final operation = Object();
    _activeOperation = operation;
    emit(
      state.copyWith(
        status: ShowFormStatus.submitting,
        clearTitleError: true,
        clearDescriptionError: true,
        clearShowDateError: true,
        clearPosterError: true,
        clearSessionsError: true,
        clearSubmitErrorMessage: true,
      ),
    );

    try {
      await _repository.addShow(newShow, posterCopy);
      if (isClosed || !identical(_activeOperation, operation)) return;
      _activeOperation = null;
      emit(
        state.copyWith(
          status: ShowFormStatus.submitted,
          submissionCount: state.submissionCount + 1,
          clearSubmitErrorMessage: true,
        ),
      );
    } catch (_) {
      if (isClosed || !identical(_activeOperation, operation)) return;
      _activeOperation = null;
      emit(
        state.copyWith(
          status: ShowFormStatus.failure,
          submitErrorMessage: submitFailedMessage,
        ),
      );
    }
  }

  static String? _validateTitle(String trimmedTitle) {
    if (trimmedTitle.isEmpty) return titleRequiredMessage;
    if (trimmedTitle.length > ShowFormState.maxTitleLength) {
      return titleTooLongMessage;
    }
    return null;
  }

  static String? _validateDescription(String trimmedDescription) {
    if (trimmedDescription.isEmpty) return descriptionRequiredMessage;
    if (trimmedDescription.length > ShowFormState.maxDescriptionLength) {
      return descriptionTooLongMessage;
    }
    return null;
  }

  static String? _validateDate(String trimmedDate) {
    if (trimmedDate.isEmpty) return showDateRequiredMessage;
    try {
      validateShowDate(trimmedDate);
      return null;
    } on ArgumentError {
      return showDateInvalidMessage;
    }
  }

  static String? _validatePosterCandidate(Uint8List bytes) {
    if (bytes.isEmpty) return posterEmptyMessage;
    if (bytes.lengthInBytes > ShowFormState.maxPosterBytes) {
      return posterTooLargeMessage;
    }
    return null;
  }

  static String _posterPickError(Object error) =>
      error is FormatException ? posterFormatMessage : posterPickFailedMessage;

  static String? _validatePosterForSubmit(Uint8List? bytes) {
    if (bytes == null) return posterRequiredMessage;
    return _validatePosterCandidate(bytes);
  }

  static (List<SessionTime>?, String?) _validateSessions(
    List<String> rawSlots,
  ) {
    if (rawSlots.isEmpty || rawSlots.length > ShowFormState.maxSessions) {
      return (null, sessionsInvalidMessage);
    }
    final parsed = <SessionTime>[];
    for (final raw in rawSlots) {
      try {
        parsed.add(SessionTime(raw.trim()));
      } on ArgumentError {
        return (null, sessionsInvalidMessage);
      }
    }
    if (parsed.toSet().length != parsed.length) {
      return (null, sessionsDuplicateMessage);
    }
    return (parsed, null);
  }

  @override
  Future<void> close() {
    _activeOperation = null;
    return super.close();
  }
}
