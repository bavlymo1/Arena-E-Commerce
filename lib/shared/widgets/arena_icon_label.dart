import 'package:flutter/material.dart';

/// Wrapping icon-and-label row that avoids horizontal overflow in buttons at high text scales.
class ArenaIconLabel extends StatelessWidget {
  const ArenaIconLabel({
    required this.icon,
    required this.label,
    this.iconSize = 18,
    this.spacing = 8,
    this.mainAxisAlignment = MainAxisAlignment.center,
    this.textAlign = TextAlign.center,
    super.key,
  });

  final IconData icon;
  final String label;
  final double iconSize;
  final double spacing;
  final MainAxisAlignment mainAxisAlignment;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: mainAxisAlignment,
      children: <Widget>[
        Icon(icon, size: iconSize),
        SizedBox(width: spacing),
        Flexible(child: Text(label, textAlign: textAlign)),
      ],
    );
  }
}
