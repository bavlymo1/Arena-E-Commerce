import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../vendor_shows/domain/models/session.dart';

const List<String> _monthAbbreviations = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Formats an ISO `yyyy-MM-dd` show date into a concise UTC calendar label,
/// falling back to [isoDate] if the input is malformed.
String formatShowDateLabel(String isoDate) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(isoDate);
  if (match == null) return isoDate;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  if (year < 1 || month < 1 || month > 12 || day < 1 || day > 31) {
    return isoDate;
  }
  final parsed = DateTime.utc(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return isoDate;
  }
  return '${_monthAbbreviations[month - 1]} $day, $year';
}

/// Formats a 24-hour `HH:mm` session time into 12-hour clock text,
/// falling back to [hhMm] if the input is malformed.
String formatSessionTime12Hour(String hhMm) {
  final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(hhMm);
  if (match == null) return hhMm;
  final hour = int.parse(match.group(1)!);
  final minute = match.group(2)!;
  final period = hour < 12 ? 'AM' : 'PM';
  final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '$displayHour:$minute $period';
}

/// Returns a singular/plural remaining-seat count label bounded to capacity.
String formatRemainingSeatsLabel(Session session) {
  final remaining = (session.capacity - session.bookedSeats.length).clamp(
    0,
    session.capacity,
  );
  return remaining == 1 ? '1 seat left' : '$remaining seats left';
}

/// Renders loaded show artwork bytes or a structured arena stage fallback.
class ShowPosterBanner extends StatelessWidget {
  const ShowPosterBanner({
    required this.title,
    this.posterBytes,
    this.height = 142,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.isLoading = false,
    super.key,
  });

  final Uint8List? posterBytes;
  final String title;
  final double height;
  final BorderRadius borderRadius;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final bytes = posterBytes;
    final Widget artwork = bytes != null && bytes.isNotEmpty
        ? Image.memory(
            bytes,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            cacheWidth: 720,
            gaplessPlayback: true,
            semanticLabel: '$title artwork',
            errorBuilder: (context, error, stackTrace) =>
                _StageFallbackArtwork(height: height),
          )
        : _StageFallbackArtwork(height: height);

    return Semantics(
      image: true,
      label: '$title artwork',
      excludeSemantics: true,
      child: ClipRRect(borderRadius: borderRadius, child: artwork),
    );
  }
}

class _StageFallbackArtwork extends StatelessWidget {
  const _StageFallbackArtwork({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRect(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFF4E202D),
                Color(0xFF211825),
                Color(0xFF101219),
              ],
              stops: <double>[0.0, 0.55, 1.0],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned(
                right: 36,
                top: 20,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF4D8C4).withValues(alpha: 0.9),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 148,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1822).withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFAB6B7E).withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: <double>[0.4, 1.0],
                      colors: <Color>[Colors.transparent, Color(0x9908080A)],
                    ),
                  ),
                ),
              ),
              const Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: Text(
                  'LIVE AT ARENA CENTRAL',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFFF8E4DF),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared inline notice banner aligned with the ArenaPass prototype surfaces.
class DiscoveryNoticeBanner extends StatelessWidget {
  const DiscoveryNoticeBanner({
    required this.icon,
    required this.message,
    this.isError = false,
    super.key,
  });

  final IconData icon;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accentColor = isError ? colorScheme.error : colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError
              ? colorScheme.error.withValues(alpha: 0.5)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: accentColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared centered state block for empty, no-match, error and unavailable views.
class DiscoveryStatusPanel extends StatelessWidget {
  const DiscoveryStatusPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.isError = false,
    this.useOutlinedAction = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;
  final bool useOutlinedAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 26,
              color: isError ? colorScheme.error : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: useOutlinedAction
                  ? OutlinedButton(
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    )
                  : FilledButton(
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
