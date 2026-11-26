import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/vendor_notifications/presentation/cubit/vendor_notifications_cubit.dart';
import '../../features/vendor_notifications/presentation/cubit/vendor_notifications_state.dart';
import '../../features/vendor_notifications/presentation/screens/vendor_updates_screen.dart';
import '../../features/vendor_shows/presentation/cubit/show_form_cubit.dart';
import '../../features/vendor_shows/presentation/cubit/vendor_show_details_cubit.dart';
import '../../features/vendor_shows/presentation/cubit/vendor_shows_cubit.dart';
import '../../features/vendor_shows/presentation/screens/add_show_screen.dart';
import '../../features/vendor_shows/presentation/screens/vendor_show_details_screen.dart';
import '../../features/vendor_shows/presentation/screens/vendor_shows_screen.dart';
import 'app_routes.dart';

void _returnToShows(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(AppRoutes.vendorShows);
  }
}

/// Builds Vendor navigation configuration without owning shell theme or DI state.
GoRouter createVendorRouter({
  required VendorShowsCubit Function() createShowsCubit,
  required VendorShowDetailsCubit Function(String showId) createDetailsCubit,
  ShowFormCubit Function()? createShowFormCubit,
  bool hasUpdates = false,
}) => GoRouter(
  initialLocation: AppRoutes.vendorShows,
  routes: [
    GoRoute(
      path: AppRoutes.vendorShows,
      builder: (context, _) => BlocProvider(
        create: (_) => createShowsCubit(),
        child: hasUpdates
            ? BlocSelector<
                VendorNotificationsCubit,
                VendorNotificationsState,
                int
              >(
                selector: (state) => state.unreadCount,
                builder: (context, unreadCount) => VendorShowsScreen(
                  onAddShow: createShowFormCubit != null
                      ? () => context.push(AppRoutes.vendorAddShow)
                      : null,
                  onShowSelected: (id) =>
                      context.push(AppRoutes.vendorShowDetailsPath(id)),
                  onOpenUpdates: () => context.push(AppRoutes.vendorUpdates),
                  unreadUpdatesCount: unreadCount,
                ),
              )
            : VendorShowsScreen(
                onAddShow: createShowFormCubit != null
                    ? () => context.push(AppRoutes.vendorAddShow)
                    : null,
                onShowSelected: (id) =>
                    context.push(AppRoutes.vendorShowDetailsPath(id)),
              ),
      ),
    ),
    GoRoute(
      path: AppRoutes.vendorAddShow,
      redirect: (_, _) =>
          createShowFormCubit != null ? null : AppRoutes.vendorShows,
      pageBuilder: (context, state) => MaterialPage<void>(
        key: state.pageKey,
        child: BlocProvider(
          create: (_) => createShowFormCubit!(),
          child: AddShowScreen(
            onBackToShows: () => _returnToShows(context),
            onShowSaved: () => _returnToShows(context),
          ),
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.vendorShowDetails,
      builder: (context, state) {
        final showId = state.pathParameters[AppRoutes.showIdParam]!;
        return BlocProvider(
          key: ValueKey(showId),
          create: (_) => createDetailsCubit(showId),
          child: PopScope(
            canPop: Navigator.canPop(context),
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) context.go(AppRoutes.vendorShows);
            },
            child: VendorShowDetailsScreen(
              onBackToShows: () => context.go(AppRoutes.vendorShows),
            ),
          ),
        );
      },
    ),
    if (hasUpdates)
      GoRoute(
        path: AppRoutes.vendorUpdates,
        builder: (context, _) => VendorUpdatesScreen(
          onBackToShows: () => _returnToShows(context),
          onEventSelected: (event) =>
              context.push(AppRoutes.vendorShowDetailsPath(event.showId)),
        ),
      ),
  ],
);
