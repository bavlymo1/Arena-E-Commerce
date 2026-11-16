import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import 'app_variant.dart';
import 'startup_cubit.dart';
import 'startup_screen.dart';

/// Owns its isolated composition container and router for this app instance.
class ArenaPassApp extends StatefulWidget {
  const ArenaPassApp({required this.services, super.key});
  final GetIt services;

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
          child: StartupScreen(variant: variant),
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
    routerConfig: router,
  );
}
