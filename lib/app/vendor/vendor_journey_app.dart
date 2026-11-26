import 'package:flutter/material.dart';

import '../../features/vendor_shows/presentation/cubit/show_form_cubit.dart';
import '../../features/vendor_shows/presentation/cubit/vendor_show_details_cubit.dart';
import '../../features/vendor_shows/presentation/cubit/vendor_shows_cubit.dart';
import '../router/vendor_router.dart';
import '../startup/arena_pass_app.dart';
import '../theme/app_theme.dart';

/// Shared vendor MaterialApp shell; root owners manage DI container disposal.
class VendorJourneyApp extends StatefulWidget {
  const VendorJourneyApp({
    required this.createShowsCubit,
    required this.createDetailsCubit,
    this.createShowFormCubit,
    this.hasUpdates = false,
    this.title = 'ArenaPass Vendor',
    this.banner,
    super.key,
  });

  final VendorShowsCubit Function() createShowsCubit;
  final VendorShowDetailsCubit Function(String showId) createDetailsCubit;
  final ShowFormCubit Function()? createShowFormCubit;
  final bool hasUpdates;
  final String title;
  final String? banner;

  @override
  State<VendorJourneyApp> createState() => _VendorJourneyAppState();
}

class _VendorJourneyAppState extends State<VendorJourneyApp> {
  late final router = createVendorRouter(
    createShowsCubit: widget.createShowsCubit,
    createDetailsCubit: widget.createDetailsCubit,
    createShowFormCubit: widget.createShowFormCubit,
    hasUpdates: widget.hasUpdates,
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
      darkTheme: buildAppTheme(brightness: Brightness.dark),
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      builder: bannerText == null
          ? null
          : (context, child) => wrapWithEnvironmentBanner(
              context,
              banner: bannerText,
              child: child!,
            ),
    );
  }
}
