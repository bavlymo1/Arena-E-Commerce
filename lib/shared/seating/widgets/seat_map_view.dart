import 'package:flutter/material.dart';

import '../../widgets/arena_loading_view.dart';
import '../../widgets/arena_notice_banner.dart';
import '../../widgets/arena_status_panel.dart';
import '../seat_layout.dart';
import 'seat_legend.dart';
import 'seat_tile.dart';

enum SeatMapLoadState { loading, ready, unavailable, error }

typedef SeatTileSelectorBuilder = Widget Function(
  BuildContext context,
  int seatNumber,
  Widget Function(BuildContext context, SeatVisualStatus status, bool busy)
  builder,
);

class SeatMapView extends StatefulWidget {
  const SeatMapView({
    this.bookedSeats = const <int>{},
    this.myConfirmedSeats = const <int>{},
    this.selectedSeats = const <int>{},
    this.onSeatTap,
    this.vendorMode = false,
    this.busy = false,
    this.loadState = SeatMapLoadState.ready,
    this.conflictMessage,
    this.errorMessage,
    this.onRetry,
    this.seatSelectorBuilder,
    this.selectedSummaryBuilder,
    super.key,
  });

  final Set<int> bookedSeats;
  final Set<int> myConfirmedSeats;
  final Set<int> selectedSeats;
  final ValueChanged<int>? onSeatTap;
  final bool vendorMode;
  final bool busy;
  final SeatMapLoadState loadState;
  final String? conflictMessage;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final SeatTileSelectorBuilder? seatSelectorBuilder;
  final WidgetBuilder? selectedSummaryBuilder;

  @override
  State<SeatMapView> createState() => _SeatMapViewState();
}

class _SeatMapViewState extends State<SeatMapView> {
  bool _listMode = false;
  int _selectedRow = 1;

  int get _bookedTotal =>
      widget.bookedSeats.union(widget.myConfirmedSeats).length;

  bool get _isSoldOut => _bookedTotal >= SeatLayout.totalSeats;

  Widget _buildSeat(BuildContext context, int seatNumber) {
    Widget buildTile(
      BuildContext context,
      SeatVisualStatus status,
      bool isBusy,
    ) {
      return SeatTile(
        seatNumber: seatNumber,
        status: status,
        onTap: widget.onSeatTap,
        readOnly: widget.vendorMode,
        busy: isBusy,
        listMode: _listMode,
      );
    }

    if (widget.seatSelectorBuilder != null) {
      return widget.seatSelectorBuilder!(context, seatNumber, buildTile);
    }

    final status = SeatLayout.statusForSeat(
      seatNumber,
      bookedSeats: widget.bookedSeats,
      myConfirmedSeats: widget.myConfirmedSeats,
      selectedSeats: widget.selectedSeats,
      vendorMode: widget.vendorMode,
    );
    return buildTile(context, status, widget.busy);
  }

  Widget _buildGridRow(BuildContext context, SeatRowSpec row) {
    const spacing = 4.0;
    const aisleWidth = 12.0;

    return Padding(
      key: ValueKey<String>('seat-grid-row-${row.rowNumber}'),
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          for (var i = 0; i < row.leadingSeats.length; i++) ...<Widget>[
            if (i > 0) SizedBox(width: spacing),
            _buildSeat(context, row.leadingSeats[i]),
          ],
          if (row.hasCentralAisle) ...<Widget>[
            SizedBox(
              key: ValueKey<String>('seat-aisle-row-${row.rowNumber}'),
              width: aisleWidth,
            ),
            for (var i = 0; i < row.trailingSeats.length; i++) ...<Widget>[
              if (i > 0) SizedBox(width: spacing),
              _buildSeat(context, row.trailingSeats[i]),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildStageMap(BuildContext context) {
    final gridColumn = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final row in SeatLayout.rows) _buildGridRow(context, row),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outline,
                width: 3,
              ),
            ),
            borderRadius: const BorderRadius.vertical(
              top: Radius.elliptical(180, 24),
              bottom: Radius.circular(8),
            ),
          ),
          child: Text(
            'Arena floor',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            return ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: FittedBox(
                key: const ValueKey<String>('seat-map-fit-box'),
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: gridColumn,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRowListView(BuildContext context) {
    final activeRow = SeatLayout.rowSpec(_selectedRow);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (final row in SeatLayout.rows)
              ChoiceChip(
                key: ValueKey<String>('row-tab-${row.rowNumber}'),
                label: Text('Row ${row.rowNumber}'),
                selected: _selectedRow == row.rowNumber,
                onSelected: (_) => setState(() => _selectedRow = row.rowNumber),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          key: ValueKey<String>('row-list-seats-${activeRow.rowNumber}'),
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final seat in activeRow.seats) _buildSeat(context, seat),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.loadState) {
      case SeatMapLoadState.loading:
        return const ArenaLoadingView(label: 'Loading seats…');
      case SeatMapLoadState.unavailable:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: ArenaStatusPanel(
              icon: Icons.event_busy_outlined,
              title: 'Show unavailable',
              message: 'This show or session no longer accepts bookings.',
            ),
          ),
        );
      case SeatMapLoadState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ArenaStatusPanel(
              icon: Icons.error_outline,
              isError: true,
              title: 'Unable to load seats',
              message:
                  widget.errorMessage ??
                  'Your existing choices are preserved. Please retry.',
              actionLabel: widget.onRetry != null ? 'Try again' : null,
              onAction: widget.onRetry,
            ),
          ),
        );
      case SeatMapLoadState.ready:
        break;
    }

    final sortedSelected = widget.selectedSeats.toList()..sort();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: ArenaNoticeBanner(
              key: ValueKey<String>('seat-busy-banner'),
              icon: Icons.hourglass_top_outlined,
              message: 'Submitting booking… Please wait.',
              emphasizeText: true,
              iconSpacing: 10,
            ),
          ),
        if (widget.conflictMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ArenaNoticeBanner(
              key: const ValueKey<String>('seat-conflict-banner'),
              icon: Icons.warning_amber_rounded,
              message: widget.conflictMessage!,
              isError: true,
              liveRegion: true,
              emphasizeText: true,
              iconSpacing: 10,
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              Text('Booked', style: Theme.of(context).textTheme.bodyMedium),
              Text(
                '$_bookedTotal / ${SeatLayout.totalSeats}',
                key: const ValueKey<String>('seat-booked-count'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
        if (_isSoldOut)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: ArenaNoticeBanner(
              key: ValueKey<String>('seat-sold-out-banner'),
              icon: Icons.info_outline,
              message: 'Sold out. All seats booked.',
              emphasizeText: true,
              iconSpacing: 10,
            ),
          ),
        Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (_listMode)
                  _buildRowListView(context)
                else
                  _buildStageMap(context),
                const SizedBox(height: 12),
                SeatLegend(vendorMode: widget.vendorMode),
              ],
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            OutlinedButton(
              key: const ValueKey<String>('seat-mode-toggle'),
              onPressed: () => setState(() => _listMode = !_listMode),
              child: Text(_listMode ? 'Show map' : 'Row list'),
            ),
          ],
        ),
        if (!widget.vendorMode) ...<Widget>[
          const SizedBox(height: 8),
          if (widget.selectedSummaryBuilder != null)
            widget.selectedSummaryBuilder!(context)
          else
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                Text(
                  'Selected seats',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  sortedSelected.isEmpty ? 'None' : sortedSelected.join(', '),
                  key: const ValueKey<String>('seat-selected-summary'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
        ],
      ],
    );
  }
}
