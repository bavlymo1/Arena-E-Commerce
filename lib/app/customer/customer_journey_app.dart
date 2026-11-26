import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../features/booking/domain/repositories/booking_repository.dart';
import '../../features/booking/presentation/cubit/booking_cubit.dart';
import '../../features/booking/presentation/cubit/seat_selection_cubit.dart';
import '../../features/customer_auth/presentation/cubit/customer_auth_cubit.dart';
import '../../features/customer_auth/presentation/cubit/customer_auth_state.dart';
import '../../features/discovery/presentation/cubit/discovery_cubit.dart';
import '../../features/discovery/presentation/cubit/show_details_cubit.dart';
import '../../features/vendor_shows/domain/repositories/shows_repository.dart';
import '../router/app_routes.dart';
import '../router/customer_router.dart';
import '../startup/arena_pass_app.dart';
import '../theme/app_theme.dart';

/// Root shell for Customer journeys owning auth lifecycle, router lifetime, and DI disposal.
class CustomerJourneyApp extends StatefulWidget {
  const CustomerJourneyApp({
    required this.services,
    this.discoverBuilder,
    this.detailsBuilder,
    this.initialLocation = AppRoutes.customerDiscover,
    this.auth,
    this.banner,
    super.key,
  });
  final GetIt services;
  final Widget Function(BuildContext, ValueChanged<String>)? discoverBuilder;
  final Widget Function(BuildContext, String, ValueChanged<String>)?
  detailsBuilder;
  final String initialLocation;
  final CustomerAuthCubit? auth;
  final String? banner;

  @override
  State<CustomerJourneyApp> createState() => _CustomerJourneyAppState();
}

class _CustomerJourneyAppState extends State<CustomerJourneyApp> {
  final _authRefresh = ValueNotifier<int>(0);
  StreamSubscription<CustomerAuthState>? _authSubscription;
  String? _sessionUid;
  int _sessionEpoch = 0;

  bool get _hasShows => widget.services.isRegistered<ShowsRepository>();
  bool get _hasBooking => widget.services.isRegistered<BookingRepository>();
  String get _home =>
      _hasShows ? AppRoutes.customerDiscover : AppRoutes.customerAccount;

  @override
  void initState() {
    super.initState();
    _sessionUid = widget.auth?.state.isSignedIn == true
        ? widget.auth!.state.user!.uid
        : null;
    _authSubscription = widget.auth?.stream.listen((state) {
      final uid = state.isSignedIn ? state.user!.uid : null;
      if (uid != _sessionUid) {
        if (_sessionUid != null && _hasShows) {
          widget.services<ShowsRepository>().clearPosterCache();
        }
        _sessionUid = uid;
        _sessionEpoch++;
        router.go(
          uid == null
              ? (state.isChecking
                    ? AppRoutes.customerStartup
                    : AppRoutes.customerLogin)
              : _home,
        );
      }
      _authRefresh.value++;
    });
  }

  late final router = createCustomerRouter(
    initialLocation: widget.initialLocation,
    refreshListenable: _authRefresh,
    readAuthState: widget.auth == null ? null : () => widget.auth!.state,
    readSessionEpoch: () => _sessionEpoch,
    hasShows: _hasShows,
    createDiscoveryCubit: _hasShows
        ? () => widget.services<DiscoveryCubit>()
        : null,
    createShowDetailsCubit: _hasShows
        ? (showId) => widget.services<ShowDetailsCubit>(param1: showId)
        : null,
    createSeatSelectionCubit: _hasBooking
        ? (showId, sessionId) => widget.services<SeatSelectionCubit>(
            param1: showId,
            param2: sessionId,
          )
        : null,
    createBookingCubit: _hasBooking
        ? (showId, sessionId) =>
              widget.services<BookingCubit>(param1: showId, param2: sessionId)
        : null,
    discoverBuilder: widget.discoverBuilder,
    detailsBuilder: widget.detailsBuilder,
  );

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    _authRefresh.dispose();
    router.dispose();
    unawaited(widget.services.reset());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bannerText = widget.banner;
    return MaterialApp.router(
      title: 'ArenaPass Customer',
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(brightness: Brightness.dark),
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      builder: !_hasShows || bannerText == null
          ? null
          : (context, child) => wrapWithEnvironmentBanner(
              context,
              banner: bannerText,
              child: child!,
            ),
    );
  }
}
