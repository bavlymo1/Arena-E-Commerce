import 'package:e_commerce_project/app/vendor/vendor_demo_app.dart';
import 'package:e_commerce_project/app/customer/demo_customer_repository.dart';
import 'package:e_commerce_project/app/di/vendor_registration.dart';
import 'package:e_commerce_project/features/booking/domain/models/booking_request.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/repositories/shows_repository.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/cubit/vendor_show_details_cubit.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/cubit/vendor_shows_cubit.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/screens/vendor_show_details_screen.dart';
import 'package:e_commerce_project/features/vendor_shows/presentation/screens/vendor_shows_screen.dart';
import 'package:e_commerce_project/shared/seating/widgets/seat_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('vendor list details session map and back own their Cubits', (
    tester,
  ) async {
    final services = createDemoVendorServices();
    await tester.pumpWidget(createVendorDemoApp(services: services));
    await tester.pumpAndSettle();
    expect(find.textContaining('LOCAL DEMO'), findsOneWidget);
    final list = tester
        .element(find.byType(VendorShowsScreen))
        .read<VendorShowsCubit>();
    await tester.tap(find.text('Skyline Jam'));
    await tester.pumpAndSettle();
    final details = tester
        .element(find.byType(VendorShowDetailsScreen))
        .read<VendorShowDetailsCubit>();
    expect(details.state.showId, 'demo-success');
    expect(details.state.vendorId, 'demo-vendor');
    expect(details.state.selectedSession!.bookedSeats, {7});
    final evening = find.byKey(const ValueKey('vendor-session-option-1900'));
    await tester.ensureVisible(evening);
    await tester.pumpAndSettle();
    await tester.tap(evening);
    await tester.pumpAndSettle();
    expect(details.state.selectedSession!.bookedSeats, {9, 18});
    final seat = find.byKey(const ValueKey('seat-grid-1'));
    await tester.ensureVisible(seat);
    await tester.pumpAndSettle();
    final tiles = tester.widgetList<SeatTile>(find.byType(SeatTile)).toList();
    expect(tiles, hasLength(47));
    expect(tiles.every((tile) => tile.readOnly), isTrue);
    await tester.tap(seat);
    await tester.pumpAndSettle();
    expect(details.state.selectedSession!.bookedSeats, {9, 18});
    expect(find.textContaining('Confirm'), findsNothing);
    final repository = services<ShowsRepository>() as DemoCustomerRepository;
    await repository.confirm(
      BookingRequest(
        bookingId: 'vendor-journey-customer-booking',
        customerUid: DemoCustomerRepository.customerUid,
        showId: 'demo-success',
        sessionId: '1900',
        seats: [1, 47],
      ),
    );
    await tester.pumpAndSettle();
    expect(details.state.selectedSession!.bookedSeats, {1, 9, 18, 47});
    expect(details.state.show!.bookedCount, 5);
    expect(list.state.shows.first.bookedCount, 5);
    await tester.tap(find.byTooltip('Back to My shows'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
    expect(details.isClosed, isTrue);
    expect(list.isClosed, isFalse);
    expect(find.byType(VendorShowsScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
    expect(list.isClosed, isTrue);
  });
}
