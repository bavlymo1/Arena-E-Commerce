import 'package:flutter/material.dart';

import 'seat_tile.dart';

class SeatLegend extends StatelessWidget {
  const SeatLegend({this.vendorMode = false, super.key});

  final bool vendorMode;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 8,
      children: <Widget>[
        const _LegendItem(
          label: 'Available',
          fill: SeatColors.availableFill,
          border: SeatColors.availableBorder,
          ink: SeatColors.availableInk,
        ),
        const _LegendItem(
          label: 'Booked',
          fill: SeatColors.bookedFill,
          border: SeatColors.bookedBorder,
          ink: SeatColors.bookedInk,
        ),
        if (!vendorMode) ...<Widget>[
          const _LegendItem(
            label: 'Selected',
            fill: SeatColors.greenFill,
            border: SeatColors.greenBorder,
            ink: SeatColors.greenInk,
          ),
          const _LegendItem(
            label: 'Yours',
            fill: SeatColors.greenFill,
            border: SeatColors.greenBorder,
            ink: SeatColors.greenInk,
            symbol: '✓',
          ),
        ],
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.label,
    required this.fill,
    required this.border,
    required this.ink,
    this.symbol,
  });

  final String label;
  final Color fill;
  final Color border;
  final Color ink;
  final String? symbol;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 14,
          height: 14,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: border),
          ),
          child: symbol == null
              ? null
              : Text(
                  symbol!,
                  style: TextStyle(
                    color: ink,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
