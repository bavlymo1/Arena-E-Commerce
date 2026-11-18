import 'package:flutter/material.dart';

/// Compact ArenaPass ticket-stub mark matching the prototype app bar badge.
class CustomerAuthBrandMark extends StatelessWidget {
  const CustomerAuthBrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ExcludeSemantics(
      child: Container(
        width: 28,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'A',
          style: TextStyle(
            color: colorScheme.onPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// Accessible inline notice or error banner with optional retry action.
class CustomerAuthNoticeBanner extends StatelessWidget {
  const CustomerAuthNoticeBanner({
    required this.message,
    this.isError = false,
    this.actionLabel,
    this.onAction,
    this.actionKey,
    super.key,
  });

  final String message;
  final bool isError;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accentColor = isError ? colorScheme.error : colorScheme.primary;

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isError
                ? colorScheme.error.withValues(alpha: 0.5)
                : colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  isError ? Icons.error_outline : Icons.info_outline,
                  size: 18,
                  color: accentColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: actionKey,
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Reusable password form field with visibility toggle and keyboard/autofill support.
class CustomerPasswordFormField extends StatelessWidget {
  const CustomerPasswordFormField({
    required this.fieldKey,
    required this.toggleKey,
    required this.controller,
    required this.focusNode,
    required this.labelText,
    required this.obscureText,
    required this.onToggleVisibility,
    required this.enabled,
    required this.textInputAction,
    required this.autofillHints,
    required this.validator,
    this.showLabel = 'Show password',
    this.hideLabel = 'Hide password',
    this.onFieldSubmitted,
    super.key,
  });

  final Key fieldKey;
  final Key toggleKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String labelText;
  final bool obscureText;
  final VoidCallback onToggleVisibility;
  final bool enabled;
  final TextInputAction textInputAction;
  final Iterable<String> autofillHints;
  final FormFieldValidator<String> validator;
  final String showLabel;
  final String hideLabel;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final visibilityLabel = obscureText ? showLabel : hideLabel;

    return TextFormField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      obscureText: obscureText,
      enableSuggestions: false,
      autocorrect: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        labelText: labelText,
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
        suffixIcon: IconButton(
          key: toggleKey,
          tooltip: visibilityLabel,
          onPressed: enabled ? onToggleVisibility : null,
          icon: Icon(
            obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }
}

/// Shared email input decoration matching the ArenaPass form surfaces.
InputDecoration customerAuthEmailDecoration(
  BuildContext context, {
  required String labelText,
  required String hintText,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
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
