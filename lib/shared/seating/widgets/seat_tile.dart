import 'package:flutter/material.dart';

import '../seat_layout.dart';

class SeatColors {
  static const Color availableFill = Color(0xFFFFFFFF);
  static const Color availableInk = Color(0xFF211C24);
  static const Color availableBorder = Color(0xFF766F78);

  static const Color bookedFill = Color(0xFF766E78);
  static const Color bookedInk = Color(0xFFFFFFFF);
  static const Color bookedBorder = Color(0xFF766E78);

  static const Color greenFill = Color(0xFF9AE5B5);
  static const Color greenInk = Color(0xFF102519);
  static const Color greenBorder = Color(0xFF36784B);
}

class SeatTile extends StatelessWidget {
  const SeatTile({
    required this.seatNumber,
    required this.status,
    this.onTap,
    this.readOnly = false,
    this.busy = false,
    this.listMode = false,
    this.enlarged = false,
    super.key,
  });

  final int seatNumber;
  final SeatVisualStatus status;
  final ValueChanged<int>? onTap;
  final bool readOnly;
  final bool busy;
  final bool listMode;
  final bool enlarged;

  bool get _canTap =>
      !readOnly && !busy && status.isInteractive && onTap != null;

  @override
  Widget build(BuildContext context) {
    final (fill, ink, border, borderWidth) = switch (status) {
      SeatVisualStatus.available => (
        SeatColors.availableFill,
        SeatColors.availableInk,
        SeatColors.availableBorder,
        1.0,
      ),
      SeatVisualStatus.bookedByOther => (
        SeatColors.bookedFill,
        SeatColors.bookedInk,
        SeatColors.bookedBorder,
        1.0,
      ),
      SeatVisualStatus.selected => (
        SeatColors.greenFill,
        SeatColors.greenInk,
        SeatColors.greenBorder,
        1.5,
      ),
      SeatVisualStatus.mineConfirmed => (
        SeatColors.greenFill,
        SeatColors.greenInk,
        SeatColors.greenBorder,
        2.0,
      ),
    };

    final label = SeatLayout.semanticsLabelForSeat(seatNumber, status);
    final isMine = status == SeatVisualStatus.mineConfirmed;
    final isSelected = status == SeatVisualStatus.selected;
    final tileText = isMine ? '$seatNumber✓' : '$seatNumber';

    final Widget content;
    if (listMode) {
      content = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 68),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Center(
            child: Text(
              tileText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ink,
                fontSize: 13,
                fontWeight: isSelected || isMine
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    } else {
      final size = enlarged ? 44.0 : 30.0;
      content = SizedBox(
        width: size,
        height: size,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Text(
                tileText,
                style: TextStyle(
                  color: ink,
                  fontSize: enlarged ? 12 : 10,
                  fontWeight: isSelected || isMine
                      ? FontWeight.w700
                      : FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      button: !readOnly,
      enabled: _canTap,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(listMode || enlarged ? 10 : 7),
          side: BorderSide(color: border, width: borderWidth),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey<String>(
            'seat-${listMode ? 'list' : 'grid'}-$seatNumber',
          ),
          onTap: _canTap ? () => onTap!(seatNumber) : null,
          child: content,
        ),
      ),
    );
  }
}
