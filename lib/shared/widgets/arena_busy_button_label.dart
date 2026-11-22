import 'package:flutter/material.dart';

/// Compact spinner-plus-label row for busy action buttons.
class ArenaBusyButtonLabel extends StatelessWidget {
  const ArenaBusyButtonLabel({
    required this.label,
    this.strokeColor,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.textAlign,
    super.key,
  });

  final String label;
  final Color? strokeColor;
  final MainAxisAlignment mainAxisAlignment;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: mainAxisAlignment,
      children: <Widget>[
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color:
                strokeColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(child: Text(label, textAlign: textAlign)),
      ],
    );
  }
}
