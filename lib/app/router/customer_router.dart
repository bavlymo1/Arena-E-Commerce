import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/booking/presentation/cubit/booking_cubit.dart';
import '../../features/booking/presentation/cubit/seat_selection_cubit.dart';
import '../../features/booking/presentation/screens/booking_result_screen.dart';
import '../../features/booking/presentation/screens/seat_selection_screen.dart';
import '../../features/customer_auth/presentation/cubit/customer_auth_state.dart';
import '../../features/customer_auth/presentation/screens/account_screen.dart';
import '../../features/customer_auth/presentation/screens/login_screen.dart';
import '../../features/customer_auth/presentation/screens/register_screen.dart';
import '../../features/discovery/presentation/cubit/discovery_cubit.dart';
import '../../features/discovery/presentation/cubit/show_details_cubit.dart';
import '../../features/discovery/presentation/screens/discovery_screen.dart';
import '../../features/discovery/presentation/screens/show_details_screen.dart';
import '../startup/app_variant.dart';
import '../startup/startup_cubit.dart';
import '../startup/startup_screen.dart';
import 'app_routes.dart';

/// Builds Customer navigation configuration without holding DI container state.
GoRouter createCustomerRouter({
  String initialLocation = AppRoutes.customerDiscover,
  Listenable? refreshListenable,
  CustomerAuthState Function()? readAuthState,
  required int Function() readSessionEpoch,
  required bool hasShows,
  DiscoveryCubit Function()? createDiscoveryCubit,
  ShowDetailsCubit Function(String showId)? createShowDetailsCubit,
  SeatSelectionCubit Function(String showId, String sessionId)?
  createSeatSelectionCubit,
  BookingCubit Function(String showId, String sessionId)? createBookingCubit,
  Widget Function(BuildContext, ValueChanged<String>)? discoverBuilder,
  Widget Function(BuildContext, String, ValueChanged<String>)? detailsBuilder,
}) {
  final hasBooking =
      createSeatSelectionCubit != null && createBookingCubit != null;

  return GoRouter(
    initialLocation: readAuthState == null
        ? initialLocation
        : AppRoutes.customerStartup,
    refreshListenable: refreshListenable,
    redirect: (context, route) {
      if (readAuthState == null) return null;
      final state = readAuthState();
      final path = route.uri.path;
      if (state.isChecking) {
        return path == AppRoutes.customerStartup
            ? null
            : AppRoutes.customerStartup;
      }
      if (!state.isSignedIn) {
        return path == AppRoutes.customerLogin ||
                path == AppRoutes.customerRegister
            ? null
            : AppRoutes.customerLogin;
      }
      if (!hasShows) {
        return path == AppRoutes.customerAccount
            ? null
            : AppRoutes.customerAccount;
      }
      return path == AppRoutes.customerStartup ||
              path == AppRoutes.customerLogin ||
              path == AppRoutes.customerRegister
          ? AppRoutes.customerDiscover
          : null;
    },
    routes: [
      if (readAuthState != null) ...[
        GoRoute(
          path: AppRoutes.customerStartup,
          builder: (_, _) => BlocProvider(
            create: (_) => StartupCubit(() async => 'Checking session'),
            child: const StartupScreen(
              variant: AppVariant.customer,
              title: 'Checking session',
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.customerLogin,
          builder: (context, _) => PopScope(
            canPop: false,
            child: LoginScreen(
              onRegisterRequested: () => context.go(AppRoutes.customerRegister),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.customerRegister,
          builder: (context, _) => RegisterScreen(
            onLoginRequested: () => context.go(AppRoutes.customerLogin),
          ),
        ),
        GoRoute(
          path: AppRoutes.customerAccount,
          builder: (_, _) => const AccountScreen(),
        ),
      ],
      GoRoute(
        path: AppRoutes.customerDiscover,
        builder: (context, _) => KeyedSubtree(
          key: ValueKey(('discover', readSessionEpoch())),
          child: discoverBuilder != null
              ? discoverBuilder(
                  context,
                  (showId) =>
                      context.push(AppRoutes.customerShowDetailsPath(showId)),
                )
              : BlocProvider(
                  create: (_) => createDiscoveryCubit!(),
                  child: DiscoveryScreen(
                    onShowSelected: (showId) =>
                        context.push(AppRoutes.customerShowDetailsPath(showId)),
                    onAccount: readAuthState == null
                        ? null
                        : () => context.push(AppRoutes.customerAccount),
                  ),
                ),
        ),
      ),
      GoRoute(
        path: AppRoutes.customerShowDetails,
        builder: (context, state) {
          final showId = state.pathParameters[AppRoutes.showIdParam]!;
          void openSession(String sessionId) {
            if (hasBooking) {
              context.push(
                AppRoutes.customerSeatSelectionPath(showId, sessionId),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Booking backend setup pending.')),
              );
            }
          }

          return KeyedSubtree(
            key: ValueKey(('details', readSessionEpoch(), showId)),
            child: detailsBuilder != null
                ? detailsBuilder(context, showId, openSession)
                : BlocProvider(
                    create: (_) => createShowDetailsCubit!(showId),
                    child: PopScope(
                      canPop: Navigator.canPop(context),
                      onPopInvokedWithResult: (didPop, _) {
                        if (!didPop) context.go(AppRoutes.customerDiscover);
                      },
                      child: ShowDetailsScreen(
                        onSessionSelected: openSession,
                        onBackToDiscover: () =>
                            context.go(AppRoutes.customerDiscover),
                      ),
                    ),
                  ),
          );
        },
      ),
      if (hasBooking)
        ShellRoute(
          builder: (context, state, child) {
            final showId = state.pathParameters[AppRoutes.showIdParam]!;
            final sessionId = state.pathParameters[AppRoutes.sessionIdParam]!;
            return MultiBlocProvider(
              key: ValueKey((readSessionEpoch(), showId, sessionId)),
              providers: [
                BlocProvider(
                  create: (_) => createSeatSelectionCubit(showId, sessionId),
                ),
                BlocProvider(
                  create: (_) => createBookingCubit(showId, sessionId),
                ),
              ],
              child: child,
            );
          },
          routes: [
            GoRoute(
              path: AppRoutes.customerSeatSelection,
              builder: (context, state) {
                final showId = state.pathParameters[AppRoutes.showIdParam]!;
                final sessionId =
                    state.pathParameters[AppRoutes.sessionIdParam]!;
                return SeatSelectionScreen(
                  onDetails: () =>
                      context.go(AppRoutes.customerShowDetailsPath(showId)),
                  onResult: (bookingId) => context.go(
                    AppRoutes.customerBookingResultPath(
                      showId,
                      sessionId,
                      bookingId,
                    ),
                  ),
                );
              },
            ),
            GoRoute(
              path: AppRoutes.customerBookingResult,
              builder: (context, state) {
                final showId = state.pathParameters[AppRoutes.showIdParam]!;
                final sessionId =
                    state.pathParameters[AppRoutes.sessionIdParam]!;
                return BookingResultScreen(
                  bookingId: state.pathParameters[AppRoutes.bookingIdParam]!,
                  onDetails: () =>
                      context.go(AppRoutes.customerShowDetailsPath(showId)),
                  onReviewMap: () {
                    context.read<BookingCubit>().newAttempt();
                    final selection = context.read<SeatSelectionCubit>();
                    selection.setSubmitting(false);
                    selection.clearSelection();
                    context.go(
                      AppRoutes.customerSeatSelectionPath(showId, sessionId),
                    );
                  },
                );
              },
            ),
          ],
        ),
    ],
  );
}
