import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/formatting/date_time_formatting.dart';
import '../cubit/show_form_cubit.dart';
import '../cubit/show_form_state.dart';
import '../widgets/vendor_show_poster_banner.dart';

/// Vendor show creation form consuming [ShowFormCubit].
class AddShowScreen extends StatefulWidget {
  const AddShowScreen({
    this.onShowSaved,
    this.onBackToShows,
    this.onPickPoster,
    super.key,
  });

  final VoidCallback? onShowSaved;
  final VoidCallback? onBackToShows;
  final ShowPosterPicker? onPickPoster;

  @override
  State<AddShowScreen> createState() => _AddShowScreenState();
}

class _AddShowScreenState extends State<AddShowScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _dateController;
  final List<TextEditingController> _sessionControllers =
      <TextEditingController>[];
  late int _lastNotifiedSubmissionCount;

  @override
  void initState() {
    super.initState();
    final initial = context.read<ShowFormCubit>().state;
    _lastNotifiedSubmissionCount = initial.submissionCount;
    _titleController = TextEditingController(text: initial.title);
    _descriptionController = TextEditingController(text: initial.description);
    _dateController = TextEditingController(text: initial.showDate);
    _syncSessionControllers(initial.sessionTimes);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    for (final controller in _sessionControllers) {
      controller.dispose();
    }
    _sessionControllers.clear();
    super.dispose();
  }

  void _syncControllers(ShowFormState state) {
    _setControllerText(_titleController, state.title);
    _setControllerText(_descriptionController, state.description);
    _setControllerText(_dateController, state.showDate);
    _syncSessionControllers(state.sessionTimes);
  }

  void _syncSessionControllers(List<String> sessionTimes) {
    final targetLength = sessionTimes.length;
    final sharedCount = _sessionControllers.length < targetLength
        ? _sessionControllers.length
        : targetLength;
    for (var i = 0; i < sharedCount; i++) {
      _setControllerText(_sessionControllers[i], sessionTimes[i]);
    }
    while (_sessionControllers.length < targetLength) {
      _sessionControllers.add(
        TextEditingController(text: sessionTimes[_sessionControllers.length]),
      );
    }
    while (_sessionControllers.length > targetLength) {
      _sessionControllers.removeLast().dispose();
    }
  }

  void _setControllerText(TextEditingController controller, String text) {
    if (controller.text == text) return;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  Future<void> _chooseDate(BuildContext context, ShowFormCubit cubit) async {
    final parsed = tryParseIsoDateParts(cubit.state.showDate.trim());
    final initialDate = parsed == null
        ? DateTime.now()
        : DateTime(parsed.$1, parsed.$2, parsed.$3);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
    );
    if (!mounted || picked == null) return;
    final formatted =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
    cubit.updateShowDate(formatted);
  }

  Future<void> _chooseSessionTime(
    BuildContext context,
    ShowFormCubit cubit,
    int index,
  ) async {
    final current = index < cubit.state.sessionTimes.length
        ? cubit.state.sessionTimes[index]
        : '';
    final parsed = tryParseHourMinute(current.trim());
    final initialTime = parsed == null
        ? const TimeOfDay(hour: 19, minute: 0)
        : TimeOfDay(hour: parsed.$1, minute: parsed.$2);
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (!mounted || picked == null) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    cubit.updateSessionTime(index, formatted);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final canGoBack = widget.onBackToShows != null || Navigator.canPop(context);
    void handleBack() => widget.onBackToShows != null
        ? widget.onBackToShows!()
        : Navigator.maybePop(context);

    return BlocConsumer<ShowFormCubit, ShowFormState>(
      listener: (context, state) {
        _syncControllers(state);
        if (state.isSubmitted &&
            state.submissionCount > _lastNotifiedSubmissionCount) {
          _lastNotifiedSubmissionCount = state.submissionCount;
          widget.onShowSaved?.call();
        }
      },
      builder: (context, state) {
        final cubit = context.read<ShowFormCubit>();
        void submit() {
          FocusScope.of(context).unfocus();
          unawaited(cubit.submit());
        }

        final page = Scaffold(
          appBar: AppBar(
            leading: canGoBack
                ? IconButton(
                    key: const ValueKey<String>('add-show-back-button'),
                    tooltip: 'Back to My shows',
                    onPressed: state.isBusy ? null : handleBack,
                    icon: const Icon(Icons.arrow_back),
                  )
                : null,
            title: const Text(
              'Add show',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'ArenaPass Console',
                    style: textTheme.labelLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add show',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set show details, poster artwork, and 1–5 daily sessions.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    key: const ValueKey<String>('add-show-title-field'),
                    controller: _titleController,
                    enabled: !state.isSubmitting,
                    maxLength: ShowFormState.maxTitleLength,
                    textInputAction: TextInputAction.next,
                    onChanged: cubit.updateTitle,
                    decoration: _fieldDecoration(
                      context,
                      labelText: 'Show title',
                      hintText: 'Apex Legends Invitational',
                      errorText: state.titleError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey<String>('add-show-description-field'),
                    controller: _descriptionController,
                    enabled: !state.isSubmitting,
                    maxLength: ShowFormState.maxDescriptionLength,
                    minLines: 3,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    onChanged: cubit.updateDescription,
                    decoration: _fieldDecoration(
                      context,
                      labelText: 'Description',
                      hintText: 'Describe the event, lineup, and arena notes',
                      errorText: state.descriptionError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey<String>('add-show-date-field'),
                    controller: _dateController,
                    enabled: !state.isSubmitting,
                    keyboardType: TextInputType.datetime,
                    textInputAction: TextInputAction.next,
                    onChanged: cubit.updateShowDate,
                    decoration: _fieldDecoration(
                      context,
                      labelText: 'Show date',
                      hintText: 'YYYY-MM-DD',
                      errorText: state.showDateError,
                      suffixIcon: IconButton(
                        key: const ValueKey<String>(
                          'add-show-date-picker-button',
                        ),
                        tooltip: 'Choose show date',
                        onPressed: state.isSubmitting
                            ? null
                            : () => unawaited(_chooseDate(context, cubit)),
                        icon: const Icon(Icons.calendar_today_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Show artwork',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: state.posterError != null
                            ? colorScheme.error.withValues(alpha: 0.7)
                            : colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (state.hasPoster)
                          VendorShowPosterBanner(
                            key: const ValueKey<String>(
                              'add-show-poster-preview',
                            ),
                            posterBytes: state.posterBytes,
                            title: state.title.trim().isEmpty
                                ? 'Show artwork'
                                : state.title.trim(),
                            height: 160,
                            borderRadius: BorderRadius.circular(12),
                          )
                        else
                          Container(
                            key: const ValueKey<String>(
                              'add-show-poster-placeholder',
                            ),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colorScheme.outlineVariant,
                              ),
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
                              key: const ValueKey<String>(
                                'add-show-gallery-button',
                              ),
                              onPressed: state.isBusy
                                  ? null
                                  : () => unawaited(
                                      cubit.pickPoster(
                                        ShowPosterSource.gallery,
                                        picker: widget.onPickPoster,
                                      ),
                                    ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(120, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: VendorButtonContent(
                                icon: Icons.photo_library_outlined,
                                label: state.isPickingPoster
                                    ? 'Selecting…'
                                    : 'Gallery',
                              ),
                            ),
                            OutlinedButton(
                              key: const ValueKey<String>(
                                'add-show-camera-button',
                              ),
                              onPressed: state.isBusy
                                  ? null
                                  : () => unawaited(
                                      cubit.pickPoster(
                                        ShowPosterSource.camera,
                                        picker: widget.onPickPoster,
                                      ),
                                    ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(120, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const VendorButtonContent(
                                icon: Icons.photo_camera_outlined,
                                label: 'Camera',
                              ),
                            ),
                          ],
                        ),
                        if (state.posterError != null) ...<Widget>[
                          const SizedBox(height: 12),
                          Text(
                            state.posterError!,
                            key: const ValueKey<String>(
                              'add-show-poster-error',
                            ),
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Sessions',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '47 seats per session · ${state.sessionTimes.length} of ${ShowFormState.maxSessions} slots',
                    key: const ValueKey<String>('add-show-sessions-counter'),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (
                    var i = 0;
                    i < state.sessionTimes.length;
                    i++
                  ) ...<Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            key: ValueKey<String>('add-show-session-time-$i'),
                            controller: _sessionControllers[i],
                            enabled: !state.isBusy,
                            keyboardType: TextInputType.datetime,
                            textInputAction: i == state.sessionTimes.length - 1
                                ? TextInputAction.done
                                : TextInputAction.next,
                            onChanged: (value) =>
                                cubit.updateSessionTime(i, value),
                            decoration: _fieldDecoration(
                              context,
                              labelText: 'Session ${i + 1} time',
                              hintText: 'HH:mm',
                              suffixIcon: IconButton(
                                key: ValueKey<String>(
                                  'add-show-session-picker-$i',
                                ),
                                tooltip: 'Choose session ${i + 1} time',
                                onPressed: state.isBusy
                                    ? null
                                    : () => unawaited(
                                        _chooseSessionTime(context, cubit, i),
                                      ),
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
                            onPressed: state.isBusy
                                ? null
                                : () => cubit.removeSessionSlot(i),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (state.sessionsError != null) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        state.sessionsError!,
                        key: const ValueKey<String>('add-show-sessions-error'),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                  OutlinedButton(
                    key: const ValueKey<String>('add-show-add-session-button'),
                    onPressed: state.canAddSession
                        ? cubit.addSessionSlot
                        : null,
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
                  if (state.submitErrorMessage != null) ...<Widget>[
                    const SizedBox(height: 20),
                    Semantics(
                      liveRegion: true,
                      container: true,
                      child: VendorNoticeBanner(
                        key: const ValueKey<String>(
                          'add-show-submit-error-banner',
                        ),
                        icon: Icons.error_outline,
                        message: state.submitErrorMessage!,
                        isError: true,
                        actionLabel: 'Try again',
                        actionKey: const ValueKey<String>(
                          'add-show-retry-submit-button',
                        ),
                        onAction: state.isBusy ? null : submit,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const ValueKey<String>('add-show-submit-button'),
                    onPressed: state.isBusy ? null : submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: state.isSubmitting
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Flexible(child: Text('Saving show…')),
                            ],
                          )
                        : const Text('Save show'),
                  ),
                ],
              ),
            ),
          ),
        );
        return PopScope(canPop: !state.isSubmitting, child: page);
      },
    );
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String labelText,
    required String hintText,
    String? errorText,
    Widget? suffixIcon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      errorText: errorText,
      errorMaxLines: 2,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colorScheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
    );
  }
}
