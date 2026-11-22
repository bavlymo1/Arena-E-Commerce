import 'package:e_commerce_project/app/theme/app_theme.dart';
import 'package:e_commerce_project/shared/widgets/arena_busy_button_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'ArenaBusyButtonLabel renders 18px spinner, label, default and custom stroke color',
    (tester) async {
      final theme = buildAppTheme(brightness: Brightness.light);

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: Column(
              children: <Widget>[
                FilledButton(
                  onPressed: null,
                  child: ArenaBusyButtonLabel(label: 'Saving show…'),
                ),
                OutlinedButton(
                  onPressed: null,
                  child: ArenaBusyButtonLabel(
                    label: 'Retrying…',
                    strokeColor: Colors.teal,
                    mainAxisAlignment: MainAxisAlignment.center,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Saving show…'), findsOneWidget);
      expect(find.text('Retrying…'), findsOneWidget);

      final spinners = tester
          .widgetList<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .toList();
      expect(spinners, hasLength(2));
      expect(spinners[0].strokeWidth, 2);
      expect(spinners[0].color, theme.colorScheme.onSurfaceVariant);
      expect(spinners[1].strokeWidth, 2);
      expect(spinners[1].color, Colors.teal);

      final spinnerBoxes = tester
          .widgetList<SizedBox>(
            find.ancestor(
              of: find.byType(CircularProgressIndicator),
              matching: find.byType(SizedBox),
            ),
          )
          .where((box) => box.width == 18 && box.height == 18);
      expect(spinnerBoxes, hasLength(2));
    },
  );

  testWidgets(
    'ArenaBusyButtonLabel wraps cleanly inside buttons on 300x640 at 2.0x scale',
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
            body: Padding(
              padding: EdgeInsets.all(16),
              child: FilledButton(
                onPressed: null,
                child: ArenaBusyButtonLabel(
                  label: 'Creating account…',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Creating account…'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
