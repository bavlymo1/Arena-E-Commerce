import 'package:flutter/material.dart';

import 'arena_brand_mark.dart';

/// Shared AppBar brand mark paired with an ellipsis-bounded screen title.
class ArenaBrandAppBarTitle extends StatelessWidget {
  const ArenaBrandAppBarTitle({
    required this.title,
    this.spacing = 10,
    super.key,
  });

  final String title;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const ArenaBrandMark(),
        SizedBox(width: spacing),
        Expanded(
          child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
