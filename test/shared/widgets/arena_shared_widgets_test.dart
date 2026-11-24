import 'dart:typed_data';

import 'package:e_commerce_project/app/theme/app_theme.dart';
import 'package:e_commerce_project/shared/widgets/arena_brand_app_bar_title.dart';
import 'package:e_commerce_project/shared/widgets/arena_brand_mark.dart';
import 'package:e_commerce_project/shared/widgets/arena_busy_button_label.dart';
import 'package:e_commerce_project/shared/widgets/arena_icon_label.dart';
import 'package:e_commerce_project/shared/widgets/arena_loading_view.dart';
import 'package:e_commerce_project/shared/widgets/arena_notice_banner.dart';
import 'package:e_commerce_project/shared/widgets/arena_page_header.dart';
import 'package:e_commerce_project/shared/widgets/arena_poster_banner.dart';
import 'package:e_commerce_project/shared/widgets/arena_show_date_row.dart';
import 'package:e_commerce_project/shared/widgets/arena_status_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final Uint8List _validPng = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0xF8,
  0xCF,
  0xC0,
  0x50,
  0x0F,
  0x00,
  0x04,
  0x85,
  0x01,
  0x80,
  0x84,
  0xA9,
  0x8C,
  0x21,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

void main() {
  testWidgets(
    'ArenaBrandMark renders prototype badge colors and excludes semantics',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(brightness: Brightness.dark),
            home: const Scaffold(body: Center(child: ArenaBrandMark())),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.color, const Color(0xFFFF668E));
        expect(decoration.borderRadius, BorderRadius.circular(8));
        expect(tester.getSize(find.byType(ArenaBrandMark)), const Size(28, 30));
        expect(find.bySemanticsLabel('A'), findsNothing);
      } finally {
        handle.dispose();
      }
    },
  );

  testWidgets(
    'ArenaPosterBanner renders memory artwork and falls back on null or corrupt bytes',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Column(
              children: <Widget>[
                ArenaPosterBanner(title: 'Loaded Show', posterBytes: _validPng),
                const ArenaPosterBanner(
                  title: 'Fallback Show',
                  posterBytes: null,
                  fallbackLabel: 'ARENA CONSOLE',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.gaplessPlayback, isTrue);
      expect((image.image as ResizeImage).width, 720);
      expect(find.text('ARENA CONSOLE'), findsOneWidget);
      expect(find.bySemanticsLabel('Loaded Show artwork'), findsOneWidget);
      expect(find.bySemanticsLabel('Fallback Show artwork'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: ArenaPosterBanner(
              title: 'Corrupt Show',
              posterBytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LIVE AT ARENA CENTRAL'), findsOneWidget);
      expect(find.bySemanticsLabel('Corrupt Show artwork'), findsOneWidget);
    },
  );

  testWidgets(
    'ArenaNoticeBanner supports TextButton/OutlinedButton, liveRegion, and 300px 2.0x scale',
    (tester) async {
      tester.view.physicalSize = const Size(300, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      var textActionCalls = 0;
      var outlinedActionCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(brightness: Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2.0)),
            child: child!,
          ),
          home: Scaffold(
            body: ListView(
              children: <Widget>[
                ArenaNoticeBanner(
                  icon: Icons.error_outline,
                  message: 'Auth failed',
                  isError: true,
                  liveRegion: true,
                  useTextAction: true,
                  emphasizeText: true,
                  actionLabel: 'Retry auth',
                  actionKey: const ValueKey<String>('notice-text-action'),
                  onAction: () => textActionCalls++,
                ),
                ArenaNoticeBanner(
                  icon: Icons.info_outline,
                  message: 'Sync notice',
                  actionLabel: 'Retry sync',
                  actionKey: const ValueKey<String>('notice-outlined-action'),
                  onAction: () => outlinedActionCalls++,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(TextButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(
        tester
            .widget<Semantics>(
              find.descendant(
                of: find.byType(ArenaNoticeBanner).first,
                matching: find.byWidgetPredicate(
                  (w) => w is Semantics && w.properties.liveRegion == true,
                ),
              ),
            )
            .properties
            .liveRegion,
        isTrue,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('notice-text-action')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('notice-outlined-action')),
      );
      expect(textActionCalls, 1);
      expect(outlinedActionCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ArenaStatusPanel supports filled vs outlined actions and error icon tone',
    (tester) async {
      var primaryCalls = 0;
      var outlinedCalls = 0;
      final theme = buildAppTheme(brightness: Brightness.dark);

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Column(
              children: <Widget>[
                ArenaStatusPanel(
                  icon: Icons.error_outline,
                  title: 'Load failed',
                  message: 'Try reloading.',
                  actionLabel: 'Retry load',
                  actionKey: const ValueKey<String>('status-filled'),
                  onAction: () => primaryCalls++,
                  isError: true,
                ),
                ArenaStatusPanel(
                  icon: Icons.search_off_outlined,
                  title: 'No match',
                  message: 'Adjust query.',
                  actionLabel: 'Clear',
                  actionKey: const ValueKey<String>('status-outlined'),
                  onAction: () => outlinedCalls++,
                  useOutlinedAction: true,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
      final errorIcon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
      expect(errorIcon.color, theme.colorScheme.error);

      await tester.tap(find.byKey(const ValueKey<String>('status-filled')));
      await tester.tap(find.byKey(const ValueKey<String>('status-outlined')));
      expect(primaryCalls, 1);
      expect(outlinedCalls, 1);
    },
  );

  test('buildAppTheme configures shared prototype card, input, and button themes in light and dark modes', () {
    final expectedButtonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(13),
    );
    for (final brightness in Brightness.values) {
      final isDark = brightness == Brightness.dark;
      final expectedSurface = isDark
          ? const Color(0xFF1B1A1E)
          : const Color(0xFFFFFFFF);
      final expectedLine = isDark
          ? const Color(0xFF3A353F)
          : const Color(0xFFC7BAC5);
      final theme = buildAppTheme(brightness: brightness);
      final decoration = theme.inputDecorationTheme;
      expect(decoration.filled, isTrue);
      expect(decoration.fillColor, expectedSurface);
      for (final border in <InputBorder?>[
        decoration.border,
        decoration.enabledBorder,
      ]) {
        expect(border, isA<OutlineInputBorder>());
        final outline = border! as OutlineInputBorder;
        expect(outline.borderRadius, BorderRadius.circular(12));
        expect(outline.borderSide.color, expectedLine);
      }
      expect(theme.cardTheme.color, expectedSurface);
      expect(theme.cardTheme.elevation, 0);
      expect(theme.cardTheme.surfaceTintColor, Colors.transparent);
      expect(
        theme.cardTheme.shape,
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: expectedLine),
        ),
      );

      expect(
        theme.filledButtonTheme.style?.minimumSize?.resolve(<WidgetState>{}),
        const Size(0, 48),
      );
      expect(
        theme.filledButtonTheme.style?.shape?.resolve(<WidgetState>{}),
        expectedButtonShape,
      );
      expect(
        theme.outlinedButtonTheme.style?.minimumSize?.resolve(<WidgetState>{}),
        const Size(0, 48),
      );
      expect(
        theme.outlinedButtonTheme.style?.side?.resolve(<WidgetState>{}),
        BorderSide(color: expectedLine),
      );
      expect(
        theme.outlinedButtonTheme.style?.shape?.resolve(<WidgetState>{}),
        expectedButtonShape,
      );
      expect(
        theme.textButtonTheme.style?.minimumSize?.resolve(<WidgetState>{}),
        const Size(0, 44),
      );
      expect(
        theme.textButtonTheme.style?.shape?.resolve(<WidgetState>{}),
        expectedButtonShape,
      );
    }
  });

  testWidgets(
    'shared Batch 4 widgets and Card theme render cleanly in light/dark at 320px and 2.0x text scale',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (final brightness in Brightness.values) {
        final isDark = brightness == Brightness.dark;
        final expectedSurface = isDark
            ? const Color(0xFF1B1A1E)
            : const Color(0xFFFFFFFF);
        final expectedLine = isDark
            ? const Color(0xFF3A353F)
            : const Color(0xFFC7BAC5);
        final theme = buildAppTheme(brightness: brightness);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2.0)),
              child: child!,
            ),
            home: Scaffold(
              appBar: AppBar(
                title: const ArenaBrandAppBarTitle(
                  title: 'ArenaPass Console Very Long Title',
                ),
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const ArenaPageHeader(
                      eyebrow: 'ArenaPass',
                      title: 'Discover shows',
                      subtitle: 'Subtitle wraps cleanly on narrow screens.',
                    ),
                    const SizedBox(height: 12),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const ArenaShowDateRow(
                              showDate: '2026-12-20',
                              showIcon: true,
                              prominent: true,
                              dateLabelKey: ValueKey<String>('test-date-label'),
                              trailing: Chip(label: Text('Active')),
                            ),
                            const SizedBox(height: 12),
                            ArenaPosterBanner(
                              title: 'Sample',
                              posterBytes: _validPng,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {},
                      child: const ArenaIconLabel(
                        icon: Icons.add,
                        label: 'Add show with a longer wrapping label',
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(120, 48),
                      ),
                      onPressed: null,
                      child: const ArenaBusyButtonLabel(label: 'Saving…'),
                    ),
                    const SizedBox(height: 8),
                    const ArenaLoadingView(
                      label: 'Loading…',
                      padding: EdgeInsets.all(12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byKey(const ValueKey<String>('test-date-label')),
          findsOneWidget,
        );
        expect(find.text('Dec 20, 2026'), findsOneWidget);
        expect(find.text('2026-12-20'), findsOneWidget);
        expect(find.text('Discover shows'), findsOneWidget);
        final cardMaterial = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(Card),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(cardMaterial.color, expectedSurface);
        expect(cardMaterial.surfaceTintColor, Colors.transparent);
        expect(
          cardMaterial.shape,
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: expectedLine),
          ),
        );
        final outlinedMaterial = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(OutlinedButton),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(
          outlinedMaterial.shape,
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
            side: BorderSide(color: expectedLine),
          ),
        );
        final titleText = tester.widget<Text>(
          find.text('ArenaPass Console Very Long Title'),
        );
        expect(titleText.maxLines, 1);
        expect(titleText.overflow, TextOverflow.ellipsis);
        expect(tester.takeException(), isNull);
      }

      // Also verify compactSubtitle uses bodySmall vs default bodyMedium.
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: Column(
              children: <Widget>[
                ArenaPageHeader(
                  eyebrow: 'ArenaPass',
                  title: 'Default',
                  subtitle: 'Normal subtitle',
                ),
                ArenaPageHeader(
                  eyebrow: 'ArenaPass',
                  title: 'Compact',
                  subtitle: 'Compact subtitle',
                  compactSubtitle: true,
                ),
              ],
            ),
          ),
        ),
      );
      final normalSize = tester
          .widget<Text>(find.text('Normal subtitle'))
          .style
          ?.fontSize;
      final compactSize = tester
          .widget<Text>(find.text('Compact subtitle'))
          .style
          ?.fontSize;
      expect(compactSize, lessThan(normalSize!));
    },
  );
}
