import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../features/vendor_access/presentation/cubit/vendor_access_cubit.dart';
import '../../features/vendor_access/presentation/cubit/vendor_access_state.dart';
import '../../features/vendor_access/presentation/screens/vendor_access_gate.dart';
import '../../features/vendor_notifications/presentation/cubit/vendor_notifications_cubit.dart';
import '../../features/vendor_shows/presentation/cubit/show_form_cubit.dart';
import '../../features/vendor_shows/presentation/cubit/vendor_show_details_cubit.dart';
import '../../features/vendor_shows/presentation/cubit/vendor_shows_cubit.dart';
import '../theme/app_theme.dart';
import 'vendor_journey_router.dart';

/// Root owner for enrolled Vendor access gating, notifications, and routing.
class VendorEnrolledApp extends StatefulWidget {
  const VendorEnrolledApp({
    required this.services,
    this.canAddShow = true,
    this.banner,
    super.key,
  });

  final GetIt services;
  final bool canAddShow;
  final String? banner;

  @override
  State<VendorEnrolledApp> createState() => _VendorEnrolledAppState();
}

class _VendorEnrolledAppState extends State<VendorEnrolledApp> {
  @override
  void dispose() {
    unawaited(widget.services.reset());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<VendorAccessCubit>(
      create: (_) => widget.services<VendorAccessCubit>(),
      child: BlocBuilder<VendorAccessCubit, VendorAccessState>(
        builder: (context, accessState) {
          if (accessState is AccessAllowed) {
            return BlocProvider<VendorNotificationsCubit>(
              key: ValueKey<String>(accessState.vendorId),
              create: (_) => widget.services<VendorNotificationsCubit>(
                param1: accessState.vendorId,
              ),
              child: VendorJourneyRouter(
                key: ValueKey<String>('vendor-journey-${accessState.vendorId}'),
                title: 'ArenaPass Vendor',
                banner: widget.banner,
                canAddShow: widget.canAddShow,
                hasUpdates: true,
                createShowsCubit: () => widget.services<VendorShowsCubit>(
                  param1: accessState.vendorId,
                ),
                createShowFormCubit: widget.canAddShow
                    ? () => widget.services<ShowFormCubit>(
                        param1: accessState.vendorId,
                      )
                    : null,
                createDetailsCubit: (showId) =>
                    widget.services<VendorShowDetailsCubit>(
                      param1: accessState.vendorId,
                      param2: showId,
                    ),
              ),
            );
          }

          return MaterialApp(
            title: 'ArenaPass Vendor',
            theme: buildAppTheme(),
            darkTheme: buildAppTheme(brightness: Brightness.dark),
            debugShowCheckedModeBanner: false,
            home: VendorAccessGate(builder: (_, _) => const SizedBox.shrink()),
          );
        },
      ),
    );
  }
}
