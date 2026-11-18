import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../features/customer_auth/presentation/cubit/customer_auth_cubit.dart';
import '../../features/discovery/presentation/cubit/discovery_cubit.dart';
import '../../features/discovery/presentation/cubit/show_details_cubit.dart';
import '../../features/discovery/presentation/screens/discovery_screen.dart';
import '../../features/discovery/presentation/screens/show_details_screen.dart';
import '../di/customer_journey_registration.dart';
import 'customer_journey_app.dart';

/// Explicit local fixtures; the normal Customer entry point stays unavailable.
CustomerJourneyApp createCustomerDemoApp({
  GetIt? services,
  CustomerAuthCubit? auth,
}) {
  final graph = services ?? createDemoCustomerServices();
  return CustomerJourneyApp(
    services: graph,
    auth: auth,
    discoverBuilder: (context, onShow) => BlocProvider(
      create: (_) => graph<DiscoveryCubit>(),
      child: DiscoveryScreen(
        onShowSelected: onShow,
        onAccount: auth == null ? null : () => context.push('/account'),
      ),
    ),
    detailsBuilder: (context, showId, onSession) => BlocProvider(
      key: ValueKey(showId),
      create: (_) => graph<ShowDetailsCubit>(param1: showId),
      child: PopScope(
        canPop: Navigator.canPop(context),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) context.go('/discover');
        },
        child: ShowDetailsScreen(
          onSessionSelected: onSession,
          onBackToDiscover: () => context.go('/discover'),
        ),
      ),
    ),
  );
}
