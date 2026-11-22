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
