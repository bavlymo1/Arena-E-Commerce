import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../features/customer_auth/presentation/cubit/customer_auth_cubit.dart';
import '../../features/customer_auth/presentation/cubit/customer_auth_state.dart';
import '../../features/customer_auth/presentation/screens/login_screen.dart';
import '../../features/customer_auth/presentation/screens/register_screen.dart';
import '../../features/customer_auth/presentation/screens/account_screen.dart';
import '../../features/vendor_shows/domain/repositories/shows_repository.dart';
import '../../features/booking/domain/repositories/booking_repository.dart';
import '../../features/booking/presentation/cubit/booking_cubit.dart';
import '../../features/booking/presentation/cubit/seat_selection_cubit.dart';
import '../../features/booking/presentation/screens/booking_result_screen.dart';
import '../../features/booking/presentation/screens/seat_selection_screen.dart';
import '../theme/app_theme.dart';
import '../startup/startup_screen.dart';
import '../startup/startup_cubit.dart';
import '../startup/app_variant.dart';

/// Presentation builders let the separately owned discovery screens join the
/// same route graph without a second implementation of those screens.
class CustomerJourneyApp extends StatefulWidget {
  const CustomerJourneyApp({
    required this.services,
    required this.discoverBuilder,
    required this.detailsBuilder,
    this.initialLocation = '/discover',
    this.auth,
    super.key,
  });
  final GetIt services;
  final Widget Function(BuildContext, ValueChanged<String>) discoverBuilder;
  final Widget Function(BuildContext, String, ValueChanged<String>)
  detailsBuilder;
  final String initialLocation;
  final CustomerAuthCubit? auth;

  @override
  State<CustomerJourneyApp> createState() => _CustomerJourneyAppState();
}

class _CustomerJourneyAppState extends State<CustomerJourneyApp> {
  final _authRefresh = ValueNotifier<int>(0);
  StreamSubscription<CustomerAuthState>? _authSubscription;
  String? _sessionUid;
  int _sessionEpoch = 0;

  @override
  void initState() {
    super.initState();
    _sessionUid = widget.auth?.state.isSignedIn == true
        ? widget.auth!.state.user!.uid
        : null;
    _authSubscription = widget.auth?.stream.listen((state) {
      final uid = state.isSignedIn ? state.user!.uid : null;
      if (uid != _sessionUid) {
        if (_sessionUid != null) {
          widget.services<ShowsRepository>().clearPosterCache();
        }
        _sessionUid = uid;
        _sessionEpoch++;
        router.go(
          uid == null
              ? (state.isChecking ? '/startup' : '/login')
              : '/discover',
        );
      }
      _authRefresh.value++;
    });
  }

  static String details(String showId) =>
      '/show/${Uri.encodeComponent(showId)}';
  static String seats(String showId, String sessionId) =>
      '${details(showId)}/session/${Uri.encodeComponent(sessionId)}';
  late final router = GoRouter(
    initialLocation: widget.auth == null ? widget.initialLocation : '/startup',
    refreshListenable: _authRefresh,
    redirect: (context, route) {
      final auth = widget.auth;
      if (auth == null) return null;
      final state = auth.state;
      final path = route.uri.path;
      if (state.isChecking) return path == '/startup' ? null : '/startup';
      if (!state.isSignedIn) {
        return path == '/login' || path == '/register' ? null : '/login';
      }
      return path == '/startup' || path == '/login' || path == '/register'
          ? '/discover'
          : null;
    },
    routes: [
      if (widget.auth != null) ...[
        GoRoute(
          path: '/startup',
          builder: (_, _) => BlocProvider(
            create: (_) => StartupCubit(() async => 'Checking session'),
            child: const StartupScreen(
              variant: AppVariant.customer,
              title: 'Checking session',
            ),
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (context, _) => PopScope(
            canPop: false,
            child: LoginScreen(
              onRegisterRequested: () => context.go('/register'),
            ),
          ),
        ),
        GoRoute(
          path: '/register',
          builder: (context, _) =>
              RegisterScreen(onLoginRequested: () => context.go('/login')),
        ),
        GoRoute(path: '/account', builder: (_, _) => const AccountScreen()),
      ],
      GoRoute(
        path: '/discover',
        builder: (context, state) => KeyedSubtree(
          key: ValueKey(('discover', _sessionEpoch)),
          child: widget.discoverBuilder(
            context,
            (showId) => context.push(details(showId)),
          ),
        ),
      ),
      GoRoute(
        path: '/show/:showId',
        builder: (context, state) {
          final showId = state.pathParameters['showId']!;
          return KeyedSubtree(
            key: ValueKey(('details', _sessionEpoch, showId)),
            child: widget.detailsBuilder(context, showId, (sessionId) {
              if (widget.services.isRegistered<BookingRepository>()) {
                context.push(seats(showId, sessionId));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Booking backend setup pending.'),
                  ),
                );
              }
            }),
          );
        },
      ),
      if (widget.services.isRegistered<BookingRepository>())
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
    unawaited(_authSubscription?.cancel());
    _authRefresh.dispose();
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
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                widget.auth == null
                    ? 'LOCAL DEMO · sample account and data · resets on restart'
                    : 'LOCAL EMULATORS · booking setup pending',
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
