import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Renders loaded show artwork bytes or a structured arena stage fallback.
class ArenaPosterBanner extends StatelessWidget {
  const ArenaPosterBanner({
    required this.title,
    this.posterBytes,
    this.height = 142,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.fallbackLabel = 'LIVE AT ARENA CENTRAL',
    super.key,
  });

  final Uint8List? posterBytes;
  final String title;
  final double height;
  final BorderRadius borderRadius;
  final String fallbackLabel;

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
            errorBuilder: (context, error, stackTrace) =>
                _StageFallbackArtwork(height: height, label: fallbackLabel),
          )
        : _StageFallbackArtwork(height: height, label: fallbackLabel);

    return Semantics(
      image: true,
      label: '$title artwork',
      excludeSemantics: true,
      child: ClipRRect(borderRadius: borderRadius, child: artwork),
    );
  }
}

class _StageFallbackArtwork extends StatelessWidget {
  const _StageFallbackArtwork({required this.height, required this.label});

  final double height;
  final String label;

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
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
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
