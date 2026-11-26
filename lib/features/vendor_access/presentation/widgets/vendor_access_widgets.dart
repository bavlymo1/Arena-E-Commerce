import 'package:flutter/material.dart';

import '../../../../shared/widgets/arena_brand_app_bar_title.dart';
import '../vendor_access_strings.dart';

/// Shared ArenaPass Console scaffold used by vendor access gate screens.
class VendorAccessScaffold extends StatelessWidget {
  const VendorAccessScaffold({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const ArenaBrandAppBarTitle(
          title: VendorAccessStrings.screenTitle,
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
                  children: children,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
