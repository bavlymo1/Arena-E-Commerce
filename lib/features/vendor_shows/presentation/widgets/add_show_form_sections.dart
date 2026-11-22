import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../shared/widgets/arena_busy_button_label.dart';
import '../../../../shared/widgets/arena_notice_banner.dart';
import '../../../../shared/widgets/arena_poster_banner.dart';
import '../cubit/show_form_state.dart';
import 'vendor_show_widgets.dart';

InputDecoration _addShowFieldDecoration({
  required String labelText,
  required String hintText,
  String? errorText,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    errorText: errorText,
    errorMaxLines: 2,
    suffixIcon: suffixIcon,
  );
}

/// Show title, description, and show date input fields for [AddShowScreen].
class AddShowDetailsFields extends StatelessWidget {
  const AddShowDetailsFields({
    required this.titleController,
    required this.descriptionController,
    required this.dateController,
    required this.enabled,
    required this.titleError,
    required this.descriptionError,
    required this.showDateError,
    required this.onTitleChanged,
    required this.onDescriptionChanged,
    required this.onDateChanged,
    required this.onPickDate,
    super.key,
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController dateController;
  final bool enabled;
  final String? titleError;
  final String? descriptionError;
  final String? showDateError;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onDescriptionChanged;
  final ValueChanged<String> onDateChanged;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          key: const ValueKey<String>('add-show-title-field'),
          controller: titleController,
          enabled: enabled,
          maxLength: ShowFormState.maxTitleLength,
          textInputAction: TextInputAction.next,
          onChanged: onTitleChanged,
          decoration: _addShowFieldDecoration(
            labelText: 'Show title',
            hintText: 'Apex Legends Invitational',
            errorText: titleError,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey<String>('add-show-description-field'),
          controller: descriptionController,
          enabled: enabled,
          maxLength: ShowFormState.maxDescriptionLength,
          minLines: 3,
          maxLines: 5,
          textInputAction: TextInputAction.newline,
          onChanged: onDescriptionChanged,
          decoration: _addShowFieldDecoration(
            labelText: 'Description',
            hintText: 'Describe the event, lineup, and arena notes',
            errorText: descriptionError,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey<String>('add-show-date-field'),
          controller: dateController,
          enabled: enabled,
          keyboardType: TextInputType.datetime,
          textInputAction: TextInputAction.next,
          onChanged: onDateChanged,
          decoration: _addShowFieldDecoration(
            labelText: 'Show date',
            hintText: 'YYYY-MM-DD',
            errorText: showDateError,
            suffixIcon: IconButton(
              key: const ValueKey<String>('add-show-date-picker-button'),
              tooltip: 'Choose show date',
              onPressed: enabled ? onPickDate : null,
              icon: const Icon(Icons.calendar_today_outlined),
            ),
          ),
        ),
      ],
    );
  }
}

/// Poster preview/placeholder card with gallery and camera selection actions.
class AddShowPosterSection extends StatelessWidget {
  const AddShowPosterSection({
    required this.title,
    required this.posterBytes,
    required this.hasPoster,
    required this.posterError,
    required this.isBusy,
    required this.isPickingPoster,
    required this.pickingPosterSource,
    required this.onPickGallery,
    required this.onPickCamera,
    super.key,
  });

  final String title;
  final Uint8List? posterBytes;
  final bool hasPoster;
  final String? posterError;
  final bool isBusy;
  final bool isPickingPoster;
  final ShowPosterSource? pickingPosterSource;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Show artwork',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: posterError != null
                  ? colorScheme.error.withValues(alpha: 0.7)
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (hasPoster)
                ArenaPosterBanner(
                  key: const ValueKey<String>('add-show-poster-preview'),
                  posterBytes: posterBytes,
                  title: title.trim().isEmpty ? 'Show artwork' : title.trim(),
                  height: 160,
                  borderRadius: BorderRadius.circular(12),
                  fallbackLabel: 'ARENA CONSOLE',
                )
              else
                Container(
                  key: const ValueKey<String>('add-show-poster-placeholder'),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.image_outlined,
                        size: 28,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No artwork selected',
                        textAlign: TextAlign.center,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose a gallery image or take a photo (max 200 KB).',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  OutlinedButton(
                    key: const ValueKey<String>('add-show-gallery-button'),
                    onPressed: isBusy ? null : onPickGallery,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(120, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: VendorButtonContent(
                      icon: Icons.photo_library_outlined,
                      label:
                          isPickingPoster &&
                              pickingPosterSource == ShowPosterSource.gallery
                          ? 'Selecting…'
                          : 'Gallery',
                    ),
                  ),
                  OutlinedButton(
                    key: const ValueKey<String>('add-show-camera-button'),
                    onPressed: isBusy ? null : onPickCamera,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(120, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: VendorButtonContent(
                      icon: Icons.photo_camera_outlined,
                      label:
                          isPickingPoster &&
                              pickingPosterSource == ShowPosterSource.camera
                          ? 'Selecting…'
                          : 'Camera',
                    ),
                  ),
                ],
              ),
              if (posterError != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  posterError!,
                  key: const ValueKey<String>('add-show-poster-error'),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Daily sessions editor (1–5 slots) consuming parent-owned controllers.
class AddShowSessionsSection extends StatelessWidget {
  const AddShowSessionsSection({
    required this.sessionControllers,
    required this.sessionCount,
    required this.isBusy,
    required this.canAddSession,
    required this.sessionsError,
    required this.onSessionChanged,
    required this.onPickSessionTime,
    required this.onRemoveSession,
    required this.onAddSession,
    super.key,
  });

  final List<TextEditingController> sessionControllers;
  final int sessionCount;
  final bool isBusy;
  final bool canAddSession;
  final String? sessionsError;
  final void Function(int index, String value) onSessionChanged;
  final ValueChanged<int> onPickSessionTime;
  final ValueChanged<int> onRemoveSession;
  final VoidCallback onAddSession;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Sessions',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          '47 seats per session · $sessionCount of ${ShowFormState.maxSessions} slots',
          key: const ValueKey<String>('add-show-sessions-counter'),
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < sessionCount; i++) ...<Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: ValueKey<String>('add-show-session-time-$i'),
                  controller: sessionControllers[i],
                  enabled: !isBusy,
                  keyboardType: TextInputType.datetime,
                  textInputAction: i == sessionCount - 1
                      ? TextInputAction.done
                      : TextInputAction.next,
                  onChanged: (value) => onSessionChanged(i, value),
                  decoration: _addShowFieldDecoration(
                    labelText: 'Session ${i + 1} time',
                    hintText: 'HH:mm',
                    suffixIcon: IconButton(
                      key: ValueKey<String>('add-show-session-picker-$i'),
                      tooltip: 'Choose session ${i + 1} time',
                      onPressed: isBusy ? null : () => onPickSessionTime(i),
                      icon: const Icon(Icons.access_time_outlined),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: IconButton(
                  key: ValueKey<String>('add-show-remove-session-$i'),
                  tooltip: 'Remove session ${i + 1}',
                  onPressed: isBusy ? null : () => onRemoveSession(i),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (sessionsError != null) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              sessionsError!,
              key: const ValueKey<String>('add-show-sessions-error'),
              style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
          ),
        ],
        OutlinedButton(
          key: const ValueKey<String>('add-show-add-session-button'),
          onPressed: canAddSession ? onAddSession : null,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const VendorButtonContent(
            icon: Icons.add,
            label: 'Add session',
          ),
        ),
      ],
    );
  }
}

/// Submission error banner and primary save button footer for [AddShowScreen].
class AddShowSubmitFooter extends StatelessWidget {
  const AddShowSubmitFooter({
    required this.isBusy,
    required this.isSubmitting,
    required this.submitErrorMessage,
    required this.onSubmit,
    super.key,
  });

  final bool isBusy;
  final bool isSubmitting;
  final String? submitErrorMessage;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (submitErrorMessage != null) ...<Widget>[
          const SizedBox(height: 20),
          ArenaNoticeBanner(
            key: const ValueKey<String>('add-show-submit-error-banner'),
            icon: Icons.error_outline,
            message: submitErrorMessage!,
            isError: true,
            liveRegion: true,
            actionLabel: 'Try again',
            actionKey: const ValueKey<String>('add-show-retry-submit-button'),
            onAction: isBusy ? null : onSubmit,
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          key: const ValueKey<String>('add-show-submit-button'),
          onPressed: isBusy ? null : onSubmit,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: isSubmitting
              ? const ArenaBusyButtonLabel(label: 'Saving show…')
              : const Text('Save show'),
        ),
      ],
    );
  }
}
