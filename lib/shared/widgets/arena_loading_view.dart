import 'package:flutter/material.dart';

/// Centered progress indicator with an explanatory status label.
class ArenaLoadingView extends StatelessWidget {
  const ArenaLoadingView({
    required this.label,
    this.padding = const EdgeInsets.all(24),
    super.key,
  });

  final String label;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(label),
          ],
        ),
      ),
    );
  }
}
