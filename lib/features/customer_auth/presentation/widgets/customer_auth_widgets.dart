import 'package:flutter/material.dart';

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
