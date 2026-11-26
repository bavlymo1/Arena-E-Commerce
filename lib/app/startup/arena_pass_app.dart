import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import 'app_variant.dart';
import 'startup_cubit.dart';
import 'startup_screen.dart';

/// Wraps an app navigator with a top environment banner when [banner] is non-null.
Widget wrapWithEnvironmentBanner(
  BuildContext context, {
  required String banner,
  required Widget child,
}) => Column(
  children: [
    Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(banner, textAlign: TextAlign.center),
        ),
      ),
    ),
    Expanded(child: child),
  ],
);

/// Owns its isolated composition container and router for this app instance.
class ArenaPassApp extends StatefulWidget {
  const ArenaPassApp({
    required this.services,
    this.startupTitle = 'Setup pending',
    super.key,
  });
  final GetIt services;
  final String startupTitle;

  @override
  State<ArenaPassApp> createState() => _ArenaPassAppState();
}

class _ArenaPassAppState extends State<ArenaPassApp> {
  late final variant = widget.services<AppVariant>();
  late final router = GoRouter(
    initialLocation: '/startup',
    redirect: (context, state) =>
        state.uri.path == '/startup' ? null : '/startup',
    routes: [
      GoRoute(
        path: '/startup',
        builder: (context, state) => BlocProvider(
          create: (_) => widget.services<StartupCubit>()..retry(),
          child: StartupScreen(variant: variant, title: widget.startupTitle),
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
    title: 'ArenaPass ${variant.label}',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    darkTheme: buildAppTheme(brightness: Brightness.dark),
    routerConfig: router,
  );
}
