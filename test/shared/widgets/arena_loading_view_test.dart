import 'package:e_commerce_project/app/theme/app_theme.dart';
import 'package:e_commerce_project/shared/widgets/arena_loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'ArenaLoadingView renders centered spinner, label, key, and custom padding',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: ArenaLoadingView(
              key: ValueKey<String>('sample-loading'),
              label: 'Loading shows…',
              padding: EdgeInsets.symmetric(vertical: 48),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('sample-loading')),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading shows…'), findsOneWidget);

      final padding = tester.widget<Padding>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('sample-loading')),
          matching: find.byType(Padding),
        ),
      );
      expect(padding.padding, const EdgeInsets.symmetric(vertical: 48));
    },
  );

  testWidgets(
    'ArenaLoadingView uses 24px default padding and fits narrow 300x640 at 2.0x scale',
    (tester) async {
      tester.view.physicalSize = const Size(300, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(brightness: Brightness.dark),
          home: const Scaffold(
            body: ArenaLoadingView(label: 'Loading booking updates…'),
          ),
        ),
      );

      final padding = tester.widget<Padding>(
        find.descendant(
          of: find.byType(ArenaLoadingView),
          matching: find.byType(Padding),
        ),
      );
      expect(padding.padding, const EdgeInsets.all(24));
      expect(find.text('Loading booking updates…'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
