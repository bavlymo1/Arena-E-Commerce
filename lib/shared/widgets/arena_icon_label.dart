import 'package:flutter/material.dart';

/// Wrapping icon-and-label row that avoids horizontal overflow in buttons at high text scales.
class ArenaIconLabel extends StatelessWidget {
  const ArenaIconLabel({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
  }
}
