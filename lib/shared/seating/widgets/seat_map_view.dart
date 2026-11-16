import 'package:flutter/material.dart';

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
    this.unavailableMessage,
    this.onRetry,
    this.seatSelectorBuilder,
    this.selectedSummaryBuilder,
    this.initialListMode = false,
    this.initialEnlarged = false,
    this.initialRow = 1,
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
  final String? unavailableMessage;
  final VoidCallback? onRetry;
  final SeatTileSelectorBuilder? seatSelectorBuilder;
  final WidgetBuilder? selectedSummaryBuilder;
  final bool initialListMode;
  final bool initialEnlarged;
  final int initialRow;

  @override
  State<SeatMapView> createState() => _SeatMapViewState();
}

class _SeatMapViewState extends State<SeatMapView> {
  late bool _listMode = widget.initialListMode;
  late bool _enlarged = widget.initialEnlarged;
  late int _selectedRow = widget.initialRow.clamp(1, SeatLayout.rowCount);

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
        enlarged: _enlarged,
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
    final spacing = _enlarged ? 5.0 : 4.0;
    final aisleWidth = _enlarged ? 18.0 : 12.0;

    return Padding(
      key: ValueKey<String>('seat-grid-row-${row.rowNumber}'),
      padding: EdgeInsets.symmetric(vertical: _enlarged ? 4.5 : 3.5),
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
        if (_enlarged)
          SingleChildScrollView(
            key: const ValueKey<String>('seat-map-enlarged-scroll'),
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: gridColumn,
            ),
          )
        else
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
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Loading seats…'),
              ],
            ),
          ),
        );
      case SeatMapLoadState.unavailable:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.event_busy_outlined, size: 40),
                const SizedBox(height: 12),
                Text(
                  'Show unavailable',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.unavailableMessage ??
                      'This show or session no longer accepts bookings.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      case SeatMapLoadState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.error_outline, size: 40),
                const SizedBox(height: 12),
                Text(
                  'Unable to load seats',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.errorMessage ??
                      'Your existing choices are preserved. Please retry.',
                  textAlign: TextAlign.center,
                ),
                if (widget.onRetry != null) ...<Widget>[
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: widget.onRetry,
                    child: const Text('Try again'),
                  ),
                ],
              ],
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
          const _StatusBanner(
            key: ValueKey<String>('seat-busy-banner'),
            icon: Icons.hourglass_top_outlined,
            message: 'Submitting booking… Please wait.',
          ),
        if (widget.conflictMessage != null)
          _StatusBanner(
            key: const ValueKey<String>('seat-conflict-banner'),
            icon: Icons.warning_amber_rounded,
            message: widget.conflictMessage!,
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
          const _StatusBanner(
            key: ValueKey<String>('seat-sold-out-banner'),
            icon: Icons.info_outline,
            message: 'Sold out. All seats booked.',
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
            if (!_listMode)
              OutlinedButton(
                key: const ValueKey<String>('seat-zoom-toggle'),
                onPressed: () => setState(() => _enlarged = !_enlarged),
                child: Text(_enlarged ? 'Fit map' : 'Enlarge map'),
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

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.icon, required this.message, super.key});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
