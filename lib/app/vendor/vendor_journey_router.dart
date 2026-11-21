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
import '../theme/app_theme.dart';

/// Shared vendor navigation graph; root owners manage DI container disposal.
class VendorJourneyRouter extends StatefulWidget {
  const VendorJourneyRouter({
    required this.createShowsCubit,
    required this.createDetailsCubit,
    this.createShowFormCubit,
    this.canAddShow = false,
    this.hasUpdates = false,
    this.title = 'ArenaPass Vendor',
    this.banner,
    super.key,
  });

  final VendorShowsCubit Function() createShowsCubit;
  final VendorShowDetailsCubit Function(String showId) createDetailsCubit;
  final ShowFormCubit Function()? createShowFormCubit;
  final bool canAddShow;
  final bool hasUpdates;
  final String title;
  final String? banner;

  @override
  State<VendorJourneyRouter> createState() => _VendorJourneyRouterState();
}

class _VendorJourneyRouterState extends State<VendorJourneyRouter> {
  void _returnToShows(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/shows');
    }
  }

  late final GoRouter router = GoRouter(
    initialLocation: '/shows',
    routes: [
      GoRoute(
        path: '/shows',
        builder: (context, _) => BlocProvider(
          create: (_) => widget.createShowsCubit(),
          child: widget.hasUpdates
              ? BlocSelector<
                  VendorNotificationsCubit,
                  VendorNotificationsState,
                  int
                >(
                  selector: (state) => state.unreadCount,
                  builder: (context, unreadCount) => VendorShowsScreen(
                    onAddShow: widget.canAddShow
                        ? () => context.push('/add-show')
                        : null,
                    onShowSelected: (id) =>
                        context.push('/show/${Uri.encodeComponent(id)}'),
                    onOpenUpdates: () => context.push('/updates'),
                    unreadUpdatesCount: unreadCount,
                  ),
                )
              : VendorShowsScreen(
                  onAddShow: widget.canAddShow
                      ? () => context.push('/add-show')
                      : null,
                  onShowSelected: (id) =>
                      context.push('/show/${Uri.encodeComponent(id)}'),
                ),
        ),
      ),
      GoRoute(
        path: '/add-show',
        redirect: (_, _) =>
            widget.canAddShow && widget.createShowFormCubit != null
            ? null
            : '/shows',
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: BlocProvider(
            create: (_) => widget.createShowFormCubit!(),
            child: AddShowScreen(
              onBackToShows: () => _returnToShows(context),
              onShowSaved: () => _returnToShows(context),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/show/:showId',
        builder: (context, state) => BlocProvider(
          key: ValueKey(state.pathParameters['showId']),
          create: (_) =>
              widget.createDetailsCubit(state.pathParameters['showId']!),
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
      if (widget.hasUpdates)
        GoRoute(
          path: '/updates',
          builder: (context, _) => VendorUpdatesScreen(
            onBackToShows: () => _returnToShows(context),
            onEventSelected: (event) =>
                context.push('/show/${Uri.encodeComponent(event.showId)}'),
          ),
        ),
    ],
  );

  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bannerText = widget.banner;
    return MaterialApp.router(
      title: widget.title,
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      builder: bannerText == null
          ? null
          : (context, child) => Column(
              children: [
                Material(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(bannerText, textAlign: TextAlign.center),
                    ),
                  ),
                ),
                Expanded(child: child!),
              ],
            ),
    );
  }
}
