import 'dart:async';

import 'package:e_commerce_project/app/theme/app_theme.dart';
import 'package:e_commerce_project/features/vendor_access/domain/models/vendor_access.dart';
import 'package:e_commerce_project/features/vendor_access/domain/repositories/vendor_access_repository.dart';
import 'package:e_commerce_project/features/vendor_access/presentation/cubit/vendor_access_cubit.dart';
import 'package:e_commerce_project/features/vendor_access/presentation/screens/vendor_access_gate.dart';
import 'package:e_commerce_project/features/vendor_access/presentation/screens/vendor_not_enrolled_screen.dart';
import 'package:e_commerce_project/features/vendor_access/presentation/vendor_access_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeVendorAccessRepository implements VendorAccessRepository {
  int checkCalls = 0;
  Future<VendorAccess> Function()? onCheck;

  @override
  Future<VendorAccess> check() {
    checkCalls++;
    final handler = onCheck;
    if (handler != null) {
      return handler();
    }
    return Future<VendorAccess>.value(VendorNotEnrolled(uid: 'fake-uid'));
  }
}

Widget _wrapGate({required VendorAccessCubit cubit, ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? buildAppTheme(),
    home: BlocProvider<VendorAccessCubit>.value(
      value: cubit,
      child: VendorAccessGate(
        builder: (context, allowed) => Scaffold(
          body: Center(child: Text('Allowed vendor: ${allowed.vendorId}')),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'VendorAccessGate renders checking, not-enrolled, error+retry, and allowed states',
    (tester) async {
      final firstGate = Completer<VendorAccess>();
      final retryGate = Completer<VendorAccess>();
      final thirdGate = Completer<VendorAccess>();
      var call = 0;
      final repo = _FakeVendorAccessRepository()
        ..onCheck = () {
          call++;
          return switch (call) {
            1 => firstGate.future,
            2 => retryGate.future,
            _ => thirdGate.future,
          };
        };
      final cubit = VendorAccessCubit(repo);

      try {
        await tester.pumpWidget(_wrapGate(cubit: cubit));
        await tester.pump();

        // 1. Checking state renders progress indicator and message.
        expect(
          find.byKey(
            const ValueKey<String>('vendor-access-checking-indicator'),
          ),
          findsOneWidget,
        );
        expect(find.text(VendorAccessStrings.checkingMessage), findsOneWidget);

        // 2. Error state renders safe message and Retry button.
        firstGate.completeError(StateError('internal emulator failure'));
        await tester.pumpAndSettle();
        expect(
          find.text(VendorAccessStrings.checkErrorMessage),
          findsOneWidget,
        );
        expect(find.textContaining('internal emulator'), findsNothing);
        expect(
          find.byKey(
            const ValueKey<String>('vendor-access-error-retry-button'),
          ),
          findsOneWidget,
        );

        // 3. Tapping Retry from error moves through checking -> not enrolled.
        await tester.tap(
          find.byKey(
            const ValueKey<String>('vendor-access-error-retry-button'),
          ),
        );
        await tester.pump();
        expect(repo.checkCalls, 2);
        expect(
          find.byKey(
            const ValueKey<String>('vendor-access-checking-indicator'),
          ),
          findsOneWidget,
        );

        retryGate.complete(VendorNotEnrolled(uid: 'anon-device-uid-77'));
        await tester.pumpAndSettle();

        expect(
          find.text(VendorAccessStrings.notEnrolledExplanation),
          findsOneWidget,
        );
        final idWidget = tester.widget<SelectableText>(
          find.byKey(const ValueKey<String>('vendor-access-device-id')),
        );
        expect(idWidget.data, 'anon-device-uid-77');

        // 4. Tapping Retry from not-enrolled triggers check and opens allowed child.
        await tester.tap(
          find.byKey(const ValueKey<String>('vendor-access-retry-button')),
        );
        await tester.pump();
        expect(repo.checkCalls, 3);
        expect(
          find.byKey(
            const ValueKey<String>('vendor-access-checking-indicator'),
          ),
          findsOneWidget,
        );

        thirdGate.complete(
          VendorAllowed(uid: 'anon-device-uid-77', vendorId: 'arena'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Allowed vendor: arena'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(cubit.close);
      }
    },
  );

  testWidgets(
    'Copy Device ID writes exact UID to clipboard and shows confirmation SnackBar',
    (tester) async {
      final clipboardCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboardCalls.add(call);
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      final repo = _FakeVendorAccessRepository()
        ..onCheck = () async => VendorNotEnrolled(uid: 'uid-clipboard-check-9');
      final cubit = VendorAccessCubit(repo);

      try {
        await tester.pumpWidget(_wrapGate(cubit: cubit));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey<String>('vendor-access-copy-button')),
        );
        await tester.pumpAndSettle();

        expect(clipboardCalls, hasLength(1));
        expect(clipboardCalls.single.method, 'Clipboard.setData');
        expect(clipboardCalls.single.arguments, <String, dynamic>{
          'text': 'uid-clipboard-check-9',
        });
        expect(find.text(VendorAccessStrings.deviceIdCopied), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(cubit.close);
      }
    },
  );

  testWidgets(
    'VendorNotEnrolledScreen displays inline loading indicator when isChecking is true',
    (tester) async {
      var retryCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: VendorNotEnrolledScreen(
            uid: 'uid-inline-loading',
            isChecking: true,
            onRetry: () => retryCount++,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(VendorAccessStrings.retrying), findsOneWidget);

      final retryButton = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey<String>('vendor-access-retry-button')),
      );
      expect(retryButton.onPressed, isNull);

      await tester.tap(
        find.byKey(const ValueKey<String>('vendor-access-retry-button')),
      );
      expect(retryCount, 0);
    },
  );

  testWidgets(
    'all gate states render cleanly at 300x640 and 2.0x text scale in light and dark themes',
    (tester) async {
      tester.view.physicalSize = const Size(300, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final themes = <String, ThemeData>{
        'light': buildAppTheme(),
        'dark': ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xffd52f65),
            brightness: Brightness.dark,
          ),
        ),
      };

      for (final themeEntry in themes.entries) {
        final gate1 = Completer<VendorAccess>();
        final gate2 = Completer<VendorAccess>();
        final gate3 = Completer<VendorAccess>();
        var call = 0;
        final repo = _FakeVendorAccessRepository()
          ..onCheck = () {
            call++;
            return switch (call) {
              1 => gate1.future,
              2 => gate2.future,
              _ => gate3.future,
            };
          };
        final cubit = VendorAccessCubit(repo);

        try {
          await tester.pumpWidget(
            _wrapGate(cubit: cubit, theme: themeEntry.value),
          );
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: '${themeEntry.key} checking',
          );

          gate1.complete(
            VendorNotEnrolled(
              uid: 'anon_vendor_device_1234567890abcdef_long_identifier',
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${themeEntry.key} not-enrolled',
          );

          final retryFinder = find.byKey(
            const ValueKey<String>('vendor-access-retry-button'),
          );
          await tester.scrollUntilVisible(
            retryFinder,
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${themeEntry.key} not-enrolled scroll',
          );

          await tester.tap(retryFinder);
          await tester.pump();
          gate2.completeError(StateError('offline'));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${themeEntry.key} error',
          );

          final errorRetryFinder = find.byKey(
            const ValueKey<String>('vendor-access-error-retry-button'),
          );
          await tester.scrollUntilVisible(
            errorRetryFinder,
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.tap(errorRetryFinder);
          await tester.pump();
          gate3.complete(VendorAllowed(uid: 'u1', vendorId: 'arena'));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${themeEntry.key} allowed',
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(cubit.close);
        }
      }
    },
  );

  testWidgets(
    'exposes semantics live regions, labels, and accessible touch targets',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final gate1 = Completer<VendorAccess>();
        final gate2 = Completer<VendorAccess>();
        var call = 0;
        final repo = _FakeVendorAccessRepository()
          ..onCheck = () => ++call == 1 ? gate1.future : gate2.future;
        final cubit = VendorAccessCubit(repo);

        try {
          await tester.pumpWidget(_wrapGate(cubit: cubit));
          await tester.pump();

          final checkingSemantics = tester.getSemantics(
            find.byKey(const ValueKey<String>('vendor-access-checking-panel')),
          );
          expect(checkingSemantics.flagsCollection.isLiveRegion, isTrue);

          gate1.complete(VendorNotEnrolled(uid: 'sem-uid-101'));
          await tester.pumpAndSettle();

          expect(
            find.bySemanticsLabel(VendorAccessStrings.copyDeviceId),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel(VendorAccessStrings.retry),
            findsOneWidget,
          );
          expect(
            tester
                .getSemantics(
                  find.text(VendorAccessStrings.notEnrolledExplanation),
                )
                .label,
            contains(VendorAccessStrings.notEnrolledExplanation),
          );
          expect(
            tester
                .getSemantics(
                  find.byKey(const ValueKey<String>('vendor-access-device-id')),
                )
                .value,
            'sem-uid-101',
          );

          final copySize = tester.getSize(
            find.byKey(const ValueKey<String>('vendor-access-copy-button')),
          );
          final retrySize = tester.getSize(
            find.byKey(const ValueKey<String>('vendor-access-retry-button')),
          );
          expect(copySize.height, greaterThanOrEqualTo(48));
          expect(retrySize.height, greaterThanOrEqualTo(48));

          await tester.tap(
            find.byKey(const ValueKey<String>('vendor-access-retry-button')),
          );
          await tester.pump();
          gate2.completeError(StateError('network error'));
          await tester.pumpAndSettle();

          final errorSemantics = tester.getSemantics(
            find.byKey(const ValueKey<String>('vendor-access-error-panel')),
          );
          expect(errorSemantics.flagsCollection.isLiveRegion, isTrue);
          expect(
            find.bySemanticsLabel(VendorAccessStrings.retry),
            findsOneWidget,
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(cubit.close);
        }
      } finally {
        semantics.dispose();
      }
    },
  );
}
