import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../features/booking/presentation/cubit/booking_cubit.dart';
import '../../features/booking/presentation/cubit/seat_selection_cubit.dart';
import '../../features/booking/presentation/screens/booking_result_screen.dart';
import '../../features/booking/presentation/screens/seat_selection_screen.dart';
import '../theme/app_theme.dart';

/// Presentation builders let the separately owned discovery screens join the
/// same route graph without a second implementation of those screens.
class CustomerJourneyApp extends StatefulWidget {
  const CustomerJourneyApp({
    required this.services,
    required this.discoverBuilder,
    required this.detailsBuilder,
    this.initialLocation = '/discover',
    super.key,
  });
  final GetIt services;
  final Widget Function(BuildContext, ValueChanged<String>) discoverBuilder;
  final Widget Function(BuildContext, String, ValueChanged<String>)
  detailsBuilder;
  final String initialLocation;

  @override
  State<CustomerJourneyApp> createState() => _CustomerJourneyAppState();
}

class _CustomerJourneyAppState extends State<CustomerJourneyApp> {
  static String details(String showId) =>
      '/show/${Uri.encodeComponent(showId)}';
  static String seats(String showId, String sessionId) =>
      '${details(showId)}/session/${Uri.encodeComponent(sessionId)}';
  late final router = GoRouter(
    initialLocation: widget.initialLocation,
    routes: [
      GoRoute(
        path: '/discover',
        builder: (context, state) => widget.discoverBuilder(
          context,
          (showId) => context.push(details(showId)),
        ),
      ),
      GoRoute(
        path: '/show/:showId',
        builder: (context, state) {
          final showId = state.pathParameters['showId']!;
          return widget.detailsBuilder(
            context,
            showId,
            (sessionId) => context.push(seats(showId, sessionId)),
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) {
          final showId = state.pathParameters['showId']!;
          final sessionId = state.pathParameters['sessionId']!;
          return MultiBlocProvider(
            key: ValueKey((showId, sessionId)),
            providers: [
              BlocProvider(
                create: (_) => widget.services<SeatSelectionCubit>(
                  param1: showId,
                  param2: sessionId,
                ),
              ),
              BlocProvider(
                create: (_) => widget.services<BookingCubit>(
                  param1: showId,
                  param2: sessionId,
                ),
              ),
            ],
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/show/:showId/session/:sessionId',
            builder: (context, state) {
              final showId = state.pathParameters['showId']!;
              final sessionId = state.pathParameters['sessionId']!;
              return SeatSelectionScreen(
                onDetails: () => context.go(details(showId)),
                onResult: (bookingId) => context.go(
                  '${seats(showId, sessionId)}/result/${Uri.encodeComponent(bookingId)}',
                ),
              );
            },
          ),
          GoRoute(
            path: '/show/:showId/session/:sessionId/result/:bookingId',
            builder: (context, state) {
              final showId = state.pathParameters['showId']!;
              final sessionId = state.pathParameters['sessionId']!;
              return BookingResultScreen(
                bookingId: state.pathParameters['bookingId']!,
                onDetails: () => context.go(details(showId)),
                onReviewMap: () {
                  context.read<BookingCubit>().newAttempt();
                  final selection = context.read<SeatSelectionCubit>();
                  selection.setSubmitting(false);
                  selection.clearSelection();
                  context.go(seats(showId, sessionId));
                },
              );
            },
          ),
        ],
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
    title: 'ArenaPass Customer · Demo',
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
                'LOCAL DEMO · sample account and data · resets on restart',
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
