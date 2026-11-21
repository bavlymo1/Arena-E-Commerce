import 'package:flutter/material.dart';

import '../vendor_access_strings.dart';

/// Shared ArenaPass Console scaffold used by vendor access gate screens.
class VendorAccessScaffold extends StatelessWidget {
  const VendorAccessScaffold({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: <Widget>[
            _VendorAccessBrandMark(
              background: colorScheme.primary,
              foreground: colorScheme.onPrimary,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                VendorAccessStrings.consoleTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: <Widget>[
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      VendorAccessStrings.screenTitle,
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...children,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wrapping button label/icon content that prevents horizontal overflow at 2.0x scale.
class VendorAccessButtonContent extends StatelessWidget {
  const VendorAccessButtonContent({
    required this.icon,
    required this.label,
    super.key,
  });

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        icon,
        const SizedBox(width: 8),
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
  }
}

class _VendorAccessBrandMark extends StatelessWidget {
  const _VendorAccessBrandMark({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 28,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'A',
          style: TextStyle(
            color: foreground,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}
