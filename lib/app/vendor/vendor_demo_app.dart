import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../features/vendor_shows/presentation/cubit/vendor_show_details_cubit.dart';
import '../../features/vendor_shows/presentation/cubit/vendor_shows_cubit.dart';
import '../../features/vendor_shows/presentation/screens/vendor_show_details_screen.dart';
import '../../features/vendor_shows/presentation/screens/vendor_shows_screen.dart';
import '../di/vendor_registration.dart';
import '../theme/app_theme.dart';

VendorDemoApp createVendorDemoApp({GetIt? services}) =>
    VendorDemoApp(services: services ?? createDemoVendorServices());

/// Explicit local preview; enrollment and production startup remain pending.
class VendorDemoApp extends StatefulWidget {
  const VendorDemoApp({required this.services, super.key});
  final GetIt services;

  @override
  State<VendorDemoApp> createState() => _VendorDemoAppState();
}

class _VendorDemoAppState extends State<VendorDemoApp> {
  late final router = GoRouter(
    initialLocation: '/shows',
    routes: [
      GoRoute(
        path: '/shows',
        builder: (context, _) => BlocProvider(
          create: (_) => widget.services<VendorShowsCubit>(),
          child: VendorShowsScreen(
            onShowSelected: (id) =>
                context.push('/show/${Uri.encodeComponent(id)}'),
          ),
        ),
      ),
      GoRoute(
        path: '/show/:showId',
        builder: (context, state) => BlocProvider(
          key: ValueKey(state.pathParameters['showId']),
          create: (_) => widget.services<VendorShowDetailsCubit>(
            param1: state.pathParameters['showId']!,
          ),
          child: PopScope(
            canPop: Navigator.canPop(context),
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) context.go('/shows');
            },
            child: VendorShowDetailsScreen(
              onBackToShows: () => context.go('/shows'),
            ),
          ),
        ),
      ),
    ],
  );

  @override
  void dispose() {
    router.dispose();
    unawaited(widget.services.reset());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'ArenaPass Vendor · Demo',
    theme: buildAppTheme(),
    debugShowCheckedModeBanner: false,
    routerConfig: router,
    builder: (context, child) => Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: const SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'LOCAL DEMO · sample vendor and data · resets on restart',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        Expanded(child: child!),
      ],
    ),
  );
}
