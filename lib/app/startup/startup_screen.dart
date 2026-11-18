import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_variant.dart';
import 'startup_cubit.dart';

class StartupScreen extends StatelessWidget {
  const StartupScreen({
    required this.variant,
    this.title = 'Setup pending',
    super.key,
  });
  final AppVariant variant;
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('ArenaPass ${variant.label}')),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: BlocBuilder<StartupCubit, StartupState>(
              builder: (context, state) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    variant == AppVariant.customer
                        ? Icons.confirmation_number_outlined
                        : Icons.storefront_outlined,
                    size: 56,
                  ),
                  const SizedBox(height: 24),
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  if (state.checking)
                    const CircularProgressIndicator()
                  else ...[
                    Text(state.message!, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: context.read<StartupCubit>().retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
