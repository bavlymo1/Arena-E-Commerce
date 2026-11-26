import 'package:flutter/material.dart';

/// Shared inline notice or error banner aligned with ArenaPass surface tokens.
class ArenaNoticeBanner extends StatelessWidget {
  const ArenaNoticeBanner({
    required this.icon,
    required this.message,
    this.isError = false,
    this.actionLabel,
    this.onAction,
    this.actionKey,
    this.liveRegion = false,
    this.useTextAction = false,
    this.emphasizeText = false,
    this.padding = const EdgeInsets.all(12),
    this.iconSpacing = 12,
    super.key,
  });

  final IconData icon;
  final String message;
  final bool isError;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Key? actionKey;
  final bool liveRegion;
  final bool useTextAction;
  final bool emphasizeText;
  final EdgeInsetsGeometry padding;
  final double iconSpacing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accentColor = isError ? colorScheme.error : colorScheme.primary;
    final hasAction = actionLabel != null && onAction != null;

    final Widget content = Container(
      padding: padding,
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
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 18, color: accentColor),
              SizedBox(width: iconSpacing),
              Expanded(
                child: Text(
                  message,
                  style: textTheme.bodyMedium?.copyWith(
                    color: emphasizeText
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (hasAction) ...<Widget>[
            SizedBox(height: useTextAction ? 8 : 10),
            Align(
              alignment: useTextAction
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: useTextAction
                  ? TextButton(
                      key: actionKey,
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    )
                  : OutlinedButton(
                      key: actionKey,
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    ),
            ),
          ],
        ],
      ),
    );

    if (!liveRegion) return content;
    return Semantics(liveRegion: true, container: true, child: content);
  }
}
