import 'package:e_commerce_project/app/theme/app_theme.dart';
import 'package:e_commerce_project/features/vendor_notifications/presentation/widgets/alert_permission_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'AlertPermissionBanner triggers retry callback without overflow in light and dark @ 2.0x scale',
    (tester) async {
      tester.view.physicalSize = const Size(300, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      var retries = 0;
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(brightness: brightness),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: AlertPermissionBanner(
                  onRetryPermission: () => retries++,
                ),
              ),
            ),
          ),
        );

        expect(
          find.text('Device alerts are off. New bookings still appear here.'),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(
            const ValueKey<String>('vendor-updates-permission-retry-button'),
          ),
        );
        expect(tester.takeException(), isNull);
      }
      expect(retries, 2);
    },
  );
}
