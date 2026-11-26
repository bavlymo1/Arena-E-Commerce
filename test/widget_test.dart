import 'package:e_commerce_project/app/customer/customer_app.dart';
import 'package:e_commerce_project/app/vendor/vendor_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final variant in ['Customer', 'Vendor']) {
    testWidgets('$variant starts unavailable and retry never grants access', (
      tester,
    ) async {
      await tester.pumpWidget(
        variant == 'Customer' ? createCustomerApp() : createVendorApp(),
      );
      await tester.pumpAndSettle();
      expect(find.text('ArenaPass $variant'), findsOneWidget);
      expect(find.text('Setup pending'), findsOneWidget);
      expect(find.textContaining('Cloud setup is pending'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Setup pending'), findsOneWidget);
      expect(find.text('Sign in'), findsNothing);
      expect(find.text('My Shows'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
