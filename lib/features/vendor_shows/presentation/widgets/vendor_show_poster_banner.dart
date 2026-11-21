import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../domain/models/session.dart';
import '../../domain/models/show.dart';

/// Returns a bounded `X / capacity booked` summary for a vendor session.
String formatVendorSessionBookedSummary(Session session) {
  final booked = session.bookedSeats.length.clamp(0, session.capacity);
  return '$booked / ${session.capacity} booked';
}

/// Returns the vendor-facing show-wide booked seat summary.
String formatVendorShowBookedSummary(Show show) =>
    '${show.bookedCount} booked total';

/// Adaptive icon-plus-label button child that wraps cleanly at high text scales.
class VendorButtonContent extends StatelessWidget {
  const VendorButtonContent({
    required this.icon,
    required this.label,
    super.key,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Flexible(child: Text(label)),
      ],
    );
  }
}

/// Renders loaded show artwork bytes or a structured arena stage fallback.
class VendorShowPosterBanner extends StatelessWidget {
  const VendorShowPosterBanner({
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
                _VendorStageFallbackArtwork(height: height),
          )
        : _VendorStageFallbackArtwork(height: height);

    return Semantics(
      image: true,
      label: '$title artwork',
      excludeSemantics: true,
      child: ClipRRect(borderRadius: borderRadius, child: artwork),
    );
  }
}

class _VendorStageFallbackArtwork extends StatelessWidget {
  const _VendorStageFallbackArtwork({required this.height});

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
                  'ARENA CONSOLE',
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

/// Inline vendor notice banner aligned with ArenaPass surface tokens.
class VendorNoticeBanner extends StatelessWidget {
  const VendorNoticeBanner({
    required this.icon,
    required this.message,
    this.isError = false,
    this.actionLabel,
    this.onAction,
    this.actionKey,
    super.key,
  });

  final IconData icon;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
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
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                key: actionKey,
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

/// Centered vendor state panel for empty, unavailable, and error views.
class VendorStatusPanel extends StatelessWidget {
  const VendorStatusPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionKey,
    this.isError = false,
    this.useOutlinedAction = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Key? actionKey;
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
                      key: actionKey,
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    )
                  : FilledButton(
                      key: actionKey,
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
