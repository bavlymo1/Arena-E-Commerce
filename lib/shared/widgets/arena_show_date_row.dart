import 'package:flutter/material.dart';

import '../../core/formatting/date_time_formatting.dart';

/// Wrapping show-date display combining human-readable date, ISO date, and optional trailing badge.
class ArenaShowDateRow extends StatelessWidget {
  const ArenaShowDateRow({
    required this.showDate,
    this.showIcon = false,
    this.prominent = false,
    this.dateLabelKey,
    this.trailing,
    super.key,
  });

  final String showDate;
  final bool showIcon;
  final bool prominent;
  final Key? dateLabelKey;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dateLabel = formatShowDateLabel(showDate);

    return Wrap(
      spacing: 8,
      runSpacing: trailing != null ? 6 : 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        if (showIcon)
          Icon(
            Icons.calendar_today_outlined,
            size: 15,
            color: colorScheme.primary,
          ),
        Text(
          dateLabel,
          key: dateLabelKey,
          style: (prominent ? textTheme.labelLarge : textTheme.labelMedium)
              ?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
        ),
        Text(
          showDate,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
