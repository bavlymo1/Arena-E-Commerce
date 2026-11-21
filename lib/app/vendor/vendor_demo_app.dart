import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../features/vendor_shows/presentation/cubit/show_form_cubit.dart';
import '../../features/vendor_shows/presentation/cubit/vendor_show_details_cubit.dart';
import '../../features/vendor_shows/presentation/cubit/vendor_shows_cubit.dart';
import '../di/vendor_registration.dart';
import 'vendor_journey_router.dart';

VendorDemoApp createVendorDemoApp({GetIt? services}) =>
    VendorDemoApp(services: services ?? createDemoVendorServices());

/// Explicit local preview; enrollment and production startup remain pending.
class VendorDemoApp extends StatefulWidget {
  const VendorDemoApp({
    required this.services,
    this.banner = 'LOCAL DEMO · sample vendor and data · resets on restart',
    this.canAddShow = false,
    super.key,
  });
  final GetIt services;
  final String banner;
  final bool canAddShow;

  @override
  State<VendorDemoApp> createState() => _VendorDemoAppState();
}

class _VendorDemoAppState extends State<VendorDemoApp> {
  @override
  void dispose() {
    unawaited(widget.services.reset());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => VendorJourneyRouter(
    title: 'ArenaPass Vendor · Demo',
    banner: widget.banner,
    canAddShow: widget.canAddShow,
    createShowsCubit: () => widget.services<VendorShowsCubit>(),
    createShowFormCubit: widget.canAddShow
        ? () => widget.services<ShowFormCubit>()
        : null,
    createDetailsCubit: (showId) =>
        widget.services<VendorShowDetailsCubit>(param1: showId),
  );
}
