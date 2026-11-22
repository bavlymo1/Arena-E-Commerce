import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/formatting/date_time_formatting.dart';
import '../cubit/show_form_cubit.dart';
import '../cubit/show_form_state.dart';
import '../widgets/add_show_form_sections.dart';

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
                  AddShowDetailsFields(
                    titleController: _titleController,
                    descriptionController: _descriptionController,
                    dateController: _dateController,
                    enabled: !state.isSubmitting,
                    titleError: state.titleError,
                    descriptionError: state.descriptionError,
                    showDateError: state.showDateError,
                    onTitleChanged: cubit.updateTitle,
                    onDescriptionChanged: cubit.updateDescription,
                    onDateChanged: cubit.updateShowDate,
                    onPickDate: () => unawaited(_chooseDate(context, cubit)),
                  ),
                  const SizedBox(height: 24),
                  AddShowPosterSection(
                    title: state.title,
                    posterBytes: state.posterBytes,
                    posterError: state.posterError,
                    isBusy: state.isBusy,
                    isPickingPoster: state.isPickingPoster,
                    pickingPosterSource: state.pickingPosterSource,
                    onPickGallery: () => unawaited(
                      cubit.pickPoster(
                        ShowPosterSource.gallery,
                        picker: widget.onPickPoster,
                      ),
                    ),
                    onPickCamera: () => unawaited(
                      cubit.pickPoster(
                        ShowPosterSource.camera,
                        picker: widget.onPickPoster,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  AddShowSessionsSection(
                    sessionControllers: _sessionControllers,
                    isBusy: state.isBusy,
                    canAddSession: state.canAddSession,
                    sessionsError: state.sessionsError,
                    onSessionChanged: cubit.updateSessionTime,
                    onPickSessionTime: (i) =>
                        unawaited(_chooseSessionTime(context, cubit, i)),
                    onRemoveSession: cubit.removeSessionSlot,
                    onAddSession: cubit.addSessionSlot,
                  ),
                  AddShowSubmitFooter(
                    isBusy: state.isBusy,
                    isSubmitting: state.isSubmitting,
                    submitErrorMessage: state.submitErrorMessage,
                    onSubmit: submit,
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
}
