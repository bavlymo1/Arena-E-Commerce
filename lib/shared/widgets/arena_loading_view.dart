import 'package:flutter/material.dart';

/// Centered progress indicator with an explanatory status label.
class ArenaLoadingView extends StatelessWidget {
  const ArenaLoadingView({
    required this.label,
    this.padding = const EdgeInsets.all(24),
    this.indicatorKey,
    super.key,
  });

  final String label;
  final EdgeInsetsGeometry padding;
  final Key? indicatorKey;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(key: indicatorKey),
            const SizedBox(height: 16),
            Text(label),
          ],
        ),
      ),
    );
  }
}
