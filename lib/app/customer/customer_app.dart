import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../features/customer_auth/domain/repositories/customer_auth_repository.dart';
import '../../features/customer_auth/presentation/cubit/customer_auth_cubit.dart';
import '../di/customer_registration.dart';
import '../startup/arena_pass_app.dart';
import 'customer_demo_app.dart';

Widget createCustomerApp({
  GetIt? services,
  String? banner = 'LOCAL EMULATORS',
}) {
  final graph = services ?? createCustomerServices();
  if (!graph.isRegistered<CustomerAuthRepository>()) {
    return ArenaPassApp(services: graph);
  }
  return BlocProvider(
    create: (_) => graph<CustomerAuthCubit>(),
    child: Builder(
      builder: (context) => createCustomerDemoApp(
        services: graph,
        auth: context.read<CustomerAuthCubit>(),
        banner: banner,
      ),
    ),
  );
}
