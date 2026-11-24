import 'package:flutter/material.dart';

/// Shared screen heading with brand/console eyebrow, title, and optional subtitle.
class ArenaPageHeader extends StatelessWidget {
  const ArenaPageHeader({
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.compactSubtitle = false,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final bool compactSubtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          eyebrow,
          style: textTheme.labelLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (subtitle case final subtitleText?) ...<Widget>[
          SizedBox(height: compactSubtitle ? 6 : 8),
          Text(
            subtitleText,
            style:
                (compactSubtitle ? textTheme.bodySmall : textTheme.bodyMedium)
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
